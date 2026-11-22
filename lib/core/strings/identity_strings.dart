/// Chuỗi hiển thị cho xác minh danh tính (eKYC).
class IdentityStrings {
  IdentityStrings._();

  static const String title = 'Xác minh danh tính';
  static const String menu = 'Xác minh danh tính (eKYC)';
  static const String intro =
      'Chụp CCCD 2 mặt và ảnh chân dung để xác minh tài khoản. Admin duyệt thủ công; ảnh được lưu riêng tư.';

  // Trạng thái
  static const String statusNone = 'Chưa xác minh';
  static const String statusPending = 'Đang chờ duyệt';
  static const String statusApproved = 'Đã xác minh';
  static const String statusRejected = 'Bị từ chối';
  static const String pendingNote = 'Hồ sơ đã gửi, Admin đang duyệt. Trong lúc chờ không gửi lại được.';
  static const String approvedNote = 'Tài khoản đã được xác minh danh tính.';
  static String rejectedNote(String reason) =>
      reason.isEmpty ? 'Hồ sơ bị từ chối. Sửa lại và gửi lại nhé.' : 'Hồ sơ bị từ chối: $reason';
  static String submittedAt(String time) => 'Gửi lúc $time';

  // Form
  static const String fullName = 'Họ và tên (như trên CCCD)';
  static const String idNumber = 'Số CCCD (12 số)';
  static const String dateOfBirth = 'Ngày sinh';
  static const String address = 'Địa chỉ (không bắt buộc)';
  static const String pickDate = 'Chọn ngày sinh';
  static const String required = 'Bắt buộc';
  static const String invalidIdNumber = 'Số CCCD phải gồm đúng 12 chữ số.';
  static const String underAge = 'Bạn phải từ 18 tuổi trở lên.';

  static const String photosTitle = 'Ảnh xác minh';
  static const String idFront = 'CCCD mặt trước';
  static const String idBack = 'CCCD mặt sau';
  static const String selfie = 'Ảnh chân dung';
  static const String takePhoto = 'Chụp ảnh';
  static const String fromGallery = 'Chọn từ thư viện';
  static const String retake = 'Chụp lại';
  static const String uploading = 'Đang tải ảnh...';
  static const String missingPhoto = 'Cần đủ 3 ảnh.';
  static const String pickError = 'Không mở được máy ảnh / thư viện.';
  static const String uploadError = 'Tải ảnh lên không được, thử lại nhé.';

  static const String submit = 'Gửi xác minh';
  static const String resubmit = 'Gửi lại';
  static const String submitted = 'Đã gửi hồ sơ xác minh. Admin sẽ duyệt sớm.';
  static const String loadError = 'Không tải được trạng thái xác minh.';
  static const String retry = 'Thử lại';
}
