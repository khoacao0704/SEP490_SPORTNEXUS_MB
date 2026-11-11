import 'player_survey.dart';
import 'sport.dart';

/// Elo cá nhân (PERSONAL) hay của đội (TEAM).
enum RatingType {
  personal('PERSONAL', 'Cá nhân'),
  team('TEAM', 'Đội');

  const RatingType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static RatingType fromApi(Object? v) => v?.toString().toUpperCase() == 'TEAM' ? team : personal;
}

/// Một dòng Elo (của mình, của đội mình hoặc trên bảng xếp hạng).
class SportRating {
  final RatingType type;

  /// Người hoặc đội sở hữu Elo này.
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String sportCategoryId;
  final Sport? sport;
  final String sportName;
  final int rating;

  /// Hạng mức chữ của BE: Đồng / Bạc / Vàng / Bạch kim / Kim cương (KHÔNG phải thứ hạng).
  final String rank;
  final int ratedMatches;

  /// Elo tạm tính (chưa đủ 10 trận tính Elo): thay đổi nhanh hơn.
  final bool isProvisional;

  const SportRating({
    required this.type,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatarUrl,
    required this.sportCategoryId,
    this.sport,
    this.sportName = '',
    required this.rating,
    this.rank = '',
    this.ratedMatches = 0,
    this.isProvisional = false,
  });

  String get sportLabel => sport?.label ?? sportName;

  /// Hạng mức theo Elo khi BE không trả (cùng mốc với BE).
  static String rankFor(int rating) => rating < 1100
      ? 'Đồng'
      : rating < 1300
          ? 'Bạc'
          : rating < 1500
              ? 'Vàng'
              : rating < 1700
                  ? 'Bạch kim'
                  : 'Kim cương';

  String get rankLabel => rank.isNotEmpty ? rank : rankFor(rating);
}

/// Một trang bảng xếp hạng; vị trí = (trang − 1) × số dòng mỗi trang + thứ tự + 1.
class LeaderboardPage {
  final List<SportRating> items;
  final int page;
  final int pageSize;
  final bool hasMore;

  const LeaderboardPage({required this.items, required this.page, required this.pageSize, required this.hasMore});

  int positionOf(int index) => (page - 1) * pageSize + index + 1;
}

/// Câu hỏi khảo sát trình độ: chọn một đáp án, hoặc tự chấm thang 1–5 (câu kỹ thuật).
enum AssessmentQuestionType {
  singleChoice,
  scale;

  static AssessmentQuestionType fromApi(Object? v) =>
      v?.toString().toUpperCase().startsWith('SCALE') == true ? scale : singleChoice;
}

class AssessmentOption {
  final String value;
  final String label;

  const AssessmentOption(this.value, this.label);
}

class AssessmentQuestion {
  final String code;
  final String question;
  final AssessmentQuestionType type;
  final List<AssessmentOption> options;

  const AssessmentQuestion({required this.code, required this.question, required this.type, this.options = const []});

  bool get isScale => type == AssessmentQuestionType.scale;

  /// Câu thang điểm không có đáp án riêng thì dùng 1–5.
  List<AssessmentOption> get choices => options.isNotEmpty || !isScale
      ? options
      : [for (var i = 1; i <= 5; i++) AssessmentOption('$i', '$i')];
}

/// Trạng thái bằng chứng thành tích (để Elo vượt 1400).
enum EvidenceStatus {
  none('NONE', ''),
  pending('PENDING', 'Bằng chứng đang chờ Admin duyệt'),
  approved('APPROVED', 'Bằng chứng đã được duyệt'),
  rejected('REJECTED', 'Bằng chứng bị từ chối');

  const EvidenceStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static EvidenceStatus fromApi(Object? v) =>
      values.where((s) => s.apiValue == v?.toString().toUpperCase()).firstOrNull ?? none;
}

/// Kết quả một lần làm khảo sát trình độ.
class SkillAssessment {
  final String id;
  final String sportCategoryId;
  final Sport? sport;
  final String sportName;

  /// Điểm 0–100.
  final int score;

  /// Elo tính từ điểm (1000 + điểm × 6, tối đa 1600).
  final int computedRating;

  /// Elo được gán: tối đa 1400 khi chưa có bằng chứng được duyệt.
  final int assignedRating;
  final SkillLevel? skillLevel;

