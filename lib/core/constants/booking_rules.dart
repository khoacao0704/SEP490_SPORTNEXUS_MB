/// Quy tắc đặt sân thường đã chốt.
class BookingRules {
  BookingRules._();

  /// Hủy trước giờ chơi ít nhất chừng này thì được hoàn 100%.
  static const Duration freeCancelBeforeStart = Duration(hours: 24);

  /// Cọc khi chọn "ký quỹ": 1/4 tiền sân (làm tròn lên 1.000đ), phần còn lại trả tại sân.
  static int depositAmount(int total) => quarterOf(total);

  /// Hủy trong vòng 24 giờ trước giờ chơi thì mất 1/4 tiền sân (không vượt quá số đã trả).
  static int lateCancelFee(int total) => quarterOf(total);

  /// Cọc khi đặt nhiều khung giờ: mỗi khung là một lượt đặt riêng, cọc 1/4 của từng khung.
  static int depositFor(Iterable<int> slotPrices) => slotPrices.fold(0, (sum, p) => sum + depositAmount(p));

  static int quarterOf(int total) => ((total / 4) / 1000).ceil() * 1000;
}
