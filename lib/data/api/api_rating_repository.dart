import 'dart:io';

import '../../core/strings/rating_strings.dart';
import '../../models/player_survey.dart';
import '../../models/sport.dart';
import '../../models/sport_rating.dart';
import '../repositories/rating_repository.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// Elo + khảo sát trình độ qua BE (/api/v1/ratings).
///
/// - GET /ratings/me: mảng, không phân trang (dòng đội có ratingType TEAM, ownerId = teamId).
/// - GET /ratings/leaderboard?sportCategoryId&ratingType=PERSONAL|TEAM&page&pageSize (≤100), công khai.
/// - `rank` là hạng mức chữ, KHÔNG phải thứ hạng; vị trí do app tự tính theo trang.
/// - Khảo sát: GET /assessments/questions/{sportCategoryId}, POST /assessments/{sportCategoryId}
///   {answers, techniques, evidenceUrls}, GET /assessments/me.
/// - Phải gửi cả `answers` (chuỗi) lẫn `techniques` (số nguyên 1–5), thiếu thì gửi {}.
/// - Ảnh bằng chứng: POST /api/v1/uploads/images?purpose=general rồi gửi link vào `evidenceUrls`.
class ApiRatingRepository implements RatingRepository {
  static const String myRatingsPath = '/api/v1/ratings/me';
  static const String leaderboardPath = '/api/v1/ratings/leaderboard';
  static const String myAssessmentsPath = '/api/v1/ratings/assessments/me';
  static const String uploadPath = '/api/v1/uploads/images';
  static const String feedbackPath = '/api/v1/ratings/feedback';
  static const int maxImageBytes = 5 * 1024 * 1024;
  static String questionsPath(String categoryId) => '/api/v1/ratings/assessments/questions/$categoryId';
  static String submitPath(String categoryId) => '/api/v1/ratings/assessments/$categoryId';

  static const int pageSize = 20;

  final ApiClient _api;
  final Future<String?> Function(Sport sport) _categoryIdOf;
  final Future<Sport?> Function(String categoryId) _sportOf;

  ApiRatingRepository({required this._api, required this._categoryIdOf, required this._sportOf});

  Future<String> _requireCategoryId(Sport sport) async {
    final id = await _categoryIdOf(sport);
    if (id == null) throw RatingException(RatingStrings.sportUnavailable(sport.label));
    return id;
  }

  @override
  Future<List<SportRating>> getMyRatings() async {
    final data = await _call(() => _api.get(myRatingsPath));
    return [for (final m in _maps(data is Map ? data['items'] : data)) await _rating(m)];
  }

  @override
  Future<LeaderboardPage> getLeaderboard(Sport sport, {RatingType type = RatingType.personal, int page = 1}) async {
    final id = await _requireCategoryId(sport);
    final data = await _call(
      () => _api.get(
        leaderboardPath,
        query: {'sportCategoryId': id, 'ratingType': type.apiValue, 'page': page, 'pageSize': pageSize},
      ),
    );
    final list = _maps(data is Map ? data['items'] : data);
    final items = [for (final m in list) await _rating(m, fallbackSport: sport, fallbackType: type)];
    final total = data is Map ? (data['totalItems'] as num?)?.toInt() : null;
    return LeaderboardPage(
      items: items,
      page: page,
      pageSize: pageSize,
      hasMore: total != null ? page * pageSize < total : items.length == pageSize,
    );
  }

  @override
  Future<AssessmentForm> getAssessmentForm(Sport sport) async {
    final id = await _requireCategoryId(sport);
    final data = await _call(() => _api.get(questionsPath(id)));
    final m = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final current = m['current'];
    final blocked = m['blockedReason']?.toString().trim();
    return AssessmentForm(
      sportCategoryId: id,
      sportName: m['sportName']?.toString() ?? sport.label,
      questions: [
        for (final q in _maps(m['questions']))
          AssessmentQuestion(
            code: q['code']?.toString() ?? '',
            question: (q['question'] ?? q['text'] ?? q['label'])?.toString() ?? '',
            type: AssessmentQuestionType.fromApi(q['type']),
            options: [
              for (final o in _maps(q['options']))
                AssessmentOption(o['value']?.toString() ?? '', (o['label'] ?? o['value'])?.toString() ?? ''),
            ],
          ),
      ].where((q) => q.code.isNotEmpty).toList(),
      current: current is Map ? await _assessment(Map<String, dynamic>.from(current), fallbackSport: sport) : null,
      blockedReason: blocked == null || blocked.isEmpty ? null : blocked,
    );
  }