  /// Câu trả lời mâu thuẫn BE phát hiện.
  final List<String> flags;
  final List<String> evidenceUrls;
  final EvidenceStatus evidenceStatus;
  final String reviewNote;
  final DateTime? createdAt;

  const SkillAssessment({
    required this.id,
    required this.sportCategoryId,
    this.sport,
    this.sportName = '',
    required this.score,
    required this.computedRating,
    required this.assignedRating,
    this.skillLevel,
    this.flags = const [],
    this.evidenceUrls = const [],
    this.evidenceStatus = EvidenceStatus.none,
    this.reviewNote = '',
    this.createdAt,
  });

  String get sportLabel => sport?.label ?? sportName;

  /// Elo bị giữ ở 1400 vì chưa có bằng chứng được duyệt.
  bool get isCapped => computedRating > assignedRating;
}

/// Đề khảo sát trình độ của một môn.
class AssessmentForm {
  final String sportCategoryId;
  final String sportName;
  final List<AssessmentQuestion> questions;

  /// Lần làm gần nhất (nếu có).
  final SkillAssessment? current;

  /// Lý do chưa làm (lại) được: môn bị khoá, đã có trận giải, đang chờ duyệt, chưa đủ 90 ngày…
  final String? blockedReason;

  const AssessmentForm({
    required this.sportCategoryId,
    this.sportName = '',
    this.questions = const [],
    this.current,
    this.blockedReason,
  });

  bool get isBlocked => blockedReason != null && blockedReason!.trim().isNotEmpty;
}

/// Ràng buộc giữa các câu của khảo sát trình độ (BE kiểm tra; app chặn trước cho khỏi lỗi khi nộp).
/// Chỉ áp khi bộ câu hỏi có các câu này (Admin sửa được bộ câu hỏi):
/// - TOURNAMENT_LEVEL = NONE → BEST_RESULT phải NONE, RECENT_TOURNAMENTS phải ZERO.
/// - TOURNAMENT_LEVEL khác NONE → BEST_RESULT không được NONE.
class AssessmentRules {
  AssessmentRules._();

  static const String tournamentLevel = 'TOURNAMENT_LEVEL';
  static const String bestResult = 'BEST_RESULT';
  static const String recentTournaments = 'RECENT_TOURNAMENTS';
  static const String none = 'NONE';
  static const String zero = 'ZERO';

  /// Đáp án không chọn được của câu [code] theo các câu đã trả lời.
  static Set<String> disabledOptions(AssessmentQuestion question, Map<String, String> answers) {
    final level = answers[tournamentLevel];
    if (level == null) return const {};
    final values = question.choices.map((o) => o.value).toSet();
    switch (question.code.toUpperCase()) {
      case bestResult:
        return level == none ? (values..remove(none)) : {if (values.contains(none)) none};
      case recentTournaments:
        return level == none && values.contains(zero) ? (values..remove(zero)) : const {};
      default:
        return const {};
    }
  }

  /// Câu trả lời sau khi chọn [value] cho câu [code]: tự điền / bỏ các câu phụ thuộc cho hợp lệ.
  static Map<String, String> answer(
    Map<String, String> answers,
    List<AssessmentQuestion> questions,
    String code,
    String value,
  ) {
    final next = {...answers, code: value};
    if (code.toUpperCase() != tournamentLevel) return next;
    bool has(String c, String v) => questions.any((q) => q.code.toUpperCase() == c && q.choices.any((o) => o.value == v));
    if (value == none) {
      if (has(bestResult, none)) next[bestResult] = none;
      if (has(recentTournaments, zero)) next[recentTournaments] = zero;
    } else if (next[bestResult] == none) {
      next.remove(bestResult);
    }
    return next;
  }
}

/// Nhận xét trình độ thật so với trình độ người chơi tự khai (sau trận, trong 72 giờ).
/// 3 người khác nhau cùng nhận xét lệch một phía thì Elo người đó được điều chỉnh ±50 một lần.
enum SkillVerdict {
  lower('LOWER', 'Yếu hơn khai báo'),
  accurate('ACCURATE', 'Đúng trình độ'),
  higher('HIGHER', 'Mạnh hơn khai báo');

  const SkillVerdict(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
