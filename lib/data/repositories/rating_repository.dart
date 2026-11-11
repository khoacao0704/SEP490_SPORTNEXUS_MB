import '../../models/sport.dart';
import '../../models/sport_rating.dart';
import '../api/api_error_codes.dart';

/// Lỗi Elo / khảo sát trình độ; [message] sẵn sàng để hiển thị.
class RatingException implements Exception, CodedError {
  @override
  final String message;

  @override
  final String? code;

  @override
  final Map<String, dynamic>? detail;

  const RatingException(this.message, {this.code, this.detail});

  RatingException.fromApi(CodedError e) : this(e.message, code: e.code, detail: e.detail);

  @override
  String toString() => 'RatingException: $message';
}

/// Elo theo môn (cá nhân + đội), bảng xếp hạng và khảo sát trình độ toàn diện.
///
/// Elo không tự sinh từ khảo sát người chơi: mỗi môn phải làm khảo sát trình độ một lần mới có Elo
/// (chưa có thì không tạo đội / nhận lời mời vào đội / đăng ký giải môn đó được).
abstract class RatingRepository {
  /// Elo của mình và của các đội mình đang ở; rỗng khi chưa làm khảo sát trình độ môn nào.
  Future<List<SportRating>> getMyRatings();

  /// Bảng xếp hạng (công khai); chỉ người / đội đã có trận tính Elo. [page] bắt đầu từ 1.
  Future<LeaderboardPage> getLeaderboard(Sport sport, {RatingType type = RatingType.personal, int page = 1});

  /// Đề khảo sát trình độ của môn + lần làm gần nhất + lý do bị chặn (nếu có).
  Future<AssessmentForm> getAssessmentForm(Sport sport);

  /// Nộp bài: [answers] = câu chọn đáp án (mã câu → giá trị), [techniques] = câu thang 1–5 (mã câu → điểm),
  /// [evidenceUrls] = 1–5 link bằng chứng thành tích (không bắt buộc, cần khi muốn Elo vượt 1400).
  Future<SkillAssessment> submitAssessment(
    Sport sport, {
    required Map<String, String> answers,
    required Map<String, int> techniques,
    List<String> evidenceUrls = const [],
  });

  /// Nhận xét trình độ một người cùng trận ([contextId] = id kèo LFG / đơn đặt sân / trận giải), trong 72 giờ sau trận.
  /// Đã nhận xét người này trong trận rồi thì bỏ qua. Fair Play của mình dưới 50 thì BE từ chối (403).
  Future<void> sendSkillFeedback({required String revieweeId, required String contextId, required SkillVerdict verdict});

  /// Tải một ảnh bằng chứng (JPG / PNG / WEBP ≤5MB) lên, trả link https để gửi trong `evidenceUrls`.
  Future<String> uploadEvidence(String filePath);

  /// Kết quả khảo sát gần nhất của từng môn.
  Future<List<SkillAssessment>> getMyAssessments();
}
