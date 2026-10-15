/// Quy tắc check-in / check-out phía Chủ sân đã chốt.
class OwnerRules {
  OwnerRules._();

  /// Mở check-in từ 30 phút trước giờ chơi.
  static const Duration checkInOpensBefore = Duration(minutes: 30);

  /// Quá 15 phút sau giờ chơi chưa check-in thì hệ thống (BE) tự đánh vắng mặt, trừ Fair Play.
  static const Duration checkInClosesAfter = Duration(minutes: 15);
}

/// Phí duy trì bài đăng sân hàng tháng.
class ListingFeeRules {
  ListingFeeRules._();

  /// 10% tổng doanh thu tháng (toàn bộ tiền sân, gồm phần chủ sân tự thu tại sân, và tiền phạt).
  static const int percent = 10;

  /// Ngày 1 chốt phí tháng trước, hạn trả hết ngày 7. Quá hạn: ẩn tất cả cơ sở, chặn rút tiền.
  static const int dueDay = 7;

  static int feeFor(int revenue) => (revenue * percent / 100).round();
}
