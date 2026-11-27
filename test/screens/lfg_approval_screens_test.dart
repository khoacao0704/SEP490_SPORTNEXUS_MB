import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/screens/lfg/create_lfg_match_screen.dart';
import 'package:test1/screens/lfg/edit_lfg_match_screen.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';
import 'package:test1/screens/lfg/lfg_screen.dart';
import 'package:test1/widgets/lfg/lfg_approval.dart';

import '../helpers/layout_check.dart';

/// B1 (kèo cần duyệt người) + B2 (sửa kèo) trên bản giả lập.
void main() {
  late MockLfgRepository lfg;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.review = review;
    AppRepositories.lfg = lfg;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.facility = AppRepositories.lfgFacility = MockFacilityRepository(latency: Duration.zero);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  /// Người dùng hiện tại tạo kèo ghép 4 cần duyệt, có [requests] người giả lập đang chờ duyệt.
  Future<LfgMatch> hostedMatch({int requests = 2, String note = ''}) async {
    final facility = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 19).add(const Duration(days: 3));
    final slot = TimeSlot(
      id: 'slot-approval',
      facilityId: facility.id,
      sport: Sport.badminton,
      start: start,
      end: start.add(const Duration(hours: 1)),
      price: 160000,
      courtName: 'Sân 4',
      isAvailable: true,
    );
    final match = await lfg.createMatch(
      hold: SlotHold(holdId: 'h', slots: [slot], expiresAt: now.add(const Duration(minutes: 10))),
      facility: facility,
      format: LfgFormat.doubles,
      note: note,
      requireApproval: true,
    );
    for (var i = 0; i < requests; i++) {
      await lfg.simulatePlayerJoined(match.id);
    }
    return match;
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('tạo kèo: có công tắc duyệt người, mặc định tắt, bật thì đổi lời giải thích', (tester) async {
    await pump(tester, const CreateLfgMatchScreen());
    await tester.tap(find.textContaining('Sân Cầu Lông Thiên Triều').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(LfgApprovalSwitch), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text(LfgStrings.approvalOff), findsOneWidget);
    await tester.ensureVisible(find.byType(LfgApprovalSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LfgStrings.approvalTitle));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.approvalOn), findsOneWidget);
  });

  testWidgets('chủ kèo: duyệt, từ chối người chờ; loại người đã vào (có hỏi xác nhận)', (tester) async {
    final match = await tester.runAsync(() => hostedMatch());
    await pump(tester, LfgMatchDetailScreen(matchId: match!.id));
    expect(find.text('${LfgStrings.pendingSection} (2)'), findsOneWidget);
    expect(find.text(LfgStrings.needsApproval), findsOneWidget);

    await tester.tap(find.text(LfgStrings.approve).first);
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.approvedMessage('Phương Linh')), findsOneWidget);
    expect(find.text('${LfgStrings.pendingSection} (1)'), findsOneWidget);
    expect(find.text('Phương Linh'), findsOneWidget); // đã vào danh sách thành viên

    await tester.tap(find.text(LfgStrings.reject));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.rejectedMessage('Tuấn Kiệt')), findsOneWidget);
    expect(find.text(LfgStrings.pastSection), findsOneWidget);
    expect(find.textContaining(LfgStrings.memberStatus(LfgMemberStatus.rejected)), findsOneWidget);

    await tester.tap(find.text(LfgStrings.remove));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.removeMessage('Phương Linh')), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, LfgStrings.remove));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.removedMessage('Phương Linh')), findsOneWidget);
    expect(find.textContaining(LfgStrings.memberStatus(LfgMemberStatus.removed)), findsOneWidget);
    expect(find.text(LfgStrings.emptySlot), findsNWidgets(3));
  });

  testWidgets('sửa kèo: khóa sân/ca/thể thức, đổi số người, trình độ, ghi chú, tắt duyệt rồi lưu', (tester) async {
    final match = await tester.runAsync(() => hostedMatch(requests: 0));
    await pump(tester, LfgMatchDetailScreen(matchId: match!.id));
    await tester.tap(find.text(LfgStrings.editMatch));
    await tester.pumpAndSettle();
    expect(find.byType(EditLfgMatchScreen), findsOneWidget);
    expect(find.text(LfgStrings.lockedInfo), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // ghép 4: cần thêm 3 người

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Khá'));
    await tester.tap(find.byType(Switch));
    await tester.enterText(find.byType(TextField), 'Đến đúng giờ nhé');
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.approvalOff), findsOneWidget);

    await tester.tap(find.text(LfgStrings.saveEdit));
    await tester.pumpAndSettle();
    expect(find.byType(LfgMatchDetailScreen), findsOneWidget);
    expect(find.text(LfgStrings.editSaved), findsOneWidget);
    expect(find.text('Đến đúng giờ nhé'), findsOneWidget);
    expect(find.text(LfgStrings.needsApproval), findsNothing);
    expect(find.text(LfgStrings.emptySlot), findsNWidgets(2));
    final saved = await tester.runAsync(() => lfg.getMatch(match.id));
    expect(saved!.totalSlots, 3);
    expect(saved.skillLevel?.label, 'Khá');
  });

  testWidgets('người khác: kèo cần duyệt thì gửi yêu cầu (không qua thanh toán), rồi rút được', (tester) async {
    final match = await tester.runAsync(() async {
      final m = await hostedMatch(requests: 0);
      await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
      return m;
    });
    await pump(tester, LfgMatchDetailScreen(matchId: match!.id));
    expect(find.text(LfgStrings.editMatch), findsNothing);
    expect(find.textContaining(LfgStrings.pendingSection), findsNothing);

    await tester.tap(find.text(LfgStrings.sendRequestLong));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.requestDialogTitle), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(LfgStrings.sendRequestLong)));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.requestSent), findsOneWidget);
    expect(find.text(LfgStrings.statusPendingApproval), findsOneWidget);

    await tester.tap(find.text(LfgStrings.withdrawRequest));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.withdrawnMessage), findsOneWidget);
    expect(find.text(LfgStrings.sendRequestLong), findsOneWidget);
  });

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('bố cục: chi tiết kèo của chủ kèo (chờ duyệt + đã rời) và màn sửa kèo không tràn', (tester) async {
    final match = await tester.runAsync(() async {
      final m = await hostedMatch(requests: 3, note: 'Ghi chú dài để kiểm tra xuống dòng trên máy nhỏ và chữ phóng to.');
      await lfg.approveRequest(m.id, 'u-guest-1');
      await lfg.rejectRequest(m.id, 'u-guest-2');
      return lfg.getMatch(m.id);
    });
    await expectNoOverflow(tester, 'Chi tiết kèo (chủ kèo)', () => LfgMatchDetailScreen(matchId: match!.id),
        interact: scrollToEnd);
    await expectNoOverflow(tester, 'Sửa kèo', () => EditLfgMatchScreen(match: match!), interact: scrollToEnd);
  });

  testWidgets('bảng tin: kèo cần duyệt có nhãn + nút GỬI YÊU CẦU, không tràn', (tester) async {
    await tester.runAsync(() async {
      await hostedMatch(requests: 0);
      await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
    });
    await pump(tester, const LfgScreen());
    await tester.scrollUntilVisible(find.text(LfgStrings.sendRequest), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text(LfgStrings.sendRequest), findsOneWidget);
    expect(find.text(LfgStrings.needsApproval), findsOneWidget);
    await expectNoOverflow(tester, 'Bảng tin (kèo cần duyệt)', () => const LfgScreen(), interact: scrollToEnd);
  });
}
