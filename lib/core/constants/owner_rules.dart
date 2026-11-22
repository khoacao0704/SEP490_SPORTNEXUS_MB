/// Quy tắc check-in / check-out phía Chủ sân đã chốt.
class OwnerRules {
  OwnerRules._();

  /// Mở check-in từ 30 phút trước giờ chơi.
  static const Duration checkInOpensBefore = Duration(minutes: 30);

  /// Quá 15 phút sau giờ chơi chưa check-in thì hệ thống (BE) tự đánh vắng mặt, trừ Fair Play.
  static const Duration checkInClosesAfter = Duration(minutes: 15);
}

/// Chủ sân hủy đơn của khách (BE 20/11/2026, OwnerCancelBookingAsync). Hủy được mọi lúc khi đơn chưa hủy.
/// Khách luôn được hoàn 100% + voucher 10%. Điểm phạt trừ thẳng vào Ví điểm Chủ sân (ví có thể âm).
class OwnerCancelRules {
  OwnerCancelRules._();

  /// Hủy dưới mốc này trước giờ chơi là hủy muộn: phạt nặng hơn và trừ Fair Play. Mốc này là hằng số cứng trong BE.
  static const Duration lateBefore = Duration(hours: 48);
  static const int latePenaltyPercent = 20;
  static const int earlyPenaltyPercent = 10;
  static const int lateFairPlayPenalty = 10;

  /// Voucher khách nhận khi bị Chủ sân hủy đơn.
  static const int customerVoucherPercent = 10;

  static bool isLate(DateTime start, DateTime now) => now.isAfter(start.subtract(lateBefore));

  /// round(Tổng tiền đơn × 10% / 20%), giống công thức BE.
  static int penaltyFor(int totalAmount, {required bool late}) =>
      (totalAmount * (late ? latePenaltyPercent : earlyPenaltyPercent) / 100).round();
}

/// Phí duy trì bài đăng sân hàng tháng.
class ListingFeeRules {
  ListingFeeRules._();

  /// 10% tổng doanh thu tháng (toàn bộ giá sân, gồm phần chủ sân tự thu tại sân, và Điểm phạt).
  static const int percent = 10;

  /// Ngày 1 chốt phí tháng trước, hạn trả hết ngày 7. Quá hạn: ẩn tất cả cơ sở, chặn đổi Điểm ra tiền.
  static const int dueDay = 7;

  static int feeFor(int revenue) => (revenue * percent / 100).round();
}
