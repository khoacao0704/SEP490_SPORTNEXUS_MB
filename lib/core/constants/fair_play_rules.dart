/// Quy tắc Fair Play đã chốt.
///
/// BE tính toán điểm (cộng/trừ sau đánh giá, trừ khi hủy/vắng, hồi phục theo thời gian);
/// mobile chỉ đọc điểm và tự xét có được ghép LFG hay không.
class FairPlayRules {
  FairPlayRules._();

  static const int initialScore = 100;
  static const int maxScore = 100;

  /// Dưới mức này không được tạo kèo hay Flash Claim LFG.
  static const int minScoreForLfg = 30;

  /// Điểm dưới 30 tự hồi dần theo thời gian, hồi tới mức này thì dừng.
  static const int recoveryCap = 40;

  /// Thời hạn đánh giá sau khi chủ sân check-out.
  static const Duration reviewWindow = Duration(hours: 24);

  static bool canJoinLfg(int score) => score >= minScoreForLfg;

  static bool isRecovering(int score) => score < recoveryCap;
}
