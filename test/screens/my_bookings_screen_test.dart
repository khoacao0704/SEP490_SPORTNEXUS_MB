import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
import 'package:test1/widgets/main_drawer.dart';

import '../helpers/layout_check.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    final facility = MockFacilityRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    final bookings = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
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

  testWidgets('sân đã đặt: còn 4 ngày hủy được hoàn 80%, báo rõ số mất', (tester) async {
    await pump(tester);
    expect(find.text('Sân Cầu Lông Thiên Triều'), findsOneWidget);
    expect(find.text(BookingStrings.lateCancelNote), findsOneWidget); // đặt mẫu còn ~12 giờ
    expect(find.text(BookingStrings.cancel), findsNWidgets(2));

    // Đặt mẫu Thiên Triều (còn 4 ngày) nằm sau Hoa Lư (còn ~12 giờ).
    await tester.tap(find.text(BookingStrings.cancel).last);
    await tester.pumpAndSettle();
    // 168.000 × 80% = 134.400 được hoàn, mất 33.600; có nhắc trả lại voucher.
    expect(
      find.text(BookingStrings.confirmCancel(80, 134400, 33600) + BookingStrings.voucherReturnedNote),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, BookingStrings.cancel));
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.cancelledMessage(134400)), findsOneWidget);
    expect(find.text(BookingStrings.refunded(134400)), findsOneWidget);
    expect(find.text(BookingStrings.cancel), findsOneWidget);
  });

  testWidgets('hủy dưới 48 giờ: báo không được hoàn tiền', (tester) async {
    await pump(tester);
    await tester.tap(find.text(BookingStrings.cancel).first);
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.confirmCancel(0, 0, 700000)), findsOneWidget);
  });

  testWidgets('vé QR: hộp thoại hiện mã QR, không lỗi bố cục (không trắng màn)', (tester) async {
    await pump(tester);
    await tester.tap(find.text(BookingStrings.ticket).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(BookingStrings.ticketTitle), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.text(BookingStrings.close));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
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
  testWidgets('mở menu bên ở Lịch đặt: mục đang chọn vẽ bình thường, không lỗi ListTile', (tester) async {
    await pump(tester);
    final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
  });
  testWidgets('menu bên: nhiều cỡ máy + chữ phóng to không tràn', (tester) async {
    await expectNoOverflow(
      tester,
      'Menu bên',
      () => const Scaffold(drawer: MainDrawer(selectedIndex: 3), body: SizedBox()),
      interact: (tester) async {
        tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
        await settleFrames(tester);
      },
    );
  });
}
