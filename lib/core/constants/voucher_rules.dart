import '../../models/time_slot.dart';

/// Luật áp voucher khi đặt sân (BE 22/11/2026, AI đọc BookingService): 1 mã / đơn, gửi `voucherId` trong POST /bookings.
/// - Giảm = Round(tổng đơn × %), tổng đơn là giá sau giảm gói; không có trần, không giảm quá tổng đơn.
/// - Chỉ áp khi lần đặt tạo ĐÚNG 1 đơn: cùng 1 sân con, các ca liền nhau (BE gộp ca liền nhau thành 1 đơn).
/// - Không áp cho gói định kỳ (≥4 đơn), đơn chia tiền, LFG. Hủy đơn → BE trả mã lại. Nền tảng chịu phần giảm.
/// BE chưa có API xem trước → app tự tính; lỗi từ POST /bookings (400, chỉ có câu thông báo) là lớp chặn cuối.
class VoucherRules {
  VoucherRules._();

  /// Số Điểm được giảm khi áp [percent]% cho [total].
  static int discount(int total, int percent) {
    if (percent <= 0 || total <= 0) return 0;
    final value = (total * percent / 100).round();
    return value > total ? total : value;
  }

  /// Các ca đang chọn sẽ thành đúng 1 đơn (cùng sân con, liền nhau) → dùng được voucher.
  static bool formsSingleBooking(List<TimeSlot> slots) {
    if (slots.isEmpty) return false;
    final sorted = [...slots]..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].courtName != sorted[0].courtName || sorted[i].start != sorted[i - 1].end) return false;
    }
    return true;
  }
}
