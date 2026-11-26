import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_booking_data.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/owner_booking.dart';
import 'package:test1/models/owner_court.dart';

void main() {
  // Thứ 5, 15/10/2026 15:00 (giống test vận hành).
  final now = DateTime(2026, 10, 15, 15, 0);
  final tomorrow = DateTime(2026, 10, 16);
  const tt = MockOwnerBookingData.thienTrieu;
  late MockOwnerRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
    repo = MockOwnerRepository(latency: Duration.zero, now: () => now);
  });

  List<ScheduleSlot> slotsOf(FacilityDaySchedule d, String courtId) => d.courts.firstWhere((c) => c.id == courtId).slots;

  test('thêm / sửa / tạm ngưng / xóa sân con', () async {
    await repo.createCourt(tt, const CourtInput(categoryId: 'sp-pickleball', name: 'Sân P1', defaultPrice: 90000, teamSize: 2));
    var courts = await repo.getCourts(tt);
    final p1 = courts.singleWhere((c) => c.name == 'Sân P1');
    expect(p1.categoryName, 'Pickleball');
    expect(p1.isActive, isTrue);

    await repo.updateCourt(tt, p1, p1.toInput().copyWith(status: 'INACTIVE', defaultPrice: 100000));
    courts = await repo.getCourts(tt);
    final updated = courts.singleWhere((c) => c.id == p1.id);
    expect(updated.isActive, isFalse);
    expect(updated.defaultPrice, 100000);

    final removed = await repo.deleteCourt(tt, p1.id);
    expect(removed, greaterThan(0));
    expect((await repo.getCourts(tt)).any((c) => c.id == p1.id), isFalse);
  });

  test('chi tiết sân có số ca trống 7 ngày tới', () async {
    final c = await repo.getCourt(tt, 'c-tt-1');
    expect(c.availableSlotsNext7Days, greaterThan(50));
    expect(c.effectiveSlotMinutes, 60);
  });

  test('giờ mở cửa đổi số ca trong ngày; đóng trước mở thì báo lỗi', () async {
    await repo.updateOpenHours(tt, openTime: '08:00', closeTime: '20:00');
    final day = await repo.getDaySchedule(tt, tomorrow);
    expect(slotsOf(day, 'c-tt-1'), hasLength(12));
    await expectLater(repo.updateOpenHours(tt, openTime: '20:00', closeTime: '08:00'), throwsA(anything));
  });

  test('thao tác hàng loạt: khóa, mở, đổi giá, xóa; ca có khách bị bỏ qua', () async {
    final lock = await repo.bulkSlots(
      tt,
      BulkSlotRequest(
        action: BulkSlotAction.lock,
        courtIds: const ['c-tt-1'],
        dateFrom: now,
        dateTo: now,
        startTime: '15:00',
        endTime: '18:00',
      ),
    );
    // 15h (vãng lai), 16h, 17h (đơn chờ góp tiền 17–19h) → chỉ 16h khóa được.
    expect(lock.matched, 3);
    expect(lock.affected, 1);
    expect(lock.skipped, 2);

    final unlock = await repo.bulkSlots(tt, BulkSlotRequest(action: BulkSlotAction.unlock, dateFrom: now, dateTo: now));
    expect(unlock.affected, 2, reason: 'ca vừa khóa + ca 18h sân 3 khóa sẵn');

    final price = await repo.bulkSlots(
      tt,
      BulkSlotRequest(action: BulkSlotAction.setPrice, dateFrom: tomorrow, dateTo: tomorrow, daysOfWeek: const [5], price: 120000),
    );
    expect(price.affected, greaterThan(0));
    expect(slotsOf(await repo.getDaySchedule(tt, tomorrow), 'c-tt-2').first.price, 120000);

    final none = await repo.bulkSlots(
      tt,
      BulkSlotRequest(action: BulkSlotAction.setPrice, dateFrom: tomorrow, dateTo: tomorrow, daysOfWeek: const [0], price: 1),
    );
    expect(none.matched, 0, reason: 'mai là Thứ 6, lọc CN thì không khớp');

    final del = await repo.bulkSlots(
      tt,
      BulkSlotRequest(action: BulkSlotAction.delete, courtIds: const ['c-tt-2'], dateFrom: tomorrow, dateTo: tomorrow),
    );
    expect(del.affected, 16);
    expect(slotsOf(await repo.getDaySchedule(tt, tomorrow), 'c-tt-2'), isEmpty);
  });

  test('sinh ca: tạo lại ca đã xóa, áp khung giá giờ vàng, bỏ qua ca có khách và ca đã qua', () async {
    await repo.bulkSlots(
      tt,
      BulkSlotRequest(action: BulkSlotAction.delete, courtIds: const ['c-tt-2'], dateFrom: tomorrow, dateTo: tomorrow),
    );
    final rows = await repo.generateSlots(
      tt,
      GenerateSlotsRequest(
        courtIds: const ['c-tt-2'],
        dateFrom: tomorrow,
        dateTo: tomorrow,
        priceRules: const [SlotPriceRule(startTime: '17:00', endTime: '22:00', price: 150000)],
      ),
    );
    expect(rows.single.created, 16);
    final slots = slotsOf(await repo.getDaySchedule(tt, tomorrow), 'c-tt-2');
    expect(slots, hasLength(16));
    expect(slots.firstWhere((s) => s.start.hour == 18).price, 150000);
    expect(slots.firstWhere((s) => s.start.hour == 10).price, 80000);

    final today = await repo.generateSlots(tt, GenerateSlotsRequest(courtIds: const ['c-tt-1'], dateFrom: now, dateTo: now));
    expect(today.single.past, 9, reason: '06:00–14:00 đã qua');
    expect(today.single.skipped, 3, reason: '15h vãng lai, 17–19h chờ góp tiền');
  });

  test('lịch 7 ngày và số ca khách đặt được hôm nay', () async {
    final range = await repo.getSlotsRange(tt, from: now, to: now.add(const Duration(days: 6)));
    expect(range.days, hasLength(7));
    expect(range.totalSlots, 7 * 3 * 16);
    expect(range.lockedSlots, 1);
    expect(range.bookedSlots, greaterThanOrEqualTo(5));

    final a = await repo.getAvailability(tt, now);
    expect(a.totalCourts, 3);
    expect(a.bookableCourts, 3);
    expect(a.availableSlots, greaterThan(0));
  });

  test('đợt giá đặc biệt: đổi giá ca trống trong đợt, giữ ca có khách; xóa đợt', () async {
    final r = await repo.savePricePeriod(
      tt,
      PricePeriod(name: 'Phụ thu Tết', fromDate: now, toDate: now, startTime: '15:00', endTime: '18:00', price: 130000),
    );
    expect(r.updatedSlots, 5, reason: '15–18h còn trống: sân 1 lúc 16h, sân 2 lúc 16h–17h, sân 3 lúc 15h, 17h');
    expect(r.skippedBookedSlots, 4);
    final list = await repo.getPricePeriods(tt, from: now);
    expect(list.single.name, 'Phụ thu Tết');
    await repo.deletePricePeriod(tt, list.single.id);
    expect(await repo.getPricePeriods(tt, from: now), isEmpty);
  });

  test('đợt giá trùng phạm vi đổi giá (như findOverlappingPeriods của Web)', () {
    final p = PricePeriod(
      name: 'Tết',
      fromDate: DateTime(2027, 2, 1),
      toDate: DateTime(2027, 2, 5),
      courtIds: const ['a'],
      startTime: '17:00',
      endTime: '22:00',
      price: 1,
    );
    expect(p.overlaps(courts: const [], from: DateTime(2027, 2, 5), to: DateTime(2027, 2, 9)), isTrue);
    expect(p.overlaps(courts: const ['b'], from: DateTime(2027, 2, 2), to: DateTime(2027, 2, 2)), isFalse);
    expect(p.overlaps(courts: const ['a'], from: DateTime(2027, 2, 2), to: DateTime(2027, 2, 2), start: '06:00', end: '17:00'), isFalse);
    expect(p.overlaps(courts: const ['a'], from: DateTime(2027, 2, 6), to: DateTime(2027, 2, 9)), isFalse);
  });

  test('tóm tắt thứ trong tuần như Web', () {
    expect(WeekDays.summary(const []), 'Mọi ngày');
    expect(WeekDays.summary(const [1, 2, 3, 4, 5]), 'T2 – T6');
    expect(WeekDays.summary(const [6, 0]), 'T7, CN');
    expect(WeekDays.ofDate(DateTime(2026, 10, 18)), 0, reason: '18/10/2026 là Chủ nhật');
  });

  test('nội dung gửi BE: sửa sân gửi "" / 0 / clearIsIndoor; sinh ca và hàng loạt đúng tên trường', () {
    const input = CourtInput(categoryId: 'c', name: 'Sân 1', defaultPrice: 100000);
    expect(input.toJson(editing: false), {
      'categoryId': 'c',
      'name': 'Sân 1',
      'defaultPrice': 100000,
      'courtType': null,
      'surfaceType': null,
      'isIndoor': null,
      'maxPlayers': null,
      'teamSize': null,
      'slotMinutes': null,
    });
    final edit = input.copyWith(status: 'INACTIVE').toJson(editing: true, previousIsIndoor: true);
    expect(edit['courtType'], '');
    expect(edit['slotMinutes'], 0);
    expect(edit['clearIsIndoor'], isTrue);
    expect(edit['status'], 'INACTIVE');

    final gen = GenerateSlotsRequest(
      dateFrom: DateTime(2026, 12, 1),
      dateTo: DateTime(2026, 12, 7),
      openTime: '06:00',
      priceRules: const [SlotPriceRule(daysOfWeek: [6, 0], startTime: '17:00', endTime: '22:00', price: 150000)],
    ).toJson();
    expect(gen['dateFrom'], '2026-12-01');
    expect(gen['openTime'], '06:00:00');
    expect(gen['closeTime'], isNull);
    expect(gen['courtIds'], isNull);
    expect((gen['priceRules'] as List).single, {'daysOfWeek': [6, 0], 'startTime': '17:00:00', 'endTime': '22:00:00', 'price': 150000});

    final bulk = BulkSlotRequest(
      action: BulkSlotAction.setPrice,
      courtIds: const ['x'],
      dateFrom: DateTime(2026, 12, 1),
      dateTo: DateTime(2026, 12, 1),
      price: 90000,
    );
    expect(bulk.updateJson()['action'], 'SET_PRICE');
    expect(bulk.updateJson()['price'], 90000);
    expect(bulk.filterJson().containsKey('action'), isFalse);
  });
}
