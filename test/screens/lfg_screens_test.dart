import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/core/strings/review_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/screens/lfg/create_lfg_match_screen.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';
import 'package:test1/screens/lfg/lfg_payment_screen.dart';
import 'package:test1/screens/lfg/lfg_screen.dart';

void main() {
  late MockWalletRepository wallet;
  late MockLfgRepository lfg;

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wallet = MockWalletRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    AppRepositories.wallet = wallet;
    AppRepositories.review = review;
    AppRepositories.lfg = lfg;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.facility = MockFacilityRepository(latency: Duration.zero);
    await loginAs('player@sportnexus.vn');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Future<LfgMatch> seed(String facilityName) async {
    final feed = await lfg.getFeed(const LfgFeedQuery(city: 'Hồ Chí Minh'));
    return feed.map((i) => i.match).firstWhere((m) => m.facilityName == facilityName);
  }

  testWidgets('bảng tin: hiện kèo, lọc theo môn; tab Kèo của tôi', (tester) async {
    await pump(tester, const LfgScreen());
    expect(find.text('Sân Bóng Hoa Lư • Quận 1'), findsOneWidget);
    expect(find.text(LfgStrings.joined), findsOneWidget); // kèo Gò Vấp đang tham gia

    await tester.tap(find.widgetWithText(ChoiceChip, 'Bóng Đá'));
    await tester.pumpAndSettle();
    expect(find.text('Sân Bóng Hoa Lư • Quận 1'), findsOneWidget);
    expect(find.text('Sân Cầu Lông Thiên Triều • Quận 7'), findsNothing);
    expect(find.text('${LfgFormat.teamVsTeam.label} • 7 vs 7'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '5 vs 5'));
    await tester.pumpAndSettle();
    expect(find.text('Sân Bóng Hoa Lư • Quận 1'), findsNothing);

    await tester.tap(find.text(LfgStrings.tabMine));
    await tester.pumpAndSettle();
    expect(find.text('Gò Vấp Arena • Gò Vấp'), findsOneWidget);
  });

  testWidgets('Flash Claim từ chi tiết kèo: thanh toán bằng ví, có vé QR và nút Rời kèo', (tester) async {
    final match = await tester.runAsync(() => seed('Sân Cầu Lông Thiên Triều'));
    await pump(tester, LfgMatchDetailScreen(matchId: match!.id));
    expect(find.text(LfgStrings.emptySlot), findsNWidgets(2));

    await tester.tap(find.textContaining(LfgStrings.flashClaim));
    await tester.pumpAndSettle();
    expect(find.byType(LfgPaymentScreen), findsOneWidget);
    expect(find.textContaining('Đang giữ chỗ'), findsOneWidget);

    await tester.tap(find.text(LfgStrings.confirmPay));
    await tester.pumpAndSettle();
    expect(find.byType(LfgMatchDetailScreen), findsOneWidget);
    expect(find.text(LfgStrings.yourTicket), findsOneWidget);
    expect(find.text('Khoa Cao ${LfgStrings.you}'), findsOneWidget);
    expect(find.text(LfgStrings.leave), findsOneWidget);
  });

  testWidgets('rời kèo chưa đủ người: hỏi xác nhận, được hoàn 100%', (tester) async {
    final match = await tester.runAsync(() => seed('Gò Vấp Arena'));
    await pump(tester, LfgMatchDetailScreen(matchId: match!.id));

    await tester.tap(find.text(LfgStrings.leave));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.confirmLeaveTitle), findsOneWidget);
    expect(find.textContaining('Bạn được hoàn 100%'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, LfgStrings.leave));
    await tester.pumpAndSettle();
    expect(find.textContaining('đã được hoàn vào ví'), findsOneWidget);
    expect(find.text(LfgStrings.yourTicket), findsNothing);
    expect(find.textContaining(LfgStrings.flashClaim), findsOneWidget);
  });

  testWidgets('Fair Play dưới 30: Flash Claim bị chặn ngay', (tester) async {
    await loginAs('restricted@sportnexus.vn');
    final match = await tester.runAsync(() => seed('Sân Cầu Lông Thiên Triều'));
    await pump(tester, LfgMatchDetailScreen(matchId: match!.id));

    await tester.tap(find.textContaining(LfgStrings.flashClaim));
    await tester.pumpAndSettle();
    expect(find.text(ReviewStrings.blockedTitle), findsOneWidget);
    expect(find.byType(LfgPaymentScreen), findsNothing);
  });

  testWidgets('tạo kèo: chỉ có các ngày trong khoảng 48 giờ – 5 ngày, chọn sân và giờ rồi thanh toán', (tester) async {
    await pump(tester, const CreateLfgMatchScreen());
    expect(find.text(LfgStrings.depositExplain('Ghép 4 (2 vs 2)', 4, false)), findsOneWidget);

    await tester.tap(find.text('Sân Cầu Lông Thiên Triều'));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.timeWindowNote), findsOneWidget);

    // Chọn ngày cuối (luôn có đủ khung giờ trong cửa sổ 48h–5 ngày) rồi khung giờ đầu tiên.
    final days = find.descendant(of: find.byType(ListView).at(1), matching: find.byType(GestureDetector));
    expect(days, findsWidgets);
    await tester.tap(days.last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(' - ').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(LfgStrings.continueToPay));
    await tester.pumpAndSettle();
    expect(find.byType(LfgPaymentScreen), findsOneWidget);

    await tester.tap(find.text(LfgStrings.confirmPay));
    await tester.pumpAndSettle();
    expect(find.byType(LfgMatchDetailScreen), findsOneWidget);
    expect(find.text(LfgStrings.cancelMatch), findsOneWidget);
    expect(find.text(LfgStrings.yourTicket), findsOneWidget);
  });

  testWidgets('kèo đã chốt: không có nút rời, gửi yêu cầu hủy rồi chờ người khác', (tester) async {
    final match = await tester.runAsync(() => lfg.getMyMatches());
    final full = match!.firstWhere((m) => m.facilityName == 'Pickleball Thảo Điền');
    await pump(tester, LfgMatchDetailScreen(matchId: full.id));
    expect(find.text(LfgStrings.leave), findsNothing);
    expect(find.text(LfgStrings.confirmedNote), findsOneWidget);

    await tester.tap(find.text(LfgStrings.requestCancel));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.confirmRequestTitle), findsOneWidget);
    await tester.tap(find.text(LfgStrings.sendRequest));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.waitingOthers), findsOneWidget);
    expect(find.text(LfgStrings.approvalsCount(1, 4)), findsOneWidget);

    await tester.tap(find.text(LfgStrings.simulateApprove));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.statusCancelledMutual), findsOneWidget);
    expect(find.text(LfgStrings.yourTicket), findsNothing);
  });

  testWidgets('người khác xin hủy: mình đồng ý cuối cùng thì kèo hủy', (tester) async {
    final mine = await tester.runAsync(() => lfg.getMyMatches());
    final requested = mine!.firstWhere((m) => m.cancelRequest != null);
    await pump(tester, LfgMatchDetailScreen(matchId: requested.id));
    expect(find.text(LfgStrings.cancelRequestBy('Thu Trang')), findsOneWidget);

    await tester.tap(find.text(LfgStrings.approve));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.mutualCancelledMessage), findsOneWidget);
    expect(find.text(LfgStrings.statusCancelledMutual), findsOneWidget);
  });
}
