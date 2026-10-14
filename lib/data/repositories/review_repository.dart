import '../../models/review.dart';

class ReviewException implements Exception {
  final String message;

  const ReviewException(this.message);

  @override
  String toString() => 'ReviewException: $message';
}

abstract class ReviewRepository {
  /// Các buổi đã check-out, còn trong hạn 24 giờ và chưa đánh giá; hạn gần nhất trước.
  Future<List<PendingReview>> getPendingReviews();

  /// Gửi đánh giá cho một buổi (chỉ một lần, không sửa được).
  /// [players]: người chơi được chấm; người không có trong danh sách coi như bỏ qua.
  /// Ném [ReviewException] nếu đã quá hạn, đã gửi rồi, hoặc không chấm gì.
  Future<void> submitReview(
    String sessionId, {
    FacilityReviewInput? facility,
    List<PlayerReviewInput> players = const [],
  });

  /// Điểm Fair Play hiện tại của người dùng và lịch sử thay đổi.
  Future<FairPlaySummary> getFairPlay();
}
