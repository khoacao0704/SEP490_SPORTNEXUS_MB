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

    test('bảng điểm theo sao trung bình (theo BE): <1.5 −5, <2.5 −2, >4 +3, ≥4.5 +5', () {
      expect(FairPlayRules.reviewDelta(1), -5);
      expect(FairPlayRules.reviewDelta(1.49), -5);
      expect(FairPlayRules.reviewDelta(1.5), -2);
      expect(FairPlayRules.reviewDelta(2.49), -2);
      expect(FairPlayRules.reviewDelta(2.5), 0);
      expect(FairPlayRules.reviewDelta(4), 0);
      expect(FairPlayRules.reviewDelta(4.1), 3);
      expect(FairPlayRules.reviewDelta(4.5), 5);
      expect(FairPlayRules.noShowPenalty, -10);
    });
  });

  group('Fair Play', () {
    test('điểm = tổng lịch sử, lịch sử mới nhất trước, có điểm sau mỗi lần đổi', () async {
      final fp = await repo.getFairPlay();
      expect(fp.score, 93);
      expect(fp.canJoinLfg, isTrue);
      expect(fp.isBanned, isFalse);
      expect(fp.history.first.delta, 3);
      expect(fp.history.first.scoreAfter, 93);
      expect(fp.history.last.type, FairPlayEventType.initial);
      expect(fp.hasMoreHistory, isFalse);
    });

    test('tài khoản demo bị hạn chế có 25 điểm, không được ghép LFG (không phải bị cấm)', () async {
      await loginAs('restricted@sportnexus.vn');
      final fp = await repo.getFairPlay();
      expect(fp.score, 25);
      expect(fp.canJoinLfg, isFalse);
      expect(fp.isBanned, isFalse);
      expect(fp.history.map((e) => e.type), contains(FairPlayEventType.late));
    });

    test('tài khoản mới đăng ký bắt đầu 100 điểm', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await repo.getFairPlay()).score, FairPlayRules.initialScore);
    });

    test('bị Admin cấm dù đủ điểm', () {
      const fp = FairPlaySummary(score: 80, isLfgBlocked: true, banReason: 'Gian lận');
      expect(fp.canJoinLfg, isFalse);
      expect(fp.isBanned, isTrue);
    });
  });

  group('danh sách chờ chấm', () {
    test('chỉ gồm trận còn hạn (24 giờ sau giờ kết thúc), hạn gần nhất trước, mỗi trận có người để chấm', () async {
      final pending = await repo.getPendingReviews();
      expect(pending.map((p) => p.sessionId), ['ss-booking-thaodien', 'ss-lfg-eco-1v1', 'ss-lfg-thientrieu']);
      expect(pending.every((p) => !p.isExpired(clock) && p.players.isNotEmpty), isTrue);
      final lfg = pending.last;
      expect(lfg.deadline, lfg.end.add(FairPlayRules.reviewWindow));
      expect(lfg.players, hasLength(3));
    });

    test('qua hạn thì tự biến mất khỏi danh sách', () async {
      await repo.getPendingReviews(); // ghi mốc dữ liệu giả
      clock = clock.add(const Duration(hours: 5));
      expect((await repo.getPendingReviews()).map((p) => p.sessionId), isNot(contains('ss-booking-thaodien')));
    });
  });

  group('chấm người chơi', () {
    test('chấm một phần thì trận còn người chưa chấm; chấm hết thì trận biến khỏi danh sách', () async {
      await repo.ratePlayers('ss-lfg-thientrieu', const [
        PlayerReviewInput(playerId: 'u-minhtuan', stars: 5, tags: {ReviewTag.onTime, ReviewTag.fairPlay}),
      ]);
      var session = (await repo.getPendingReviews()).firstWhere((p) => p.sessionId == 'ss-lfg-thientrieu');
      expect(session.players.map((p) => p.userId), ['u-hoangnam', 'u-thutrang']);

      await repo.ratePlayers('ss-lfg-thientrieu', const [
        PlayerReviewInput(playerId: 'u-hoangnam', stars: 2, tags: {ReviewTag.late}),
        PlayerReviewInput(playerId: 'u-thutrang', stars: 4),
      ]);
      expect((await repo.getPendingReviews()).map((p) => p.sessionId), isNot(contains('ss-lfg-thientrieu')));
    });

    test('đã chấm tính riêng cho từng tài khoản', () async {
      await repo.ratePlayers('ss-booking-thaodien', const [PlayerReviewInput(playerId: 'u-lananh', stars: 4)]);
      await loginAs('restricted@sportnexus.vn');
      expect((await repo.getPendingReviews()).map((p) => p.sessionId), contains('ss-booking-thaodien'));
    });

    test('số sao ngoài 1–5, người không có trong trận, trận quá hạn thì báo lỗi', () async {
      expect(
        () => repo.ratePlayers('ss-lfg-eco-1v1', const [PlayerReviewInput(playerId: 'u-quocbao', stars: 6)]),
        reviewError(ReviewStrings.invalidStars),
      );
      expect(
        () => repo.ratePlayers('ss-lfg-eco-1v1', const [PlayerReviewInput(playerId: 'u-la', stars: 5)]),
        throwsA(isA<ReviewException>()),
      );
      expect(
        () => repo.ratePlayers('ss-lfg-hoalu-expired', const [PlayerReviewInput(playerId: 'u-ductri', stars: 3)]),
        reviewError(ReviewStrings.expired),
      );
    });

    test('thẻ nhanh ghép vào đầu nhận xét theo thứ tự cố định', () {
      expect(
        const PlayerReviewInput(playerId: 'x', stars: 5, tags: {ReviewTag.fairPlay, ReviewTag.onTime}, comment: ' Đánh hay ')
            .commentWithTags,
        'Đúng giờ, Chơi đẹp. Đánh hay',
      );
      expect(const PlayerReviewInput(playerId: 'x', stars: 3, tags: {ReviewTag.late}).commentWithTags, 'Đến trễ');
      expect(const PlayerReviewInput(playerId: 'x', stars: 3, comment: 'Ok').commentWithTags, 'Ok');
    });
  });

  group('đánh giá cơ sở', () {
    test('danh sách mới nhất trước, có tổng hợp và lọc theo sao', () async {
      final page = await repo.getFacilityReviews('f-hcm-thientrieu');
      expect(page.items, hasLength(3));
      expect(page.stats.total, 3);
      expect(page.stats.average, 3.7);
      expect(page.stats.distribution[5], 1);
      expect(page.items.first.ownerReply, isNotNull);

      final twoStars = await repo.getFacilityReviews('f-hcm-thientrieu', stars: 2);
      expect(twoStars.items.single.stars, 2);
      expect(twoStars.stats.total, 3);
    });

    test('chỉ đánh giá được cơ sở đã chơi, mỗi cơ sở một lần, hiện trong đánh giá của tôi', () async {
      expect((await repo.getEligibility('f-hcm-fpt')).canReview, isFalse);
      expect(
        () => repo.submitFacilityReview('f-hcm-fpt', const FacilityReviewInput(stars: 5)),
        reviewError(ReviewStrings.notEligible),
      );

      expect((await repo.getEligibility('f-hcm-eco-q7')).canReview, isTrue);
      final review = await repo.submitFacilityReview('f-hcm-eco-q7', const FacilityReviewInput(stars: 4, comment: 'Ổn'));

      final eligibility = await repo.getEligibility('f-hcm-eco-q7');
      expect(eligibility.canReview, isFalse);
      expect(eligibility.existingReviewId, review.id);
      expect(
        () => repo.submitFacilityReview('f-hcm-eco-q7', const FacilityReviewInput(stars: 5)),
        throwsA(isA<ReviewException>()),
      );

      final list = await repo.getFacilityReviews('f-hcm-eco-q7');
      expect(list.items.first.id, review.id);
      expect(list.stats.total, 2);
      final mine = await repo.getMyReviews();
      expect(mine.items.single.facilityName, 'Eco Sport Quận 7');
    });
  });
}
