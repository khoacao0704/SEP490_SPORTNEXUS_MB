import '../../models/app_user.dart';

/// Lỗi nghiệp vụ trả về từ tầng xác thực; [message] đã sẵn sàng để hiển thị cho người dùng.
class AuthException implements Exception {
  final String message;

  /// true khi tài khoản tồn tại nhưng chưa xác thực OTP.
  final bool needsVerification;

  const AuthException(this.message, {this.needsVerification = false});

  @override
  String toString() => 'AuthException: $message';
}

class RegisterRequest {
  final String fullName;
  final String email;
  final String phone;
  final String password;

  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
  });
}

enum OtpPurpose { register, resetPassword }

/// Hợp đồng xác thực mà UI sử dụng.
/// Hiện tại dùng [MockAuthRepository]; khi nối Swagger chỉ cần viết bản cài đặt gọi API.
abstract class AuthRepository {
  /// Đăng nhập bằng email hoặc số điện thoại.
  /// [rememberMe] = false thì lần mở app sau phải đăng nhập lại.
  Future<AppUser> login(String identifier, String password, {bool rememberMe = true});

  /// Tạo tài khoản ở trạng thái chưa xác thực và gửi OTP về email.
  Future<void> register(RegisterRequest request);

  Future<void> verifyRegisterOtp(String email, String otp);

  /// Gửi OTP đặt lại mật khẩu về email đã đăng ký.
  Future<void> requestPasswordReset(String email);

  /// Trả về reset token dùng cho [resetPassword].
  Future<String> verifyResetOtp(String email, String otp);

  Future<void> resetPassword(String email, String resetToken, String newPassword);

  Future<void> resendOtp(String email, OtpPurpose purpose);

  /// Người dùng của phiên đã ghi nhớ, `null` nếu chưa đăng nhập.
  Future<AppUser?> getCurrentUser();

  Future<void> logout();
}
