/// Quy tắc Fair Play đã chốt.
///
/// BE tính toán điểm (cộng/trừ sau đánh giá, trừ khi vắng/trễ, hồi phục theo thời gian);
/// mobile chỉ đọc điểm và tự xét có được ghép LFG hay không.
class FairPlayRules {
  FairPlayRules._();

  static const int initialScore = 100;
  static const int maxScore = 100;

  /// Dưới mức này không được tạo kèo hay Flash Claim LFG.
  static const int minScoreForLfg = 30;

  /// Điểm dưới 30 tự hồi dần theo thời gian, hồi tới mức này thì dừng.
  /// Trên mức này chỉ tăng nhờ được người chơi khác đánh giá tốt.
  static const int recoveryCap = 40;

  /// Thời hạn đánh giá sau khi chủ sân check-out.
  static const Duration reviewWindow = Duration(hours: 24);

  /// Vắng mặt (không check-in) hoặc trễ quá [lateLimit].
  static const int noShowPenalty = -10;
  static const Duration lateLimit = Duration(minutes: 15);

  /// Điểm cộng/trừ theo số sao trung bình người chơi khác chấm sau một trận LFG.
  /// Team vs Team: người đại diện ghép kèo nhận thay cả đội.
  static int reviewDelta(double averageStars) {
    if (averageStars < 2.5) return -5;
    if (averageStars < 4) return 0;
    if (averageStars <= 4.5) return 3;
    return 5;
  }

  static bool canJoinLfg(int score) => score >= minScoreForLfg;

  static bool isRecovering(int score) => score < recoveryCap;
}
