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
import 'package:test1/core/constants/lfg_rules.dart';
import 'package:test1/models/facility_search.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/screens/lfg/create_lfg_match_screen.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';
import 'package:test1/screens/lfg/lfg_payment_screen.dart';
import 'package:test1/screens/lfg/lfg_screen.dart';

void main() {
  late MockWalletRepository wallet;
  late MockLfgRepository lfg;

  Future<void> loginAs(String identifier) => MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wallet = MockWalletRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.review = review;
    AppRepositories.lfg = lfg;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.facility = AppRepositories.lfgFacility = MockFacilityRepository(latency: Duration.zero);
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
    expect(find.text('Sân Bóng Hoa Lư • Sân 1 • Quận 1'), findsOneWidget);
    expect(find.text(LfgStrings.joined), findsOneWidget); // kèo Gò Vấp đang tham gia

    // Hàng chip môn chỉ dựng chip đang hiện: cuộn ngang tới Bóng Đá.
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Bóng Đá'),
      120,
      scrollable: find
          .ancestor(of: find.widgetWithText(ChoiceChip, LfgStrings.allSports), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bóng Đá'));
    await tester.pumpAndSettle();
    expect(find.text('Sân Bóng Hoa Lư • Sân 1 • Quận 1'), findsOneWidget);
    expect(find.textContaining('Sân Cầu Lông Thiên Triều'), findsNothing);
    expect(find.text('${LfgFormat.teamVsTeam.label} • 7 vs 7'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '5 vs 5'));
    await tester.pumpAndSettle();
    expect(find.text('Sân Bóng Hoa Lư • Sân 1 • Quận 1'), findsNothing);

    await tester.tap(find.text(LfgStrings.tabMine));
    await tester.pumpAndSettle();
    expect(find.text('Gò Vấp Arena • Sân 4 • Gò Vấp'), findsOneWidget);
  });

  testWidgets('Gợi ý cho bạn: hiện điểm phù hợp + lý do, không có kèo mình đã vào; bộ lọc trình độ', (tester) async {
    await pump(tester, const LfgScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, LfgStrings.recommended));
    await tester.pumpAndSettle();
    expect(find.textContaining('Phù hợp '), findsWidgets);
    expect(find.textContaining('Đúng môn bạn chơi'), findsWidgets);
    expect(find.text(LfgStrings.joined), findsNothing);

    // Bộ lọc: chọn trình độ → quay về bảng tin, chip hiện số bộ lọc.
    await tester.tap(find.widgetWithText(ChoiceChip, LfgStrings.filters));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Khá'));
    await tester.tap(find.text(LfgStrings.applyFilters));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, LfgStrings.filtersCount(1)), findsOneWidget);
    expect(find.textContaining('Phù hợp '), findsNothing);
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

  testWidgets('tạo kèo từ ca AI gợi ý: chọn sẵn sân + ca + hình thức theo số người cần tìm', (tester) async {
    final preset = await tester.runAsync(() async {
      final facility = (await AppRepositories.lfgFacility.searchFacilities(
        const FacilitySearchQuery(city: 'Hồ Chí Minh', sport: Sport.badminton),
      )).map((r) => r.facility).firstWhere((f) => f.name == 'Sân Cầu Lông Thiên Triều');
      final day = DateTime.now().add(const Duration(days: 4));
      final slots = await AppRepositories.lfgFacility.getTimeSlots(facility.id, Sport.badminton, day);
      final slot = slots.firstWhere((s) => s.isAvailable && LfgRules.canCreateFor(s.start, DateTime.now()));
      return LfgCreatePreset(
        sport: Sport.badminton,
        facilityId: facility.id,
        courtSlotId: slot.id,
        start: slot.start,
        slotsNeeded: 1,
      );
    });
    await pump(tester, CreateLfgMatchScreen(preset: preset));
    // Ca đã chọn sẵn → có nút thanh toán; 1 người cần tìm = ghép 2.
    expect(find.text(LfgStrings.continueToPay), findsOneWidget);
    expect(find.text(LfgStrings.depositExplain(LfgFormat.singles.label, 2, false)), findsOneWidget);
  });

  testWidgets('kèo đã chốt nhưng còn trước T−48h: vẫn rời được, không cần gửi yêu cầu hủy', (tester) async {
    final match = await tester.runAsync(() => lfg.getMyMatches());
    final full = match!.firstWhere((m) => m.facilityName == 'Pickleball Thảo Điền' && m.cancelRequest == null);
    await pump(tester, LfgMatchDetailScreen(matchId: full.id));
    expect(find.text(LfgStrings.statusConfirmed), findsOneWidget);
    expect(find.text(LfgStrings.requestCancel), findsNothing);

    await tester.tap(find.text(LfgStrings.leave));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.confirmLeaveTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, LfgStrings.leave));
    await tester.pumpAndSettle();
    expect(find.text(LfgStrings.leftMessage(full.depositPerSlot)), findsOneWidget);
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
