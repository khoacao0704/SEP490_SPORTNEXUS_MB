import '../../core/constants/fair_play_rules.dart';
import '../../models/review.dart';
import '../repositories/review_repository.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// Đánh giá cơ sở, chấm người chơi cùng trận và Fair Play qua BE.
class ApiReviewRepository implements ReviewRepository {
  static const String pendingPath = '/api/v1/fair-play/pending-ratings';
  static const String ratePath = '/api/v1/reviews/fair-play';
  static const String createReviewPath = '/api/v1/facility-reviews';
  static const String myReviewsPath = '/api/v1/facility-reviews/my-reviews';
  static const String fairPlayPath = '/api/v1/fair-play/me';
  static String facilityReviewsPath(String facilityId) => '/api/v1/facilities/$facilityId/reviews';
  static String eligibilityPath(String facilityId) => '/api/v1/facility-reviews/eligibility/$facilityId';

  /// BE giới hạn nhận xét khi chấm người chơi.
  static const int playerCommentMaxLength = 500;

  final ApiClient _api;

  ApiReviewRepository({required this._api});

  // ---------------- Chấm người chơi ----------------

  @override
  Future<List<PendingReview>> getPendingReviews() async {
    final data = await _call(() => _api.get(pendingPath));
    final list = data is List ? data : const [];
    return list
        .whereType<Map>()
        .map((e) => pendingFromApi(Map<String, dynamic>.from(e)))
        .where((p) => p.players.isNotEmpty)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  @override
  Future<void> ratePlayers(String sessionId, List<PlayerReviewInput> players) async {
    for (final p in players) {
      var comment = p.commentWithTags;
      if (comment.length > playerCommentMaxLength) comment = comment.substring(0, playerCommentMaxLength);
      try {
        await _api.post(
          ratePath,
          body: {'revieweeId': p.playerId, 'contextId': sessionId, 'score': p.stars, if (comment.isNotEmpty) 'comment': comment},
        );
      } on ApiException catch (e) {
        // Đã chấm người này rồi (vd. gửi lại sau lỗi mạng giữa chừng): coi như xong.
        if (e.statusCode == 409) continue;
        throw ReviewException(e.message);
      }
    }
  }

  // ---------------- Đánh giá cơ sở ----------------

  @override
  Future<FacilityReviewPage> getFacilityReviews(String facilityId, {int? stars, int page = 1}) async {
    const size = ReviewRepository.reviewPageSize;
    final data = await _call(
      () => _api.get(
        facilityReviewsPath(facilityId),
        auth: false,
        query: {'rating': ?stars, 'page': page, 'pageSize': size},
      ),
    );
    return reviewPageFromApi(data, page: page);
  }

  @override
  Future<ReviewEligibility> getEligibility(String facilityId) async {
    final data = await _call(() => _api.get(eligibilityPath(facilityId)));
    final map = data is Map ? data : const {};
    final existing = map['existingReviewId']?.toString();
    return ReviewEligibility(
      canReview: map['canReview'] == true,
      reason: map['reason']?.toString(),
      existingReviewId: existing == null || existing.isEmpty ? null : existing,
    );
  }

  @override
  Future<FacilityReviewItem> submitFacilityReview(String facilityId, FacilityReviewInput input) async {
    final comment = input.comment.trim();
    final data = await _call(
      () => _api.post(
        createReviewPath,
        body: {'facilityId': facilityId, 'rating': input.stars, if (comment.isNotEmpty) 'comment': comment},
      ),
    );
    return reviewFromApi(data is Map ? Map<String, dynamic>.from(data) : const {});
  }

  @override
  Future<FacilityReviewPage> getMyReviews({int page = 1}) async {
    const size = ReviewRepository.reviewPageSize;
    final data = await _call(() => _api.get(myReviewsPath, query: {'page': page, 'pageSize': size}));
    return reviewPageFromApi(data, page: page);
  }

  // ---------------- Fair Play ----------------

  @override
  Future<FairPlaySummary> getFairPlay({int page = 1}) async {
    const size = ReviewRepository.fairPlayPageSize;
    final data = await _call(() => _api.get(fairPlayPath, query: {'page': page, 'pageSize': size}));
    return fairPlayFromApi(data is Map ? Map<String, dynamic>.from(data) : const {}, page: page);
  }

  // ---------------- Chuyển đổi ----------------

  static PendingReview pendingFromApi(Map<String, dynamic> json) {
    final players = (json['players'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (p) => ReviewablePlayer(
            userId: p['userId'].toString(),
            name: p['fullName']?.toString() ?? '',
            avatarUrl: _nonEmpty(p['avatarUrl']),
          ),
        )
        .toList();
    final sportName = json['sportName']?.toString() ?? '';
    final end = _date(json['endTime']) ?? DateTime.now();
    return PendingReview(
      sessionId: json['contextId'].toString(),
      type: SessionType.fromApi(json['contextType']?.toString()),
      facilityId: json['facilityId']?.toString() ?? '',
      facilityName: json['facilityName']?.toString() ?? '',
      courtName: _nonEmpty(json['courtName']),
      sport: ApiFacilityRepository.sportFromName(sportName),
      sportName: sportName,
      start: _date(json['startTime']) ?? end,
      end: end,
      deadline: _date(json['ratingDeadline']) ?? end.add(FairPlayRules.reviewWindow),
      players: players,
    );
  }

  static FacilityReviewItem reviewFromApi(Map<String, dynamic> json) => FacilityReviewItem(
    id: json['id']?.toString() ?? '',
    userId: json['userId']?.toString() ?? '',
    userName: json['userFullName']?.toString() ?? '',
    userAvatarUrl: _nonEmpty(json['userAvatarUrl']),
    stars: (json['rating'] as num?)?.toInt() ?? 0,
    comment: json['comment']?.toString() ?? '',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    ownerReply: _nonEmpty(json['ownerReply']),
    repliedAt: _date(json['repliedAt']),
    facilityId: _nonEmpty(json['facilityId']),
    facilityName: _nonEmpty(json['facilityName']),
    facilityAddress: _nonEmpty(json['facilityAddress']),
    facilityThumbnailUrl: _nonEmpty(json['facilityThumbnailUrl']),
    isHidden: json['isHidden'] == true,
    hiddenReason: _nonEmpty(json['hiddenReason']),
  );

  static FacilityReviewPage reviewPageFromApi(Object? data, {required int page}) {
    final map = data is Map ? data : const {};
    final items = (map['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => reviewFromApi(Map<String, dynamic>.from(e)))
        .toList();
    final rawDistribution = map['ratingDistribution'] is Map ? map['ratingDistribution'] as Map : const {};
    final distribution = <int, int>{};
    rawDistribution.forEach((key, value) {
      final stars = int.tryParse(key.toString());
      if (stars != null && value is num) distribution[stars] = value.toInt();
    });
    return FacilityReviewPage(
      items: items,
      stats: FacilityReviewStats(
        average: (map['averageRating'] as num?)?.toDouble() ?? 0,
        total: (map['totalReviews'] as num?)?.toInt() ?? (map['totalItems'] as num?)?.toInt() ?? items.length,
        distribution: distribution,
      ),
      hasMore: _hasMore(map, page: page, size: ReviewRepository.reviewPageSize, count: items.length),
    );
  }

  static FairPlaySummary fairPlayFromApi(Map<String, dynamic> json, {required int page}) {
    final rawHistory = json['history'];
    final historyMap = rawHistory is Map ? rawHistory : const {};
    final historyList = rawHistory is List ? rawHistory : historyMap['items'] as List? ?? const [];
    final history = historyList.whereType<Map>().map((e) {
      return FairPlayEvent(
        id: e['id']?.toString() ?? '',
        type: FairPlayEventType.fromApi(e['source']?.toString()),
        delta: (e['delta'] as num?)?.round() ?? 0,
        scoreAfter: (e['scoreAfter'] as num?)?.round(),
        reason: e['reason']?.toString() ?? '',
        createdAt: _date(e['createdAt']) ?? DateTime.now(),
      );
    }).toList();
    final score = (json['fairPlayScore'] as num?)?.round() ?? FairPlayRules.initialScore;
    final minScore = (json['minClaimScore'] as num?)?.round() ?? FairPlayRules.minScoreForLfg;
    final blocked = json['isLfgBlocked'];
    final average = (json['averageRating'] as num?)?.toDouble();
    return FairPlaySummary(
      score: score,
      minScoreForLfg: minScore,
      recoveryCap: (json['recoveryCap'] as num?)?.round() ?? FairPlayRules.recoveryCap,
      isLfgBlocked: blocked is bool ? blocked : null,
      banReason: _nonEmpty(json['claimBanReason']),
      bannedUntil: _date(json['claimBannedUntil']),
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      averageRating: average == null || average <= 0 ? null : average,
      history: history,
      hasMoreHistory: rawHistory is Map
          ? _hasMore(historyMap, page: page, size: ReviewRepository.fairPlayPageSize, count: history.length)
          : false,
    );
  }

  static bool _hasMore(Map map, {required int page, required int size, required int count}) {
    final totalPages = (map['totalPages'] as num?)?.toInt();
    if (totalPages != null) return page < totalPages;
    final totalItems = (map['totalItems'] as num?)?.toInt();
    if (totalItems != null) return page * size < totalItems;
    return count >= size;
  }

  static DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  static String? _nonEmpty(Object? value) {
    final s = value?.toString();
    return s == null || s.isEmpty ? null : s;
  }

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw ReviewException(e.message);
    }
  }
}
