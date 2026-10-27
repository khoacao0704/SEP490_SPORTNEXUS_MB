/// Xác thực số điện thoại bằng SMS thật (Firebase Phone Auth): gửi mã → nhập mã → nhận `firebaseIdToken`
/// để gửi cho BE thay cho `otpCode`. SĐT truyền vào đã chuẩn hóa dạng 0xxxxxxxxx.
abstract class PhoneVerifier {
  /// Gửi (hoặc gửi lại) mã 6 số qua SMS. Android có thể tự xác thực luôn mà không cần nhập mã:
  /// khi đó [isVerified] thành `true` và [verifiedPhones] phát SĐT đó.
  Future<void> sendCode(String phone);

  /// Đổi mã người dùng nhập lấy `firebaseIdToken`. SĐT vừa xác thực còn hạn thì trả luôn token cũ (bỏ qua [code]).
  Future<String> verifyCode(String phone, String code);

  /// SĐT đã xác thực trên máy và token còn dùng được (BE chỉ nhận trong 10 phút).
  bool isVerified(String phone);

  /// Phát SĐT mỗi khi được xác thực (kể cả tự xác thực trên Android).
  Stream<String> get verifiedPhones;

  /// Quên token đã dùng xong (BE đã nhận).
  void clear();
}
