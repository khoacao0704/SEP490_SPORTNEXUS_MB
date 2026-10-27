/// Chuỗi hiển thị cho các màn hình xác thực (đăng nhập, đăng ký, OTP, quên mật khẩu).
class AuthStrings {
  AuthStrings._();

  // Đăng nhập
  static const String loginTitle = 'Đăng Nhập SportNexus';
  static const String loginSubtitle = 'Chào mừng bạn trở lại với nền tảng quản lý & đặt sân thể thao';
  static const String identifierLabel = 'Tên đăng nhập';
  static const String identifierHint = 'Nhập tên đăng nhập';
  static const String rememberMe = 'Ghi nhớ đăng nhập';
  static const String forgotPasswordLink = 'Quên mật khẩu?';
  static const String loginButton = 'ĐĂNG NHẬP';
  static const String orLoginWith = 'HOẶC ĐĂNG NHẬP BẰNG';
  static const String noAccount = 'Chưa có tài khoản? ';
  static const String registerNow = 'Đăng ký ngay';
  static const String googleLoginFailed = 'Không đăng nhập được bằng Google. Vui lòng thử lại.';
  static const String facebookLoginFailed = 'Không đăng nhập được bằng Facebook. Vui lòng thử lại.';
  static const String socialComingSoon = 'Đăng nhập bằng mạng xã hội sẽ sớm được hỗ trợ';
  static const String socialLoginFailed = 'Không đăng nhập được. Vui lòng thử lại.';
  static const String socialEmailUnverified =
      'Email này đã được dùng để đăng ký tài khoản nhưng chưa xác thực. Vui lòng đăng nhập bằng tên đăng nhập '
      'và mật khẩu, xác thực email, rồi mới đăng nhập bằng Google / Facebook.';
  static const String socialSignUpTitle = 'Tạo tài khoản mới?';
  static const String socialSignUpMessage =
      'Email này chưa có tài khoản SportNexus. Tạo tài khoản Người chơi mới bằng thông tin trên?';
  static const String socialSignUpCreate = 'Tạo tài khoản';
  static const String cancel = 'Hủy';

  // Đăng ký
  static const String registerTitle = 'Tạo Tài Khoản';
  static const String registerSubtitle = 'Đăng ký để đặt sân, ghép trận và kết nối cộng đồng thể thao';
  static const String usernameLabel = 'Tên đăng nhập';
  static const String usernameHint = 'Chữ, số, dấu chấm hoặc gạch dưới';
  static const String usernameRule = '3-30 ký tự: chữ không dấu, số, dấu "." hoặc "_"';
  static const String roleLabel = 'Bạn là';
  static const String rolePlayer = 'Người chơi';
  static const String roleOwner = 'Chủ sân';
  static const String fullNameLabel = 'Họ và tên';
  static const String fullNameHint = 'Nhập họ và tên';
  static const String emailLabel = 'Email';
  static const String emailHint = 'Nhập email';
  static const String phoneLabel = 'Số điện thoại';
  static const String phoneHint = 'Nhập số điện thoại';
  static const String confirmPasswordLabel = 'Xác nhận mật khẩu';
  static const String confirmPasswordHint = 'Nhập lại mật khẩu';
  static const String agreeTermsPrefix = 'Tôi đồng ý với ';
  static const String termsOfService = 'Điều khoản sử dụng';
  static const String agreeTermsRequired = 'Vui lòng đồng ý với Điều khoản sử dụng';
  static const String registerButton = 'ĐĂNG KÝ';
  static const String haveAccount = 'Đã có tài khoản? ';
  static const String loginNow = 'Đăng nhập';
  static const String registerSuccess = 'Xác thực thành công! Vui lòng đăng nhập để tiếp tục.';
  static const String registerDone = 'Đăng ký thành công! Vui lòng đăng nhập để tiếp tục.';

  // Mật khẩu
  static const String passwordLabel = 'Mật khẩu';
  static const String passwordHint = 'Nhập mật khẩu';
  static const String newPasswordLabel = 'Mật khẩu mới';
  static const String newPasswordHint = 'Nhập mật khẩu mới';
  static const String passwordRule = 'Tối thiểu 8 ký tự, gồm cả chữ và số';

  // OTP
  static const String otpTitle = 'Xác Thực OTP';
  static String otpSubtitle(String phone) => 'Mã xác thực gồm 6 chữ số đã được gửi đến số điện thoại\n$phone';

