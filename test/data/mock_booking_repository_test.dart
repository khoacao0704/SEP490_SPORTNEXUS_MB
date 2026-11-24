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
    expect(list.first.cancelRefundPercent(clock), 0); // còn ~12 giờ
    expect(list[1].cancelRefundPercent(clock), 80); // còn 4 ngày
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
  });

  test('đặt nhiều khung giờ: mỗi khung là một lượt đặt riêng, hủy riêng từng khung', () async {
    final bookings = await bookMany(BookingPaymentType.full, count: 2);
    expect(bookings, hasLength(2));
    expect(bookings.map((b) => b.ticketCode).toSet(), hasLength(2));
    expect(bookings.every((b) => b.amountPaid == b.totalPrice), isTrue);
    expect(bookings.first.end.isAfter(bookings.last.start), isFalse);

    await repo.cancelBooking(bookings.first.id);
    expect(await isTaken(bookings.first), isFalse);
    expect(await isTaken(bookings.last), isTrue);
    final mine = await repo.getMyBookings();
    expect(mine.firstWhere((b) => b.id == bookings.last.id).status(clock), BookingStatus.upcoming);
  });

  test('hủy từ 7 ngày: hoàn 100%, nhả khung giờ', () async {
    final booking = await book(BookingPaymentType.full, daysAhead: 8);
    expect(booking.cancelRefundPercent(clock), 100);
    final before = await wallet.getBalance();

    final cancelled = await repo.cancelBooking(booking.id);
    expect(cancelled.status(clock), BookingStatus.cancelled);
    expect(cancelled.refunded, booking.totalPrice);
    expect(await wallet.getBalance(), before + booking.totalPrice);
    expect(await isTaken(booking), isFalse);
    expect(() => repo.cancelBooking(booking.id), error(BookingStrings.cannotCancel));
  });

  test('hủy còn 3–7 ngày hoàn 80%, còn 48 giờ – 3 ngày hoàn 50%', () async {
    final four = await book(BookingPaymentType.full, daysAhead: 4);
    final two = await book(BookingPaymentType.full, daysAhead: 3); // ca sớm nhất ngày +3: còn ~68 giờ
    expect(four.cancelRefundPercent(clock), 80);
    expect(two.cancelRefundPercent(clock), 50);
    final before = await wallet.getBalance();

    final a = await repo.cancelBooking(four.id);
    final b = await repo.cancelBooking(two.id);
    expect(a.refunded, BookingCancelPolicy.refund(four.totalPrice, 80));
    expect(b.refunded, BookingCancelPolicy.refund(two.totalPrice, 50));
    expect(await wallet.getBalance(), before + a.refunded + b.refunded);
  });

  test('hủy dưới 48 giờ: không được hoàn tiền', () async {
    final full = await book(BookingPaymentType.full, daysAhead: 0);
    expect(full.cancelRefundPercent(clock), 0);
    final before = await wallet.getBalance();
    final cancelled = await repo.cancelBooking(full.id);
    expect(cancelled.status(clock), BookingStatus.cancelled);
    expect(cancelled.refunded, 0);
    expect(await wallet.getBalance(), before);

    final demo = (await repo.getMyBookings()).firstWhere((b) => b.id == 'DEMO2'); // 700.000đ, còn ~12 giờ
    expect(demo.cancelFee(clock), 700000);
    expect(demo.refundIfCancelled(clock), 0);
    expect((await repo.cancelBooking('DEMO2')).refunded, 0);
  });

  test('chỉ người đặt được hủy; chia tiền hủy dưới 48 giờ thì không ai được hoàn', () async {
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
    expect(cancelled.refunded, 0);
    expect(await wallet.getBalance(), before);
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

  group('gói cố định hằng tuần', () {
    /// Cùng giờ, cùng sân ở [weeks] tuần liên tiếp kể từ [daysAhead] ngày tới (chọn giờ mà mọi tuần còn trống).
    Future<SlotHold> holdWeekly({int weeks = 4, int daysAhead = 3, int stepDays = 7}) async {
      final days = [
        for (var i = 0; i < weeks; i++)
          await facility.getTimeSlots('f-test', Sport.badminton, clock.add(Duration(days: daysAhead + stepDays * i))),
      ];
      for (final first in days.first.where((s) => !s.isFull)) {
        final picked = [
          for (final d in days)
            d.where((s) => s.start.hour == first.start.hour && s.start.minute == first.start.minute).firstOrNull,
        ];
        if (picked.every((s) => s != null && !s.isFull)) return facility.holdSlots(picked.cast<TimeSlot>());
      }
      throw StateError('không tìm được giờ trống đủ các tuần');
    }

    Future<List<Booking>> bookPackage(SlotHold h, {bool recurring = true}) => repo.createBooking(
          hold: h,
          paymentType: BookingPaymentType.full,
          facilityName: 'Sân Test',
          sportLabel: 'Cầu Lông',
          location: 'Quận 1',
          schedule: 'Lịch test',
          recurring: recurring,
          discountPercent: 10,
        );

    test('đặt gói 4 tuần: chung mã gói, giảm 10%, trừ ví giá đã giảm', () async {
      final before = await wallet.getBalance();
      final h = await holdWeekly();
      final bookings = await bookPackage(h);
      expect(bookings, hasLength(4));
      expect(bookings.map((b) => b.recurringGroupId).toSet(), hasLength(1));
      expect(bookings.first.recurringGroupId, isNotNull);
      final original = h.slots.fold(0, (sum, s) => sum + s.price);
      final paid = bookings.fold(0, (sum, b) => sum + b.amountPaid);
      expect(paid, lessThan(original));
      expect(bookings.first.originalPrice, h.slots.first.price);
      expect(await wallet.getBalance(), before - paid);
      // Lưu lại vẫn còn mã gói.
      final mine = (await repo.getMyBookings()).where((b) => b.isRecurring).toList();
      expect(mine, hasLength(4));
    });

    test('không thành gói (ít hơn 4 tuần / bỏ tuần) mà bật gói: báo lỗi như BE', () async {
      await expectLater(
        bookPackage(await holdWeekly(weeks: 3)),
        error(BookingStrings.notAPackage(BookingStrings.packageTooFew)),
      );
      await expectLater(
        bookPackage(await holdWeekly(stepDays: 14)),
        error(BookingStrings.notAPackage(BookingStrings.packageWeekly)),
      );
    });

    test('hủy một buổi = hủy cả gói, hoàn 100%', () async {
      final bookings = await bookPackage(await holdWeekly(daysAhead: 5));
      final before = await wallet.getBalance();
      await repo.cancelBooking(bookings[2].id);
      final mine = (await repo.getMyBookings()).where((b) => b.recurringGroupId == bookings.first.recurringGroupId);
      expect(mine.every((b) => b.cancelledAt != null), isTrue);
      // Buổi đầu còn ~5 ngày → hoàn 80% cho từng buổi (mỗi buổi làm tròn riêng).
      final refund = bookings.fold(0, (sum, b) => sum + BookingCancelPolicy.refund(b.amountPaid, 80));
      expect(await wallet.getBalance(), before + refund);
    });

    test('còn dưới 48 giờ trước buổi đầu: không hủy được gói', () async {
      final bookings = await bookPackage(await holdWeekly(daysAhead: 1));
      clock = bookings.first.start.subtract(const Duration(hours: 47));
      await expectLater(repo.cancelBooking(bookings.last.id), error(BookingStrings.packageCancelTooLate));
    });
  });
}
