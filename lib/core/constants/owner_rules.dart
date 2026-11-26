/// Chủ sân hủy đơn của khách (BE 20/11/2026, OwnerCancelBookingAsync; Web ownerCancelPenalty.js).
/// Khách luôn được hoàn 100% + voucher 10%. Điểm phạt trừ thẳng vào Ví điểm Chủ sân (ví có thể âm).
/// Đơn khách vãng lai trả tại quầy: không phạt tiền, không trừ Fair Play.
/// BE không có API xem trước tiền phạt nên app tự tính, số thật đọc từ kết quả hủy.
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

  static int percentFor({required bool late, bool walkIn = false}) =>
      walkIn ? 0 : (late ? latePenaltyPercent : earlyPenaltyPercent);

  static int fairPlayFor({required bool late, bool walkIn = false}) => walkIn || !late ? 0 : lateFairPlayPenalty;

  /// round(Tổng tiền đơn × 10% / 20%), giống công thức BE; vãng lai = 0.
  static int penaltyFor(int totalAmount, {required bool late, bool walkIn = false}) =>
      (totalAmount * percentFor(late: late, walkIn: walkIn) / 100).round();
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
