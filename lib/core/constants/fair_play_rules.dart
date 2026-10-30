/// Quy tắc Fair Play (theo BE).
///
/// BE tính toán điểm (cộng/trừ sau đánh giá, trừ khi vắng/trễ/hủy, hồi phục theo thời gian)
/// và trả cờ chặn ghép LFG; mobile chỉ đọc. Các hằng số ở đây là giá trị mặc định của BE,
/// dùng cho bản giả lập và phần giải thích.
class FairPlayRules {
  FairPlayRules._();

  static const int initialScore = 100;
  static const int maxScore = 100;

  /// Dưới mức này không được tạo kèo hay Flash Claim LFG (Admin chỉnh được trên BE).
  static const int minScoreForLfg = 30;

  /// Điểm thấp tự hồi [recoveryPerDay] mỗi ngày, tới mức này thì dừng.
  /// Trên mức này chỉ tăng nhờ được người chơi khác đánh giá tốt.
  static const int recoveryCap = 40;
  static const int recoveryPerDay = 1;

  /// Thời hạn chấm người chơi cùng trận, tính từ giờ kết thúc trận.
  static const Duration reviewWindow = Duration(hours: 24);

  /// Vắng mặt, check-in trễ quá [lateLimit], hủy muộn hoặc chủ kèo hủy kèo.
  static const int noShowPenalty = -10;
  static const Duration lateLimit = Duration(minutes: 15);

  /// Điểm cộng/trừ theo số sao trung bình người chơi khác chấm trong một trận.
  /// BE chốt khi hết hạn chấm.
  static int reviewDelta(double averageStars) {
    if (averageStars < 1.5) return -5;
    if (averageStars < 2.5) return -2;
    if (averageStars >= 4.5) return 5;
    if (averageStars > 4) return 3;
    return 0;
  }

  static bool canJoinLfg(int score) => score >= minScoreForLfg;

  static bool isRecovering(int score) => score < recoveryCap;
}
