import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/split_payment_strings.dart';
import 'package:test1/core/strings/booking_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/screens/booking/booking_checkout_screen.dart';
import 'package:test1/screens/booking/split_payment_screen.dart';
import 'package:test1/screens/booking/split_payments_screen.dart';

/// Như BE hiện tại: chỉ trả 100%, chưa chia tiền.
class _NoDepositBookings extends MockBookingRepository {
  _NoDepositBookings({required super.facility, super.latency});

  @override
  bool get supportsDeposit => false;

  @override
  bool get supportsSplitPayment => false;
}

void main() {
  late MockFacilityRepository facility;

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    facility = MockFacilityRepository(latency: Duration.zero);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.facility = AppRepositories.lfgFacility = facility;
    AppRepositories.booking = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    await loginAs('player@sportnexus.vn');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    // Màn Thanh toán cũ có hàng chưa co giãn, cần màn hình rộng ở font test.
    tester.view.physicalSize = const Size(1800, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Future<SlotHold> holdSlot(WidgetTester tester) async {
    final hold = await tester.runAsync(() async {
      final now = DateTime.now();
      final slots = await facility.getTimeSlots('f-hcm-thientrieu', Sport.badminton, now.add(const Duration(days: 1)));
      return facility.holdSlots([slots.firstWhere((s) => !s.isFull)]);
    });
    return hold!;
  }

  testWidgets('thanh toán đặt sân: chọn chia 2 phần, trả phần của mình rồi sang màn chia tiền', (tester) async {
    final hold = await holdSlot(tester);
    await pump(
      tester,
      BookingCheckoutScreen(
        sport: 'Cầu Lông',
        courtName: 'Sân Cầu Lông Thiên Triều',
        location: 'Quận 7, Hồ Chí Minh',
        dateTime: 'Ngày mai • 08:00 - 09:00',
        totalAmount: hold.totalPrice,
        initialSecondsRemaining: 600,
        hold: hold,
      ),
    );

    await tester.tap(find.text(SplitPaymentStrings.option));
    await tester.pumpAndSettle();
    expect(find.text(SplitPaymentStrings.partsTitle), findsOneWidget);
    await tester.tap(find.text(SplitPaymentStrings.partsLabel(2)));
    await tester.pumpAndSettle();
    expect(find.text(SplitPaymentStrings.payNow(2)), findsOneWidget);

    await tester.tap(find.textContaining('Xác nhận thanh toán'));
    await tester.pumpAndSettle();
    expect(find.byType(SplitPaymentScreen), findsOneWidget);
    expect(find.text(SplitPaymentStrings.progress(1, 2)), findsOneWidget);
    expect(find.text(SplitPaymentStrings.shareLinkTitle), findsOneWidget);

    await tester.tap(find.text(SplitPaymentStrings.simulateFriend));
    await tester.pumpAndSettle();
    expect(find.text(SplitPaymentStrings.statusCompleted), findsOneWidget);
    expect(find.text(SplitPaymentStrings.completedNote), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // dừng đồng hồ đếm ngược
  });

  testWidgets('BE chưa có cọc 1/4 / chia tiền: chọn thì báo đang phát triển, giữ thanh toán 100%', (tester) async {
    final hold = await holdSlot(tester);
    final facilityRepo = facility;
    AppRepositories.booking = _NoDepositBookings(facility: facilityRepo, latency: Duration.zero);
    await pump(
      tester,
      BookingCheckoutScreen(
        sport: 'Cầu Lông',
        courtName: 'Sân Cầu Lông Thiên Triều',
        location: 'Quận 7, Hồ Chí Minh',
        dateTime: 'Ngày mai • 08:00 - 09:00',
        totalAmount: hold.totalPrice,
        initialSecondsRemaining: 600,
        hold: hold,
      ),
    );

    await tester.tap(find.text('Ký quỹ (1/4 tiền sân)'));
    await tester.pump();
    expect(find.text(BookingStrings.depositUnavailable), findsOneWidget);

    await tester.tap(find.text(SplitPaymentStrings.option));
    await tester.pump();
    expect(find.text(BookingStrings.splitUnavailable), findsOneWidget);
    expect(find.text(SplitPaymentStrings.partsTitle), findsNothing);
    expect(find.text('Thanh toán 100% tiền sân'), findsWidgets);

    await tester.pumpWidget(const SizedBox()); // dừng đồng hồ đếm ngược
  });

  testWidgets('người nhận link: nhập mã, trả phần của mình', (tester) async {
    final hold = await holdSlot(tester);
    final split = await tester.runAsync(() => AppRepositories.split.create(
          hold: hold,
          parts: 4,
          facilityName: 'Sân Cầu Lông Thiên Triều',
          sportLabel: 'Cầu Lông',
          location: 'Quận 7, Hồ Chí Minh',
          schedule: 'Ngày mai • 08:00 - 09:00',
        ));
    await tester.runAsync(() => loginAs('restricted@sportnexus.vn'));

    await pump(tester, const SplitPaymentsScreen());
    expect(find.text(SplitPaymentStrings.empty), findsOneWidget);
    await tester.enterText(find.byType(TextField), split!.code.toLowerCase());
    await tester.tap(find.text(SplitPaymentStrings.open));
    await tester.pumpAndSettle();

    expect(find.byType(SplitPaymentScreen), findsOneWidget);
    expect(find.text(SplitPaymentStrings.shareLinkTitle), findsNothing);
    expect(find.text(SplitPaymentStrings.yourShare(split.shares[1].amount)), findsOneWidget);

    await tester.tap(find.text(SplitPaymentStrings.payShare));
    await tester.pumpAndSettle();
    expect(find.text(SplitPaymentStrings.progress(2, 4)), findsOneWidget);
    expect(find.text(SplitPaymentStrings.paid), findsOneWidget);
    expect(find.text(SplitPaymentStrings.payShare), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
