import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/split_payment_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/booking_repository.dart';
import 'package:test1/models/booking.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/screens/booking/booking_checkout_screen.dart';
import 'package:test1/screens/booking/my_bookings_screen.dart';
import 'package:test1/screens/booking/split_booking_screen.dart';
import 'package:test1/screens/booking/split_payments_screen.dart';

import '../helpers/layout_check.dart';

const _me = 'u-player-001';

/// Như BE thật: chia tiền bằng cách mời bạn; giữ một đơn trong bộ nhớ.
class _InviteBookings extends MockBookingRepository {
  _InviteBookings({required super.facility}) : super(latency: Duration.zero);

  Booking? current;
  final List<String> calls = [];
  List<String> createdWith = const [];

  @override
  bool get supportsSplitInvite => true;

  @override
  bool get supportsSplitPayment => false;

  @override
  Future<PlayerLookup> findPlayerByPhone(String phone) async {
    if (phone == '0901111111') return const PlayerLookup(id: 'u-a', fullName: 'Nguyễn An', phoneMasked: '******1111');
    throw const BookingException(SplitPaymentStrings.playerNotFound);
  }

  @override
  Future<List<Booking>> createSplitBooking({
    required SlotHold hold,
    required List<String> inviteeIds,
    required String facilityName,
    required String sportLabel,
    required String location,
  }) async {
    createdWith = inviteeIds;
    current = split(hostPaid: true, friendPaid: false, hostIsMe: true);
    return [current!];
  }

  @override
  Future<Booking> getBooking(String bookingId) async => current!;

  /// Lịch đặt của tôi (null = như bản giả lập).
  List<Booking>? mine;

  @override
  Future<List<Booking>> getMyBookings() async => mine ?? super.getMyBookings();

  @override
  Future<Booking> joinSplit(String bookingId) async {
    calls.add('join');
    return current = split(hostPaid: true, friendPaid: true, hostIsMe: false, done: true);
  }

  /// Có giá trị thì trả bù báo lỗi này (như BE: ví không đủ…).
  String? payError;

  @override
  Future<Booking> payRemaining(String bookingId) async {
    if (payError != null) throw BookingException(payError!);
    calls.add('payRemaining');
    return current = split(hostPaid: true, friendPaid: true, hostIsMe: true, done: true);
  }

  static Booking split({required bool hostPaid, required bool friendPaid, required bool hostIsMe, bool done = false}) {
    final start = DateTime.now().add(const Duration(days: 1));
    final host = hostIsMe ? _me : 'u-host';
    final friend = hostIsMe ? 'u-a' : _me;
    return Booking(
      id: 'b1',
      bookerId: host,
      facilityName: 'Hà Nội Badminton Center',
      location: '36 Trần Duy Hưng',
      sportLabel: 'Cầu Lông',
      courtName: 'Sân 1',
      schedule: 'Ngày mai • 06:00 - 07:00',
      start: start,
      end: start.add(const Duration(hours: 1)),
      totalPrice: 100000,
      paymentType: BookingPaymentType.split,
      payments: const [],
      createdAt: DateTime.now(),
      awaitingPayment: !done,
      myShare: 50000,
      participants: [
        BookingParticipant(userId: host, name: hostIsMe ? 'Khoa Cao' : 'Chủ kèo', amount: 50000, isPaid: hostPaid, isHost: true),
        BookingParticipant(userId: friend, name: hostIsMe ? 'Nguyễn An' : 'Khoa Cao', amount: 50000, isPaid: friendPaid),
      ],
    );
  }
}

extension on Booking {
  /// Như một dòng của my-bookings: không có danh sách người góp.
  Booking withoutParticipants() => Booking(
        id: id,
        bookerId: bookerId,
        facilityName: facilityName,
        location: location,
        sportLabel: sportLabel,
        courtName: courtName,
        schedule: schedule,
        start: start,
        end: end,
        totalPrice: totalPrice,
        paymentType: paymentType,
        payments: payments,
        createdAt: createdAt,
        awaitingPayment: awaitingPayment,
        myShare: myShare,
      );
}

