import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/fair_play_rules.dart';
import 'package:test1/core/strings/review_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/repositories/review_repository.dart';
import 'package:test1/models/review.dart';

void main() {
  late DateTime clock;
  late MockReviewRepository repo;

  Future<void> loginAs(String identifier) async {
    await MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');
  }

  Matcher reviewError(String message) =>
      throwsA(isA<ReviewException>().having((e) => e.message, 'message', message));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 14, 20, 0);
    repo = MockReviewRepository(latency: Duration.zero, now: () => clock);
    await loginAs('player@sportnexus.vn');
  });

  group('FairPlayRules', () {
    test('dưới 30 thì không được ghép LFG; dưới 40 là đang hồi phục', () {
      expect(FairPlayRules.canJoinLfg(30), isTrue);
      expect(FairPlayRules.canJoinLfg(29), isFalse);
      expect(FairPlayRules.isRecovering(39), isTrue);
      expect(FairPlayRules.isRecovering(40), isFalse);
    });

    test('bảng điểm theo sao trung bình: dưới 2.5 trừ 5, 2.5–3.9 giữ nguyên, 4–4.5 cộng 3, trên 4.5 cộng 5', () {
      expect(FairPlayRules.reviewDelta(1), -5);
      expect(FairPlayRules.reviewDelta(2.4), -5);
      expect(FairPlayRules.reviewDelta(2.5), 0);
      expect(FairPlayRules.reviewDelta(3.9), 0);
      expect(FairPlayRules.reviewDelta(4), 3);
      expect(FairPlayRules.reviewDelta(4.5), 3);
      expect(FairPlayRules.reviewDelta(4.6), 5);
      expect(FairPlayRules.noShowPenalty, -10);
    });
  });

  group('Fair Play', () {
    test('điểm = tổng lịch sử, lịch sử mới nhất trước', () async {
      final fp = await repo.getFairPlay();
      expect(fp.score, 93);
      expect(fp.canJoinLfg, isTrue);
      expect(fp.history.first.delta, 3);
      expect(fp.history.last.type, FairPlayEventType.initial);
    });

    test('tài khoản demo bị hạn chế có 25 điểm, không được ghép LFG', () async {
      await loginAs('restricted@sportnexus.vn');
      final fp = await repo.getFairPlay();
      expect(fp.score, 25);
      expect(fp.canJoinLfg, isFalse);
    });

    test('tài khoản mới đăng ký bắt đầu 100 điểm', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await repo.getFairPlay()).score, FairPlayRules.initialScore);
    });
  });

  group('danh sách chờ đánh giá', () {
    test('chỉ gồm buổi còn trong hạn 24 giờ, hạn gần nhất trước', () async {
      final pending = await repo.getPendingReviews();
      expect(pending.map((p) => p.sessionId), ['ss-booking-thaodien', 'ss-lfg-eco-1v1', 'ss-lfg-thientrieu']);
      expect(pending.every((p) => !p.isExpired(clock)), isTrue);
    });

    test('đặt sân thường không có người chơi để chấm; trận LFG thì có', () async {
      final pending = await repo.getPendingReviews();
      expect(pending.firstWhere((p) => p.type == SessionType.booking).players, isEmpty);
      expect(pending.firstWhere((p) => p.sessionId == 'ss-lfg-thientrieu').players, hasLength(3));
    });

    test('qua hạn 24 giờ thì tự biến mất khỏi danh sách', () async {
      await repo.getPendingReviews(); // ghi mốc dữ liệu giả
      clock = clock.add(const Duration(hours: 5));
      expect((await repo.getPendingReviews()).map((p) => p.sessionId), isNot(contains('ss-booking-thaodien')));
    });
  });

  group('gửi đánh giá', () {
    test('gửi xong thì biến khỏi danh sách, không gửi lại được', () async {
      await repo.submitReview(
        'ss-lfg-thientrieu',
        facility: const FacilityReviewInput(stars: 5),
        players: const [
          PlayerReviewInput(playerId: 'u-minhtuan', stars: 5, tags: {ReviewTag.onTime, ReviewTag.fairPlay}),
          PlayerReviewInput(playerId: 'u-hoangnam', stars: 2, tags: {ReviewTag.late}),
        ],
      );
      expect((await repo.getPendingReviews()).map((p) => p.sessionId), isNot(contains('ss-lfg-thientrieu')));
      expect(
        () => repo.submitReview('ss-lfg-thientrieu', facility: const FacilityReviewInput(stars: 4)),
        reviewError(ReviewStrings.alreadySubmitted),
      );
    });

    test('đánh giá đã gửi tính riêng cho từng tài khoản', () async {
      await repo.submitReview('ss-booking-thaodien', facility: const FacilityReviewInput(stars: 4));
      await loginAs('restricted@sportnexus.vn');
      expect((await repo.getPendingReviews()).map((p) => p.sessionId), contains('ss-booking-thaodien'));
    });

    test('không chấm gì thì báo lỗi', () async {
      expect(() => repo.submitReview('ss-lfg-thientrieu'), reviewError(ReviewStrings.nothingRated));
    });

    test('số sao ngoài 1–5 thì báo lỗi', () async {
      expect(
        () => repo.submitReview('ss-booking-thaodien', facility: const FacilityReviewInput(stars: 6)),
        reviewError(ReviewStrings.invalidStars),
      );
    });

    test('chấm người không có trong trận thì báo lỗi', () async {
      expect(
        () => repo.submitReview('ss-lfg-eco-1v1', players: const [PlayerReviewInput(playerId: 'u-la', stars: 5)]),
        throwsA(isA<ReviewException>()),
      );
    });

    test('quá hạn thì không gửi được', () async {
      expect(
        () => repo.submitReview('ss-lfg-hoalu-expired', facility: const FacilityReviewInput(stars: 3)),
        reviewError(ReviewStrings.expired),
      );
    });
  });
}
