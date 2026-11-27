/// Luật hoàn tiền khi người đặt hủy (BE BookingCancelPolicy.Evaluate, 24/11/2026), theo thời gian còn lại tới giờ chơi:
/// - từ 7 ngày: hoàn 100% • từ 3 đến dưới 7 ngày: 80% • từ 48 giờ đến dưới 3 ngày: 50%
/// - dưới 48 giờ: đơn lẻ hoàn 0%, gói định kỳ không hủy được.
/// - Đơn chia Điểm còn chờ góp: luôn hoàn 100%.
/// - Gói định kỳ: bậc xét MỘT lần theo buổi đầu còn hiệu lực; % áp cho từng buổi, tổng hoàn = tổng các buổi.
/// - Đơn chia Điểm đã đủ: mọi người cùng một %, chia theo tỷ lệ phần đã góp (người cuối nhận phần còn lại).
/// - % tính trên số đã trả thật (sau voucher); hủy có hoàn thì BE trả lại voucher.
/// BE chưa có API xem trước tiền hoàn → app tự tính; số thật đọc refundAmount BE trả sau khi hủy.
class BookingCancelPolicy {
  BookingCancelPolicy._();

  /// (còn lại ít nhất, % hoàn), sắp từ mốc xa nhất.
  static const List<(Duration, int)> tiers = [
    (Duration(days: 7), 100),
    (Duration(days: 3), 80),
    (Duration(hours: 48), 50),
  ];

  /// Dưới mốc này: đơn lẻ hoàn 0%, gói không hủy được.
  static const Duration lockBeforeStart = Duration(hours: 48);

  /// % hoàn khi hủy lúc còn [left] tới giờ chơi.
  static int refundPercent(Duration left) {
    for (final (min, percent) in tiers) {
      if (left >= min) return percent;
    }
    return 0;
  }

  /// Bậc đang áp: hủy tới [until] (còn đúng mốc vẫn tính) thì được [percent]%; `null` khi đã dưới 48 giờ.
  static ({DateTime until, int percent})? currentTier(DateTime start, DateTime now) {
    for (final (min, percent) in tiers) {
      final until = start.subtract(min);
      if (!now.isAfter(until)) return (until: until, percent: percent);
    }
    return null;
  }

  /// Số được hoàn: [amount] × [percent]%, làm tròn như BE (Math.Round của .NET: .5 về số chẵn gần nhất).
  static int refund(int amount, int percent) {
    if (percent >= 100) return amount;
    if (percent <= 0 || amount <= 0) return 0;
    return roundHalfEven(amount * percent / 100);
  }

  /// Làm tròn tới số nguyên, phần .5 về số chẵn gần nhất (banker's rounding, mặc định của .NET).
  static int roundHalfEven(double value) {
    final floor = value.floorToDouble();
    final diff = value - floor;
    if ((diff - 0.5).abs() < 1e-9) return floor.toInt().isEven ? floor.toInt() : floor.toInt() + 1;
    return value.round();
  }

  /// Chia [total] tiền hoàn cho từng người theo tỷ lệ [paid] (BE BookingPayoutHelper.Split): mỗi người làm tròn,
  /// người cuối nhận phần còn lại để tổng khớp.
  static List<int> split(int total, List<int> paid) {
    final sum = paid.fold(0, (a, b) => a + b);
    if (paid.isEmpty || sum <= 0) return List.filled(paid.length, 0);
    final result = <int>[];
    var given = 0;
    for (var i = 0; i < paid.length; i++) {
      final share = i == paid.length - 1 ? total - given : roundHalfEven(total * paid[i] / sum);
      result.add(share);
      given += share;
    }
    return result;
  }
}

/// Đặt sân gói cố định hằng tuần (BE: IsRecurring + RecurringGroupId).
/// - Gói = cùng sân con, cùng giờ, các tuần liên tiếp (buổi sau cách buổi trước đúng 7 ngày, không bỏ tuần).
///   Các ca liền nhau trong cùng một ngày tính là một buổi.
/// - Giảm theo % chủ sân đặt cho cơ sở (0–50%, 0% vẫn là gói); gói không chia Điểm nhóm.
/// - Người đặt hủy bất kỳ buổi nào = hủy cả gói, chỉ khi còn ít nhất [cancelBeforeFirst] trước buổi đầu;
///   hoàn theo bậc [BookingCancelPolicy] tính tới buổi đầu, áp cho từng buổi.
class RecurringBookingRules {
  RecurringBookingRules._();

  static const int minSessions = 4;

  static const Duration interval = Duration(days: 7);

  /// Chủ sân đặt % giảm trong khoảng 0–[maxDiscountPercent] (BE trả 400 nếu ngoài khoảng); gợi ý sẵn [suggestedDiscountPercent].
  static const int maxDiscountPercent = 50;
  static const int suggestedDiscountPercent = 10;
  static const Duration cancelBeforeFirst = Duration(hours: 48);

  /// Giá sau giảm [percent]% (làm tròn tới đồng); chỉ để hiển thị trước khi đặt, giá thật lấy từ BE.
  static int discounted(int amount, int percent) => percent <= 0 ? amount : (amount * (100 - percent) / 100).round();
}
