/// Chuỗi hiển thị cho Hồ sơ cá nhân: xem / sửa hồ sơ, ảnh đại diện, đổi mật khẩu, xóa tài khoản.
class ProfileStrings {
  ProfileStrings._();

  static const String title = 'Hồ Sơ Cá Nhân';
  static const String loadError = 'Không tải được hồ sơ mới nhất. Đang hiện thông tin đã lưu.';
  static const String editProfile = 'Sửa hồ sơ';
  static const String changePassword = 'Đổi mật khẩu';

  // Sửa hồ sơ
  static const String editTitle = 'Sửa Hồ Sơ';
  static const String fullNameLabel = 'Họ và tên';
  static const String usernameLabel = 'Tên đăng nhập';
  static const String phoneLabel = 'Số điện thoại';
  static const String emailLabel = 'Email';
  static const String lockedFieldsNote =
      'Tên đăng nhập, số điện thoại và email chưa đổi được trên app. Liên hệ Quản trị viên nếu cần thay đổi.';
  static const String save = 'LƯU THAY ĐỔI';
  static const String saved = 'Đã cập nhật hồ sơ';
  static const String nameTooLong = 'Họ và tên tối đa 100 ký tự';

  // Ảnh đại diện
  static const String changeAvatar = 'Đổi ảnh đại diện';
  static const String takePhoto = 'Chụp ảnh';
  static const String fromGallery = 'Chọn từ thư viện';
  static const String removeAvatar = 'Xóa ảnh đại diện';
  static const String avatarUpdated = 'Đã cập nhật ảnh đại diện';
  static const String avatarRemoved = 'Đã xóa ảnh đại diện';
  static const String pickPhotoError = 'Không mở được camera / thư viện ảnh. Hãy kiểm tra quyền truy cập của ứng dụng.';
  static const String avatarRule = 'Ảnh JPG, PNG hoặc WEBP, tối đa 5MB.';
  static const String avatarTooLarge = 'Ảnh đại diện không được vượt quá 5MB.';
  static const String avatarBadFormat = 'Chỉ hỗ trợ ảnh định dạng JPG, PNG hoặc WEBP.';

  // Đổi mật khẩu
  static const String changePasswordTitle = 'Đổi Mật Khẩu';
  static const String changePasswordNote = 'Sau khi đổi mật khẩu, bạn sẽ phải đăng nhập lại trên mọi thiết bị.';
  static const String oldPasswordLabel = 'Mật khẩu hiện tại';
  static const String newPasswordLabel = 'Mật khẩu mới';
  static const String confirmPasswordLabel = 'Nhập lại mật khẩu mới';
  static const String samePassword = 'Mật khẩu mới không được trùng với mật khẩu cũ.';
  static const String wrongOldPassword = 'Mật khẩu hiện tại không chính xác.';
  static const String confirmMismatch = 'Xác nhận mật khẩu mới không khớp.';
  static const String changePasswordButton = 'ĐỔI MẬT KHẨU';
  static const String passwordChanged = 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại bằng mật khẩu mới.';

  // Đặt mật khẩu (tài khoản tạo bằng Google / Facebook)
  static const String setPassword = 'Đặt mật khẩu';
  static const String setPasswordTitle = 'Đặt Mật Khẩu';
  static const String setPasswordNote =
      'Tài khoản của bạn được tạo bằng Google / Facebook nên chưa có mật khẩu. Đặt mật khẩu để có thể đăng nhập '
      'bằng tên đăng nhập và mật khẩu.';
  static const String setPasswordButton = 'ĐẶT MẬT KHẨU';
  static const String passwordSet = 'Đã đặt mật khẩu.';
  static const String alreadyHasPassword = 'Tài khoản đã có mật khẩu. Vui lòng dùng chức năng Đổi mật khẩu.';

  // Xóa tài khoản
  static const String deleteAccount = 'Xóa tài khoản';
  static const String deleteWarningTitle = 'Xóa tài khoản?';
  static const String deleteWarning =
      'Tài khoản sẽ bị xóa và không đăng nhập được nữa. Lịch sử đặt sân, kèo LFG và điểm Fair Play của bạn sẽ không còn dùng được.\n\n'
      'Chỉ xóa được khi bạn không còn lịch đặt sân sắp diễn ra và ví không còn tiền.';
  static const String deleteContinue = 'Tiếp tục';
  static const String deleteConfirmTitle = 'Xác nhận xóa tài khoản';
  static const String deletePasswordLabel = 'Nhập mật khẩu để xác nhận';
  static const String deleteReasonLabel = 'Lý do (không bắt buộc)';
  static const String deleteButton = 'XÓA TÀI KHOẢN';
  static const String wrongDeletePassword = 'Mật khẩu xác nhận không chính xác.';
  static const String deleted = 'Tài khoản của bạn đã được xóa.';
  static const String cancel = 'Hủy';
}
