import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/booking_strings.dart';
import 'package:test1/models/booking.dart';
import 'package:test1/models/recurring_plan.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';

TimeSlot _slot(DateTime day, int hour, {String court = 'Sân 2', bool free = true, int price = 100000}) => TimeSlot(
      id: '$court|${day.toIso8601String()}|$hour',
      facilityId: 'f1',
      sport: Sport.badminton,
      courtName: court,
      start: DateTime(day.year, day.month, day.day, hour),
      end: DateTime(day.year, day.month, day.day, hour + 1),
      price: price,
      isAvailable: free,
    );

/// Ca dài [hours] giờ bắt đầu lúc [hour].
TimeSlot _long(DateTime day, int hour, int hours, {String court = 'Sân 2'}) => TimeSlot(
      id: '$court|${day.toIso8601String()}|$hour+$hours',
      facilityId: 'f1',
      sport: Sport.badminton,
      courtName: court,
      start: DateTime(day.year, day.month, day.day, hour),
      end: DateTime(day.year, day.month, day.day, hour + hours),
      price: 200000,
      isAvailable: true,
    );

Booking _booking(String id, DateTime start, {String? group = 'G1', DateTime? cancelledAt, int price = 90000}) => Booking(
      id: id,
      bookerId: 'u-me',
      facilityName: 'Sân A',
      location: 'Q1',
      sportLabel: 'Cầu Lông',
      courtName: 'Sân 2',
      schedule: '',
      start: start,
      end: start.add(const Duration(hours: 1)),
      totalPrice: price,
      paymentType: BookingPaymentType.full,
      payments: [BookingPayment(userId: 'u-me', name: 'Me', amount: price)],
      createdAt: DateTime(2026, 11, 1),
      cancelledAt: cancelledAt,
      recurringGroupId: group,
    );

