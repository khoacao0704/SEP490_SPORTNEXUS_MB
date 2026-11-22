/// Quy tắc đặt sân thường đã chốt. Đặt sân thường KHÔNG có cọc: trả 100% hoặc chia Điểm nhóm.
class BookingRules {
  BookingRules._();

  /// Hủy trước giờ chơi ít nhất chừng này thì được hoàn 100%; hủy trong khoảng này thì mất 100%
  /// (không hoàn cho ai, kể cả người góp Điểm nhóm — chủ sân nhận hết).
  static const Duration freeCancelBeforeStart = Duration(hours: 24);
}

/// Đặt sân gói cố định hằng tuần (BE: IsRecurring + RecurringGroupId).
/// - Gói = cùng sân con, cùng giờ, các tuần liên tiếp (buổi sau cách buổi trước đúng 7 ngày, không bỏ tuần).
///   Các ca liền nhau trong cùng một ngày tính là một buổi.
/// - Giảm theo % chủ sân đặt cho cơ sở (0–50%, 0% vẫn là gói); gói không chia Điểm nhóm.
/// - Người đặt hủy bất kỳ buổi nào = hủy cả gói, chỉ khi còn ít nhất [cancelBeforeFirst] trước buổi đầu; hoàn 100%.
class RecurringBookingRules {
  RecurringBookingRules._();

  static const int minSessions = 4;

  /// Số tuần tối đa cho chọn. BE sinh sẵn khung giờ trước ~35 ngày nên tuần xa có thể "chưa mở lịch".
  static const int maxSessions = 8;

  static const Duration interval = Duration(days: 7);

  /// Chủ sân đặt % giảm trong khoảng 0–[maxDiscountPercent] (BE trả 400 nếu ngoài khoảng); gợi ý sẵn [suggestedDiscountPercent].
  static const int maxDiscountPercent = 50;
  static const int suggestedDiscountPercent = 10;
  static const Duration cancelBeforeFirst = Duration(hours: 48);

  /// Giá sau giảm [percent]% (làm tròn tới đồng); chỉ để hiển thị trước khi đặt, giá thật lấy từ BE.
  static int discounted(int amount, int percent) => percent <= 0 ? amount : (amount * (100 - percent) / 100).round();
}
