import '../../models/app_user.dart';
import '../../models/user_role.dart';

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
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String password;

  /// Người chơi hoặc Chủ sân (BE không cho tự đăng ký Admin).
  final UserRole role;

  const RegisterRequest({
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    this.role = UserRole.player,
  });
}

enum OtpPurpose { register, resetPassword }

/// Hợp đồng xác thực mà UI sử dụng: ApiAuthRepository (BE thật) hoặc MockAuthRepository.
abstract class AuthRepository {
  /// Đăng nhập bằng tên đăng nhập (bản giả lập nhận thêm email / số điện thoại).
  /// [rememberMe] = false thì lần mở app sau phải đăng nhập lại.
  Future<AppUser> login(String identifier, String password, {bool rememberMe = true});

  /// Bắt đầu đăng ký: gửi OTP về số điện thoại của [request]; tài khoản được tạo ở [verifyRegisterOtp].
  /// Không có OTP ([supportsOtp] = false) thì tạo tài khoản ngay.
  /// Trả về mã OTP khi máy chủ đang ở môi trường thử nghiệm (devOtp), ngoài ra `null`.
  Future<String?> register(RegisterRequest request);

  /// Có xác thực OTP khi đăng ký / quên mật khẩu không. `false`: đăng ký xong dùng được ngay, quên mật khẩu báo
  /// "đang phát triển".
  bool get supportsOtp;

  Future<void> verifyRegisterOtp(String phone, String otp);

  /// Gửi OTP đặt lại mật khẩu về số điện thoại đã đăng ký. Trả về devOtp như [register].
  Future<String?> requestPasswordReset(String phone);

  /// Trả về reset token dùng cho [resetPassword].
  Future<String> verifyResetOtp(String phone, String otp);

  Future<void> resetPassword(String phone, String resetToken, String newPassword);

  /// Gửi lại OTP. Trả về devOtp như [register].
  Future<String?> resendOtp(String phone, OtpPurpose purpose);

  /// Người dùng của phiên đã ghi nhớ, `null` nếu chưa đăng nhập.
  Future<AppUser?> getCurrentUser();

  /// Xóa phiên trên máy. [revoke] = true (người dùng bấm Đăng xuất): báo máy chủ thu hồi phiên đăng nhập;
  /// false khi phiên đã hết hạn hoặc chỉ cần thoát trên máy này.
  Future<void> logout({bool revoke = true});

  // ---------------- Hồ sơ của chính mình ----------------

  /// Tải hồ sơ mới nhất từ máy chủ và lưu lại vào phiên.
  Future<AppUser> getProfile();

  /// Đổi họ tên (tên đăng nhập, SĐT, email chưa đổi được).
  Future<AppUser> updateFullName(String fullName);

  /// Tải ảnh JPG / PNG / WEBP tối đa 5MB lên làm ảnh đại diện.
  Future<AppUser> uploadAvatar(String filePath);

  Future<AppUser> removeAvatar();

  /// Đổi mật khẩu. Thành công thì mọi phiên đăng nhập bị thu hồi: đăng xuất tại máy, người dùng đăng nhập lại.
  Future<void> changePassword({required String oldPassword, required String newPassword, required String confirmPassword});

  /// Xóa tài khoản (xóa mềm). Chặn nếu còn lịch đặt sân sắp diễn ra hoặc ví còn tiền. Thành công thì đăng xuất.
  Future<void> deleteAccount({required String password, String? reason});
}
