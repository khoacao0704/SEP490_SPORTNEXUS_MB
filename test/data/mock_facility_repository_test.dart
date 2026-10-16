import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/facility_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/repositories/facility_repository.dart';
import 'package:test1/models/court_type.dart';
import 'package:test1/models/facility.dart';
import 'package:test1/models/facility_search.dart';
import 'package:test1/models/geo_point.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/widgets/facility/slot_picker.dart';

void main() {
  // "Bây giờ" cố định 08:00 sáng để kết quả test không phụ thuộc giờ chạy.
  final now = DateTime(2026, 10, 14, 8, 0);
  final tomorrow = DateTime(2026, 10, 15);
  late MockFacilityRepository repo;
  late DateTime clock;

  setUp(() {
    clock = now;
    repo = MockFacilityRepository(latency: Duration.zero, now: () => clock);
  });

  group('searchFacilities', () {
    test('chỉ trả về cơ sở trong thành phố đã chọn', () async {
      final results = await repo.searchFacilities(const FacilitySearchQuery(city: 'Hà Nội'));
      expect(results, isNotEmpty);
      expect(results.every((r) => r.facility.city == 'Hà Nội'), isTrue);
    });

    test('lọc theo môn và quận', () async {
      final results = await repo.searchFacilities(const FacilitySearchQuery(
        city: 'Hồ Chí Minh',
        district: 'Quận 7',
        sport: Sport.pickleball,
      ));
      expect(results.map((r) => r.facility.id), containsAll(['f-hcm-thientrieu', 'f-hcm-eco-q7']));
      expect(results.every((r) => r.facility.offeringFor(Sport.pickleball) != null), isTrue);
    });

    test('từ khóa tìm không phân biệt dấu, theo tên hoặc địa chỉ', () async {
      final byName = await repo.searchFacilities(const FacilitySearchQuery(city: 'Hồ Chí Minh', keyword: 'thao dien'));
      expect(byName.single.facility.id, 'f-hcm-thaodien');

      final byAddress =
          await repo.searchFacilities(const FacilitySearchQuery(city: 'Hồ Chí Minh', keyword: 'nguyen thi thap'));
      expect(byAddress.single.facility.id, 'f-hcm-eco-q7');
    });

    test('có GPS thì tính khoảng cách và sắp xếp gần nhất trước', () async {
      const nearQ7 = GeoPoint(10.7535, 106.7285);
      final results = await repo.searchFacilities(
        const FacilitySearchQuery(city: 'Hồ Chí Minh', userLocation: nearQ7),
      );
      expect(results.first.facility.id, 'f-hcm-thientrieu');
      final distances = results.map((r) => r.distanceKm!).toList();
      expect(distances, orderedEquals([...distances]..sort()));
    });

    test('không có GPS thì không có khoảng cách, sắp xếp theo đánh giá', () async {
      final results = await repo.searchFacilities(const FacilitySearchQuery(city: 'Hồ Chí Minh'));
      expect(results.every((r) => r.distanceKm == null), isTrue);
      final ratings = results.map((r) => r.facility.rating).toList();
      expect(ratings, orderedEquals([...ratings]..sort((a, b) => b.compareTo(a))));
    });

    test('sắp xếp theo giá dùng giá của môn đang lọc', () async {
      final results = await repo.searchFacilities(const FacilitySearchQuery(
        city: 'Hồ Chí Minh',
        sport: Sport.badminton,
        sort: FacilitySort.priceLowToHigh,
      ));
      final prices = results.map((r) => r.facility.offeringFor(Sport.badminton)!.priceFrom).toList();
      expect(prices, orderedEquals([...prices]..sort()));
    });
  });

  test('getDistricts trả về các quận có cơ sở, không trùng', () async {
    final districts = await repo.getDistricts('Hồ Chí Minh');
    expect(districts, containsAll(['Quận 7', 'Thủ Đức', 'Quận 1']));
    expect(districts.toSet().length, districts.length);
  });

  group('getTimeSlots', () {
    test('khung giờ nằm trong giờ mở cửa, đúng thời lượng theo môn', () async {
      final badminton = await repo.getTimeSlots('f-hcm-fpt', Sport.badminton, tomorrow);
      final football = await repo.getTimeSlots('f-hcm-fpt', Sport.football, tomorrow);

      expect(badminton.first.start, DateTime(2026, 10, 15, 6, 0));
      expect(badminton.every((s) => s.end.difference(s.start).inMinutes == 60), isTrue);
      expect(football.every((s) => s.end.difference(s.start).inMinutes == 90), isTrue);
      // FPT đóng cửa 21:30
      expect(badminton.last.end.isAfter(DateTime(2026, 10, 15, 21, 30)), isFalse);
    });

    test('mỗi sân con có lịch riêng: đủ Sân 1 → Sân 6, cùng khung giờ, sắp theo sân', () async {
      final slots = await repo.getTimeSlots('f-hcm-thientrieu', Sport.badminton, tomorrow);
      expect(courtsOf(slots), [for (var i = 1; i <= 6; i++) 'Sân $i']);
      final perCourt = slots.where((s) => s.courtName == 'Sân 1').map((s) => s.start).toList();
      expect(slots.where((s) => s.courtName == 'Sân 6').map((s) => s.start), perCourt);
      expect(slots.map((s) => s.id).toSet(), hasLength(slots.length));
      // Có cả sân trống lẫn sân đã đặt để demo.
      expect(slots.any((s) => s.isAvailable), isTrue);
      expect(slots.any((s) => s.isFull), isTrue);
    });

    test('giờ cao điểm từ 17:00 đắt hơn', () async {
      final slots = await repo.getTimeSlots('f-hcm-thientrieu', Sport.badminton, tomorrow);
      final morning = slots.firstWhere((s) => s.start.hour == 8);
      final evening = slots.firstWhere((s) => s.start.hour == 18);
      expect(morning.price, 120000);
      expect(evening.price, greaterThan(morning.price));
    });

    test('mở lại nhiều lần vẫn ra cùng trạng thái từng sân con', () async {
      final a = await repo.getTimeSlots('f-hcm-hoalu', Sport.football, tomorrow);
      final b = await MockFacilityRepository(latency: Duration.zero, now: () => clock)
          .getTimeSlots('f-hcm-hoalu', Sport.football, tomorrow);
      expect(a.map((s) => s.isAvailable), b.map((s) => s.isAvailable));
    });

    test('loại sân: mỗi loại có số sân và giá riêng; bỏ trống thì lấy loại rẻ nhất', () async {
      final hoalu = MockFacilityData.facilities.firstWhere((f) => f.id == 'f-hcm-hoalu');
      expect(hoalu.sports.where((s) => s == Sport.football), hasLength(1));
      expect(hoalu.offeringsFor(Sport.football).map((o) => o.courtType),
          [CourtType.football5, CourtType.football7, CourtType.football11]);

      final five = await repo.getTimeSlots('f-hcm-hoalu', Sport.football, tomorrow);
      final seven = await repo.getTimeSlots('f-hcm-hoalu', Sport.football, tomorrow, courtType: CourtType.football7);
      expect(five.every((s) => s.courtType == CourtType.football5), isTrue);
      expect(courtsOf(five), ['Sân 1', 'Sân 2', 'Sân 3']);
      expect(seven.every((s) => s.courtType == CourtType.football7), isTrue);
      expect(courtsOf(seven), ['Sân 1', 'Sân 2']);
      expect(seven.first.price, greaterThan(five.first.price));
      expect(seven.first.id, isNot(five.first.id));

      expect(await repo.getTimeSlots('f-hcm-govap', Sport.football, tomorrow, courtType: CourtType.football7), isEmpty);
    });

    test('môn cơ sở không có thì trả về rỗng', () async {
      expect(await repo.getTimeSlots('f-hn-hoankiem', Sport.football, tomorrow), isEmpty);
    });
  });

  group('giữ chỗ 10 phút', () {
    // Cơ sở 2 sân để dễ kiểm tra việc trừ dần.
    const twoCourts = Facility(
      id: 'f-test',
      name: 'Sân Test',
      address: '1 Test',
      city: 'Hồ Chí Minh',
      district: 'Quận 1',
      location: GeoPoint(10.77, 106.70),
      offerings: [SportOffering(sport: Sport.badminton, courtCount: 2, priceFrom: 100000)],
      rating: 4,
      reviewCount: 1,
      imageUrls: [],
      openTime: '06:00',
      closeTime: '22:00',
      phone: '0',
    );

    late MockFacilityRepository testRepo;

    setUp(() {
      testRepo = MockFacilityRepository(latency: Duration.zero, now: () => clock, facilities: [twoCourts]);
    });

    Future<TimeSlot> freshSlot(String id) async =>
        (await testRepo.getTimeSlots('f-test', Sport.badminton, tomorrow)).firstWhere((s) => s.id == id);

    Future<List<TimeSlot>> openSlots() async =>
        (await testRepo.getTimeSlots('f-test', Sport.badminton, tomorrow)).where((s) => !s.isFull).toList();

    String label(TimeSlot s) => '${s.courtName} • ${Formatters.slotLabel(s.start, s.end)}';

    test('giữ đúng sân con đã chọn; sân con khác cùng giờ không bị ảnh hưởng; nhả thì trống lại', () async {
      final slot = (await openSlots()).first;
      final sameTimeOtherCourt = (await testRepo.getTimeSlots('f-test', Sport.badminton, tomorrow))
          .firstWhere((s) => s.start == slot.start && s.courtName != slot.courtName);

      final hold = await testRepo.holdSlots([slot]);
      expect(hold.slots.single.courtName, slot.courtName);
      expect((await freshSlot(slot.id)).isAvailable, isFalse);
      expect((await freshSlot(sameTimeOtherCourt.id)).isAvailable, sameTimeOtherCourt.isAvailable);
      expect(hold.secondsRemaining(clock), 600);

      await testRepo.releaseHold(hold.holdId);
      expect((await freshSlot(slot.id)).isAvailable, isTrue);
    });

    test('giữ nhiều khung (kể cả khác ngày) trong 1 lần, tổng tiền cộng dồn, nhả thì trả lại tất cả', () async {
      final open = await openSlots();
      final otherDay = (await testRepo.getTimeSlots('f-test', Sport.badminton, tomorrow.add(const Duration(days: 2))))
          .firstWhere((s) => !s.isFull);
      final picked = [otherDay, open[1], open[0]]; // cố tình không theo thứ tự

      final hold = await testRepo.holdSlots(picked);
      expect(hold.slots.map((s) => s.start), [open[0].start, open[1].start, otherDay.start]..sort()); // đã sắp theo giờ
      expect(hold.totalPrice, picked.fold<int>(0, (sum, s) => sum + s.price));
      expect((await freshSlot(open[0].id)).isAvailable, isFalse);
      expect((await freshSlot(open[1].id)).isAvailable, isFalse);

      await testRepo.releaseHold(hold.holdId);
      expect((await freshSlot(open[0].id)).isAvailable, isTrue);
      expect((await freshSlot(open[1].id)).isAvailable, isTrue);
    });

    test('đặt 2 sân con cùng một giờ trong 1 lần được', () async {
      final slots = await testRepo.getTimeSlots('f-test', Sport.badminton, tomorrow);
      final start = slots.firstWhere((s) => slots.where((o) => o.start == s.start && o.isAvailable).length == 2).start;
      final both = slots.where((s) => s.start == start).toList();

      final hold = await testRepo.holdSlots(both);
      expect(hold.slots.map((s) => s.courtName).toSet(), {'Sân 1', 'Sân 2'});
    });

    test('chọn trùng 1 khung 2 lần thì chỉ giữ 1 lần', () async {
      final slot = (await openSlots()).first;
      final hold = await testRepo.holdSlots([slot, slot]);
      expect(hold.slots, hasLength(1));
    });

    test('sân con đã có người giữ thì không giữ được nữa, báo rõ sân và khung nào', () async {
      final slot = (await openSlots()).first;
      await testRepo.holdSlots([slot]);
      expect((await freshSlot(slot.id)).isFull, isTrue);
      expect(
        () => testRepo.holdSlots([slot]),
        throwsA(isA<FacilityException>().having((e) => e.message, 'message', FacilityStrings.slotJustFull(label(slot)))),
      );
    });

    test('1 khung vừa có người đặt thì không giữ khung nào (tất cả hoặc không)', () async {
      final open = await openSlots();
      final full = open[0];
      final other = open[1];
      await testRepo.holdSlots([full]);

      await expectLater(testRepo.holdSlots([other, full]), throwsA(isA<FacilityException>()));
      expect((await freshSlot(other.id)).isAvailable, isTrue);
    });

    test('quá 10 phút thì chỗ giữ tự hết hạn', () async {
      final slot = (await openSlots()).first;
      await testRepo.holdSlots([slot]);

      clock = now.add(const Duration(minutes: 10, seconds: 1));
      expect((await freshSlot(slot.id)).isAvailable, isTrue);
    });

    test('không giữ được khung giờ đã bắt đầu', () async {
      final today = await testRepo.getTimeSlots('f-test', Sport.badminton, now);
      final started = today.firstWhere((s) => s.hasStarted(now) && s.isAvailable);
      expect(
        () => testRepo.holdSlots([started]),
        throwsA(isA<FacilityException>().having((e) => e.message, 'message', FacilityStrings.slotStarted(label(started)))),
      );
    });

    test('danh sách rỗng thì báo lỗi', () async {
      expect(() => testRepo.holdSlots([]), throwsA(isA<FacilityException>()));
    });
  });

  test('describeSlotSchedule gom theo ngày, sắp theo giờ, kèm sân con', () {
    TimeSlot slot(DateTime start, String court) => TimeSlot(
          id: '$court${start.toIso8601String()}',
          facilityId: 'f',
          sport: Sport.badminton,
          courtName: court,
          start: start,
          end: start.add(const Duration(hours: 1)),
          price: 100000,
          isAvailable: true,
        );
    final text = describeSlotSchedule([
      slot(DateTime(2026, 10, 17, 7), 'Sân 3'),
      slot(DateTime(2026, 10, 15, 20), 'Sân 1'),
      slot(DateTime(2026, 10, 15, 18), 'Sân 2'),
    ]);
    expect(text, 'Thứ 5, 15/10: Sân 2 18:00 - 19:00, Sân 1 20:00 - 21:00\nThứ 7, 17/10: Sân 3 07:00 - 08:00');
  });

  test('freeSlotsByCourt đếm khung còn đặt được của từng sân', () {
    TimeSlot slot(String court, int hour, bool free) => TimeSlot(
          id: '$court$hour',
          facilityId: 'f',
          sport: Sport.badminton,
          courtName: court,
          start: DateTime(2026, 10, 15, hour),
          end: DateTime(2026, 10, 15, hour + 1),
          price: 100000,
          isAvailable: free,
        );
    final now = DateTime(2026, 10, 15, 9, 30);
    final slots = [slot('Sân 1', 9, true), slot('Sân 1', 10, true), slot('Sân 1', 11, false), slot('Sân 2', 10, false)];
    expect(freeSlotsByCourt(slots, now), {'Sân 1': 1, 'Sân 2': 0}); // 9:00 đã bắt đầu
  });

  test('dữ liệu giả hợp lệ: id không trùng, mỗi cơ sở có ít nhất 1 môn', () {
    final ids = MockFacilityData.facilities.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(MockFacilityData.facilities.every((f) => f.offerings.isNotEmpty), isTrue);
  });
}
