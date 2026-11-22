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
  static const String pendingSplitsTitle = 'Đang chờ nhóm chia Điểm';
  static String pendingSplit(int paid, int parts, String facility) => '$facility • đã trả $paid/$parts phần';

  // Thẻ đặt sân
  static const String statusUpcoming = 'Sắp diễn ra';
  static const String statusCancelled = 'Đã hủy';
  static const String statusCompleted = 'Đã kết thúc';
  static const String total = 'Giá sân';
  static const String paid = 'Đã trả';
  static String refunded(int amount) => 'Đã hoàn ${Formatters.vnd(amount)}';
  static const String ticket = 'Vé QR';
  static const String ticketTitle = 'VÉ QR CHECK-IN';
  static const String ticketNote = 'Xuất trình mã này cho chủ sân khi check-in và check-out.';
  static const String ticketRefreshNote = 'Mã tự đổi sau mỗi 30 giây, không cần chụp lại.';
  static const String ticketLoadError = 'Không tải được vé. Vui lòng thử lại.';
  static const String cancelReasonTitle = 'Lý do hủy';
  static const String cancelReasonHint = 'Nhập lý do hủy';
  static const String splitUnavailable = 'Chia Điểm nhóm đang được phát triển.';
  static const String close = 'Đóng';
  static const String cancel = 'Hủy đặt sân';
  static String freeCancelUntil(String t) => 'Hủy miễn phí trước $t';
  static const String lateCancelNote = 'Đã trong 24 giờ trước giờ chơi: hủy sẽ không được hoàn Điểm';
  static const String contributor = 'Bạn góp Điểm trong nhóm';

  // Hủy
  static const String confirmCancelTitle = 'Hủy đặt sân?';
  static String confirmCancelFree(int refund) =>
      'Còn hơn 24 giờ trước giờ chơi nên được hoàn 100% (${Formatters.vnd(refund)}).';
  static String confirmCancelLate(int lost) =>
      'Đã trong vòng 24 giờ trước giờ chơi nên không được hoàn Điểm (mất ${Formatters.vnd(lost)}).';
  static const String splitCancelFreeNote = ' Những người góp cũng được hoàn đủ phần của họ.';
  static const String splitCancelLateNote = ' Điểm của những người đã góp cũng không được hoàn.';
  static const String keep = 'Không';
  static String cancelledMessage(int refund) =>
      refund > 0 ? 'Đã hủy đặt sân. Hoàn ${Formatters.vnd(refund)} vào Ví điểm.' : 'Đã hủy đặt sân.';

  // Gói cố định hằng tuần
  static String discountBadge(int percent) => 'Giảm $percent% khi đặt cố định hằng tuần (từ 4 buổi)';
  static const String recurringToggle = 'Đặt lặp lại hằng tuần';
  static String recurringToggleHint(int percent) =>
      percent > 0 ? 'Cùng sân, cùng khung giờ mỗi tuần • giảm $percent%' : 'Cùng sân, cùng khung giờ mỗi tuần';
  static const String recurringPatternHint =
      'Chọn các khung giờ trên 1 sân con trong ngày bắt đầu, rồi chọn thứ lặp lại và số tuần.';
  static const String recurringOneCourtOnly = 'Chỉ áp dụng khi chọn khung giờ trên 1 sân con';
  static const String recurringLockedMultiCourt =
      'Đặt lặp lại chỉ áp dụng cho 1 sân con: đã tắt vì bạn chọn khung trên nhiều sân.';
  static const String recurringOneDay =
      'Đặt lặp lại chỉ chọn khung giờ trong 1 ngày bắt đầu: đã bỏ các khung ở ngày khác.';
  static const String recurringWeekdaysTitle = 'Lặp lại vào';
  static const List<String> weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const String recurringNoWeekday = 'Chọn ít nhất 1 thứ trong tuần.';
  static String recurringStartFrom(String date) => 'Bắt đầu từ $date';
  static const String recurringWeeksTitle = 'Số tuần (tính từ ngày bắt đầu)';
  static String recurringWeeks(int n) => '$n tuần';
  static String recurringCount(int days, int slots, int courts, int weeks, int total) =>
      '$days thứ × $slots khung${courts > 1 ? ' (trên $courts sân)' : ''} × $weeks tuần = $total lượt đặt';
  static String recurringPartialFail(int done, int total, String error) =>
      'Đã đặt được $done/$total gói, gói còn lại bị lỗi: $error\nCác gói đã đặt nằm trong Lịch Đặt (hủy được nếu cần).';
  static const String recurringPartialTitle = 'Đặt chưa trọn lịch';
  static const String recurringChecking = 'Đang kiểm tra các tuần sau...';
  static const String recurringWeekTaken = 'Đã có người đặt';
  static const String recurringWeekNotOpen = 'Sân chưa mở lịch';
  static const String recurringIncomplete =
      'Lịch lặp lại phải đủ mọi tuần liên tiếp. Đổi giờ / thứ khác hoặc giảm số tuần để bỏ buổi bị kẹt.';
  static const String recurringNoSplit = 'Gói cố định không chia Điểm nhóm được.';
  static const String recurringCancelRule =
      'Hủy là hủy cả gói, chỉ khi còn ít nhất 48 giờ trước buổi đầu; được hoàn 100%.';
  static String packageTitle(int sessions) => 'Gói cố định • $sessions buổi';
  static String packageSummary(int sessions, String weekdayTime) => '$sessions lượt • $weekdayTime hằng tuần';
  static String packagesBooked(int sessions, int packages, int amount) =>
      'Đã đặt lịch lặp lại $sessions lượt${packages > 1 ? ' ($packages gói)' : ''}, thanh toán ${Formatters.vnd(amount)}. '
      'Mỗi lượt có vé QR riêng trong Lịch Đặt.';
  static const String originalPrice = 'Giá gốc';
  static String discountRow(int percent) => 'Giảm đặt cố định ($percent%)';
  static const String estimatedNote = 'Giá cuối cùng do hệ thống tính khi đặt.';
  static String packageBooked(int sessions, int amount) =>
      'Đã đặt gói $sessions buổi, thanh toán ${Formatters.vnd(amount)}. Mỗi buổi có vé QR riêng trong Lịch Đặt.';
  static const String packageLabel = 'Gói cố định';
  static const String cancelPackage = 'Hủy cả gói';
  static String packageCancelUntil(String t) => 'Hủy cả gói được hoàn 100% trước $t';
  static const String packageCancelClosed = 'Đã quá mốc 48 giờ trước buổi đầu: gói không hủy được nữa';
  static const String confirmCancelPackageTitle = 'Hủy cả gói?';
  static String confirmCancelPackage(int sessions, int refund) =>
      'Gói cố định không hủy lẻ được. Hủy sẽ hủy toàn bộ $sessions buổi còn lại và hoàn 100% (${Formatters.vnd(refund)}).';
  static String packageCancelled(int refund) =>
      refund > 0 ? 'Đã hủy cả gói. Hoàn ${Formatters.vnd(refund)} vào Ví điểm.' : 'Đã hủy cả gói.';
  static const String sessionCancelledByOwner = 'Đã hủy';

  static String multiCourtHint(int courts) =>
      'Đang chọn $courts sân: bấm khung giờ là chọn cho cả $courts sân. Bấm lại ô sân để bỏ sân đó.';
  static String courtNotFree(String court, String times) =>
      '$court không còn trống $times nên chưa chọn được khung đó cho sân này.';

  /// Đặt nhiều sân con cùng lúc: các sân trong một ngày phải cùng bộ khung giờ.
  static String courtsMismatch(String court, String times, String day) =>
      'Các sân phải cùng khung giờ: $court còn thiếu $times ($day).';

  // Lỗi
  static String notAPackage(String reason) => 'Không đặt được gói định kỳ: $reason';
  static const String packageTooFew = 'cần ít nhất 4 buổi.';
  static const String packageSameCourt = 'các buổi phải cùng một sân con.';
  static const String packageSameLength = 'các buổi phải cùng độ dài.';
  static const String packageWeekly = 'các buổi phải cách nhau đúng 7 ngày, không bỏ tuần.';
  static const String packageCancelTooLate = 'Chỉ hủy được gói khi còn ít nhất 48 giờ trước buổi đầu tiên.';
  static const String loginRequired = 'Vui lòng đăng nhập để đặt sân.';
  static const String notFound = 'Không tìm thấy lần đặt sân.';
  static const String onlyBookerCancels = 'Chỉ người đặt mới hủy được.';
  static const String cannotCancel = 'Lần đặt này đã diễn ra hoặc đã hủy.';
  static const String useSplitFlow = 'Chia Điểm nhóm dùng luồng chia Điểm riêng.';
  static const String loadError = 'Không tải được lịch đặt. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
