import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/booking_rules.dart';
import 'package:test1/core/strings/booking_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/booking_repository.dart';
import 'package:test1/models/booking.dart';
import 'package:test1/models/facility.dart';
import 'package:test1/models/geo_point.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';

void main() {
  late DateTime clock;
  late MockWalletRepository wallet;
  late MockFacilityRepository facility;
  late MockBookingRepository repo;

  const testFacility = Facility(
    id: 'f-test',
    name: 'Sân Test',
    address: '1 Test',
    city: 'Hồ Chí Minh',
    district: 'Quận 1',
    location: GeoPoint(10.77, 106.70),
    offerings: [SportOffering(sport: Sport.badminton, courtCount: 1, priceFrom: 120000)],
    rating: 4.5,
    reviewCount: 1,
    imageUrls: [],
    openTime: '06:00',
    closeTime: '22:00',
    phone: '0900',
  );

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  Matcher error(String message) =>
      throwsA(isA<BookingException>().having((e) => e.message, 'message', message));

  /// Giữ [count] khung trống đầu tiên (chưa bắt đầu) sau [daysAhead] ngày.
  Future<SlotHold> hold({int daysAhead = 3, int count = 1}) async {
    final slots = await facility.getTimeSlots('f-test', Sport.badminton, clock.add(Duration(days: daysAhead)));
    return facility.holdSlots(slots.where((s) => !s.isFull && s.start.isAfter(clock)).take(count).toList());
  }

  Future<bool> isTaken(Booking b) async {
    final slots = await facility.getTimeSlots('f-test', Sport.badminton, b.start);
    return slots.firstWhere((s) => s.start == b.start).isFull;
  }

  Future<List<Booking>> bookMany(BookingPaymentType type, {int daysAhead = 3, int count = 1}) async =>
      repo.createBooking(
        hold: await hold(daysAhead: daysAhead, count: count),
        paymentType: type,
        facilityName: 'Sân Test',
        sportLabel: 'Cầu Lông',
        location: 'Quận 1, Hồ Chí Minh',
        schedule: 'Lịch test',
      );

  Future<Booking> book(BookingPaymentType type, {int daysAhead = 3}) async =>
      (await bookMany(type, daysAhead: daysAhead)).single;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 14, 10, 0);
    wallet = MockWalletRepository(latency: Duration.zero, now: () => clock);
    facility = MockFacilityRepository(latency: Duration.zero, now: () => clock, facilities: const [testFacility]);
    repo = MockBookingRepository(facility: facility, latency: Duration.zero, now: () => clock, wallet: wallet);
    await loginAs('player@sportnexus.vn');
  });

  test('có sẵn đặt mẫu: sắp diễn ra trước, đã qua sau', () async {
    final list = await repo.getMyBookings();
    expect(list.map((b) => b.id), ['DEMO2', 'DEMO1', 'DEMO3']);
    expect(list.first.isFreeCancel(clock), isFalse); // còn ~12 giờ
    expect(list[1].isFreeCancel(clock), isTrue); // còn 4 ngày
    expect(list.last.status(clock), BookingStatus.completed);
  });

  test('thanh toán 100% hoặc cọc 1/4: trừ ví, giữ hẳn khung giờ', () async {
    final before = await wallet.getBalance();
    final full = await book(BookingPaymentType.full);
    expect(full.amountPaid, full.totalPrice);
    expect(await wallet.getBalance(), before - full.totalPrice);

    // Quá 10 phút giữ chỗ vẫn còn bị chiếm (đã đặt).
    clock = clock.add(const Duration(minutes: 20));
    expect(await isTaken(full), isTrue);

    final deposit = await book(BookingPaymentType.deposit, daysAhead: 4);
    expect(deposit.amountPaid, BookingRules.depositAmount(deposit.totalPrice));
    expect(deposit.remainingAtCourt, deposit.totalPrice - deposit.amountPaid);
  });

  test('đặt nhiều khung giờ: mỗi khung là một lượt đặt riêng, hủy riêng từng khung', () async {
    final bookings = await bookMany(BookingPaymentType.deposit, count: 2);
    expect(bookings, hasLength(2));
    expect(bookings.map((b) => b.ticketCode).toSet(), hasLength(2));
    expect(bookings.every((b) => b.amountPaid == BookingRules.depositAmount(b.totalPrice)), isTrue);
    expect(bookings.first.end.isAfter(bookings.last.start), isFalse);

    await repo.cancelBooking(bookings.first.id);
    expect(await isTaken(bookings.first), isFalse);
    expect(await isTaken(bookings.last), isTrue);
    final mine = await repo.getMyBookings();
    expect(mine.firstWhere((b) => b.id == bookings.last.id).status(clock), BookingStatus.upcoming);
  });

  test('hủy trước 24 giờ: hoàn 100%, nhả khung giờ', () async {
    final booking = await book(BookingPaymentType.full, daysAhead: 2);
    expect(booking.isFreeCancel(clock), isTrue);
    final before = await wallet.getBalance();

    final cancelled = await repo.cancelBooking(booking.id);
    expect(cancelled.status(clock), BookingStatus.cancelled);
    expect(cancelled.refunded, booking.totalPrice);
    expect(await wallet.getBalance(), before + booking.totalPrice);
    expect(await isTaken(booking), isFalse);
    expect(() => repo.cancelBooking(booking.id), error(BookingStrings.cannotCancel));
  });

  test('hủy trong vòng 24 giờ: mất 1/4 tiền sân; cọc 1/4 thì không được hoàn', () async {
    final full = await book(BookingPaymentType.full, daysAhead: 0);
    expect(full.isFreeCancel(clock), isFalse);
    final before = await wallet.getBalance();
    final cancelled = await repo.cancelBooking(full.id);
    final expected = full.totalPrice - BookingRules.quarterOf(full.totalPrice);
    expect(cancelled.refunded, expected);
    expect(await wallet.getBalance(), before + expected);

    final demo = (await repo.getMyBookings()).firstWhere((b) => b.id == 'DEMO2'); // cọc 1/4, còn ~12 giờ
    expect(demo.refundIfCancelled(clock), 0);
    expect((await repo.cancelBooking('DEMO2')).refunded, 0);
  });

  test('chỉ người đặt được hủy; chia tiền hủy trong 24h thì phần mất trừ vào người đặt trước', () async {
    final split = MockSplitPaymentRepository(
      facility: facility,
      latency: Duration.zero,
      now: () => clock,
      wallet: wallet,
      bookings: repo,
    );
    final s = await split.create(
      hold: await hold(daysAhead: 0),
      parts: 2,
      facilityName: 'Sân Test',
      sportLabel: 'Cầu Lông',
      location: 'Quận 1',
      schedule: 'Lịch test',
    );
    await loginAs('restricted@sportnexus.vn');
    await split.payShare(s.code);
    expect(() => repo.cancelBooking(s.bookingId), error(BookingStrings.onlyBookerCancels));

    await loginAs('player@sportnexus.vn');
    final before = await wallet.getBalance();
    final cancelled = await repo.cancelBooking(s.bookingId);
    // Mất 1/4 tiền sân, trừ hết vào phần người đặt (1/2); người góp được hoàn đủ.
    expect(cancelled.refunded, s.totalAmount - BookingRules.quarterOf(s.totalAmount));
    expect(await wallet.getBalance(), before + cancelled.refunded);
  });

  test('chia tiền nhiều khung giờ: mỗi khung một lượt đặt, tiền mỗi người chia theo khung', () async {
    final split = MockSplitPaymentRepository(
      facility: facility,
      latency: Duration.zero,
      now: () => clock,
      wallet: wallet,
      bookings: repo,
    );
    final s = await split.create(
      hold: await hold(count: 2),
      parts: 2,
      facilityName: 'Sân Test',
      sportLabel: 'Cầu Lông',
      location: 'Quận 1',
      schedule: 'Lịch test',
    );
    await split.simulateFriendPaid(s.id);
    final created = (await repo.getMyBookings()).where((b) => b.id.startsWith(s.bookingId)).toList();
    expect(created, hasLength(2));
    expect(created.fold(0, (sum, b) => sum + b.amountPaid), s.totalAmount);
    expect(created.every((b) => b.amountPaid == b.totalPrice), isTrue);
  });
}
