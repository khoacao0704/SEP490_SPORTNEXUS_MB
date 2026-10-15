import '../../core/strings/auth_strings.dart';
import '../../core/utils/jwt_utils.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../repositories/auth_repository.dart';
import '../session_store.dart';
import 'api_client.dart';
import 'token_store.dart';

/// [AuthRepository] gọi Backend thật.
///
/// - Đăng nhập bằng username → nhận JWT (hạn 7 ngày, không có refresh token) + userId + role,
///   rồi lấy hồ sơ đầy đủ qua GET /api/accounts/{id} (BE chưa có /me).
/// - BE chưa có OTP / quên mật khẩu: các hàm đó báo "đang phát triển".
class ApiAuthRepository implements AuthRepository {
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

    final token = data['token'] as String;
    final userId = data['userId'] as String;
    await _tokens.write(token);

    AppUser user;
    try {
      user = AppUser.fromAccountJson(await _api.get('/api/accounts/$userId') as Map<String, dynamic>);
    } on ApiException {
      // Không lấy được hồ sơ: vẫn vào app bằng thông tin tối thiểu từ kết quả đăng nhập.
      user = AppUser(
        id: userId,
        username: identifier.trim(),
        fullName: data['fullName'] as String? ?? identifier.trim(),
        email: '',
        phone: '',
        role: UserRole.fromApi(data['role'] as String?),
      );
    }
    await SessionStore.save(user, rememberMe: rememberMe);
    return user;
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
    // Không "Ghi nhớ đăng nhập" hoặc token đã hết hạn: bắt đăng nhập lại.
    if (!await SessionStore.rememberMe() || JwtUtils.isExpired(token)) {
      await logout();
      return null;
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
