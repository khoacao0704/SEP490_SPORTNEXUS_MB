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
/// - Các buổi chờ đánh giá được tạo một lần (mốc thời gian lưu lại), nên sau 24 giờ sẽ hết hạn thật.
/// - Fair Play tính từ lịch sử sự kiện của từng tài khoản (mỗi bước giới hạn trong 0–100).
///   Tài khoản demo `restricted@sportnexus.vn` có 25 điểm để thử chặn LFG.
class MockReviewRepository implements ReviewRepository {
  static const String keySeedAt = 'review_seed_at';
  static String keyReviewed(String userId) => 'reviewed_sessions_$userId';

  final Duration latency;
  final DateTime Function() _now;

  MockReviewRepository({this.latency = const Duration(milliseconds: 400), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  @override
  Future<List<PendingReview>> getPendingReviews() async {
    await _delay();
    final now = _now();
    final reviewed = await _reviewedIds();
    final pending = (await _sessions()).where((s) => !reviewed.contains(s.sessionId) && !s.isExpired(now)).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return pending;
  }

  @override
  Future<void> submitReview(
    String sessionId, {
    FacilityReviewInput? facility,
    List<PlayerReviewInput> players = const [],
  }) async {
    await _delay();
    final session = (await _sessions()).where((s) => s.sessionId == sessionId).firstOrNull;
    if (session == null) throw const ReviewException(ReviewStrings.sessionNotFound);
    if ((await _reviewedIds()).contains(sessionId)) throw const ReviewException(ReviewStrings.alreadySubmitted);
    if (session.isExpired(_now())) throw const ReviewException(ReviewStrings.expired);
    if (facility == null && players.isEmpty) throw const ReviewException(ReviewStrings.nothingRated);

    final allStars = [if (facility != null) facility.stars, ...players.map((p) => p.stars)];
    if (allStars.any((s) => s < 1 || s > 5)) throw const ReviewException(ReviewStrings.invalidStars);

    final validIds = session.players.map((p) => p.userId).toSet();
    if (players.any((p) => !validIds.contains(p.playerId))) {
      throw const ReviewException(ReviewStrings.sessionNotFound);
    }

    final prefs = await SharedPreferences.getInstance();
    final key = keyReviewed(await _currentUserId());
    await prefs.setStringList(key, [...prefs.getStringList(key) ?? [], sessionId]);
  }

  @override
  Future<FairPlaySummary> getFairPlay() async {
    await _delay();
    final events = _fairPlayEventsFor(await _currentUserId());
    var score = 0;
    for (final e in events) {
      score = (score + e.delta).clamp(0, FairPlayRules.maxScore);
    }
    return FairPlaySummary(score: score, history: events.reversed.toList());
  }

  // ---------------- Dữ liệu giả ----------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<String> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) return 'guest';
    return (jsonDecode(raw) as Map<String, dynamic>)['id'] as String;
  }

  Future<Set<String>> _reviewedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(keyReviewed(await _currentUserId())) ?? []).toSet();
  }

  /// Mốc thời gian tạo dữ liệu giả lần đầu; các buổi chơi tính lùi từ mốc này.
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

    return [
      PendingReview(
        sessionId: 'ss-lfg-thientrieu',
        type: SessionType.lfg,
        facilityId: 'f-hcm-thientrieu',
        facilityName: 'Sân Cầu Lông Thiên Triều',
        sport: Sport.badminton,
        start: ago(240),
        end: ago(180),
        checkedOutAt: ago(170),
        players: const [
          ReviewablePlayer(userId: 'u-minhtuan', name: 'Minh Tuấn', isHost: true),
          ReviewablePlayer(userId: 'u-hoangnam', name: 'Hoàng Nam'),
          ReviewablePlayer(userId: 'u-thutrang', name: 'Thu Trang'),
        ],
      ),
      PendingReview(
        sessionId: 'ss-lfg-eco-1v1',
        type: SessionType.lfg,
        facilityId: 'f-hcm-eco-q7',
        facilityName: 'Eco Sport Quận 7',
        sport: Sport.pickleball,
        start: ago(420),
        end: ago(360),
        checkedOutAt: ago(355),
        players: const [ReviewablePlayer(userId: 'u-quocbao', name: 'Quốc Bảo', isHost: true)],
      ),
      PendingReview(
        sessionId: 'ss-booking-thaodien',
        type: SessionType.booking,
        facilityId: 'f-hcm-thaodien',
        facilityName: 'Pickleball Thảo Điền',
        sport: Sport.pickleball,
        start: ago(22 * 60),
        end: ago(21 * 60),
        checkedOutAt: ago(20 * 60),
      ),
      // Đã quá 24 giờ: không còn hiện trong danh sách.
      PendingReview(
        sessionId: 'ss-lfg-hoalu-expired',
        type: SessionType.lfg,
        facilityId: 'f-hcm-hoalu',
        facilityName: 'Sân Bóng Hoa Lư',
        sport: Sport.football,
        start: ago(32 * 60),
        end: ago(30 * 60 + 30),
        checkedOutAt: ago(30 * 60),
        players: const [ReviewablePlayer(userId: 'u-ductri', name: 'Đức Trí', isHost: true)],
      ),
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
          e('fp-1', FairPlayEventType.noShow, -10, 'Vắng mặt trận Cầu Lông • Eco Sport Quận 7', 12),
          e('fp-2', FairPlayEventType.review, 2, 'Được đánh giá tốt sau trận Pickleball • Thảo Điền', 5),
        ];
      case MockAuthRepository.restrictedPlayerId:
        return [
          initial,
          e('fp-1', FairPlayEventType.noShow, -30, 'Vắng mặt trận Bóng Đá • Sân Bóng Hoa Lư', 20),
          e('fp-2', FairPlayEventType.cancellation, -20, 'Hủy kèo LFG sát giờ • Gò Vấp Arena', 15),
          e('fp-3', FairPlayEventType.review, -15, 'Bị đánh giá "Chơi xấu" sau trận Bóng Đá', 12),
          e('fp-4', FairPlayEventType.noShow, -15, 'Vắng mặt trận Cầu Lông • Thiên Triều', 8),
          e('fp-5', FairPlayEventType.recovery, 5, 'Hồi phục theo thời gian', 1),
        ];
      default:
        return [initial];
    }
  }
}
