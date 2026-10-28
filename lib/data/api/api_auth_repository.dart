import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/api_config.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/strings/profile_strings.dart';
import '../../core/utils/jwt_utils.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../repositories/auth_repository.dart';
import '../repositories/phone_verifier.dart';
import '../session_store.dart';
import 'api_client.dart';
import 'firebase_phone_verifier.dart';
import 'token_store.dart';

/// [AuthRepository] gọi Backend thật.
///
/// - Đăng nhập bằng username → nhận access token + refresh token (đều hạn 7 ngày),
///   rồi lấy hồ sơ đầy đủ qua GET /api/auth/me (/api/accounts/{id} chỉ dành cho Admin).
/// - Hồ sơ: chỉ đổi được họ tên và ảnh đại diện; đổi mật khẩu / xóa tài khoản thu hồi mọi phiên.
/// - Xác thực SĐT bằng SMS thật qua Firebase ([PhoneVerifier]); BE nhận `firebaseIdToken` thay cho `otpCode`
///   (OTP cũ của BE không gửi SMS). Đăng ký: xác thực SĐT trước, đúng mã mới tạo tài khoản. Quên mật khẩu:
///   xác thực SĐT rồi đặt mật khẩu mới. Tài khoản Google / Facebook chưa có SĐT: thêm qua POST /auth/me/phone.
/// - Google: lấy idToken (ký cho Web Client ID) rồi đổi lấy phiên qua POST /api/auth/google.
/// - Facebook: lấy access token rồi đổi lấy phiên qua POST /api/auth/facebook (BE kiểm tra token thuộc đúng App ID).
///   Email chưa có tài khoản: BE chưa tạo gì (needsConfirmation, token null) → hỏi người dùng rồi gọi lại kèm
///   confirmCreate. Tài khoản tạo kiểu này chưa có mật khẩu (hasPassword = false) → dùng set-password.
/// - Đăng xuất: BE thu hồi phiên trên MỌI thiết bị của tài khoản.
class ApiAuthRepository implements AuthRepository {
  static const int maxAvatarBytes = 5 * 1024 * 1024;

  /// Chờ BE thu hồi phiên tối đa bấy nhiêu khi đăng xuất (server ngủ thì vẫn đăng xuất trên máy).
  static const Duration logoutTimeout = Duration(seconds: 5);

  final ApiClient _api;
  final TokenStore _tokens;
  final PhoneVerifier _phone;

  /// Thông tin đăng ký đang chờ nhập OTP.
  RegisterRequest? _pendingRegistration;

  /// GoogleSignIn chỉ được khởi tạo một lần; `null` khi chưa dùng đăng nhập Google.
  Future<void>? _googleInit;

  /// Đã đăng nhập Facebook trong lần chạy này (đăng xuất thì đăng xuất luôn khỏi Facebook).
  bool _usedFacebook = false;

  ApiAuthRepository({required this._api, required this._tokens, PhoneVerifier? phoneVerifier})
    : _phone = phoneVerifier ?? FirebasePhoneVerifier();

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
  Future<AppUser?> loginWithGoogle({bool rememberMe = true, required ConfirmSocialSignUp confirmSignUp}) async {
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

    return exchangeSocialToken('/api/auth/google', idToken, rememberMe: rememberMe, confirmSignUp: confirmSignUp);
  }

  @override
  Future<AppUser?> loginWithFacebook({bool rememberMe = true, required ConfirmSocialSignUp confirmSignUp}) async {
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

    return exchangeSocialToken('/api/auth/facebook', token, rememberMe: rememberMe, confirmSignUp: confirmSignUp);
  }

  /// Đổi token Google / Facebook lấy phiên của BE. `null` khi người dùng không đồng ý tạo tài khoản mới.
  @visibleForTesting
  Future<AppUser?> exchangeSocialToken(
    String path,
    String token, {
    required bool rememberMe,
    required ConfirmSocialSignUp confirmSignUp,
  }) async {
    // BE: "owner" tạo Chủ sân, giá trị khác là Người chơi (chỉ dùng khi email chưa có tài khoản).
    var data = await _postSocial(path, {'token': token, 'role': 'player'});
    if (data['needsConfirmation'] == true) {
      final avatar = (data['avatarUrl'] as String?)?.trim();
      final info = SocialSignUpInfo(
        fullName: data['fullName'] as String? ?? '',
        email: data['email'] as String? ?? '',
        avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
      );
      if (!await confirmSignUp(info)) return null;
      data = await _postSocial(path, {'token': token, 'role': 'player', 'confirmCreate': true});
    }
    if (data['token'] is! String) throw const AuthException(AuthStrings.socialLoginFailed);
    return _startSession(data, fallbackUsername: data['email'] as String? ?? '', rememberMe: rememberMe);
  }