  @override
  Future<SkillAssessment> submitAssessment(
    Sport sport, {
    required Map<String, String> answers,
    required Map<String, int> techniques,
    List<String> evidenceUrls = const [],
  }) async {
    final id = await _requireCategoryId(sport);
    final urls = evidenceUrls.map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
    final data = await _call(
      () => _api.post(
        submitPath(id),
        body: {'answers': answers, 'techniques': techniques, if (urls.isNotEmpty) 'evidenceUrls': urls},
      ),
    );
    return _assessment(data is Map ? Map<String, dynamic>.from(data) : const {}, fallbackSport: sport);
  }

  /// POST /ratings/feedback {revieweeId, contextId, verdict}; 409 = đã nhận xét rồi → bỏ qua.
  @override
  Future<void> sendSkillFeedback({
    required String revieweeId,
    required String contextId,
    required SkillVerdict verdict,
  }) async {
    try {
      await _api.post(
        feedbackPath,
        body: {'revieweeId': revieweeId, 'contextId': contextId, 'verdict': verdict.apiValue},
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) return;
      throw RatingException.fromApi(e);
    }
  }

  /// POST /api/v1/uploads/images?purpose=general (field `file`) → 201 {url, …}.
  @override
  Future<String> uploadEvidence(String filePath) async {
    final int size;
    try {
      size = await File(filePath).length();
    } on FileSystemException {
      throw const RatingException(RatingStrings.pickPhotoError);
    }
    if (size > maxImageBytes) throw const RatingException(RatingStrings.imageTooLarge);
    final data = await _call(() => _api.upload(uploadPath, filePath: filePath, query: const {'purpose': 'general'}));
    final url = (data is Map ? data['url'] ?? data['secureUrl'] : data)?.toString().trim() ?? '';
    if (!url.startsWith('http')) throw const RatingException(RatingStrings.uploadFailed);
    return url;
  }

  @override
  Future<List<SkillAssessment>> getMyAssessments() async {
    final data = await _call(() => _api.get(myAssessmentsPath));
    return [for (final m in _maps(data is Map ? data['items'] : data)) await _assessment(m)];
  }

  // ---------------- Chuyển đổi ----------------

  Future<Sport?> _sport(Map<String, dynamic> m) async {
    final byName = ApiFacilityRepository.sportFromName(m['sportName']?.toString());
    if (byName != null) return byName;
    final id = m['sportCategoryId']?.toString();
    return id == null ? null : _sportOf(id);
  }

  Future<SportRating> _rating(Map<String, dynamic> m, {Sport? fallbackSport, RatingType? fallbackType}) async =>
      SportRating(
        type: m.containsKey('ratingType') || m.containsKey('ownerType')
            ? RatingType.fromApi(m['ratingType'] ?? m['ownerType'])
            : fallbackType ?? RatingType.personal,
        ownerId: (m['ownerId'] ?? m['userId'] ?? m['teamId'])?.toString() ?? '',
        ownerName: (m['ownerName'] ?? m['fullName'] ?? m['teamName'])?.toString() ?? '',
        ownerAvatarUrl: _opt(m['avatarUrl'] ?? m['logoUrl']),
        sportCategoryId: m['sportCategoryId']?.toString() ?? '',
        sport: await _sport(m) ?? fallbackSport,
        sportName: m['sportName']?.toString() ?? '',
        rating: _int(m['rating']),
        rank: m['rank']?.toString() ?? '',
        ratedMatches: _int(m['ratedMatches']),
        isProvisional: m['isProvisional'] == true,
      );

  Future<SkillAssessment> _assessment(Map<String, dynamic> m, {Sport? fallbackSport}) async => SkillAssessment(
    id: m['id']?.toString() ?? '',
    sportCategoryId: m['sportCategoryId']?.toString() ?? '',
    sport: await _sport(m) ?? fallbackSport,
    sportName: m['sportName']?.toString() ?? '',
    score: _int(m['score']),
    computedRating: _int(m['computedRating']),
    assignedRating: _int(m['assignedRating'] ?? m['computedRating']),
    skillLevel: SkillLevel.fromApi(m['skillLevel']),
    flags: _strings(m['flags']),
    evidenceUrls: _strings(m['evidenceUrls']),
    evidenceStatus: EvidenceStatus.fromApi(m['evidenceStatus']),
    reviewNote: m['reviewNote']?.toString() ?? '',
    createdAt: m['createdAt'] == null ? null : DateTime.tryParse(m['createdAt'].toString())?.toLocal(),
  );

  static int _int(Object? v) => v is num ? v.round() : num.tryParse('$v')?.round() ?? 0;

  static String? _opt(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  static List<String> _strings(Object? v) =>
      v is List ? v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList() : const [];

  static List<Map<String, dynamic>> _maps(Object? v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw RatingException.fromApi(e);
    }
  }
}
