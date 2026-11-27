/// Chuỗi hiển thị cho màn Bảo mật của người chơi (theo mục Bảo mật trong Hồ sơ của Web).
class SecurityStrings {
  SecurityStrings._();

  static const String menu = 'Bảo mật';
  static const String title = 'Bảo mật';

  // Mật khẩu
  static const String passwordSection = 'Mật khẩu';
  static const String passwordHint = 'Đổi mật khẩu xong cần đăng nhập lại trên mọi thiết bị.';
  static const String setPasswordHint = 'Tài khoản Google / Facebook: đặt mật khẩu để đăng nhập bằng SĐT / email.';

  // Xác thực email
  static const String emailSection = 'Xác thực email';
  static const String emailLabel = 'Email tài khoản: ';
  static const String noEmail = 'Tài khoản chưa có email để xác thực.';
  static const String emailIntro =
      'Nhấn nút bên dưới để hệ thống SportNexus gửi mã xác thực gồm 6 chữ số vào hộp thư điện tử của bạn.';
  static const String sendOtp = 'Gửi mã OTP qua Email';
  static const String sending = 'Đang gửi…';
  static const String otpSent = 'Đã gửi mã OTP đến email của bạn!';
  static const String otpLabel = 'Nhập mã OTP 6 số nhận được trong email:';
  static String devOtp(String code) => 'Mã OTP thử nghiệm: $code';
  static const String verify = 'Xác thực email';
  static const String verifying = 'Đang xác thực…';
  static const String resend = 'Gửi lại mã';
  static const String verified = 'Xác thực email thành công!';
  static const String otpInvalid = 'Mã OTP gồm 6 chữ số.';
  static const String sendError = 'Không thể gửi OTP';
  static const String verifyError = 'Mã OTP không hợp lệ';

  // Thiết bị
  static const String devicesSection = 'Thiết bị đăng nhập';
  static const String devicesHint = 'Nghi ngờ tài khoản bị lộ? Đăng xuất khỏi mọi điện thoại và trình duyệt đang đăng nhập.';
  static const String logoutAll = 'Đăng xuất khỏi tất cả thiết bị';
  static const String logoutAllConfirm = 'Đăng xuất tài khoản khỏi tất cả thiết bị (kể cả thiết bị này)?';
  static const String cancel = 'Không';
  static const String loggedOutAll = 'Đã đăng xuất khỏi tất cả thiết bị. Vui lòng đăng nhập lại.';
  static const String logoutAllError = 'Không thể đăng xuất các thiết bị';

  // Xóa tài khoản
  static const String dangerSection = 'Vùng nguy hiểm: Xóa tài khoản vĩnh viễn';
  static const String dangerHint = 'Hành động này sẽ xóa toàn bộ lịch sử đấu, số dư ví SportNexus, thông tin môn thể thao '
      'và các đánh giá uy tín của bạn. Bạn sẽ không thể khôi phục tài khoản này sau khi xác nhận.';
}
