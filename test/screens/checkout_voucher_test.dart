import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/voucher_rules.dart';
import 'package:test1/core/strings/booking_strings.dart';
import 'package:test1/core/strings/split_payment_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_voucher_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/models/voucher.dart';
import 'package:test1/screens/booking/booking_checkout_screen.dart';

import '../helpers/layout_check.dart';

void main() {
  late MockFacilityRepository facility;
  late MockBookingRepository booking;
  late MockWalletRepository wallet;
  final thienTrieu = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-thientrieu');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wallet = MockWalletRepository(latency: Duration.zero, initialBalance: 5000000);
    facility = MockFacilityRepository(latency: Duration.zero);
    booking = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    AppRepositories.wallet = AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.facility = facility;
    AppRepositories.booking = booking;
    AppRepositories.split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, wallet: wallet, bookings: booking);
    AppRepositories.voucher = MockVoucherRepository();
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  /// Khung trống trên [courts] cùng một giờ (ngày kia).
  Future<List<TimeSlot>> freeSlots(WidgetTester tester, List<String> courts) async {
    final now = DateTime.now();
    final day = (await tester.runAsync(
      () => facility.getTimeSlots(thienTrieu.id, Sport.badminton, DateTime(now.year, now.month, now.day + 2)),
    ))!;
    for (final s in day.where((s) => s.courtName == courts.first && !s.isFull)) {
      final same = [
        for (final c in courts) day.where((d) => d.courtName == c && d.start == s.start && !d.isFull).firstOrNull,
      ];
      if (same.every((x) => x != null)) return same.cast<TimeSlot>();
    }
    throw StateError('không có giờ trống');
  }

  Widget checkout(SlotHold hold) => BookingCheckoutScreen(
        sport: 'Cầu Lông',
        courtName: thienTrieu.name,
        location: 'Q7',
        dateTime: 'Sân 1',
        totalAmount: hold.totalPrice,
        hold: hold,
      );

  test('Công thức giảm: Round(tổng × %), không quá tổng; 1 đơn = cùng sân + ca liền nhau', () {
    expect(VoucherRules.discount(168000, 10), 16800);
    expect(VoucherRules.discount(99999, 10), 10000);
    expect(VoucherRules.discount(50000, 100), 50000);
    expect(VoucherRules.discount(50000, 0), 0);
  });

  testWidgets('Đơn 1 sân: chọn mã 10% → Tổng tiền − Giảm giá = Thực thu; trả đúng số thực thu', (tester) async {
    final slot = (await freeSlots(tester, ['Sân 1'])).single;
    final hold = (await tester.runAsync(() => facility.holdSlots([slot])))!;
    final before = (await tester.runAsync(wallet.getBalance))!;
    await pump(tester, checkout(hold));

    await tester.tap(find.text(BookingStrings.voucherPick));
    await tester.pumpAndSettle();
    expect(find.text(BookingStrings.voucherSheetTitle), findsOneWidget);
    await tester.tap(find.text(BookingStrings.voucherChosen(10)).first);
    await tester.pumpAndSettle();

    final off = VoucherRules.discount(hold.totalPrice, 10);
    final pay = hold.totalPrice - off;
    expect(find.text(BookingStrings.formulaTotal), findsOneWidget);
    expect(find.text(BookingStrings.formulaDiscount(10)), findsOneWidget);
    expect(find.text('-${Formatters.vnd(off)}'), findsOneWidget);
    expect(find.text(BookingStrings.formulaPay), findsOneWidget);

    await tester.tap(find.textContaining('Xác nhận thanh toán'));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(wallet.getBalance))!, before - pay);
    final mine = (await tester.runAsync(booking.getMyBookings))!.where((b) => b.start == slot.start).toList();
    expect(mine.single.amountPaid, pay);
  });

  testWidgets('Đặt 2 sân con: nút mờ, bấm vào báo chỉ dùng khi 1 sân, ca liền nhau', (tester) async {
    final slots = await freeSlots(tester, ['Sân 1', 'Sân 2']);
    final hold = (await tester.runAsync(() => facility.holdSlots(slots)))!;
    await pump(tester, checkout(hold));

    await tester.tap(find.text(BookingStrings.voucherPick));
    await tester.pump();
    expect(find.text(BookingStrings.voucherSingleOnly), findsOneWidget);
    expect(find.text(BookingStrings.voucherSheetTitle), findsNothing);
  });

  testWidgets('Đang có mã mà chuyển sang chia tiền → tự bỏ mã, báo lý do', (tester) async {
    final slot = (await freeSlots(tester, ['Sân 1'])).single;
    final hold = (await tester.runAsync(() => facility.holdSlots([slot])))!;
    await pump(tester, checkout(hold));
    await tester.tap(find.text(BookingStrings.voucherPick));
    await tester.pumpAndSettle();
    await tester.tap(find.text(BookingStrings.voucherChosen(10)).first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(SplitPaymentStrings.option));
    await tester.tap(find.text(SplitPaymentStrings.option));
    await tester.pump();
    expect(find.text(BookingStrings.voucherRemovedForSplit), findsOneWidget);
    expect(find.text(BookingStrings.formulaPay), findsNothing);
  });

  testWidgets('Không có mã còn dùng → "Chưa có mã giảm giá"', (tester) async {
    AppRepositories.voucher = MockVoucherRepository(vouchers: [
      Voucher(
        id: 'old',
        discountPercent: 10,
        status: VoucherStatus.used,
        expiresAt: DateTime.now().add(const Duration(days: 3)),
        createdAt: DateTime.now(),
      ),
    ]);
    final slot = (await freeSlots(tester, ['Sân 1'])).single;
    final hold = (await tester.runAsync(() => facility.holdSlots([slot])))!;
    await pump(tester, checkout(hold));
    expect(find.text(BookingStrings.voucherNone), findsOneWidget);
  });

  testWidgets('Bố cục Checkout có voucher: nhiều cỡ máy + chữ phóng to không tràn', (tester) async {
    final slot = (await freeSlots(tester, ['Sân 1'])).single;
    final hold = (await tester.runAsync(() => facility.holdSlots([slot])))!;
    final problems = await collectLayoutProblems(
      tester,
      'Checkout chọn voucher',
      () => checkout(hold),
      interact: (tester) async {
        await tester.ensureVisible(find.text(BookingStrings.voucherPick));
        await settleFrames(tester);
        await tester.tap(find.text(BookingStrings.voucherPick));
        await settleFrames(tester);
        await tester.tap(find.text(BookingStrings.voucherChosen(10)).first);
        await settleFrames(tester);
      },
    );
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
