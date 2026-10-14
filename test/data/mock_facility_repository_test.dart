import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/facility_strings.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/repositories/facility_repository.dart';
import 'package:test1/models/facility.dart';
import 'package:test1/models/facility_search.dart';
import 'package:test1/models/geo_point.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';

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

    test('số sân trống không vượt quá số sân của cơ sở', () async {
      final slots = await repo.getTimeSlots('f-hcm-thientrieu', Sport.badminton, tomorrow);
      expect(slots.every((s) => s.totalCourts == 6), isTrue);
      expect(slots.every((s) => s.availableCourts >= 0 && s.availableCourts <= 6), isTrue);
    });

    test('giờ cao điểm từ 17:00 đắt hơn', () async {
      final slots = await repo.getTimeSlots('f-hcm-thientrieu', Sport.badminton, tomorrow);
      final morning = slots.firstWhere((s) => s.start.hour == 8);
      final evening = slots.firstWhere((s) => s.start.hour == 18);
      expect(morning.price, 120000);
      expect(evening.price, greaterThan(morning.price));
    });

    test('mở lại nhiều lần vẫn ra cùng số sân trống', () async {
      final a = await repo.getTimeSlots('f-hcm-hoalu', Sport.football, tomorrow);
      final b = await MockFacilityRepository(latency: Duration.zero, now: () => clock)
          .getTimeSlots('f-hcm-hoalu', Sport.football, tomorrow);
      expect(a.map((s) => s.availableCourts), b.map((s) => s.availableCourts));
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

    Future<TimeSlot> slotWithAvailable() async {
      final slots = await testRepo.getTimeSlots('f-test', Sport.badminton, tomorrow);
      return slots.firstWhere((s) => s.availableCourts == 2, orElse: () => slots.firstWhere((s) => !s.isFull));
    }

    test('giữ chỗ trừ 1 sân trống; nhả chỗ thì trả lại', () async {
      final slot = await slotWithAvailable();
      final before = slot.availableCourts;

      final hold = await testRepo.holdSlot(slot);
      expect((await freshSlot(slot.id)).availableCourts, before - 1);
      expect(hold.secondsRemaining(clock), 600);

      await testRepo.releaseHold(hold.holdId);
      expect((await freshSlot(slot.id)).availableCourts, before);
    });

    test('hết sân thì không giữ được nữa', () async {
      final slot = await slotWithAvailable();
      for (var i = 0; i < slot.availableCourts; i++) {
        await testRepo.holdSlot(slot);
      }
      expect((await freshSlot(slot.id)).isFull, isTrue);
      expect(
        () => testRepo.holdSlot(slot),
        throwsA(isA<FacilityException>().having((e) => e.message, 'message', FacilityStrings.slotJustFull)),
      );
    });

    test('quá 10 phút thì chỗ giữ tự hết hạn', () async {
      final slot = await slotWithAvailable();
      final before = slot.availableCourts;
      await testRepo.holdSlot(slot);

      clock = now.add(const Duration(minutes: 10, seconds: 1));
      expect((await freshSlot(slot.id)).availableCourts, before);
    });

    test('không giữ được khung giờ đã bắt đầu', () async {
      final today = await testRepo.getTimeSlots('f-test', Sport.badminton, now);
      final started = today.firstWhere((s) => s.hasStarted(now));
      expect(
        () => testRepo.holdSlot(started),
        throwsA(isA<FacilityException>().having((e) => e.message, 'message', FacilityStrings.slotStarted)),
      );
    });
  });

  test('dữ liệu giả hợp lệ: id không trùng, mỗi cơ sở có ít nhất 1 môn', () {
    final ids = MockFacilityData.facilities.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(MockFacilityData.facilities.every((f) => f.offerings.isNotEmpty), isTrue);
  });
}
