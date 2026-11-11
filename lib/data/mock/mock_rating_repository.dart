import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/rating_strings.dart';
import '../../models/player_survey.dart';
import '../../models/sport.dart';
import '../../models/sport_rating.dart';
import '../repositories/rating_repository.dart';
import 'mock_auth_repository.dart';

/// Bản giả lập Elo + khảo sát trình độ. Người chơi demo có sẵn Elo cầu lông; môn khác phải làm khảo sát.
/// Điểm khảo sát = trung bình các câu quy về 0–100; Elo = 1000 + điểm × 6 (tối đa 1600, chưa có bằng chứng thì ≤1400).
class MockRatingRepository implements RatingRepository {
  static const String keyPrefix = 'mock_skill_assessments_';
  static const int capWithoutEvidence = 1400;

  static const List<AssessmentQuestion> questions = [
    AssessmentQuestion(
      code: 'YEARS',
      question: 'Bạn chơi môn này bao lâu rồi?',
      type: AssessmentQuestionType.singleChoice,
      options: [
        AssessmentOption('LT_1', 'Dưới 1 năm'),
        AssessmentOption('1_3', '1–3 năm'),
        AssessmentOption('3_5', '3–5 năm'),
        AssessmentOption('GT_5', 'Trên 5 năm'),
      ],
    ),
    AssessmentQuestion(
      code: 'TOURNAMENT_LEVEL',
      question: 'Giải cao nhất bạn từng tham gia?',
      type: AssessmentQuestionType.singleChoice,
      options: [
        AssessmentOption('NONE', 'Chưa từng'),
        AssessmentOption('CLUB', 'Giải phong trào / câu lạc bộ'),
        AssessmentOption('CITY', 'Giải quận / thành phố'),
        AssessmentOption('NATIONAL', 'Giải quốc gia'),
      ],
    ),
    AssessmentQuestion(code: 'TECH_1', question: 'Kỹ thuật cơ bản (1–5)', type: AssessmentQuestionType.scale),
    AssessmentQuestion(code: 'TECH_2', question: 'Thể lực, di chuyển (1–5)', type: AssessmentQuestionType.scale),
  ];

  static const Map<String, int> _points = {
    'LT_1': 0, '1_3': 1, '3_5': 2, 'GT_5': 3, //
    'NONE': 0, 'CLUB': 1, 'CITY': 2, 'NATIONAL': 3,
  };

  @override
  Future<List<SportRating>> getMyRatings() async {
    final me = await _me();
    return [
      for (final a in await _load(me.id))
        SportRating(
          type: RatingType.personal,
          ownerId: me.id,
          ownerName: me.name,
          sportCategoryId: a.sportCategoryId,
          sport: a.sport,
          rating: a.assignedRating,
          rank: SportRating.rankFor(a.assignedRating),
          isProvisional: true,
        ),
    ];
  }

  @override
  Future<LeaderboardPage> getLeaderboard(Sport sport, {RatingType type = RatingType.personal, int page = 1}) async {
    final rows = [
      for (var i = 0; i < 25; i++)
        SportRating(
          type: type,
          ownerId: '${type.apiValue}-$i',
          ownerName: type == RatingType.team ? 'Đội ${sport.label} ${i + 1}' : 'Người chơi ${i + 1}',
          sportCategoryId: 'mock-${sport.name}',
          sport: sport,
          rating: 1750 - i * 30,
          rank: SportRating.rankFor(1750 - i * 30),
          ratedMatches: 30 - i,
        ),
    ];
    const size = 20;
    final start = (page - 1) * size;
    final items = rows.skip(start).take(size).toList();
    return LeaderboardPage(items: items, page: page, pageSize: size, hasMore: start + size < rows.length);
  }

  @override
  Future<AssessmentForm> getAssessmentForm(Sport sport) async {
    final me = await _me();
    final current = (await _load(me.id)).where((a) => a.sport == sport).firstOrNull;
    return AssessmentForm(
      sportCategoryId: 'mock-${sport.name}',
      sportName: sport.label,
      questions: questions,
      current: current,
      blockedReason: current?.evidenceStatus == EvidenceStatus.pending ? RatingStrings.mockPendingBlocked : null,
    );
  }

