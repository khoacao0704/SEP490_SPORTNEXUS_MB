/// Chuỗi hiển thị cho mục Đánh giá của Chủ sân.
class OwnerReviewStrings {
  OwnerReviewStrings._();

  static const String title = 'Đánh Giá Từ Người Chơi';
  static const String anonymous = 'Người chơi ẩn danh';
  static String reviewCount(int n) => '$n đánh giá';
  static String unreplied(int n) => '$n chưa trả lời';
  static const String filterAll = 'Tất cả';
  static const String filterUnreplied = 'Chưa trả lời';
  static const String filterLow = '1-2 sao';
  static const String empty = 'Chưa có đánh giá nào.';
  static const String emptyFilter = 'Không có đánh giá phù hợp.';
  static const String loadError = 'Không tải được đánh giá. Kéo xuống để thử lại.';

  // Trả lời
  static const String reply = 'Trả lời';
  static const String editReply = 'Sửa trả lời';
  static const String yourReply = 'Phản hồi của chủ sân';
  static const String replyTitle = 'Trả lời công khai';
  static const String replyHint = 'Câu trả lời hiện công khai dưới đánh giá cho mọi người xem.';
  static const String replyPlaceholder = 'VD: Cảm ơn bạn, sân đã thay đèn mới.';
  static const String send = 'Gửi';
  static const String replySaved = 'Đã đăng câu trả lời.';
  static const String replyEmpty = 'Hãy nhập nội dung trả lời.';
  static const int replyMaxLength = 500;
  static const String cannotReplyHidden = 'Đánh giá đã bị Admin ẩn nên không trả lời được.';

  // Báo cáo
  static const String report = 'Báo cáo';
  static const String reportTitle = 'Báo cáo đánh giá vi phạm';
  static const String reportHint = 'Admin sẽ xem xét và quyết định ẩn hay giữ đánh giá. Bạn không thể tự xóa đánh giá.';
  static const String reportNote = 'Ghi chú thêm cho Admin (không bắt buộc)';
  static const String sendReport = 'Gửi báo cáo';
  static const String reportSent = 'Đã gửi báo cáo cho Admin.';
  static const String alreadyReported = 'Đánh giá này đã được báo cáo.';
  static const String reportPending = 'Đã báo cáo • chờ Admin xem xét';
  static const String reportKept = 'Admin đã xem xét và giữ lại đánh giá';
  static const String reportHidden = 'Admin đã ẩn đánh giá này (không tính vào điểm)';
  static const String notFound = 'Không tìm thấy đánh giá.';
  static const String cancel = 'Hủy';
}
