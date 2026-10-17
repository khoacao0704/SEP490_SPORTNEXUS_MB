import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/booking_strings.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/screens/booking/my_bookings_screen.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    final facility = MockFacilityRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    final bookings = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = wallet;
    AppRepositories.facility = AppRepositories.lfgFacility = facility;
    AppRepositories.review = review;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.booking = bookings;
    AppRepositories.split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, wallet: wallet, bookings: bookings);
    AppRepositories.lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MyBookingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('sân đã đặt: hủy trước 24 giờ được hoàn 100%', (tester) async {
    await pump(tester);
    expect(find.text('Sân Cầu Lông Thiên Triều'), findsOneWidget);
    expect(find.text(BookingStrings.lateCancelNote), findsOneWidget); // đặt mẫu còn ~12 giờ
    expect(find.text(BookingStrings.cancel), findsNWidgets(2));

    // Đặt mẫu Thiên Triều (còn 4 ngày) nằm sau Hoa Lư (còn ~12 giờ).
    await tester.tap(find.text(BookingStrings.cancel).last);
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.confirmCancelFree(168000)), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, BookingStrings.cancel));
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.cancelledMessage(168000)), findsOneWidget);
    expect(find.text(BookingStrings.refunded(168000)), findsOneWidget);
    expect(find.text(BookingStrings.cancel), findsOneWidget);
  });

  testWidgets('hủy trong 24 giờ: báo mất 1/4 tiền sân', (tester) async {
    await pump(tester);
    await tester.tap(find.text(BookingStrings.cancel).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('mất 1/4 tiền sân'), findsWidgets);
    expect(find.text(BookingStrings.confirmCancelLate(175000, 0)), findsOneWidget);
  });

  testWidgets('tab Kèo LFG: kèo thật của tôi, mở chi tiết có nút rời / yêu cầu hủy', (tester) async {
    await pump(tester);
    await tester.tap(find.text(BookingStrings.tabLfg));
    await tester.pumpAndSettle();
    expect(find.text('Gò Vấp Arena • Sân 4 • Gò Vấp'), findsOneWidget);

    await tester.tap(find.text('Gò Vấp Arena • Sân 4 • Gò Vấp'));
    await tester.pumpAndSettle();
    expect(find.byType(LfgMatchDetailScreen), findsOneWidget);
    expect(find.text(LfgStrings.leave), findsOneWidget);
  });
}
