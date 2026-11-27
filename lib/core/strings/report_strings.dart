import '../utils/formatters.dart';

/// Chuỗi hiển thị cho khiếu nại đơn đặt sân / báo cáo người chơi phía Player (theo Web).
class ReportStrings {
  ReportStrings._();

  // Màn Trợ giúp & Khiếu nại
  static const String menu = 'Trợ giúp & Khiếu nại';
  static const String title = 'Trợ giúp & Khiếu nại';
  static const String tabCreate = 'Gửi khiếu nại';
  static String tabMine(int n) => 'Khiếu nại của tôi ($n)';

  // Form khiếu nại đơn
  static const String bookingFormTitle = 'Khiếu nại đơn đặt sân';
  static const String reasonLabel = 'Lý do / Loại khiếu nại';
  static const String reasonHint = '-- Chọn lý do phản ánh --';
  static const String bookingLabel = 'Đơn đặt sân liên quan';
  static const String bookingHint = '-- Chọn đơn đặt sân --';
  static const String noBookings = 'Bạn chưa có đơn đặt sân nào để khiếu nại.';
  static const String descriptionLabel = 'Mô tả chi tiết sự việc (tối thiểu 10 ký tự)';
  static const String descriptionHint =
      'Mô tả cụ thể thời gian, địa điểm, sự việc đã xảy ra để BQT SportNexus xử lý và hỗ trợ kịp thời...';
  static String evidenceLabel(int max) => 'Ảnh bằng chứng (không bắt buộc, tối đa $max)';
  static const String addImage = 'Thêm ảnh';
  static const String uploading = 'Đang tải…';
  static const String removeImage = 'Bỏ ảnh';
  static const String submitComplaint = 'Gửi khiếu nại';
  static const String sending = 'Đang gửi…';
  static const String complaintSent = 'Đã gửi khiếu nại thành công tới Ban Quản Trị!';
  static const String bookingComplaintShort = 'Khiếu nại';

  // Báo cáo người chơi
  static const String reportPlayer = 'Báo cáo';
  static const String reportPlayerTitle = 'Báo cáo người chơi';
  static const String descriptionShortLabel = 'Mô tả sự việc';
  static const String skillMisrepresentationHint =
      'Nêu rõ trận đã chơi cùng và vì sao trình độ thật khác Elo. Ảnh / video kết quả sẽ giúp Admin xác minh nhanh hơn.';
  static const String submitReport = 'Gửi báo cáo';
  static const String reportSent = 'Đã gửi báo cáo tới Admin.';
  static const String postReportSent = 'Đã gửi báo cáo bài viết vi phạm tiêu chuẩn cộng đồng tới Admin.';
  static const String commentReportSent = 'Đã gửi báo cáo bình luận vi phạm quy tắc cộng đồng tới Admin.';
  static const String matchReportSent = 'Đã gửi khiếu nại kết quả. Elo của trận sẽ chờ Admin xử lý.';
  static const String matchComplaint = 'Khiếu nại kết quả';
  static const String matchComplaintTitle = 'Khiếu nại kết quả trận';
  static const String refereeNote = 'Biên bản trọng tài: ';
  static const String organizerDecision = 'Quyết định của Ban tổ chức: ';
  static const String escalatedWaiting = 'Đã chuyển Admin, đang chờ phân xử.';
  static const String escalatedClosed = 'Admin đã phân xử.';
  static const String escalate = 'Không đồng ý, chuyển Admin';
  static const String escalateHint = 'Lý do bạn không đồng ý với Ban tổ chức';
  static const String escalateReasonRequired = 'Nhập lý do chuyển Admin.';
  static const String escalateSend = 'Gửi Admin';
  static const String escalated = 'Đã chuyển khiếu nại lên Admin phân xử.';
  static const String cannotEscalate = 'Khiếu nại này không chuyển Admin được nữa.';
  static const String cancel = 'Hủy';

  // Khiếu nại của tôi
  static const String mineEmpty = 'Bạn chưa có khiếu nại nào';
  static const String mineEmptyHint = 'Khiếu nại bạn gửi sẽ hiện ở đây kèm kết quả xử lý.';
  static String reportCode(String id) => 'Khiếu nại #$id';
  static const String reasonPrefix = 'Lý do: ';
  static String bookingRef(String id) => 'Mã đơn: #$id';
  static String reportedUser(String name) => 'Người bị báo cáo: $name';
  static const String ownerResponse = 'Giải trình của chủ sân: ';
  static const String resolution = 'Kết quả xử lý từ BQT: ';
  static String refunded(int amount) => 'Đã hoàn ${Formatters.vnd(amount)}';
  static const String withdraw = 'Rút khiếu nại';
  static const String withdrawConfirm = 'Bạn có chắc chắn muốn rút khiếu nại này không?';
  static const String keep = 'Không';
  static const String withdrawn = 'Đã rút khiếu nại thành công.';
  static const String withdrawNote = 'Người dùng tự nguyện rút lại báo cáo';

  // Lỗi
  static const String reasonsError = 'Không tải được danh sách lý do. Vui lòng thử lại sau.';
  static const String loadError = 'Không tải được danh sách khiếu nại. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
  static const String pickReason = 'Vui lòng chọn lý do khiếu nại!';
  static const String pickBooking = 'Vui lòng chọn đơn đặt sân cần khiếu nại!';
  static const String descriptionTooShort = 'Vui lòng nhập mô tả khiếu nại tối thiểu 10 ký tự!';
  static const String uploadError = 'Không tải ảnh lên được.';
  static const String sendError = 'Không thể gửi khiếu nại. Vui lòng thử lại.';
  static const String duplicateOpen = 'Đơn này đã có khiếu nại đang chờ xử lý.';
  static const String cannotWithdraw = 'Khiếu nại này không còn rút được.';
}