void main() {
  late _InviteBookings bookings;
  late MockFacilityRepository facility;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    facility = MockFacilityRepository(latency: Duration.zero);
    bookings = _InviteBookings(facility: facility);
    AppRepositories.wallet = AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.facility = facility;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.booking = bookings;
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('"Chia Tiền Sân" với BE thật: liệt kê đơn chia tiền (không có ô nhập mã), bấm mở màn góp tiền', (tester) async {
    bookings.current = _InviteBookings.split(hostPaid: true, friendPaid: false, hostIsMe: false);
    final start = DateTime.now().add(const Duration(days: 2));
    bookings.mine = [
      bookings.current!,
      Booking(
        id: 'b-full',
        bookerId: _me,
        facilityName: 'Sân không chia tiền',
        location: '',
        sportLabel: '',
        schedule: '',
        start: start,
        end: start.add(const Duration(hours: 1)),
        totalPrice: 100000,
        paymentType: BookingPaymentType.full,
        payments: const [],
        createdAt: DateTime.now(),
      ),
    ];
    await pump(tester, const SplitPaymentsScreen());

    expect(find.text(SplitPaymentStrings.enterCode), findsNothing);
    expect(find.text('Hà Nội Badminton Center'), findsOneWidget);
    expect(find.text(SplitPaymentStrings.awaiting), findsOneWidget);
    expect(find.text('Sân không chia tiền'), findsNothing);

    await tester.tap(find.text('Hà Nội Badminton Center'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SplitBookingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // dừng đồng hồ
  });

  testWidgets('người được mời: thấy ai đã góp, bấm góp phần của mình thì đơn đủ tiền', (tester) async {
    bookings.current = _InviteBookings.split(hostPaid: true, friendPaid: false, hostIsMe: false);
    await pump(tester, const SplitBookingScreen(bookingId: 'b1'));

    expect(find.text(SplitPaymentStrings.contributed), findsOneWidget);
    expect(find.text(SplitPaymentStrings.notContributed), findsOneWidget);
    expect(find.textContaining('Hạn góp còn'), findsOneWidget);
    expect(find.text(SplitPaymentStrings.payRemaining(50000)), findsNothing); // không phải người đặt

    await tester.tap(find.text(SplitPaymentStrings.payMyShare(50000)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(bookings.calls, ['join']);
    expect(find.text(SplitPaymentStrings.fullyPaidNote), findsOneWidget);
    expect(find.text(SplitPaymentStrings.payMyShare(50000)), findsNothing);
    await tester.pumpWidget(const SizedBox()); // dừng đồng hồ
  });

  testWidgets('người đặt: khoản còn thiếu + nút "Thanh toán khoản còn thiếu" nổi bật, hỏi xác nhận rồi trả bù',
      (tester) async {
    bookings.current = _InviteBookings.split(hostPaid: true, friendPaid: false, hostIsMe: true);
    await pump(tester, const SplitBookingScreen(bookingId: 'b1'));

    expect(find.text(SplitPaymentStrings.inviteMore), findsOneWidget);
    expect(find.textContaining('GÓP'), findsNothing); // người đặt đã trả phần của mình
    expect(find.text(SplitPaymentStrings.remainingBanner(50000, 1)), findsOneWidget);
    final button = find.widgetWithText(ElevatedButton, SplitPaymentStrings.payRemaining(50000));
    expect(button, findsOneWidget);
    // Nằm ngay dưới đồng hồ hạn góp, trên danh sách người góp.
    expect(tester.getTopLeft(button).dy, lessThan(tester.getTopLeft(find.text('Nguyễn An')).dy));

    // Để sau: không gọi BE.
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(SplitPaymentStrings.payRemainingConfirm(1)), findsOneWidget);
    await tester.tap(find.text(SplitPaymentStrings.cancel));
    await tester.pump(const Duration(milliseconds: 300));
    expect(bookings.calls, isEmpty);

    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(SplitPaymentStrings.confirm));
    await tester.pump(const Duration(milliseconds: 300));

    expect(bookings.calls, ['payRemaining']);
    expect(find.text(SplitPaymentStrings.payRemainingDone), findsOneWidget);
    expect(find.text(SplitPaymentStrings.fullyPaidNote), findsOneWidget);
    expect(button, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('trả bù lỗi (ví không đủ): báo câu của BE, đơn vẫn chờ góp', (tester) async {
    bookings.current = _InviteBookings.split(hostPaid: true, friendPaid: false, hostIsMe: true);
    bookings.payError = 'Số dư ví không đủ.';
    await pump(tester, const SplitBookingScreen(bookingId: 'b1'));

    await tester.tap(find.text(SplitPaymentStrings.payRemaining(50000)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(SplitPaymentStrings.confirm));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Số dư ví không đủ.'), findsOneWidget);
    expect(find.text(SplitPaymentStrings.payRemaining(50000)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Lịch Đặt & QR: người đặt có nút "Trả bù" ngay trên thẻ đơn chờ góp; người được mời thì không',
      (tester) async {
    AppRepositories.review = MockReviewRepository(latency: Duration.zero);
    AppRepositories.split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, bookings: bookings);
    AppRepositories.lfg = MockLfgRepository(latency: Duration.zero);
    bookings.current = _InviteBookings.split(hostPaid: true, friendPaid: false, hostIsMe: true);
    // Danh sách my-bookings của BE không có người góp: phải tải chi tiết mới biết khoản còn thiếu.
    bookings.mine = [bookings.current!.withoutParticipants()];
    await pump(tester, const MyBookingsScreen());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(SplitPaymentStrings.payRemainingShort));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(Formatters.vnd(50000)), findsOneWidget);
    await tester.tap(find.text(SplitPaymentStrings.confirm));
    await tester.pump(const Duration(milliseconds: 300));
    expect(bookings.calls, ['payRemaining']);
    expect(find.text(SplitPaymentStrings.payRemainingDone), findsOneWidget);

    bookings.mine = [_InviteBookings.split(hostPaid: true, friendPaid: false, hostIsMe: false).withoutParticipants()];
    await tester.pumpWidget(const SizedBox());
    await pump(tester, const MyBookingsScreen());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(SplitPaymentStrings.openSplit), findsOneWidget);
    expect(find.text(SplitPaymentStrings.payRemainingShort), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('thanh toán: mời bạn bằng SĐT, hiện chia tiền, xác nhận thì tạo đơn chia tiền và mở màn chia tiền',
      (tester) async {
    final hold = await tester.runAsync(() async {
      final now = DateTime.now();
      final slots = await facility.getTimeSlots('f-hcm-thientrieu', Sport.badminton, now.add(const Duration(days: 1)));
      return facility.holdSlots([slots.firstWhere((s) => !s.isFull)]);
    });
    await pump(
      tester,
      BookingCheckoutScreen(
        sport: 'Cầu Lông',
        courtName: 'Sân Cầu Lông Thiên Triều',
        location: 'Quận 7, Hồ Chí Minh',
        dateTime: 'Ngày mai',
        totalAmount: hold!.totalPrice,
        initialSecondsRemaining: 600,
        hold: hold,
      ),
    );

    await tester.tap(find.text(SplitPaymentStrings.option));
    await tester.pump();
    expect(find.text(SplitPaymentStrings.inviteHint), findsOneWidget);
    expect(find.text(SplitPaymentStrings.inviteByLinkSoon), findsOneWidget);

    // Chưa mời ai thì không cho thanh toán.
    final confirm = find.textContaining('Xác nhận thanh toán');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    expect(find.text(SplitPaymentStrings.inviteRequired), findsOneWidget);

    final phoneField = find.widgetWithText(TextField, SplitPaymentStrings.invitePhoneHint);
    await tester.ensureVisible(phoneField);
    await tester.enterText(phoneField, '0909999999');
    await tester.tap(find.text(SplitPaymentStrings.inviteAdd));
    await tester.pump();
    expect(find.text(SplitPaymentStrings.playerNotFound), findsOneWidget);

    await tester.enterText(phoneField, '0901111111');
    await tester.tap(find.text(SplitPaymentStrings.inviteAdd));
    await tester.pump();
    expect(find.text('Nguyễn An'), findsOneWidget);
    final price = hold.totalPrice;
    expect(find.text(SplitPaymentStrings.inviteExplain(2, price ~/ 2, price - price ~/ 2)), findsOneWidget);

    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(bookings.createdWith, ['u-a']);
    expect(find.byType(SplitBookingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bố cục: nút trả bù + popup không tràn ở mọi cỡ máy, chữ phóng to', (tester) async {
    AppRepositories.review = MockReviewRepository(latency: Duration.zero);
    AppRepositories.split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, bookings: bookings);
    AppRepositories.lfg = MockLfgRepository(latency: Duration.zero);
    Booking pending() => _InviteBookings.split(hostPaid: true, friendPaid: false, hostIsMe: true);
    final problems = <String>[
      ...await collectLayoutProblems(tester, 'Chia tiền', () {
        bookings.current = pending();
        return const SplitBookingScreen(bookingId: 'b1');
      }, interact: (t) async {
        await t.tap(find.text(SplitPaymentStrings.payRemaining(50000)));
        await settleFrames(t);
      }),
      ...await collectLayoutProblems(tester, 'Lịch đặt', () {
        bookings.current = pending();
        bookings.mine = [pending().withoutParticipants()];
        return const MyBookingsScreen();
      }),
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
