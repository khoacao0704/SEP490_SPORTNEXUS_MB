import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/fair_play_rules.dart';
import '../../core/strings/review_strings.dart';
import '../../models/review.dart';
import '../../models/sport.dart';
import '../repositories/review_repository.dart';
import 'mock_auth_repository.dart';

/// Bản giả lập [ReviewRepository].
///
/// - Các trận chờ chấm được tạo một lần (mốc thời gian lưu lại), nên sau 24 giờ sẽ hết hạn thật.
/// - Người đã chấm và đánh giá cơ sở lưu theo từng tài khoản.
/// - Được đánh giá cơ sở nếu đã chơi ở đó (cơ sở của các trận mẫu).
/// - Fair Play tính từ lịch sử sự kiện của từng tài khoản (mỗi bước giới hạn trong 0–100).
///   Tài khoản demo `restricted@sportnexus.vn` có 25 điểm để thử chặn LFG.
class MockReviewRepository implements ReviewRepository {
  static const String keySeedAt = 'review_seed_at';
  static String keyRated(String userId) => 'rated_players_$userId';
  static String keyFacilityReviews(String userId) => 'facility_reviews_$userId';

  final Duration latency;
  final DateTime Function() _now;

  MockReviewRepository({this.latency = const Duration(milliseconds: 400), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  // ---------------- Chấm người chơi ----------------

  @override
  Future<List<PendingReview>> getPendingReviews() async {
    await _delay();
    final now = _now();
    final rated = await _ratedKeys();
    final pending = <PendingReview>[];
    for (final s in await _sessions()) {
      if (s.isExpired(now)) continue;
      final left = s.players.where((p) => !rated.contains('${s.sessionId}/${p.userId}')).toList();
      if (left.isEmpty) continue;
      pending.add(
        PendingReview(
          sessionId: s.sessionId,
          type: s.type,
          facilityId: s.facilityId,
          facilityName: s.facilityName,
          courtName: s.courtName,
          sport: s.sport,
          start: s.start,
          end: s.end,
          deadline: s.deadline,
          players: left,
        ),
      );
    }
    return pending..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  @override
  Future<void> ratePlayers(String sessionId, List<PlayerReviewInput> players) async {
    await _delay();
    final session = (await _sessions()).where((s) => s.sessionId == sessionId).firstOrNull;
    if (session == null) throw const ReviewException(ReviewStrings.sessionNotFound);
    if (session.isExpired(_now())) throw const ReviewException(ReviewStrings.expired);
    if (players.any((p) => p.stars < 1 || p.stars > 5)) throw const ReviewException(ReviewStrings.invalidStars);
    final validIds = session.players.map((p) => p.userId).toSet();
    if (players.any((p) => !validIds.contains(p.playerId))) {
      throw const ReviewException(ReviewStrings.sessionNotFound);
    }

    final prefs = await SharedPreferences.getInstance();
    final key = keyRated(await _currentUserId());
    final rated = {...prefs.getStringList(key) ?? <String>[], ...players.map((p) => '$sessionId/${p.playerId}')};
    await prefs.setStringList(key, rated.toList());
  }

  // ---------------- Đánh giá cơ sở ----------------

  @override
  Future<FacilityReviewPage> getFacilityReviews(String facilityId, {int? stars, int page = 1}) async {
    await _delay();
    final all = [...await _savedReviews(), ..._seedReviews()]
        .where((r) => r.facilityId == facilityId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final distribution = {for (var s = 1; s <= 5; s++) s: all.where((r) => r.stars == s).length};
    final average = all.isEmpty ? 0.0 : all.map((r) => r.stars).reduce((a, b) => a + b) / all.length;
    final filtered = stars == null ? all : all.where((r) => r.stars == stars).toList();
    return _page(
      filtered,
      page,
      FacilityReviewStats(
        average: double.parse(average.toStringAsFixed(1)),
        total: all.length,
        distribution: distribution,
      ),
    );
  }

  @override
  Future<ReviewEligibility> getEligibility(String facilityId) async {
    await _delay();
    final existing = (await _savedReviews()).where((r) => r.facilityId == facilityId).firstOrNull;
    if (existing != null) {
      return ReviewEligibility(
        canReview: false,
        reason: ReviewStrings.facilityAlreadyReviewed,
        existingReviewId: existing.id,
      );
    }
    final played = (await _sessions()).any((s) => s.facilityId == facilityId);
    return played
        ? const ReviewEligibility(canReview: true)
        : const ReviewEligibility(canReview: false, reason: ReviewStrings.notEligible);
  }

  @override
  Future<FacilityReviewItem> submitFacilityReview(String facilityId, FacilityReviewInput input) async {
    final eligibility = await getEligibility(facilityId);
    if (!eligibility.canReview) throw ReviewException(eligibility.reason ?? ReviewStrings.notEligible);
    if (input.stars < 1 || input.stars > 5) throw const ReviewException(ReviewStrings.invalidStars);

    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    final name = raw == null ? '' : (jsonDecode(raw) as Map<String, dynamic>)['fullName'] as String? ?? '';
    final session = (await _sessions()).firstWhere((s) => s.facilityId == facilityId);
    final review = FacilityReviewItem(
      id: 'rv-${_now().microsecondsSinceEpoch}',
      userId: userId,
      userName: name,
      stars: input.stars,
      comment: input.comment.trim(),
      createdAt: _now(),
      facilityId: facilityId,
      facilityName: session.facilityName,
    );
    final key = keyFacilityReviews(userId);
    await prefs.setStringList(key, [...prefs.getStringList(key) ?? [], jsonEncode(_reviewToJson(review))]);
    return review;
  }

  @override
  Future<FacilityReviewPage> getMyReviews({int page = 1}) async {
    await _delay();
    final mine = (await _savedReviews())..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _page(mine, page, FacilityReviewStats.empty);
  }

  // ---------------- Fair Play ----------------

  @override
  Future<FairPlaySummary> getFairPlay({int page = 1}) async {
    await _delay();
    final events = _fairPlayEventsFor(await _currentUserId());
    var score = 0;
    final withScore = <FairPlayEvent>[];
    for (final e in events) {
      score = (score + e.delta).clamp(0, FairPlayRules.maxScore);
      withScore.add(
        FairPlayEvent(
          id: e.id,
          type: e.type,
          delta: e.delta,
          scoreAfter: score,
          reason: e.reason,
          createdAt: e.createdAt,
        ),
      );
    }
    const size = ReviewRepository.fairPlayPageSize;
    final history = withScore.reversed.toList();
    final start = (page - 1) * size;
    return FairPlaySummary(
      score: score,
      history: history.skip(start).take(size).toList(),
      hasMoreHistory: history.length > start + size,
    );
  }

  // ---------------- Dữ liệu giả ----------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  FacilityReviewPage _page(List<FacilityReviewItem> items, int page, FacilityReviewStats stats) {
    const size = ReviewRepository.reviewPageSize;
    final start = (page - 1) * size;
    return FacilityReviewPage(
      items: items.skip(start).take(size).toList(),
      stats: stats,
      hasMore: items.length > start + size,
    );
  }

  Future<String> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) return 'guest';
    return (jsonDecode(raw) as Map<String, dynamic>)['id'] as String;
  }

  Future<Set<String>> _ratedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(keyRated(await _currentUserId())) ?? []).toSet();
  }

  Future<List<FacilityReviewItem>> _savedReviews() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(keyFacilityReviews(await _currentUserId())) ?? [])
        .map((raw) => _reviewFromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList();
  }

  static Map<String, dynamic> _reviewToJson(FacilityReviewItem r) => {
    'id': r.id,
    'userId': r.userId,
    'userName': r.userName,
    'stars': r.stars,
    'comment': r.comment,
    'createdAt': r.createdAt.toIso8601String(),
    'facilityId': r.facilityId,
    'facilityName': r.facilityName,
  };

  static FacilityReviewItem _reviewFromJson(Map<String, dynamic> json) => FacilityReviewItem(
    id: json['id'] as String,
    userId: json['userId'] as String,
    userName: json['userName'] as String,
    stars: json['stars'] as int,
    comment: json['comment'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    facilityId: json['facilityId'] as String?,
    facilityName: json['facilityName'] as String?,
  );

  /// Mốc thời gian tạo dữ liệu giả lần đầu; các trận tính lùi từ mốc này.
  Future<DateTime> _seedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keySeedAt);
    if (saved != null) return DateTime.parse(saved);
    final now = _now();
    await prefs.setString(keySeedAt, now.toIso8601String());
    return now;
  }

  Future<List<PendingReview>> _sessions() async {
    final t = await _seedAt();
    DateTime ago(int minutes) => t.subtract(Duration(minutes: minutes));
    PendingReview session({
      required String id,
      required SessionType type,
      required String facilityId,
      required String facilityName,
      required Sport sport,
      required int startAgo,
      required int endAgo,
      required List<ReviewablePlayer> players,
    }) => PendingReview(
      sessionId: id,
      type: type,
      facilityId: facilityId,
      facilityName: facilityName,
      sport: sport,
      start: ago(startAgo),
      end: ago(endAgo),
      deadline: ago(endAgo).add(FairPlayRules.reviewWindow),
      players: players,
    );

    return [
      session(
        id: 'ss-lfg-thientrieu',
        type: SessionType.lfg,
        facilityId: 'f-hcm-thientrieu',
        facilityName: 'Sân Cầu Lông Thiên Triều',
        sport: Sport.badminton,
        startAgo: 240,
        endAgo: 180,
        players: const [
          ReviewablePlayer(userId: 'u-minhtuan', name: 'Minh Tuấn', isHost: true),
          ReviewablePlayer(userId: 'u-hoangnam', name: 'Hoàng Nam'),
          ReviewablePlayer(userId: 'u-thutrang', name: 'Thu Trang'),
        ],
      ),
      session(
        id: 'ss-lfg-eco-1v1',
        type: SessionType.lfg,
        facilityId: 'f-hcm-eco-q7',
        facilityName: 'Eco Sport Quận 7',
        sport: Sport.pickleball,
        startAgo: 420,
        endAgo: 360,
        players: const [ReviewablePlayer(userId: 'u-quocbao', name: 'Quốc Bảo', isHost: true)],
      ),
      // Đơn chia tiền: chỉ có người chơi khi từ 2 người góp tiền cùng check-in.
      session(
        id: 'ss-booking-thaodien',
        type: SessionType.booking,
        facilityId: 'f-hcm-thaodien',
        facilityName: 'Pickleball Thảo Điền',
        sport: Sport.pickleball,
        startAgo: 22 * 60,
        endAgo: 21 * 60,
        players: const [ReviewablePlayer(userId: 'u-lananh', name: 'Lan Anh')],
      ),
      // Đã quá 24 giờ sau giờ kết thúc: không còn hiện trong danh sách.
      session(
        id: 'ss-lfg-hoalu-expired',
        type: SessionType.lfg,
        facilityId: 'f-hcm-hoalu',
        facilityName: 'Sân Bóng Hoa Lư',
        sport: Sport.football,
        startAgo: 32 * 60,
        endAgo: 30 * 60 + 30,
        players: const [ReviewablePlayer(userId: 'u-ductri', name: 'Đức Trí', isHost: true)],
      ),
    ];
  }

  List<FacilityReviewItem> _seedReviews() {
    final now = _now();
    FacilityReviewItem r(String id, String facilityId, String user, int stars, String comment, int daysAgo,
            {String? reply}) =>
        FacilityReviewItem(
          id: id,
          userId: 'u-$id',
          userName: user,
          stars: stars,
          comment: comment,
          createdAt: now.subtract(Duration(days: daysAgo)),
          ownerReply: reply,
          repliedAt: reply == null ? null : now.subtract(Duration(days: daysAgo - 1)),
          facilityId: facilityId,
        );
    return [
      r('seed-1', 'f-hcm-thientrieu', 'Nguyễn Minh Anh', 5, 'Sân rộng, sạch, đèn sáng. Sẽ quay lại!', 2,
          reply: 'Cảm ơn bạn đã ủng hộ sân!'),
      r('seed-2', 'f-hcm-thientrieu', 'Trần Quốc Huy', 4, 'Sân tốt, giờ cao điểm hơi đông.', 6),
      r('seed-3', 'f-hcm-thientrieu', 'Lê Thu Hà', 2, 'Đèn sân 3 bị chớp.', 10, reply: 'Sân đã thay đèn mới, mong bạn quay lại.'),
      r('seed-4', 'f-hcm-eco-q7', 'Phạm Gia Bảo', 5, 'Mặt sân đẹp, có chỗ gửi xe rộng.', 3),
      r('seed-5', 'f-hcm-thaodien', 'Võ Ngọc Linh', 4, '', 4),
    ];
  }

  List<FairPlayEvent> _fairPlayEventsFor(String userId) {
    final now = _now();
    FairPlayEvent e(String id, FairPlayEventType type, int delta, String reason, int daysAgo) => FairPlayEvent(
          id: id,
          type: type,
          delta: delta,
          reason: reason,
          createdAt: now.subtract(Duration(days: daysAgo)),
        );
    final initial = e('fp-0', FairPlayEventType.initial, FairPlayRules.initialScore, 'Khởi tạo tài khoản', 60);

    switch (userId) {
      case 'u-player-001':
        return [
          initial,
          e('fp-1', FairPlayEventType.noShow, FairPlayRules.noShowPenalty, 'Vắng mặt trận Cầu Lông • Eco Sport Quận 7', 12),
          e('fp-2', FairPlayEventType.review, FairPlayRules.reviewDelta(4.3),
              'Được đánh giá trung bình 4.3 sao sau trận Pickleball • Thảo Điền', 5),
        ];
      case MockAuthRepository.restrictedPlayerId:
        const noShow = FairPlayRules.noShowPenalty;
        return [
          initial,
          e('fp-1', FairPlayEventType.noShow, noShow, 'Vắng mặt trận Bóng Đá • Sân Bóng Hoa Lư', 40),
          e('fp-2', FairPlayEventType.late, noShow, 'Trễ quá 15 phút trận Cầu Lông • Gò Vấp Arena', 36),
          e('fp-3', FairPlayEventType.review, FairPlayRules.reviewDelta(1.4),
              'Bị đánh giá trung bình 1.4 sao sau trận Bóng Đá', 33),
          e('fp-4', FairPlayEventType.noShow, noShow, 'Vắng mặt trận Pickleball • Eco Sport Quận 7', 30),
          e('fp-5', FairPlayEventType.noShow, noShow, 'Vắng mặt trận Cầu Lông • Thiên Triều', 26),
          e('fp-6', FairPlayEventType.late, noShow, 'Trễ quá 15 phút trận Tennis • Kỳ Hòa', 22),
          e('fp-7', FairPlayEventType.review, FairPlayRules.reviewDelta(1.4),
              'Bị đánh giá trung bình 1.4 sao sau trận Cầu Lông', 20),
          e('fp-8', FairPlayEventType.noShow, noShow, 'Vắng mặt trận Bóng Rổ • Sân Chu Văn An', 15),
          e('fp-9', FairPlayEventType.cancellation, noShow, 'Hủy kèo Cầu Lông • Thiên Triều trong 24 giờ', 8),
          e('fp-10', FairPlayEventType.recovery, 5, 'Hồi phục theo thời gian', 1),
        ];
      default:
        return [initial];
    }
  }
}
