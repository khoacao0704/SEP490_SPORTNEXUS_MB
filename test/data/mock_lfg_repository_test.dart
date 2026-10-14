import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/lfg_rules.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/lfg_repository.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';

void main() {
  late DateTime clock;
  late MockWalletRepository wallet;
  late MockLfgRepository repo;

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  Matcher lfgError(String message) => throwsA(isA<LfgException>().having((e) => e.message, 'message', message));

  const hcm = LfgFeedQuery(city: 'Hồ Chí Minh');
  String seedId(int n) => 'lfg-20261014-$n';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 14, 20, 0);
    wallet = MockWalletRepository(latency: Duration.zero, now: () => clock);
    repo = MockLfgRepository(
      latency: Duration.zero,
      now: () => clock,
      wallet: wallet,
      review: MockReviewRepository(latency: Duration.zero, now: () => clock),
    );
    await loginAs('player@sportnexus.vn');
  });

  group('LfgRules', () {
    test('cọc chia đều tiền sân, làm tròn lên 1.000đ', () {
      expect(LfgRules.depositPerSlot(140000, 4), 35000);
      expect(LfgRules.depositPerSlot(630000, 2), 315000);
      expect(LfgRules.depositPerSlot(100000, 3), 34000);
    });

    test('chỉ tạo kèo cho khung giờ từ 48 giờ đến 5 ngày tới', () {
      final now = DateTime(2026, 10, 14, 20);
      expect(LfgRules.canCreateFor(now.add(const Duration(hours: 47)), now), isFalse);
      expect(LfgRules.canCreateFor(now.add(const Duration(hours: 48)), now), isTrue);
      expect(LfgRules.canCreateFor(now.add(const Duration(days: 5)), now), isTrue);
      expect(LfgRules.canCreateFor(now.add(const Duration(days: 5, minutes: 1)), now), isFalse);
    });
  });

  group('bảng tin', () {
    test('lọc theo thành phố, môn và hình thức; sớm nhất trước', () async {
      final feed = await repo.getFeed(hcm);
      expect(feed, isNotEmpty);
      expect(feed.every((i) => i.match.city == 'Hồ Chí Minh'), isTrue);
      for (var i = 1; i < feed.length; i++) {
        expect(feed[i - 1].match.start.isAfter(feed[i].match.start), isFalse);
      }

      final football = await repo.getFeed(const LfgFeedQuery(city: 'Hồ Chí Minh', sport: Sport.football));
      expect(football.map((i) => i.match.format).toSet(), {LfgFormat.teamVsTeam});

      final hanoi = await repo.getFeed(const LfgFeedQuery(city: 'Hà Nội'));
      expect(hanoi.map((i) => i.match.facilityName), ['Sân Cầu Lông Cầu Giấy']);
    });

    test('kèo mình đang tham gia có trong "Kèo của tôi"', () async {
      final mine = await repo.getMyMatches();
      expect(mine.map((m) => m.id), [seedId(3)]);
    });
  });

  group('Flash Claim', () {
    test('giữ chỗ 10 phút, thanh toán xong thì vào kèo và bị trừ cọc', () async {
      final before = await wallet.getBalance();
      final claim = await repo.claimSlot(seedId(1));
      expect(claim.amount, claim.match.depositPerSlot);
      expect(claim.expiresAt, clock.add(LfgRules.claimHold));

      final match = await repo.confirmClaim(claim.claimId);
      expect(match.isMember('u-player-001'), isTrue);
      expect(await wallet.getBalance(), before - claim.amount);
      expect((await repo.getMyMatches()).map((m) => m.id), contains(seedId(1)));
    });

    test('chỗ đang được người khác giữ thì người sau không claim được', () async {
      // Kèo 1vs1 chỉ còn 1 chỗ: Khoa Cao giữ trước.
      await repo.claimSlot(seedId(2));

      await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
      expect(() => repo.claimSlot(seedId(2)), lfgError(LfgStrings.full));
      expect((await repo.getFeed(hcm)).map((i) => i.match.id), isNot(contains(seedId(2))));
    });

    test('Fair Play dưới 30 thì không claim được', () async {
      await loginAs('restricted@sportnexus.vn');
      expect(() => repo.claimSlot(seedId(1)), lfgError(LfgStrings.blocked));
    });

    test('hết 10 phút thì không xác nhận được nữa', () async {
      final claim = await repo.claimSlot(seedId(1));
      clock = clock.add(const Duration(minutes: 11));
      expect(() => repo.confirmClaim(claim.claimId), lfgError(LfgStrings.claimExpired));
    });

    test('đã ở trong kèo thì không claim lại', () async {
      expect(() => repo.claimSlot(seedId(3)), lfgError(LfgStrings.alreadyJoined));
    });

    test('ví không đủ tiền thì báo lỗi, chỗ vẫn giữ để trả bằng VietQR', () async {
      await SharedPreferences.getInstance().then((p) => p.setInt(MockWalletRepository.keyBalance, 1000));
      final claim = await repo.claimSlot(seedId(4));
      await expectLater(() => repo.confirmClaim(claim.claimId), throwsA(isA<LfgException>()));
      await SharedPreferences.getInstance().then((p) => p.setInt(MockWalletRepository.keyBalance, 1000000));
      expect((await repo.confirmClaim(claim.claimId)).isMember('u-player-001'), isTrue);
    });
  });

  group('hạn chốt T−48h', () {
    test('thiếu người thì tự hủy và hoàn 100% cọc', () async {
      final claim = await repo.claimSlot(seedId(1));
      await repo.confirmClaim(claim.claimId);
      final afterPay = await wallet.getBalance();

      // Kèo 1 bắt đầu 19:00 sau 3 ngày => hạn chốt 19:00 sau 1 ngày.
      clock = clock.add(const Duration(days: 1));
      final match = await repo.getMatch(seedId(1));
      expect(match.status(clock), LfgStatus.cancelled);
      expect(match.cancelReason, LfgCancelReason.notEnoughPlayers);
      expect(await wallet.getBalance(), afterPay + claim.amount);
    });

    test('đủ người thì chốt; sau đó có người rời thì chỗ để trống', () async {
      // Kèo 3 (Khoa Cao đang ở trong, 3/4) có thêm 1 người => đủ 4/4.
      await repo.simulatePlayerJoined(seedId(3));

      // Kèo 3 bắt đầu 20:00 sau 3 ngày => hạn chốt 20:00 sau 1 ngày.
      clock = clock.add(const Duration(days: 1, hours: 1));
      final locked = await repo.getMatch(seedId(3));
      expect(locked.status(clock), LfgStatus.confirmed);

      expect(await repo.leaveMatch(seedId(3)), locked.depositPerSlot);
      final after = await repo.getMatch(seedId(3));
      expect(after.members, hasLength(3));
      expect(after.status(clock), LfgStatus.confirmed);
      expect(after.isClaimable(clock), isFalse);
    });
  });

  group('rời / hủy kèo', () {
    test('người tham gia rời trước hạn: mất cọc, chỗ mở lại', () async {
      final claim = await repo.claimSlot(seedId(1));
      await repo.confirmClaim(claim.claimId);
      final balance = await wallet.getBalance();

      expect(await repo.leaveMatch(seedId(1)), claim.amount);
      expect(await wallet.getBalance(), balance);
      final match = await repo.getMatch(seedId(1));
      expect(match.isMember('u-player-001'), isFalse);
      expect(match.isClaimable(clock), isTrue);
    });

    test('host không rời được mà phải hủy; người khác hoàn 100%, host mất cọc', () async {
      final created = await _createMatch(repo, clock);
      expect(() => repo.leaveMatch(created.id), lfgError(LfgStrings.hostCannotLeave));

      await loginAs('restricted@sportnexus.vn');
      expect(() => repo.cancelMatch(created.id), lfgError(LfgStrings.notHost));

      // Một người khác vào kèo (ví giả lập dùng chung trên máy).
      await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
      final claim = await repo.claimSlot(created.id);
      await repo.confirmClaim(claim.claimId);

      await loginAs('player@sportnexus.vn');
      final balance = await wallet.getBalance();
      await repo.cancelMatch(created.id);
      final match = await repo.getMatch(created.id);
      expect(match.cancelReason, LfgCancelReason.hostCancelled);
      expect(await wallet.getBalance(), balance + claim.amount, reason: 'chỉ người tham gia được hoàn, host mất cọc');
    });
  });

  group('tạo kèo', () {
    test('trừ cọc host, kèo lên bảng tin', () async {
      final before = await wallet.getBalance();
      final match = await _createMatch(repo, clock);
      expect(match.host.userId, 'u-player-001');
      expect(await wallet.getBalance(), before - match.depositPerSlot);
      expect((await repo.getFeed(hcm)).map((i) => i.match.id), contains(match.id));
    });

    test('khung giờ dưới 48 giờ thì không tạo được', () async {
      expect(
        () => _createMatch(repo, clock, startIn: const Duration(hours: 30)),
        lfgError(LfgStrings.createWindow),
      );
    });

    test('hình thức phải hợp với môn', () async {
      expect(
        () => _createMatch(repo, clock, format: LfgFormat.teamVsTeam),
        lfgError(LfgStrings.invalidFormat),
      );
    });
  });
}

Future<LfgMatch> _createMatch(
  MockLfgRepository repo,
  DateTime now, {
  Duration startIn = const Duration(days: 3),
  LfgFormat format = LfgFormat.doubles,
}) {
  final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');
  final start = DateTime(now.year, now.month, now.day, now.hour).add(startIn);
  final slot = TimeSlot(
    id: 'slot-test',
    facilityId: facility.id,
    sport: Sport.badminton,
    start: start,
    end: start.add(const Duration(hours: 1)),
    price: 168000,
    totalCourts: 6,
    availableCourts: 3,
  );
  return repo.createMatch(
    hold: SlotHold(holdId: 'hold-test', slots: [slot], expiresAt: now.add(const Duration(minutes: 10))),
    facility: facility,
    format: format,
  );
}