  /// Chỉ hiện khi máy chủ thử nghiệm trả mã OTP (chưa có SMS thật).
  static String devOtpHint(String code) => 'Mã OTP thử nghiệm: $code';
  static const String otpVerifyButton = 'XÁC THỰC';
  static const String otpNotReceived = 'Chưa nhận được mã? ';
  static const String otpResend = 'Gửi lại mã';
  static String otpResendIn(int seconds) => 'Gửi lại sau ${seconds}s';
  static const String otpResent = 'Đã gửi lại mã OTP';
  static const String otpIncomplete = 'Vui lòng nhập đủ 6 chữ số';
  static const String otpExpired = 'Mã OTP đã hết hạn. Vui lòng gửi lại mã.';
  static const String otpTooManyRequests = 'Bạn đã yêu cầu mã quá nhiều lần. Vui lòng thử lại sau ít phút.';
  static const String smsUnavailable = 'Hệ thống tạm thời không gửi được SMS. Vui lòng thử lại sau.';
  static const String phoneVerifyFailed = 'Không xác thực được số điện thoại. Vui lòng thử lại.';

  // Thêm số điện thoại (tài khoản tạo bằng Google / Facebook)
  static const String addPhoneTitle = 'Thêm Số Điện Thoại';
  static const String addPhoneSubtitle =
      'Tài khoản cần số điện thoại đã xác thực để đặt sân, chia tiền với bạn bè và lấy lại mật khẩu.';
  static const String logout = 'Đăng xuất';
  static const String otherAccount = 'Dùng tài khoản khác? ';

  // Quên / đặt lại mật khẩu
  static const String forgotTitle = 'Quên Mật Khẩu';
  static const String forgotSubtitle = 'Nhập số điện thoại đã đăng ký, chúng tôi sẽ gửi mã OTP để đặt lại mật khẩu';
  static const String sendOtpButton = 'GỬI MÃ OTP';
  static const String resetTitle = 'Đặt Lại Mật Khẩu';
  static const String resetSubtitle = 'Tạo mật khẩu mới cho tài khoản của bạn';
  static const String resetButton = 'ĐẶT LẠI MẬT KHẨU';
  static const String resetSuccess = 'Đặt lại mật khẩu thành công! Vui lòng đăng nhập lại.';

  // Kiểm tra dữ liệu nhập
  static const String requiredField = 'Vui lòng không để trống';
  static const String invalidEmail = 'Email không hợp lệ';
  static const String invalidUsername = 'Tên đăng nhập 3-30 ký tự, chỉ gồm chữ không dấu, số, "." hoặc "_"';
  static const String invalidPhone = 'Số điện thoại không hợp lệ';
  static const String invalidIdentifier = 'Email hoặc số điện thoại không hợp lệ';
  static const String invalidPassword = 'Mật khẩu tối thiểu 8 ký tự, gồm cả chữ và số';
  static const String passwordMismatch = 'Mật khẩu xác nhận không khớp';

  // Lỗi từ máy chủ
  static const String wrongCredentials = 'Sai tài khoản hoặc mật khẩu';
  static const String accountNotVerified = 'Tài khoản chưa xác thực. Vui lòng nhập mã OTP.';
  static const String emailTaken = 'Email đã được sử dụng';
  static const String phoneTaken = 'Số điện thoại đã được sử dụng';
  static const String usernameTaken = 'Tên đăng nhập đã tồn tại.';
  static const String featureInDevelopment = 'Chức năng đang được phát triển. Vui lòng thử lại sau.';
  static const String phoneNotFound = 'Không tìm thấy tài khoản với số điện thoại này';
  static const String resetFailed =
      'Không đặt lại được mật khẩu. Hãy kiểm tra số điện thoại đã đăng ký, hoặc quay lại xác thực lại.';
  static const String wrongOtp = 'Mã OTP không đúng';
  static const String sessionExpired = 'Phiên đặt lại mật khẩu đã hết hạn. Vui lòng thử lại.';
  static const String registerExpired = 'Phiên đăng ký đã hết hạn. Vui lòng đăng ký lại.';

  // Phân luồng theo vai trò
  static const String ownerPendingTitle = 'Giao diện Chủ sân';
  static const String ownerPendingMessage = 'Giao diện dành cho Chủ sân trên ứng dụng di động đang được phát triển.';
  static const String roleNotAllowed = 'Tài khoản Quản trị viên không sử dụng ứng dụng di động. Vui lòng đăng nhập trên Web Portal.';
}
