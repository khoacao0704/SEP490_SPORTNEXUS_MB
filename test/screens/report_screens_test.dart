import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/report_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_rating_repository.dart';
import 'package:test1/data/mock/mock_report_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/player_report.dart';
import 'package:test1/screens/booking/my_bookings_screen.dart';
import 'package:test1/screens/report/support_center_screen.dart';
import 'package:test1/screens/review/submit_review_screen.dart';

import '../helpers/layout_check.dart';

/// B3: khiếu nại đơn đặt sân + báo cáo người chơi phía Player (bản giả lập).
void main() {
  late MockReportRepository report;
  late MockReviewRepository review;
  late MockBookingRepository bookings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    final facility = MockFacilityRepository(latency: Duration.zero);
    review = MockReviewRepository(latency: Duration.zero);
    bookings = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    report = MockReportRepository(latency: Duration.zero);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.facility = AppRepositories.lfgFacility = facility;
    AppRepositories.review = review;
    AppRepositories.rating = MockRatingRepository();
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.booking = bookings;
    AppRepositories.split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, wallet: wallet, bookings: bookings);
    AppRepositories.lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    AppRepositories.report = report;
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('từ Đơn của tôi: đơn chọn sẵn, kiểm lý do + mô tả ≥10 ký tự, gửi xong sang Khiếu nại của tôi rồi rút',
      (tester) async {
    await pump(tester, const MyBookingsScreen());
    await tester.tap(find.text(ReportStrings.bookingComplaintShort).first);
    await tester.pumpAndSettle();
    expect(find.byType(SupportCenterScreen), findsOneWidget);
    expect(find.textContaining('Sân Bóng Hoa Lư'), findsWidgets); // đơn đầu tiên đã chọn sẵn

    await tester.tap(find.widgetWithText(ElevatedButton, ReportStrings.submitComplaint));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.pickReason), findsOneWidget);

    await tester.tap(find.text('Lý do khác'));
    await tester.enterText(find.byType(TextField), 'ngắn');
    await tester.tap(find.widgetWithText(ElevatedButton, ReportStrings.submitComplaint));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.descriptionTooShort), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sân bị trùng giờ, phải chờ 30 phút mới được vào');
    await tester.tap(find.widgetWithText(ElevatedButton, ReportStrings.submitComplaint));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.complaintSent), findsOneWidget);
    expect(find.text(ReportStrings.tabMine(1)), findsOneWidget);
    expect(find.text(ReportStatus.pending.label), findsOneWidget);
    expect(find.textContaining('Sân bị trùng giờ'), findsOneWidget);

    await tester.tap(find.text(ReportStrings.withdraw));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.withdrawConfirm), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, ReportStrings.withdraw));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.withdrawn), findsOneWidget);
    expect(find.text(ReportStatus.withdrawn.label), findsOneWidget);
    expect(find.text(ReportStrings.withdraw), findsNothing);
  });

  testWidgets('Trợ giúp & Khiếu nại mở từ Hồ sơ: phải chọn đơn; chưa có khiếu nại thì báo trống', (tester) async {
    await pump(tester, const SupportCenterScreen());
    await tester.tap(find.text('Lý do khác'));
    await tester.enterText(find.byType(TextField), 'Mô tả đủ dài để gửi khiếu nại');
    await tester.tap(find.widgetWithText(ElevatedButton, ReportStrings.submitComplaint));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.pickBooking), findsOneWidget);

    await tester.tap(find.text(ReportStrings.tabMine(0)));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.mineEmpty), findsOneWidget);
  });

  testWidgets('màn chấm người chơi: mỗi người có nút Báo cáo → form báo cáo người chơi, gửi xong quay lại',
      (tester) async {
    final session = (await review.getPendingReviews()).firstWhere((s) => s.players.isNotEmpty);
    final player = session.players.first;
    await pump(tester, SubmitReviewScreen(session: session));
    expect(find.text(ReportStrings.reportPlayer), findsNWidgets(session.players.length));

    await tester.tap(find.text(ReportStrings.reportPlayer).first);
    await tester.pumpAndSettle();
    expect(find.byType(ReportPlayerScreen), findsOneWidget);
    expect(find.text(player.name), findsOneWidget);

    await tester.tap(find.text('Khai gian trình độ'));
    await tester.pumpAndSettle();
    expect(find.text(ReportStrings.skillMisrepresentationHint), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Khai mới chơi nhưng đánh như vận động viên');
    await tester.tap(find.text(ReportStrings.submitReport));
    await tester.pumpAndSettle();
    expect(find.byType(SubmitReviewScreen), findsOneWidget);
    expect(find.text(ReportStrings.reportSent), findsOneWidget);
    final sent = (await tester.runAsync(report.getMine))!.single;
    expect(sent.targetType, ReportTarget.user.apiValue);
    expect(sent.reason, 'SKILL_MISREPRESENTATION');
  });

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('bố cục: form khiếu nại, Khiếu nại của tôi, báo cáo người chơi, thẻ đơn, màn chấm người chơi', (tester) async {
    final session = await tester.runAsync(() async {
      final mine = await bookings.getMyBookings();
      await report.create(NewPlayerReport(
        target: ReportTarget.booking,
        reason: 'FACILITY_POOR_QUALITY',
        description: 'Mô tả rất dài để kiểm tra xuống dòng trên máy nhỏ và khi người dùng phóng to chữ trong cài đặt.',
        bookingId: mine.first.id,
      ));
      return (await review.getPendingReviews()).firstWhere((s) => s.players.isNotEmpty);
    });
    final bookingId = (await tester.runAsync(bookings.getMyBookings))!.last.id;
    await expectNoOverflow(tester, 'Gửi khiếu nại', () => SupportCenterScreen(initialBookingId: bookingId),
        interact: scrollToEnd);
    await expectNoOverflow(tester, 'Khiếu nại của tôi', () => const SupportCenterScreen(openMine: true),
        interact: scrollToEnd);
    await expectNoOverflow(tester, 'Báo cáo người chơi',
        () => const ReportPlayerScreen(userId: 'u-x', name: 'Nguyễn Văn Tên Rất Dài Để Kiểm Tra'),
        interact: scrollToEnd);
    await expectNoOverflow(tester, 'Đơn của tôi (nút Khiếu nại)', () => const MyBookingsScreen(), interact: scrollToEnd);
    await expectNoOverflow(tester, 'Chấm người chơi (nút Báo cáo)', () => SubmitReviewScreen(session: session!),
        interact: scrollToEnd);
  });
}
