/// Chuỗi hiển thị cho mục Đánh giá của Chủ sân (theo Web: OwnerReviews.jsx).
class OwnerReviewStrings {
  OwnerReviewStrings._();

  static const String title = 'Đánh giá của khách';
  static const String subtitle = 'Xem đánh giá về các cơ sở của bạn và phản hồi để giữ uy tín.';

  // Thống kê
  static const String statAverage = 'Điểm trung bình';
  static const String statTotal = 'Tổng đánh giá';
  static const String statUnreplied = 'Chưa phản hồi';
  static const String statReplyRate = 'Tỉ lệ phản hồi';
  static const String statNew30 = 'Mới trong 30 ngày';
  static const String distributionTitle = 'Phân bố số sao';
  static const String dash = '—';

  // Bộ lọc
  static const String allFacilities = 'Tất cả cơ sở';
  static const String allRatings = 'Mọi số sao';
  static String stars(int n) => '$n sao';
  static const String allReplied = 'Tất cả';
  static const String unreplied = 'Chưa phản hồi';
  static const String replied = 'Đã phản hồi';
  static const String filterFacility = 'Cơ sở';
  static const String filterRating = 'Số sao';
  static const String filterReplied = 'Phản hồi';

  // Danh sách
  static const String loading = 'Đang tải đánh giá…';
  static const String empty = 'Chưa có đánh giá nào phù hợp.';
  static const String guest = 'Khách';
  static const String hidden = 'Đã bị ẩn';
  static const String noComment = 'Khách không để lại bình luận.';
  static const String prev = 'Trước';
  static const String next = 'Sau';
  static String pageOf(int page, int total) => 'Trang $page / $total';

  // Phản hồi
  static const String yourReply = 'Phản hồi của bạn';
  static const String edit = 'Sửa';
  static const String delete = 'Xóa';
  static const String cancel = 'Hủy';
  static const String replyHint = 'Cảm ơn khách hoặc giải thích vấn đề…';
  static const String sendReply = 'Gửi phản hồi';
  static const String saveReply = 'Lưu phản hồi';
  static const String replyEmpty = 'Vui lòng nhập nội dung phản hồi.';
  static const String replySent = 'Đã gửi phản hồi.';
  static const String replyEdited = 'Đã sửa phản hồi.';
  static const String deleteConfirm = 'Xóa phản hồi này? Đánh giá của khách vẫn được giữ lại.';
  static const String replyDeleted = 'Đã xóa phản hồi.';
  static const int replyMaxLength = 1000;
  static const String noReplyYet = 'Đánh giá này chưa có phản hồi.';
  static const String alreadyReplied = 'Đánh giá này đã có phản hồi.';
  static const String notFound = 'Không tìm thấy đánh giá.';

  // Báo cáo (chỉ mobile)
  static const String report = 'Báo cáo';
  static const String reportTitle = 'Báo cáo đánh giá vi phạm';
  static const String reportHint = 'Admin sẽ xem xét và quyết định ẩn hay giữ đánh giá. Bạn không thể tự xóa đánh giá.';
  static const String reportNote = 'Ghi chú thêm cho Admin (không bắt buộc)';
  static const String sendReport = 'Gửi báo cáo';
  static const String reportSent = 'Đã gửi báo cáo cho Admin.';
  static const String alreadyReported = 'Đánh giá này đã được báo cáo.';
  static const String reportPending = 'Đã báo cáo • chờ Admin xem xét';
  static const String reportKept = 'Admin đã xem xét và giữ lại đánh giá';
  static const String reportUnavailable = 'Báo cáo đánh giá đang chờ hệ thống cập nhật, bạn thử lại sau.';
}

/// Chuỗi hiển thị cho mục Khiếu nại của Chủ sân (theo Web: OwnerReports.jsx).
class OwnerComplaintStrings {
  OwnerComplaintStrings._();

  static const String title = 'Khiếu nại của khách';
  static const String subtitle = 'Giải trình với Admin hoặc chủ động hoàn tiền cho các khiếu nại tại cơ sở của bạn.';
  static const String searchHint = 'Tìm theo tên khách, lý do…';
  static const String search = 'Tìm';
  static const String loading = 'Đang tải khiếu nại…';
  static const String empty = 'Không có khiếu nại nào.';
  static const String handle = 'Xử lý';
  static const String view = 'Xem';
  static const String loadError = 'Không tải được khiếu nại.';

  // Chi tiết
  static String detailTitle(String name) => 'Khiếu nại của $name';
  static String sentAt(String time) => 'gửi lúc $time';
  static const String bookingStatus = 'Đơn đặt:';
  static const String reason = 'Lý do';
  static const String slot = 'Ca đặt';
  static const String amount = 'Giá trị đơn';
  static const String requested = 'Khách yêu cầu hoàn';
  static const String contact = 'Liên hệ';
  static const String description = 'Mô tả của khách';
  static const String yourResponse = 'Giải trình của bạn';
  static String adminResult(String name, String note) => 'Admin${name.isEmpty ? '' : ' $name'}: $note';
  static const String adminHandled = 'đã xử lý';
  static String refunded(String amount, int pct) => ' • Hoàn $amount ($pct%)';

  // Xử lý
  static const String modeRespond = 'Gửi giải trình cho Admin';
  static const String modeRefund = 'Đồng ý hoàn tiền ngay';
  static const String fieldRespond = 'Nội dung giải trình';
  static const String fieldRefund = 'Nội dung gửi khách';
  static const String refundPercent = 'Tỉ lệ hoàn (%)';
  static const String lockSlot = 'Khóa ca này để bảo trì sân';
  static const String addEvidence = 'Thêm ảnh bằng chứng';
  static const String uploading = 'Đang tải…';
  static String evidenceCount(int n, int max) => '$n/$max ảnh';
  static const int maxEvidence = 5;
  static const int maxLength = 2000;
  static const String removeImage = 'Bỏ';
  static const String close = 'Đóng';
  static const String submitRespond = 'Gửi giải trình';
  static const String submitRefund = 'Hoàn tiền cho khách';
  static const String responseEmpty = 'Vui lòng nhập nội dung giải trình.';
  static String refundConfirm(int pct) => 'Đồng ý hoàn $pct% tiền cho khách ngay? Thao tác này không hoàn tác được.';
  static const String refundDone = 'Đã đồng ý hoàn tiền cho khách.';
  static const String respondDone = 'Đã gửi giải trình, Admin sẽ xem xét.';
  static const String uploadError = 'Không tải được ảnh.';
  static const String percentError = 'Tỉ lệ hoàn phải từ 1 đến 100%.';
  static const String cannotAct = 'Khiếu nại này đã được xử lý.';
  static const String notFound = 'Không tìm thấy khiếu nại.';
}