void main() {
  final now = DateTime(2026, 11, 19, 9);
  final tue = DateTime(2026, 11, 24);

  group('mẫu lặp lại', () {
    test('1 sân con, 1 ngày (khung liền nhau hoặc cách quãng) → hợp lệ', () {
      expect(RecurringPlan.isValidPattern([_slot(tue, 18)]), isTrue);
      expect(RecurringPlan.isValidPattern([_slot(tue, 19), _slot(tue, 18)]), isTrue);
      expect(RecurringPlan.isValidPattern([_slot(tue, 8), _slot(tue, 18)]), isTrue);
    });

    test('nhiều sân con, khác ngày hoặc chưa chọn → không hợp lệ (đặt lặp lại chỉ 1 sân con)', () {
      expect(RecurringPlan.isValidPattern([_slot(tue, 18), _slot(tue, 18, court: 'Sân 3')]), isFalse);
      expect(RecurringPlan.isValidPattern([]), isFalse);
      expect(RecurringPlan.isValidPattern([_slot(tue, 18), _slot(tue.add(const Duration(days: 1)), 18)]), isFalse);
    });

    test('ngày lặp: các thứ đã chọn trong N tuần tính từ ngày bắt đầu', () {
      // Bắt đầu T3 24/11, lặp T3 + T5 trong 2 tuần (24/11 → 07/12).
      expect(RecurringPlan.datesFor(tue, {2, 4}, 2), [
        DateTime(2026, 11, 24),
        DateTime(2026, 11, 26),
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 3),
      ]);
      // Chọn thứ đứng trước ngày bắt đầu (T2): lần đầu là T2 tuần sau, vẫn đủ N lần.
      expect(RecurringPlan.datesFor(tue, {1}, 2), [DateTime(2026, 11, 30), DateTime(2026, 12, 7)]);
    });
  });

  group('số lượt đặt', () {
    Future<List<TimeSlot>> openDay(DateTime d) async => [_slot(d, 5, court: 'Sân 1'), _slot(d, 5), _slot(d, 6), _slot(d, 8)];

    Future<RecurringPlan> plan(List<int> hours, Set<int> weekdays) => RecurringPlan.build(
          pattern: [for (final h in hours) _slot(tue, h)],
          weekdays: weekdays,
          weeks: 4,
          now: now,
          loadDay: openDay,
        );

    test('T3 slot 5 × 4 tuần = 4 lượt, 1 gói', () async {
      final p = await plan([5], {2});
      expect(p.isComplete, isTrue);
      expect(p.slots, hasLength(4));
      expect(p.slots.every((s) => s.courtName == 'Sân 2'), isTrue);
      expect(p.packages, hasLength(1));
      expect(p.originalTotal, 400000);
    });

    test('T3 slot 5 + 6 × 4 tuần = 8 lượt, 1 gói (khung liền nhau)', () async {
      final p = await plan([5, 6], {2});
      expect(p.slots, hasLength(8));
      expect(p.packages.single, hasLength(8));
    });

    test('T3 + T5, slot 5 + 6 × 4 tuần = 16 lượt, tách 2 gói (mỗi thứ một gói cho BE)', () async {
      final p = await plan([5, 6], {2, 4});
      expect(p.slots, hasLength(16));
      expect(p.packages, hasLength(2));
      expect(p.packages.map((g) => g.map((s) => s.start.weekday).toSet()), [{2}, {4}]);
      expect(p.packages.every((g) => g.length == 8), isTrue);
    });

    test('slot 5 ở Sân 1 + Sân 2 × T3 × 4 tuần = 8 lượt, mỗi sân một gói', () async {
      final p = await RecurringPlan.build(
        pattern: [_slot(tue, 5), _slot(tue, 5, court: 'Sân 1')],
        weekdays: {2},
        weeks: 4,
        now: now,
        loadDay: openDay,
      );
      expect(p.isComplete, isTrue);
      expect(p.slots, hasLength(8));
      expect(p.packages, hasLength(2));
      expect(p.packages.map((g) => g.map((s) => s.courtName).toSet()), [{'Sân 1'}, {'Sân 2'}]);
    });

    test('slot 5 + 6 ở Sân 1 + Sân 2 × T3 + T5 × 4 tuần = 32 lượt, 4 gói (2 thứ × 2 sân)', () async {
      final p = await RecurringPlan.build(
        pattern: [_slot(tue, 5), _slot(tue, 6), _slot(tue, 5, court: 'Sân 1'), _slot(tue, 6, court: 'Sân 1')],
        weekdays: {2, 4},
        weeks: 4,
        now: now,
        loadDay: (d) async => [for (final c in ['Sân 1', 'Sân 2']) for (final h in [5, 6]) _slot(d, h, court: c)],
      );
      expect(p.slots, hasLength(32));
      expect(p.packages, hasLength(4));
      expect(p.packages.every((g) => g.length == 8 && g.map((s) => s.courtName).toSet().length == 1), isTrue);
    });

    test('khung cách quãng (slot 5 + 8) cùng ngày: mỗi cụm giờ một gói', () async {
      final p = await plan([5, 8], {2});
      expect(p.slots, hasLength(8));
      expect(p.packages, hasLength(2));
      expect(p.packages.map((g) => g.map((s) => s.start.hour).toSet()), [{5}, {8}]);
    });

    test('ngày có người đặt / chưa mở lịch / tải lỗi → không đủ lịch, nêu rõ ngày', () async {
      final p = await RecurringPlan.build(
        pattern: [_slot(tue, 18)],
        weekdays: {2},
        weeks: 5,
        now: now,
        loadDay: (d) async {
          if (d == DateTime(2026, 12, 1)) return [_slot(d, 18, free: false)];
          if (d == DateTime(2026, 12, 8)) return [];
          if (d == DateTime(2026, 12, 15)) throw Exception('mạng');
          return [_slot(d, 18)];
        },
      );
      expect(p.isComplete, isFalse);
      expect(p.sessions.map((s) => s.issue), [
        null,
        RecurringIssue.taken,
        RecurringIssue.notOpen,
        RecurringIssue.notOpen,
        null,
      ]);
      expect(p.problems.map((s) => s.date), [DateTime(2026, 12, 1), DateTime(2026, 12, 8), DateTime(2026, 12, 15)]);
    });

    test('tuần có ca trùng giờ nhưng khác độ dài (60 → 120 phút) → "lệch độ dài ca", không phải "chưa mở lịch"', () async {
      final p = await RecurringPlan.build(
        pattern: [_slot(tue, 18)],
        weekdays: {2},
        weeks: 4,
        now: now,
        loadDay: (d) async {
          // Tuần 3: chủ sân gộp thành ca 17:00 - 19:00.
          if (d == DateTime(2026, 12, 8)) return [_long(d, 17, 2)];
          // Tuần 4: chỉ có ca 20:00 - 21:00 (không đè giờ mẫu) → vẫn là chưa mở lịch.
          if (d == DateTime(2026, 12, 15)) return [_slot(d, 20)];
          return [_slot(d, 18)];
        },
      );
      expect(p.isComplete, isFalse);
      expect(p.sessions.map((s) => s.issue), [null, null, RecurringIssue.lengthMismatch, RecurringIssue.notOpen]);
    });
  });

  group('kiểm gói trước khi trả (luật BE, chưa có API xem trước)', () {
    List<TimeSlot> weekly(int weeks, {int hour = 18}) =>
        [for (var i = 0; i < weeks; i++) _slot(DateTime(2026, 11, 24 + 7 * i), hour)];

    test('4 tuần liên tiếp, cùng sân, cùng độ dài → hợp lệ', () {
      expect(RecurringPlan.packageError(weekly(4)), isNull);
      // 2 ca liền nhau mỗi ngày vẫn là 1 buổi.
      expect(RecurringPlan.packageError([...weekly(4), ...weekly(4, hour: 19)]), isNull);
    });

    test('thiếu buổi / bỏ tuần / lệch độ dài / khác sân → nêu đúng lý do', () {
      expect(RecurringPlan.packageError(weekly(3)), BookingStrings.packageTooFew);
      final skipped = weekly(5)..removeAt(2);
      expect(RecurringPlan.packageError(skipped), BookingStrings.packageWeekly);
      final longer = weekly(4)..[3] = _long(DateTime(2026, 12, 15), 18, 2);
      expect(RecurringPlan.packageError(longer), BookingStrings.packageSameLength);
      final otherCourt = weekly(4)..[1] = _slot(DateTime(2026, 12, 1), 18, court: 'Sân 3');
      expect(RecurringPlan.packageError(otherCourt), BookingStrings.packageSameCourt);
    });

    test('RecurringCheckout: gói sai luật hoặc có ngày kẹt → có lý do, đánh dấu đúng khung', () {
      final ok = weekly(4);
      final bad = weekly(4, hour: 8)..[3] = _long(DateTime(2026, 12, 15), 8, 2);
      final checkout = RecurringCheckout(sessions: 8, discountPercent: 10, summary: '', packages: [ok, bad]);
      expect(checkout.problems, [BookingStrings.packageSameLength]);
      expect(checkout.badSlotIds, bad.map((s) => s.id).toSet());

      expect(RecurringCheckout(sessions: 4, discountPercent: 10, summary: '', packages: [ok]).problems, isEmpty);
      final withBadDay = RecurringCheckout(
        sessions: 4,
        discountPercent: 10,
        summary: '',
        packages: [ok],
        days: [RecurringSession(date: tue, issue: RecurringIssue.lengthMismatch)],
      );
      expect(withBadDay.problems, [BookingStrings.recurringHasBadDay]);
    });
  });

  group('đặt nhiều sân cùng lúc', () {
    test('các sân cùng bộ khung giờ trong ngày → hợp lệ (ngày khác nhau không so)', () {
      expect(findCourtsMismatch([_slot(tue, 5, court: 'Sân 1'), _slot(tue, 6, court: 'Sân 1'), _slot(tue, 5), _slot(tue, 6)]), isNull);
      expect(findCourtsMismatch([_slot(tue, 5, court: 'Sân 1'), _slot(tue.add(const Duration(days: 1)), 9)]), isNull);
      expect(findCourtsMismatch([_slot(tue, 5), _slot(tue, 9)]), isNull); // 1 sân: tự do
    });

    test('Sân 1 slot 5-6 + Sân 2 slot 5 → Sân 2 thiếu slot 6', () {
      final m = findCourtsMismatch([_slot(tue, 5, court: 'Sân 1'), _slot(tue, 6, court: 'Sân 1'), _slot(tue, 5)])!;
      expect(m.court, 'Sân 2');
      expect(m.day, tue);
      expect(m.missing.map((r) => r.$1.hour), [6]);
    });
  });

  group('gói đã đặt', () {
    test('gom các buổi cùng gói tại vị trí buổi đầu, đặt lẻ giữ nguyên', () {
      final single = _booking('S', DateTime(2026, 11, 22, 8), group: null);
      final items = BookingPackage.group([
        _booking('A1', DateTime(2026, 11, 24, 18)),
        single,
        _booking('A2', DateTime(2026, 12, 1, 18)),
      ]);
      expect(items.length, 2);
      expect((items.first as BookingPackage).sessions.map((b) => b.id), ['A1', 'A2']);
      expect(items.last, same(single));
    });

    test('hủy cả gói chỉ trước 48 giờ của buổi đầu còn lại; hoàn đủ các buổi chưa hủy', () {
      final package = BookingPackage('G1', [
        _booking('A1', DateTime(2026, 11, 22, 18), cancelledAt: DateTime(2026, 11, 18)), // chủ sân hủy lẻ
        _booking('A2', DateTime(2026, 11, 29, 18)),
        _booking('A3', DateTime(2026, 12, 6, 18)),
      ]);
      expect(package.cancelDeadline, DateTime(2026, 11, 27, 18));
      expect(package.canCancel(now, 'u-me'), isTrue);
      expect(package.canCancel(DateTime(2026, 11, 27, 18), 'u-me'), isFalse);
      expect(package.canCancel(now, 'someone-else'), isFalse);
      expect(package.refundIfCancelled, 180000);
      expect(package.totalPaid, 270000);
    });
  });
}