  @override
  Future<SkillAssessment> submitAssessment(
    Sport sport, {
    required Map<String, String> answers,
    required Map<String, int> techniques,
    List<String> evidenceUrls = const [],
  }) async {
    final me = await _me();
    var total = 0.0;
    var count = 0;
    for (final q in questions) {
      if (q.isScale) {
        total += ((techniques[q.code] ?? 1) - 1) / 4;
      } else {
        total += (_points[answers[q.code]] ?? 0) / 3;
      }
      count++;
    }
    final score = (total / count * 100).round();
    final computed = (1000 + score * 6).clamp(1000, 1600);
    final urls = evidenceUrls.where((u) => u.trim().isNotEmpty).toList();
    final result = SkillAssessment(
      id: 'as-${DateTime.now().microsecondsSinceEpoch}',
      sportCategoryId: 'mock-${sport.name}',
      sport: sport,
      sportName: sport.label,
      score: score,
      computedRating: computed,
      assignedRating: computed > capWithoutEvidence ? capWithoutEvidence : computed,
      skillLevel: score < 25
          ? SkillLevel.beginner
          : score < 50
              ? SkillLevel.intermediate
              : score < 75
                  ? SkillLevel.advanced
                  : SkillLevel.professional,
      evidenceUrls: urls,
      evidenceStatus: urls.isNotEmpty && computed > capWithoutEvidence ? EvidenceStatus.pending : EvidenceStatus.none,
      createdAt: DateTime.now(),
    );
    final list = (await _load(me.id)).where((a) => a.sport != sport).toList()..add(result);
    await _save(me.id, list);
    return result;
  }

  /// Nhận xét trình độ đã gửi (người được nhận xét + trận) để test kiểm tra.
  final List<({String revieweeId, String contextId, SkillVerdict verdict})> sentFeedback = [];

  @override
  Future<void> sendSkillFeedback({
    required String revieweeId,
    required String contextId,
    required SkillVerdict verdict,
  }) async {
    if (sentFeedback.any((f) => f.revieweeId == revieweeId && f.contextId == contextId)) return;
    sentFeedback.add((revieweeId: revieweeId, contextId: contextId, verdict: verdict));
  }

  /// Bản giả lập không tải ảnh lên: trả link giả theo tên file.
  @override
  Future<String> uploadEvidence(String filePath) async =>
      'https://mock.sportnexus.vn/evidence/${filePath.split(RegExp(r'[\\/]')).last}';

  @override
  Future<List<SkillAssessment>> getMyAssessments() async => _load((await _me()).id);

  // ---------------- Lưu trữ ----------------

  Future<({String id, String name})> _me() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    final json = raw == null ? const <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
    return (id: json['id'] as String? ?? 'guest', name: json['fullName'] as String? ?? '');
  }

  Future<List<SkillAssessment>> _load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$keyPrefix$userId');
    if (raw == null) {
      return userId == 'u-player-001'
          ? const [
              SkillAssessment(
                id: 'as-demo',
                sportCategoryId: 'mock-badminton',
                sport: Sport.badminton,
                sportName: 'Cầu Lông',
                score: 40,
                computedRating: 1240,
                assignedRating: 1240,
                skillLevel: SkillLevel.intermediate,
              ),
            ]
          : const [];
    }
    return [
      for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
        SkillAssessment(
          id: m['id'] as String,
          sportCategoryId: m['cat'] as String,
          sport: Sport.fromApi(m['sport'] as String),
          sportName: m['sportName'] as String? ?? '',
          score: m['score'] as int,
          computedRating: m['computed'] as int,
          assignedRating: m['assigned'] as int,
          skillLevel: SkillLevel.fromApi(m['level']),
          evidenceUrls: (m['urls'] as List? ?? const []).cast<String>(),
          evidenceStatus: EvidenceStatus.fromApi(m['evidence']),
          createdAt: m['at'] == null ? null : DateTime.tryParse(m['at'] as String),
        ),
    ];
  }

  Future<void> _save(String userId, List<SkillAssessment> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$keyPrefix$userId',
      jsonEncode([
        for (final a in list)
          {
            'id': a.id,
            'cat': a.sportCategoryId,
            'sport': a.sport!.apiValue,
            'sportName': a.sportName,
            'score': a.score,
            'computed': a.computedRating,
            'assigned': a.assignedRating,
            'level': a.skillLevel?.apiValue,
            'urls': a.evidenceUrls,
            'evidence': a.evidenceStatus.apiValue,
            'at': a.createdAt?.toIso8601String(),
          },
      ]),
    );
  }
}
