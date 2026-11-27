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
  /// Bậc hoàn đang áp: "Hủy trước 20:00 Thứ 4, 26/11: hoàn 80%".
  static String cancelTierUntil(String t, int percent) => 'Hủy trước $t: hoàn $percent%';
  static const String lateCancelNote = 'Dưới 48 giờ trước giờ chơi: hủy sẽ không được hoàn Điểm';
  static const String contributor = 'Bạn góp Điểm trong nhóm';

  /// Luật hoàn khi hủy (BE BookingCancelPolicy), hiện ở chi tiết sân / thanh toán.
  static const String cancelPolicy = 'Hủy đặt sân: từ 7 ngày trước giờ chơi hoàn 100%, từ 3 ngày hoàn 80%, '
      'từ 48 giờ hoàn 50%, dưới 48 giờ không hoàn.';

  // Hủy
  static const String confirmCancelTitle = 'Hủy đặt sân?';

  /// Lời xác nhận hủy theo bậc: [percent] = 100 / 80 / 50 / 0.
  static String confirmCancel(int percent, int refund, int lost) => switch (percent) {
        >= 100 => 'Còn từ 7 ngày trước giờ chơi nên được hoàn 100% (${Formatters.vnd(refund)}).',
        <= 0 => 'Dưới 48 giờ trước giờ chơi nên không được hoàn Điểm (mất ${Formatters.vnd(lost)}).',
        _ => 'Còn ${percent == 80 ? 'từ 3 đến dưới 7 ngày' : 'từ 48 giờ đến dưới 3 ngày'} trước giờ chơi nên được '
            'hoàn $percent% (${Formatters.vnd(refund)}), mất ${Formatters.vnd(lost)}.',
      };

  /// Đơn chia Điểm còn chờ góp: lúc nào hủy cũng hoàn đủ.
  static String confirmCancelAwaiting(int refund) =>
      'Đơn chia Điểm chưa đủ người góp nên được hoàn 100% (${Formatters.vnd(refund)}).';

  /// Ghi chú cho đơn chia Điểm: mọi người cùng chịu một %.
  static String splitCancelNote(int percent) => switch (percent) {
        >= 100 => ' Những người góp cũng được hoàn đủ phần của họ.',
        <= 0 => ' Điểm của những người đã góp cũng không được hoàn.',
        _ => ' Những người đã góp cũng được hoàn $percent% phần của họ.',
      };

  /// Hủy có hoàn thì BE trả lại mã giảm giá đã dùng cho đơn.
  static const String voucherReturnedNote = ' Mã giảm giá đã dùng cho đơn (nếu có) sẽ được trả lại.';
  static const String keep = 'Không';
  static String cancelledMessage(int refund) =>
      refund > 0 ? 'Đã hủy đặt sân. Hoàn ${Formatters.vnd(refund)} vào Ví điểm.' : 'Đã hủy đặt sân.';

  // Gói cố định hằng tuần
  static String discountBadge(int percent) => '🔥 -$percent% Đặt Cố Định';
  static String discountBanner(int percent) =>
      'Cơ sở này giảm $percent% khi bạn đặt cố định hằng tuần (cùng sân, cùng giờ, từ 4 tuần liên tiếp)!';
  static const String splitNotForPackage = 'Tính năng chia tiền không áp dụng cho Gói đặt lịch định kỳ.';
  static const String packagePrepayTitle = 'Tổng tiền cần thanh toán trả trước:';
  static String payNowPackage(int amount) => 'Thanh toán ngay ${Formatters.vnd(amount)}';
  static String autoPackageNote(int percent) =>
      'Các ca bạn chọn cùng sân con, cùng giờ, từ 4 tuần liên tiếp nên hệ thống tính là gói cố định hằng tuần'
      '${percent > 0 ? ' (giảm $percent%)' : ''}.';
  static const String recurringToggle = 'Lặp lại vào giờ này mỗi tuần';
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
  static const String recurringFewerWeeks = 'Bớt 1 tuần';
  static const String recurringMoreWeeks = 'Thêm 1 tuần';
  static String recurringCount(int days, int slots, int courts, int weeks, int total) =>
      '$days thứ × $slots khung${courts > 1 ? ' (trên $courts sân)' : ''} × $weeks tuần = $total lượt đặt';
  static String recurringPartialFail(int done, int total, String error) =>
      'Đã đặt được $done/$total gói, gói còn lại bị lỗi: $error\nCác gói đã đặt nằm trong Lịch Đặt (hủy được nếu cần).';
  static const String recurringPartialTitle = 'Đặt chưa trọn lịch';
  static const String recurringChecking = 'Đang kiểm tra các tuần sau...';
  static const String recurringWeekTaken = 'Đã có người đặt';
  static const String recurringWeekNotOpen = 'Sân chưa mở lịch';
  static const String recurringWeekLengthMismatch = 'Lệch độ dài ca';
  static const String recurringWeekInvalid = 'Sai luật gói';
  static const String recurringHasBadDay = 'có buổi bị thiếu ca trống hoặc lệch độ dài ca.';
  static const String recurringDaysTitle = 'Các buổi trong lịch';
  static const String recurringInvalidTitle = 'Lịch này KHÔNG thành gói định kỳ';
  static String recurringInvalid(List<String> reasons) =>
      'Lý do: ${reasons.join(' ')} Lịch như vậy không được giảm giá và hệ thống sẽ từ chối. '
      'Quay lại chọn giờ / thứ / số tuần khác.';
  static const String recurringIncomplete =
      'Lịch lặp lại phải đủ mọi tuần liên tiếp. Đổi giờ / thứ khác hoặc giảm số tuần để bỏ buổi bị kẹt.';
  static const String recurringNoSplit = 'Gói cố định không chia Điểm nhóm được.';
  // Voucher ở Checkout (thẻ 43)
  static const String voucherPick = 'Chọn Voucher';
  static const String voucherNone = 'Chưa có mã giảm giá';
  static const String voucherDontUse = 'Không dùng mã';
  static String voucherChosen(int percent) => 'Mã giảm $percent%';
  static String voucherExpires(String date) => 'HSD: $date';
  static const String voucherSheetTitle = 'Mã giảm giá của bạn';
  static const String voucherSingleOnly = 'Voucher chỉ dùng khi đặt 1 sân con, các ca liền nhau.';
  static const String voucherNotForPackage = 'Voucher không áp dụng cho gói đặt lịch định kỳ.';
  static const String voucherNotForSplit = 'Voucher không áp dụng cho đơn chia tiền.';
  static const String voucherRemovedForSplit = 'Đã bỏ mã giảm giá: voucher không áp dụng cho đơn chia tiền.';
  static const String voucherUnavailable = 'Voucher không còn khả dụng';
  static const String formulaTotal = 'Tổng tiền';
  static String formulaDiscount(int percent) => 'Voucher giảm $percent%';
  static const String formulaPay = 'Thực tế cần thanh toán';
  static const String recurringCancelRule =
      'Hủy là hủy cả gói, chỉ khi còn ít nhất 48 giờ trước buổi đầu. Hoàn theo thời gian còn lại tới buổi đầu: '
      'từ 7 ngày 100%, từ 3 ngày 80%, từ 48 giờ 50%.';
  static String packageTitle(int sessions) => 'Gói cố định • $sessions buổi';
  static String packageSummary(int sessions, String weekdayTime) => '$sessions lượt • $weekdayTime hằng tuần';
  static String packagesBooked(int sessions, int packages, int amount) =>
      'Đã đặt lịch lặp lại $sessions lượt${packages > 1 ? ' ($packages gói)' : ''}, thanh toán ${Formatters.vnd(amount)}. '
      'Mỗi lượt có vé QR riêng trong Lịch Đặt.';
  static const String originalPrice = 'Giá gốc';
  static String discountRow(int percent) => 'Đã áp dụng giảm $percent% Đặt lịch cố định';
  static String monthlyPackageNote(int percent) => 'Giảm $percent% khi đặt gói tháng (cố định hằng tuần, 4–8 tuần).';
  static const String estimatedNote = 'Giá cuối cùng do hệ thống tính khi đặt.';
  static String packageBooked(int sessions, int amount) =>
      'Đã đặt gói $sessions buổi, thanh toán ${Formatters.vnd(amount)}. Mỗi buổi có vé QR riêng trong Lịch Đặt.';
  static const String packageLabel = 'Gói cố định';
  static const String cancelPackage = 'Hủy cả gói';
  static String packageCancelUntil(String t, int percent) => 'Hủy cả gói trước $t: hoàn $percent%';
  static const String packageCancelClosed = 'Đã quá mốc 48 giờ trước buổi đầu: gói không hủy được nữa';
  static const String confirmCancelPackageTitle = 'Hủy cả gói?';
  static String confirmCancelPackage(int sessions, int percent, int refund, int lost) =>
      'Gói cố định không hủy lẻ được. Hủy sẽ hủy toàn bộ $sessions buổi còn lại và hoàn $percent% '
      '(${Formatters.vnd(refund)})${lost > 0 ? ', mất ${Formatters.vnd(lost)}' : ''}.';
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
