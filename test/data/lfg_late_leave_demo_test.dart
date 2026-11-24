import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/fair_play_rules.dart';
import 'package:test1/core/constants/lfg_rules.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/lfg_repository.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/models/wallet_transaction.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';

import '../helpers/layout_check.dart';

/// Kịch bản demo GVHD (Luồng 3 – LFG, unhappy case): 3 người chơi A (chủ kèo), B, C.
/// - B rời TRƯỚC mốc 48h: hoàn 100%, không trừ Fair Play, chỗ mở lại.
/// - C rời SAU mốc 48h (bùng kèo): không hoàn, cọc chuyển cho A ("Nhận tiền đền bù"), C −10 Fair Play,
///   kèo vẫn chốt, chỗ không mở lại. A không bị ảnh hưởng gì khác; chủ kèo không tự rời được sau mốc 48h.
void main() {
  const a = (id: 'u-demo-a', name: 'Người chơi A (chủ kèo)');
  const b = (id: 'u-demo-b', name: 'Người chơi B');
  const c = (id: 'u-demo-c', name: 'Người chơi C');

  late DateTime clock;
  late Map<String, MockWalletRepository> wallets;
  late MockReviewRepository review;
  late MockLfgRepository repo;

  /// Đăng nhập (bản giả lập đọc người dùng hiện tại từ máy).
  Future<void> loginAs(({String id, String name}) user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MockAuthRepository.keyCurrentUser, jsonEncode({'id': user.id, 'fullName': user.name}));
  }

  Future<int> balanceOf(({String id, String name}) user) => wallets[user.id]!.getBalance();

  Future<int> fairPlayOf(({String id, String name}) user) async {
    await loginAs(user);
    return (await review.getFairPlay()).score;
  }

  Future<LfgMatch> join(({String id, String name}) user, String matchId) async {
    await loginAs(user);
    final claim = await repo.claimSlot(matchId);
    return repo.confirmClaim(claim.claimId);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2030, 3, 1, 8);
    wallets = {};
    review = MockReviewRepository(latency: Duration.zero, now: () => clock);
    repo = MockLfgRepository(
      latency: Duration.zero,
      now: () => clock,
      review: review,
      // Mỗi người một ví riêng để thấy tiền đi từ người bùng sang chủ kèo.
      walletOf: (userId) => wallets.putIfAbsent(
        userId,
        () => MockWalletRepository(latency: Duration.zero, now: () => clock, keyPrefix: '${userId}_'),
      ),
    );
    for (final u in [a, b, c]) {
      wallets[u.id] = MockWalletRepository(latency: Duration.zero, now: () => clock, keyPrefix: '${u.id}_');
    }
  });

  test('3 người: B rời trước 48h được hoàn 100%; C bùng kèo trong 48h mất cọc cho A và bị −10 Fair Play', () async {
    final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');
    final start = DateTime(2030, 3, 5, 19); // 4 ngày 11 giờ nữa: trong cửa sổ tạo kèo 48h – 5 ngày
    final slot = TimeSlot(
      id: 'demo-slot',
      facilityId: facility.id,
      sport: Sport.badminton,
      courtName: 'Sân 1',
      start: start,
      end: start.add(const Duration(hours: 1)),
      price: 160000,
      isAvailable: true,
    );
    final deposit = LfgRules.depositPerSlot(slot.price, LfgFormat.doubles.totalSlots); // 40.000
    const initial = MockWalletRepository.defaultBalance;

    // 1) A tạo kèo ghép 4, trả cọc phần mình.
    await loginAs(a);
    final match = await repo.createMatch(
      hold: SlotHold(holdId: 'h1', slots: [slot], expiresAt: clock.add(const Duration(minutes: 10))),
      facility: facility,
      format: LfgFormat.doubles,
    );
    expect(await balanceOf(a), initial - deposit);

    // 2) B và C vào kèo, mỗi người trả cọc.
    await join(b, match.id);
    await join(c, match.id);
    expect(await balanceOf(b), initial - deposit);
    expect(await balanceOf(c), initial - deposit);

    // 3) Còn 3 ngày (trước mốc 48h): B rời → hoàn 100%, không trừ Fair Play, chỗ mở lại.
    clock = start.subtract(const Duration(days: 3));
    await loginAs(b);
    expect((await repo.getMatch(match.id)).isLateLeave(clock), isFalse);
    expect(await repo.leaveMatch(match.id), deposit);
    expect(await balanceOf(b), initial);
    expect(await fairPlayOf(b), FairPlayRules.initialScore);
    expect((await repo.getMatch(match.id)).slotsLeft, 2);

    // B vào lại + 1 người nữa vào → đủ 4 người, kèo chốt.
    await join(b, match.id);
    await loginAs(a);
    await repo.simulatePlayerJoined(match.id);
    expect((await repo.getMatch(match.id)).status(clock), LfgStatus.confirmed);

    // 4) Còn 10 giờ (sau mốc 48h): C bùng kèo.
    clock = start.subtract(const Duration(hours: 10));
    await loginAs(c);
    final before = await repo.getMatch(match.id);
    expect(before.isLateLeave(clock), isTrue);
    expect(await repo.leaveMatch(match.id, reason: 'Bận việc đột xuất'), 0); // không hoàn

    // C: không được hoàn cọc, bị −10 Fair Play, có lịch sử trừ điểm.
    expect(await balanceOf(c), initial - deposit);
    final cFairPlay = await review.getFairPlay();
    expect(cFairPlay.score, FairPlayRules.initialScore - LfgRules.lateLeaveFairPlay);
    expect(cFairPlay.history.first.delta, -LfgRules.lateLeaveFairPlay);

    // A: nhận đúng cọc của C ("Nhận tiền đền bù"), Fair Play không đổi.
    expect(await balanceOf(a), initial - deposit + deposit);
    final aTx = (await wallets[a.id]!.getTransactions()).first;
    expect(aTx.type, TransactionType.lfgForfeitIn);
    expect(aTx.amount, deposit);
    expect(await fairPlayOf(a), FairPlayRules.initialScore);

    // B: vẫn trong kèo, không bị ảnh hưởng.
    expect(await balanceOf(b), initial - deposit);
    expect(await fairPlayOf(b), FairPlayRules.initialScore);

    // Kèo vẫn chốt, C không còn trong kèo, chỗ của C không mở lại.
    await loginAs(a);
    final after = await repo.getMatch(match.id);
    expect(after.isMember(c.id), isFalse);
    expect(after.status(clock), LfgStatus.confirmed);
    expect(after.slotsLeft, 0);
    expect(after.isClaimable(clock), isFalse);

    // 5) Chủ kèo không tự rời được sau mốc 48h (chỉ còn hủy kèo theo luật hủy đơn phương 20/11).
    await expectLater(
      repo.leaveMatch(match.id),
      throwsA(isA<LfgException>().having((e) => e.message, 'message', LfgStrings.leaveTooLate)),
    );
  });

  group('màn chi tiết kèo', () {
    setUp(() async {
      final wallet = MockWalletRepository(latency: Duration.zero);
      final review = MockReviewRepository(latency: Duration.zero);
      AppRepositories.wallet = AppRepositories.paymentWallet = wallet;
      AppRepositories.review = review;
      AppRepositories.lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
      AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
      AppRepositories.facility = AppRepositories.lfgFacility = MockFacilityRepository(latency: Duration.zero);
      await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
    });

    // Kèo mẫu đã chốt, sáng mai (trong 48h), Khoa Cao là người tham gia.
    final now = DateTime.now();
    final matchId =
        'lfg-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-10';

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 3200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: LfgMatchDetailScreen(matchId: matchId)));
      await tester.pumpAndSettle();
    }

    testWidgets('rời kèo sát giờ: popup đỏ "KHÔNG ĐƯỢC HOÀN ĐIỂM, −10 Fair Play"; Không thì vẫn ở trong kèo', (tester) async {
      await pump(tester);
      expect(find.text(LfgStrings.lateLeaveNote), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, LfgStrings.leave));
      await tester.pumpAndSettle();
      expect(find.text(LfgStrings.lateLeaveTitle), findsOneWidget);
      expect(find.text(LfgStrings.lateLeaveWarning), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Bấm "Không": đóng popup, vẫn còn trong kèo.
      await tester.tap(find.text(LfgStrings.keep));
      await tester.pumpAndSettle();
      expect(find.text(LfgStrings.lateLeaveWarning), findsNothing);
      expect(find.widgetWithText(OutlinedButton, LfgStrings.leave), findsOneWidget);

      // Vẫn rời: báo đã chuyển cọc cho chủ kèo và bị trừ Fair Play.
      await tester.tap(find.widgetWithText(OutlinedButton, LfgStrings.leave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(LfgStrings.lateLeaveConfirm));
      await tester.pumpAndSettle();
      expect(find.text(LfgStrings.lateLeftMessage), findsOneWidget);
      expect((await tester.runAsync(() => AppRepositories.review.getFairPlay()))!.history.first.delta,
          -LfgRules.lateLeaveFairPlay);
    });

    testWidgets('popup rời kèo sát giờ không tràn chữ ở mọi cỡ máy / cỡ chữ', (tester) async {
      await expectNoOverflow(
        tester,
        'Popup rời kèo sát giờ',
        () => LfgMatchDetailScreen(matchId: matchId),
        interact: (tester) async {
          await tester.ensureVisible(find.widgetWithText(OutlinedButton, LfgStrings.leave));
          await tester.tap(find.widgetWithText(OutlinedButton, LfgStrings.leave));
          await settleFrames(tester);
        },
      );
    });
  });
}
