/// Quy tắc ghép trận LFG đã chốt.
class LfgRules {
  LfgRules._();

  /// Kèo phải đủ người trước giờ bắt đầu ít nhất chừng này; quá mốc mà thiếu người thì hủy và hoàn 100%.
  static const Duration fillDeadlineBeforeStart = Duration(hours: 48);

  /// Chỉ được tạo kèo cho khung giờ bắt đầu trong vòng chừng này kể từ bây giờ.
  static const Duration maxCreateAhead = Duration(days: 5);

  /// Thời gian giữ chỗ khi Flash Claim / tạo kèo trong lúc thanh toán.
  static const Duration claimHold = Duration(minutes: 10);

  /// Khung giờ được phép tạo kèo: bắt đầu sau 48 giờ và trong vòng 5 ngày tới.
  static bool canCreateFor(DateTime start, DateTime now) =>
      !start.isBefore(now.add(fillDeadlineBeforeStart)) && !start.isAfter(now.add(maxCreateAhead));

  /// Cọc mỗi chỗ = tiền sân chia đều số chỗ (ghép 4: 1/4, ghép 2 / team vs team: 1/2), làm tròn lên 1.000đ.
  static int depositPerSlot(int courtPrice, int totalSlots) => ((courtPrice / totalSlots) / 1000).ceil() * 1000;
}
