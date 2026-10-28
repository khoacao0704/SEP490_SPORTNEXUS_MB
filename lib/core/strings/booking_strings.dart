import '../utils/formatters.dart';

/// Chuỗi hiển thị cho đặt sân thường và màn "Lịch Đặt & QR".
class BookingStrings {
  BookingStrings._();

  // Lịch Đặt & QR
  static const String title = 'Lịch Đặt & QR';
  static const String tabBookings = 'Sân đã đặt';
  static const String tabLfg = 'Kèo LFG';
  static const String empty = 'Chưa có lịch đặt sân nào';
  static const String emptyHint = 'Đặt sân để nhận vé QR check-in tại đây.';
  static const String pendingSplitsTitle = 'Đang chờ nhóm chia tiền';
  static String pendingSplit(int paid, int parts, String facility) => '$facility • đã trả $paid/$parts phần';

  // Thẻ đặt sân
  static const String statusUpcoming = 'Sắp diễn ra';
  static const String statusCancelled = 'Đã hủy';
  static const String statusCompleted = 'Đã kết thúc';
  static const String total = 'Tiền sân';
  static const String paid = 'Đã trả';
  static String refunded(int amount) => 'Đã hoàn ${Formatters.vnd(amount)}';
  static const String ticket = 'Vé QR';
  static const String ticketTitle = 'VÉ QR CHECK-IN';
  static const String ticketNote = 'Xuất trình mã này cho chủ sân khi check-in và check-out.';
  static const String ticketRefreshNote = 'Mã tự đổi sau mỗi 30 giây, không cần chụp lại.';
  static const String ticketLoadError = 'Không tải được vé. Vui lòng thử lại.';
  static const String cancelReasonTitle = 'Lý do hủy';
  static const String cancelReasonHint = 'Nhập lý do hủy';
  static const String splitUnavailable = 'Chia tiền nhóm đang được phát triển.';
  static const String close = 'Đóng';
  static const String cancel = 'Hủy đặt sân';
  static String freeCancelUntil(String t) => 'Hủy miễn phí trước $t';
  static const String lateCancelNote = 'Đã trong 24 giờ trước giờ chơi: hủy sẽ không được hoàn tiền';
  static const String contributor = 'Bạn góp tiền trong nhóm';

  // Hủy
  static const String confirmCancelTitle = 'Hủy đặt sân?';
  static String confirmCancelFree(int refund) =>
      'Còn hơn 24 giờ trước giờ chơi nên được hoàn 100% (${Formatters.vnd(refund)}).';
  static String confirmCancelLate(int lost) =>
      'Đã trong vòng 24 giờ trước giờ chơi nên không được hoàn tiền (mất ${Formatters.vnd(lost)}).';
  static const String splitCancelFreeNote = ' Những người góp cũng được hoàn đủ phần của họ.';
  static const String splitCancelLateNote = ' Tiền những người đã góp cũng không được hoàn.';
  static const String keep = 'Không';
  static String cancelledMessage(int refund) =>
      refund > 0 ? 'Đã hủy đặt sân. Hoàn ${Formatters.vnd(refund)} vào ví.' : 'Đã hủy đặt sân.';

  // Lỗi
  static const String loginRequired = 'Vui lòng đăng nhập để đặt sân.';
  static const String notFound = 'Không tìm thấy lần đặt sân.';
  static const String onlyBookerCancels = 'Chỉ người đặt mới hủy được.';
  static const String cannotCancel = 'Lần đặt này đã diễn ra hoặc đã hủy.';
  static const String useSplitFlow = 'Chia tiền nhóm dùng luồng chia tiền riêng.';
  static const String loadError = 'Không tải được lịch đặt. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
