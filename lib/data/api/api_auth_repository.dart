import 'dart:io';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/api_config.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/strings/profile_strings.dart';
import '../../core/utils/jwt_utils.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../repositories/auth_repository.dart';
import '../session_store.dart';
import 'api_client.dart';
import 'token_store.dart';

/// [AuthRepository] gọi Backend thật.
///
/// - Đăng nhập bằng username → nhận access token + refresh token (đều hạn 7 ngày),
///   rồi lấy hồ sơ đầy đủ qua GET /api/auth/me (/api/accounts/{id} chỉ dành cho Admin).
/// - Hồ sơ: chỉ đổi được họ tên và ảnh đại diện; đổi mật khẩu / xóa tài khoản thu hồi mọi phiên.
/// - OTP gửi qua SMS về số điện thoại (BE chưa có cổng SMS: chỉ môi trường thử nghiệm trả mã trong `devOtp`).
///   Đăng ký: gửi OTP trước, nhập đúng mã mới tạo tài khoản. Quên mật khẩu: OTP kiểm tra ở bước đặt lại mật khẩu.
/// - Google: lấy idToken (ký cho Web Client ID) rồi đổi lấy phiên qua POST /api/auth/google.
/// - Facebook: lấy access token rồi đổi lấy phiên qua POST /api/auth/facebook (BE kiểm tra token thuộc đúng App ID).
/// - Đăng xuất: BE thu hồi phiên trên MỌI thiết bị của tài khoản.
class ApiAuthRepository implements AuthRepository {
  static const int maxAvatarBytes = 5 * 1024 * 1024;

  /// Chờ BE thu hồi phiên tối đa bấy nhiêu khi đăng xuất (server ngủ thì vẫn đăng xuất trên máy).
  static const Duration logoutTimeout = Duration(seconds: 5);

  /// OTP đăng ký sống 5 phút; chỉ dùng lại mã trong 4 phút đầu để người dùng còn thời gian nhập
  /// (mã sắp hết hạn mà dùng lại thì phải chờ 60 giây mới xin được mã mới).
  static const Duration registerOtpReuseWindow = Duration(minutes: 4);

  final ApiClient _api;
  final TokenStore _tokens;

  /// Thông tin đăng ký đang chờ nhập OTP.
  RegisterRequest? _pendingRegistration;

  /// Lần gửi OTP đăng ký gần nhất (SĐT đã chuẩn hóa, lúc gửi, devOtp) để dùng lại mã còn hạn.
  ({String phone, DateTime sentAt, String? devOtp})? _registerOtp;

  /// Thời điểm hiện tại; test thay để giả lập thời gian trôi.
  final DateTime Function() _now;

  /// GoogleSignIn chỉ được khởi tạo một lần; `null` khi chưa dùng đăng nhập Google.
  Future<void>? _googleInit;

  /// Đã đăng nhập Facebook trong lần chạy này (đăng xuất thì đăng xuất luôn khỏi Facebook).
  bool _usedFacebook = false;

