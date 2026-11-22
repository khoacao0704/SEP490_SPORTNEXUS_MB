/// Quy tắc ghép trận LFG đã chốt.
class LfgRules {
  LfgRules._();

  /// Kèo phải đủ người (chốt) trước giờ bắt đầu ít nhất chừng này; quá mốc mà thiếu người thì hủy và hoàn 100%.
  static const Duration fillDeadlineBeforeStart = Duration(hours: 48);

  /// Chủ kèo hủy trước mốc này: mọi người hoàn 100%, chủ kèo −[hostCancelFairPlay] Fair Play. Từ mốc này tới giờ
  /// chơi vẫn hủy được nhưng là hủy đơn phương (BE 20/11/2026; mốc thật BE trả `hostCancelUntil`).
  static const Duration hostCancelBeforeStart = Duration(hours: 48);

  /// Hủy đơn phương: chủ kèo mất chừng này % giá sân, chia đều bồi thường cho người đã vào kèo.
  static const int hostLateCancelLossPercent = 50;

  /// Điểm Fair Play chủ kèo bị trừ khi hủy kèo: trước mốc 48h / hủy đơn phương.
  static const int hostCancelFairPlay = 10;
  static const int hostLateCancelFairPlay = 20;

  /// Rời kèo trong khoảng này trước giờ chơi bị trừ Fair Play.
  static const Duration lateLeavePenaltyBeforeStart = Duration(hours: 24);

  /// Chỉ được tạo kèo cho khung giờ bắt đầu trong vòng chừng này kể từ bây giờ.
  static const Duration maxCreateAhead = Duration(days: 5);

  /// Thời gian giữ chỗ khi Flash Claim / tạo kèo trong lúc thanh toán.
  static const Duration claimHold = Duration(minutes: 10);

  /// Khung giờ được phép tạo kèo: bắt đầu sau 48 giờ và trong vòng 5 ngày tới.
  static bool canCreateFor(DateTime start, DateTime now) =>
      !start.isBefore(now.add(fillDeadlineBeforeStart)) && !start.isAfter(now.add(maxCreateAhead));

  /// Cọc mỗi chỗ = giá sân chia đều số chỗ (ghép 4: 1/4, ghép 2 / team vs team: 1/2), làm tròn lên 1.000đ.
  static int depositPerSlot(int courtPrice, int totalSlots) => ((courtPrice / totalSlots) / 1000).ceil() * 1000;
}