  Future<Map<String, dynamic>> _postSocial(String path, Map<String, dynamic> body) async {
    try {
      return await _api.post(path, body: body, auth: false) as Map<String, dynamic>;
    } on ApiException catch (e) {
      // 409: email đã đăng ký nhưng chưa xác thực. Câu của BE có đường dẫn API nên thay bằng câu dễ hiểu.
      throw AuthException(e.statusCode == 409 ? AuthStrings.socialEmailUnverified : e.message);
    }
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
        hasPassword: data['hasPassword'] as bool? ?? true,
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

  /// Đặt xong vẫn ở lại phiên hiện tại; cập nhật hồ sơ đã lưu để Hồ sơ chuyển sang "Đổi mật khẩu".
  @override
  Future<void> setPassword({required String newPassword, required String confirmPassword}) async {
    await _call(() => _api.post(
          '/api/auth/set-password',
          body: {'newPassword': newPassword, 'confirmPassword': confirmPassword},
        ));
    final user = await SessionStore.readUser();
    if (user != null) await SessionStore.save(user.copyWith(hasPassword: true), rememberMe: await SessionStore.rememberMe());
  }

  @override
  Future<void> deleteAccount({String? password, String? reason}) async {
    final note = reason?.trim();
    await _call(() => _api.delete(
          '/api/auth/me',
          body: {
            if (password != null && password.isNotEmpty) 'password': password,
            if (note != null && note.isNotEmpty) 'reason': note,
          },
        ));
    await logout(revoke: false);
  }

  /// Chưa tạo tài khoản: kiểm tra trùng trước, hợp lệ mới gửi SMS xác thực SĐT.
  /// Quay lại sửa thông tin rồi đăng ký lại cùng SĐT: SĐT vừa xác thực còn hạn thì không gửi SMS nữa,
  /// màn OTP tự đi tiếp.
  @override
  Future<String?> register(RegisterRequest request) async {
    await _checkRegistration(request);
    final phone = normalizePhone(request.phone);
    if (!_phone.isVerified(phone)) await _phone.sendCode(phone);
    _pendingRegistration = request;
    return null;
  }

  /// BE kiểm tra trùng tên đăng nhập / email / SĐT TRƯỚC khi đòi xác thực SĐT: gửi đăng ký không kèm token,
  /// nhận đúng câu "Vui lòng xác thực số điện thoại..." nghĩa là thông tin hợp lệ (không tạo tài khoản).
  Future<void> _checkRegistration(RegisterRequest request) async {
    try {
      await _api.post('/api/auth/register', body: _registerBody(request), auth: false);
    } on ApiException catch (e) {
      if (e.message.contains(_needsPhoneVerification)) return;
      throw AuthException(e.message);
    }
  }

  static const String _needsPhoneVerification = 'xác thực số điện thoại';

  Map<String, dynamic> _registerBody(RegisterRequest request) => {
        'username': request.username.trim(),
        'password': request.password,
        'fullName': request.fullName.trim(),
        'phone': request.phone.trim(),
        'email': request.email.trim(),
        // BE: "owner" tạo Chủ sân, giá trị khác là Người chơi.
        'role': request.role == UserRole.courtOwner ? 'owner' : 'player',
      };

  /// Gửi thông tin đăng ký kèm firebaseIdToken: BE tạo tài khoản với SĐT đã xác thực.
  @override
  Future<void> verifyRegisterOtp(String phone, String otp) async {
    final request = _pendingRegistration;
    if (request == null || normalizePhone(request.phone) != normalizePhone(phone)) {
      throw const AuthException(AuthStrings.registerExpired);
    }
    final idToken = await _phone.verifyCode(normalizePhone(phone), otp);
    // Trùng username / email / SĐT: BE trả câu tiếng Việt, hiển thị nguyên văn.
    await _call(() => _api.post(
          '/api/auth/register',
          body: {..._registerBody(request), 'firebaseIdToken': idToken},
          auth: false,
        ));
    _pendingRegistration = null;
    _phone.clear();
  }

  /// Chỉ gửi SMS, không gọi BE: SĐT không có tài khoản thì báo ở bước đặt mật khẩu mới.
  @override
  Future<String?> requestPasswordReset(String phone) async {
    await _phone.sendCode(normalizePhone(phone));
    return null;
  }

  /// "Reset token" là firebaseIdToken của SĐT vừa xác thực.
  @override
  Future<String> verifyResetOtp(String phone, String otp) => _phone.verifyCode(normalizePhone(phone), otp);

  /// Thành công thì BE thu hồi mọi phiên cũ của tài khoản.
  @override
  Future<void> resetPassword(String phone, String resetToken, String newPassword) async {
    try {
      await _api.post(
        '/api/auth/reset-password',
        body: {
          'phone': normalizePhone(phone),
          'firebaseIdToken': resetToken,
          'newPassword': newPassword,
          'confirmPassword': newPassword,
        },
        auth: false,
      );
    } on ApiException catch (e) {
      // SĐT không có tài khoản: BE trả "Mã OTP không chính xác...", sai ý nghĩa với luồng Firebase.
      throw AuthException(e.message.contains('OTP') ? AuthStrings.resetFailed : e.message);
    }
    _phone.clear();
  }

  @override
  Future<String?> resendOtp(String phone, OtpPurpose purpose) async {
    await _phone.sendCode(normalizePhone(phone));
    return null;
  }

  @override
  Future<String?> requestPhoneOtp(String phone) async {
    await _phone.sendCode(normalizePhone(phone));
    return null;
  }

  /// POST /auth/me/phone không trả hồ sơ: tải lại /auth/me để có SĐT mới.
  @override
  Future<AppUser> addPhone(String phone, String otp) async {
    final normalized = normalizePhone(phone);
    final idToken = await _phone.verifyCode(normalized, otp);
    await _call(() => _api.post('/api/auth/me/phone', body: {'phone': normalized, 'firebaseIdToken': idToken}));
    _phone.clear();
    return getProfile();
  }

  @override
  bool isPhoneVerified(String phone) => _phone.isVerified(normalizePhone(phone));

  @override
  Stream<String> get phoneVerifiedEvents => _phone.verifiedPhones;

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