  ApiAuthRepository({required this._api, required this._tokens, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  bool get supportsOtp => true;

  @override
  Future<AppUser> login(String identifier, String password, {bool rememberMe = true}) async {
    final Map<String, dynamic> data;
    try {
      data = await _api.post(
        '/api/auth/login',
        body: {'username': identifier.trim(), 'password': password},
        auth: false,
      ) as Map<String, dynamic>;
    } on ApiException catch (e) {
      // BE trả "Invalid username or password" (tiếng Anh) khi sai tài khoản / mật khẩu.
      throw AuthException(e.isUnauthorized ? AuthStrings.wrongCredentials : e.message);
    }

    return _startSession(data, fallbackUsername: identifier.trim(), rememberMe: rememberMe);
  }

  @override
  Future<AppUser?> loginWithGoogle({bool rememberMe = true}) async {
    final String? idToken;
    try {
      await (_googleInit ??= GoogleSignIn.instance.initialize(serverClientId: ApiConfig.googleServerClientId));
      final account = await GoogleSignIn.instance.authenticate();
      idToken = account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const AuthException(AuthStrings.googleLoginFailed);
    }
    if (idToken == null) throw const AuthException(AuthStrings.googleLoginFailed);

    return _socialLogin('/api/auth/google', idToken, rememberMe: rememberMe);
  }

  @override
  Future<AppUser?> loginWithFacebook({bool rememberMe = true}) async {
    final result = await FacebookAuth.instance.login(permissions: const ['email', 'public_profile']);
    switch (result.status) {
      case LoginStatus.cancelled:
      case LoginStatus.operationInProgress:
        return null;
      case LoginStatus.failed:
        throw const AuthException(AuthStrings.facebookLoginFailed);
      case LoginStatus.success:
        break;
    }
    final token = result.accessToken?.tokenString;
    if (token == null) throw const AuthException(AuthStrings.facebookLoginFailed);
    _usedFacebook = true;

    return _socialLogin('/api/auth/facebook', token, rememberMe: rememberMe);
  }

  /// Đổi token Google / Facebook lấy phiên của BE.
  Future<AppUser> _socialLogin(String path, String token, {required bool rememberMe}) async {
    // BE: "owner" tạo Chủ sân, giá trị khác là Người chơi (chỉ dùng khi email chưa có tài khoản).
    // Email trùng tài khoản chưa xác thực → 409, hiển thị nguyên văn câu của BE.
    final data = await _call(() async =>
        await _api.post(path, body: {'token': token, 'role': 'player'}, auth: false) as Map<String, dynamic>);
    return _startSession(data, fallbackUsername: data['email'] as String? ?? '', rememberMe: rememberMe);
  }

  /// Lưu token từ kết quả đăng nhập rồi lấy hồ sơ đầy đủ.
  Future<AppUser> _startSession(
    Map<String, dynamic> data, {
    required String fallbackUsername,
    required bool rememberMe,
  }) async {
    await _tokens.write(data['token'] as String, refreshToken: data['refreshToken'] as String?);

    AppUser user;
    try {
      user = await _fetchProfile();
    } on ApiException {
      // Không lấy được hồ sơ: vẫn vào app bằng thông tin trong kết quả đăng nhập (thiếu ảnh và Fair Play).
      final username = data['username'] as String? ?? fallbackUsername;
      user = AppUser(
        id: data['userId'] as String,
        username: username,
        fullName: data['fullName'] as String? ?? username,
        email: data['email'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        role: UserRole.fromApi(data['role'] as String?),
        isPhoneVerified: data['isPhoneVerified'] as bool? ?? false,
      );
    }
    await SessionStore.save(user, rememberMe: rememberMe);
    return user;
  }

  Future<AppUser> _fetchProfile() async =>
      AppUser.fromProfileJson(await _api.get('/api/auth/me') as Map<String, dynamic>);

  /// Lưu hồ sơ mới vào phiên, giữ nguyên lựa chọn "Ghi nhớ đăng nhập".
  Future<AppUser> _saveProfile(Object? data) async {
    final user = AppUser.fromProfileJson(data as Map<String, dynamic>);
    await SessionStore.save(user, rememberMe: await SessionStore.rememberMe());
    return user;
  }

  /// Gọi BE; lỗi thành [AuthException] mang câu tiếng Việt của BE.
  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<AppUser> getProfile() => _call(() async => _saveProfile(await _api.get('/api/auth/me')));

  @override
  Future<AppUser> updateFullName(String fullName) {
    final name = fullName.trim();
    if (name.isEmpty) throw const AuthException(AuthStrings.requiredField);
    return _call(() async => _saveProfile(await _api.put('/api/auth/me', body: {'fullName': name})));
  }

  @override
  Future<AppUser> uploadAvatar(String filePath) async {
    if (await File(filePath).length() > maxAvatarBytes) throw const AuthException(ProfileStrings.avatarTooLarge);
    return _call(() async => _saveProfile(await _api.upload('/api/auth/me/avatar', filePath: filePath)));
  }

  /// BE: gửi avatarUrl rỗng là xóa ảnh (gửi null thì giữ nguyên).
  @override
  Future<AppUser> removeAvatar() =>
      _call(() async => _saveProfile(await _api.put('/api/auth/me', body: {'avatarUrl': ''})));

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _call(() => _api.post(
          '/api/auth/change-password',
          body: {'oldPassword': oldPassword, 'newPassword': newPassword, 'confirmPassword': confirmPassword},
        ));
    // BE thu hồi mọi token: token đang giữ không dùng được nữa.
    await logout(revoke: false);
  }

  @override
  Future<void> deleteAccount({required String password, String? reason}) async {
    final note = reason?.trim();
    await _call(() => _api.delete(
          '/api/auth/me',
          body: {'password': password, if (note != null && note.isNotEmpty) 'reason': note},
        ));
    await logout(revoke: false);
  }

  /// Chưa tạo tài khoản: gửi OTP về SĐT (SĐT đã có tài khoản thì BE báo lỗi ngay ở bước này).
  /// Quay lại sửa thông tin (vd. trùng tên đăng nhập) rồi đăng ký lại cùng SĐT: dùng lại mã vừa gửi —
  /// BE kiểm tra trùng trước OTP nên mã chưa bị dùng, còn xin mã mới trong 60 giây sẽ bị từ chối.
  @override
  Future<String?> register(RegisterRequest request) async {
    final sent = _registerOtp;
    final reuse = sent != null &&
        sent.phone == normalizePhone(request.phone) &&
        _now().difference(sent.sentAt) < registerOtpReuseWindow;
    final devOtp = reuse ? sent.devOtp : await _sendOtp(request.phone, OtpPurpose.register);
    _pendingRegistration = request;
    return devOtp;
  }

  /// Gửi thông tin đăng ký kèm OTP: đúng mã thì BE tạo tài khoản (SĐT đã xác thực).
  @override
  Future<void> verifyRegisterOtp(String phone, String otp) async {
    final request = _pendingRegistration;
    if (request == null || normalizePhone(request.phone) != normalizePhone(phone)) {
      throw const AuthException(AuthStrings.registerExpired);
    }
    // Trùng username / email hoặc sai OTP: BE trả câu tiếng Việt, hiển thị nguyên văn.
    await _call(() => _api.post(
          '/api/auth/register',
          body: {
            'username': request.username.trim(),
            'password': request.password,
            'fullName': request.fullName.trim(),
            'phone': request.phone.trim(),
            'email': request.email.trim(),
            // BE: "owner" tạo Chủ sân, giá trị khác là Người chơi.
            'role': request.role == UserRole.courtOwner ? 'owner' : 'player',
            'otpCode': otp,
          },
          auth: false,
        ));
    _pendingRegistration = null;
    _registerOtp = null;
  }

  /// BE luôn trả thành công (không cho biết SĐT có tài khoản hay không).
  @override
  Future<String?> requestPasswordReset(String phone) => _sendOtp(phone, OtpPurpose.resetPassword);

  /// Không gọi BE: OTP được kiểm tra cùng lúc đặt mật khẩu mới, nên "reset token" chính là mã OTP.
  @override
  Future<String> verifyResetOtp(String phone, String otp) async => otp;

  @override
  Future<void> resetPassword(String phone, String resetToken, String newPassword) => _call(() => _api.post(
        '/api/auth/reset-password',
        body: {'phone': phone.trim(), 'otpCode': resetToken, 'newPassword': newPassword, 'confirmPassword': newPassword},
        auth: false,
      ));

  @override
  Future<String?> resendOtp(String phone, OtpPurpose purpose) => _sendOtp(phone, purpose);

  /// Đăng ký: POST send-otp (REGISTER). Quên mật khẩu: POST forgot-password (BE tự gửi OTP FORGOT_PASSWORD).
  /// Trả về devOtp (chỉ có ở môi trường thử nghiệm).
  Future<String?> _sendOtp(String phone, OtpPurpose purpose) async {
    final data = await _call(() => purpose == OtpPurpose.register
        ? _api.post('/api/auth/send-otp', body: {'phone': phone.trim(), 'type': 'REGISTER'}, auth: false)
        : _api.post('/api/auth/forgot-password', body: {'identifier': phone.trim()}, auth: false));
    final raw = data is Map<String, dynamic> ? data['devOtp']?.toString() : null;
    final devOtp = raw == null || raw.isEmpty ? null : raw;
    if (purpose == OtpPurpose.register) {
      _registerOtp = (phone: normalizePhone(phone), sentAt: _now(), devOtp: devOtp);
    }
    return devOtp;
  }

  /// Giống BE (AccountRules.NormalizePhone): bỏ dấu cách / - / . rồi đổi +84… / 84… về 0….
  static String normalizePhone(String phone) {
    final p = phone.replaceAll(RegExp(r'[\s.\-]'), '');
    if (p.startsWith('+84')) return '0${p.substring(3)}';
    if (p.startsWith('84') && p.length > 9) return '0${p.substring(2)}';
    return p;
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final token = await _tokens.read();
    final user = await SessionStore.readUser();
    if (token == null || user == null) return null;
    // Không "Ghi nhớ đăng nhập": bắt đăng nhập lại.
    if (!await SessionStore.rememberMe()) {
      await logout(revoke: false);
      return null;
    }
    // Access token hết hạn: thử refresh token, không được thì bắt đăng nhập lại.
    if (JwtUtils.isExpired(token)) {
      bool refreshed;
      try {
        refreshed = await _api.refreshSession();
      } on ApiException {
        refreshed = false; // mất mạng lúc mở app: không vào được phiên cũ
      }
      if (!refreshed) {
        await logout(revoke: false);
        return null;
      }
    }
    return user;
  }

  /// Thu hồi phiên trên BE là phụ: lỗi mạng / token đã hết hạn vẫn đăng xuất trên máy.
  @override
  Future<void> logout({bool revoke = true}) async {
    if (revoke && await _tokens.read() != null) {
      try {
        await _api.post('/api/auth/logout', refreshOnUnauthorized: false).timeout(logoutTimeout);
      } catch (_) {
        // bỏ qua: phiên trên máy vẫn bị xóa
      }
    }
    if (_googleInit != null) {
      try {
        await GoogleSignIn.instance.signOut(); // lần sau được chọn lại tài khoản Google
      } catch (_) {
        // bỏ qua: không ảnh hưởng phiên của app
      }
    }
    if (_usedFacebook) {
      _usedFacebook = false;
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {
        // bỏ qua: không ảnh hưởng phiên của app
      }
    }
    await _tokens.clear();
    await SessionStore.clear();
  }
}
