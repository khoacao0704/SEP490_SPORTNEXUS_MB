import 'dart:io';

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
/// - OTP / quên mật khẩu chưa nối: các hàm đó báo "đang phát triển".
class ApiAuthRepository implements AuthRepository {
  static const int maxAvatarBytes = 5 * 1024 * 1024;

  final ApiClient _api;
  final TokenStore _tokens;

  ApiAuthRepository({required this._api, required this._tokens});

  @override
  bool get supportsOtp => false;

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

    await _tokens.write(data['token'] as String, refreshToken: data['refreshToken'] as String?);

    AppUser user;
    try {
      user = await _fetchProfile();
    } on ApiException {
      // Không lấy được hồ sơ: vẫn vào app bằng thông tin trong kết quả đăng nhập (thiếu ảnh và Fair Play).
      final username = data['username'] as String? ?? identifier.trim();
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
    await logout();
  }

  @override
  Future<void> deleteAccount({required String password, String? reason}) async {
    final note = reason?.trim();
    await _call(() => _api.delete(
          '/api/auth/me',
          body: {'password': password, if (note != null && note.isNotEmpty) 'reason': note},
        ));
    await logout();
  }

  @override
  Future<void> register(RegisterRequest request) async {
    try {
      await _api.post(
        '/api/auth/register',
        body: {
          'username': request.username.trim(),
          'password': request.password,
          'fullName': request.fullName.trim(),
          'phone': request.phone.trim(),
          'email': request.email.trim(),
          // BE: "owner" tạo Chủ sân, giá trị khác là Người chơi.
          'role': request.role == UserRole.courtOwner ? 'owner' : 'player',
        },
        auth: false,
      );
    } on ApiException catch (e) {
      // Trùng username / SĐT / email: BE trả câu tiếng Việt, hiển thị nguyên văn.
      throw AuthException(e.message);
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final token = await _tokens.read();
    final user = await SessionStore.readUser();
    if (token == null || user == null) return null;
    // Không "Ghi nhớ đăng nhập": bắt đăng nhập lại.
    if (!await SessionStore.rememberMe()) {
      await logout();
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
        await logout();
        return null;
      }
    }
    return user;
  }

  @override
  Future<void> logout() async {
    await _tokens.clear();
    await SessionStore.clear();
  }

  // ---------------- Chưa có trên BE ----------------

  Never _notSupported() => throw const AuthException(AuthStrings.featureInDevelopment);

  @override
  Future<void> verifyRegisterOtp(String email, String otp) async => _notSupported();

  @override
  Future<void> requestPasswordReset(String email) async => _notSupported();

  @override
  Future<String> verifyResetOtp(String email, String otp) async => _notSupported();

  @override
  Future<void> resetPassword(String email, String resetToken, String newPassword) async => _notSupported();

  @override
  Future<void> resendOtp(String email, OtpPurpose purpose) async => _notSupported();
}
