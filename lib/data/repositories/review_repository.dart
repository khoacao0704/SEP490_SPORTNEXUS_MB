import '../../models/review.dart';

class ReviewException implements Exception {
  final String message;

  const ReviewException(this.message);

  @override
  String toString() => 'ReviewException: $message';
}

abstract class ReviewRepository {
  static const int reviewPageSize = 10;
  static const int fairPlayPageSize = 20;

  // ---------------- Chấm người chơi cùng trận ----------------

  /// Các trận còn hạn chấm và còn người chưa chấm; hạn gần nhất trước.
  Future<List<PendingReview>> getPendingReviews();

  /// Chấm từng người chơi của trận [sessionId] (gửi lần lượt; không sửa được).
  /// Người đã chấm trước đó thì bỏ qua. Ném [ReviewException] khi hết hạn hoặc lỗi.
  Future<void> ratePlayers(String sessionId, List<PlayerReviewInput> players);

  // ---------------- Đánh giá cơ sở ----------------

  /// Đánh giá công khai của một cơ sở, mới nhất trước. [stars] lọc theo số sao.
  Future<FacilityReviewPage> getFacilityReviews(String facilityId, {int? stars, int page = 1});

  Future<ReviewEligibility> getEligibility(String facilityId);

  /// Mỗi người một đánh giá cho mỗi cơ sở.
  Future<FacilityReviewItem> submitFacilityReview(String facilityId, FacilityReviewInput input);

  /// Đánh giá cơ sở của chính mình (kể cả bị Admin ẩn).
  Future<FacilityReviewPage> getMyReviews({int page = 1});

  // ---------------- Fair Play ----------------

  /// Điểm Fair Play, trạng thái chặn LFG và một trang lịch sử thay đổi.
  Future<FairPlaySummary> getFairPlay({int page = 1});
}
