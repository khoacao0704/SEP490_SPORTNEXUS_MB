import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/court_type.dart';
import 'package:test1/models/owner_facility.dart';
import 'package:test1/models/sport.dart';

void main() {
  // Thứ 4, 15/10/2026 15:00.
  final now = DateTime(2026, 10, 15, 15, 0);
  late MockOwnerRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MockAuthRepository(latency: Duration.zero).login('owner@sportnexus.vn', 'Owner@123');
    repo = MockOwnerRepository(latency: Duration.zero, now: () => now);
  });

  Matcher throwsOwner(String message) =>
      throwsA(isA<OwnerException>().having((e) => e.message, 'message', message));

  const input = FacilityInput(
    name: 'Sân Mới',
    streetAddress: '1 Lê Lợi',
    provinceCode: '79',
    wardCode: '26734',
    latitude: 10.77,
    longitude: 106.70,
    phone: '0901234567',
    rules: 'Mang giày thể thao\nKhông hút thuốc',
    recurringDiscountPercent: 15,
    amenityIds: ['am-parking', 'am-wifi'],
  );

  CourtPricing pricing({int peakStart = 17 * 60, int peakEnd = 21 * 60, int price = 100000}) => CourtPricing(
        slotMinutes: 60,
        peakStart: peakStart,
        peakEnd: peakEnd,
        weekdayPrice: price,
        weekdayPeakPrice: price + 40000,
        weekendPrice: price + 20000,
        weekendPeakPrice: price + 60000,
      );

  test('bộ chọn cơ sở chỉ có cơ sở đã duyệt; tab Cơ sở có cả hồ sơ chờ / bị từ chối', () async {
    final all = await repo.getOwnerFacilities();
    expect(all.map((f) => f.status), [
      ApprovalStatus.approved,
      ApprovalStatus.approved,
      ApprovalStatus.pending,
      ApprovalStatus.rejected,
    ]);
    expect((await repo.getMyFacilities()).map((f) => f.id), ['f-hcm-thientrieu', 'f-hcm-hoalu']);
  });

  test('tạo cơ sở như Web: địa chỉ lưu bằng mã tỉnh / phường, chờ Admin duyệt, kèm tiện ích', () async {
    await expectLater(
      repo.createFacility(const FacilityInput(name: ' ', streetAddress: 'x', provinceCode: '79', wardCode: '26734')),
      throwsOwner(OwnerFacilityStrings.errName),
    );
    await expectLater(
      repo.createFacility(const FacilityInput(name: 'A', streetAddress: '', provinceCode: '79', wardCode: '26734')),
      throwsOwner(OwnerFacilityStrings.errAddress),
    );
    await expectLater(
      repo.createFacility(const FacilityInput(
          name: 'A', streetAddress: 'x', provinceCode: '79', wardCode: '26734', openTime: '22:00', closeTime: '06:00')),
      throwsOwner(OwnerFacilityStrings.errHours),
    );

    final created = await repo.createFacility(input);
    expect(created.status, ApprovalStatus.pending);
    expect(created.profile.address, '1 Lê Lợi, Phường Sài Gòn, Hồ Chí Minh');
    expect(created.provinceCode, '79');
    expect(created.operations.rules, ['Mang giày thể thao', 'Không hút thuốc']);
    expect(created.recurringDiscountPercent, 15);
    expect(created.amenityItems.map((a) => a.id), ['am-parking', 'am-wifi']);
    expect((await repo.getOwnerFacilities()).first.id, created.id);
    expect((await repo.getMyFacilities()).any((f) => f.id == created.id), isFalse);
  });

  test('sửa thông tin lưu thẳng (không qua yêu cầu duyệt lại)', () async {
    final updated = await repo.updateFacility(
      'f-hcm-hoalu',
      const FacilityInput(name: 'Hoa Lư Arena', streetAddress: '2 Đinh Tiên Hoàng', provinceCode: '79', wardCode: '26737'),
    );
    expect(updated.profile.name, 'Hoa Lư Arena');
    expect(updated.profile.ward, 'Phường Tân Định');
    expect(updated.status, ApprovalStatus.approved);
    expect((await repo.getMyFacilities()).map((f) => f.name), contains('Hoa Lư Arena'));
  });

  test('ảnh: thêm, đặt đại diện, xóa; tối đa 10 ảnh', () async {
    await repo.uploadFacilityPhotos('f-own-pending', ['/tmp/a.jpg', '/tmp/b.jpg']);
    var f = await repo.getOwnerFacility('f-own-pending');
    final before = f.photos.length;
    expect(f.photos.where((p) => p.isThumbnail), hasLength(1));
    final second = f.photos.last;
    await repo.setFacilityThumbnail('f-own-pending', second.id);
    f = await repo.getOwnerFacility('f-own-pending');
    expect(f.photos.singleWhere((p) => p.isThumbnail).id, second.id);
    await repo.deleteFacilityPhoto('f-own-pending', second.id);
    f = await repo.getOwnerFacility('f-own-pending');
    expect(f.photos, hasLength(before - 1));
    expect(f.photos.where((p) => p.isThumbnail), hasLength(1), reason: 'xóa ảnh đại diện thì ảnh đầu thành đại diện');
    await expectLater(
      repo.uploadFacilityPhotos('f-own-pending', List.filled(11, '/tmp/x.jpg')),
      throwsOwner(OwnerFacilityStrings.tooManyPhotos(10)),
    );
  });

  test('tiện ích lưu riêng', () async {
    await repo.updateFacilityAmenities('f-hcm-hoalu', ['am-shower']);
    final f = await repo.getOwnerFacility('f-hcm-hoalu');
    expect(f.amenityItems.single.name, 'Phòng tắm');
    expect(f.operations.amenities, ['Phòng tắm']);
  });

  test('đóng cơ sở: còn đơn sắp tới thì chặn; không có đơn thì đóng được', () async {
    await expectLater(repo.deleteFacility('f-hcm-thientrieu'), throwsA(isA<OwnerException>()));
    await repo.deleteFacility('f-own-pending');
    expect((await repo.getOwnerFacilities()).any((f) => f.id == 'f-own-pending'), isFalse);
  });

  test('chưa duyệt thì chưa cài giá loại sân, tạm đóng', () async {
    expect(
      () => repo.saveCourt('f-own-pending', CourtConfig(sport: Sport.pickleball, courtCount: 4, pricing: pricing())),
      throwsOwner(OwnerFacilityStrings.notApproved),
    );
    expect(
      () => repo.addClosure('f-own-pending', from: now, to: now, reason: 'x'),
      throwsOwner(OwnerFacilityStrings.notApproved),
    );
  });

  test('cài giá & khung giờ cho loại sân chưa có giá', () async {
    final hoaLu = await repo.getOwnerFacility('f-hcm-hoalu');
    final half = hoaLu.courtFor(Sport.basketball, CourtType.basketballHalf)!;
    expect(half.pricing, isNull);

    expect(
      () => repo.saveCourt('f-hcm-hoalu', half.copyWith(pricing: pricing(peakStart: 5 * 60))),
      throwsOwner(OwnerFacilityStrings.invalidPeak), // mở cửa 06:00
    );
    expect(
      () => repo.saveCourt('f-hcm-hoalu', half.copyWith(pricing: pricing(price: 0))),
      throwsOwner(OwnerFacilityStrings.invalidPrice),
    );

    final saved = await repo.saveCourt('f-hcm-hoalu', half.copyWith(pricing: pricing()));
    final p = saved.courtFor(Sport.basketball, CourtType.basketballHalf)!.pricing!;
    final wednesday = DateTime(2026, 10, 14);
    final saturday = DateTime(2026, 10, 17);
    expect(p.priceAt(wednesday, 8 * 60), 100000);
    expect(p.priceAt(wednesday, 18 * 60), 140000);
    expect(p.priceAt(saturday, 8 * 60), 120000);
    expect(p.priceAt(saturday, 20 * 60), 160000);
    expect(p.priceAt(saturday, 21 * 60), 120000); // 21:00 hết cao điểm

    // 06:00 - 23:00, khung 60 phút -> 17 khung.
    expect(saved.courtFor(Sport.basketball, CourtType.basketballHalf)!.slotStarts(6 * 60, 23 * 60), hasLength(17));
  });

  test('khung 90 phút chỉ tạo khung kết thúc trước giờ đóng cửa', () async {
    final hoaLu = await repo.getOwnerFacility('f-hcm-hoalu');
    final starts = hoaLu.courtFor(Sport.football, CourtType.football5)!.slotStarts(6 * 60, 23 * 60);
    expect(starts.first, 6 * 60);
    expect(starts.last, 21 * 60);
    expect(starts, hasLength(11));
  });

  test('thêm loại sân mới, đổi số sân con', () async {
    final added = await repo.saveCourt(
      'f-hcm-thientrieu',
      CourtConfig(sport: Sport.tennis, courtCount: 2, pricing: pricing()),
    );
    expect(added.courts.map((c) => c.sport), contains(Sport.tennis));

    // Chặn giảm sân con đang có đơn: đợt 2 làm lại theo sân con của Web.
    final badminton = added.courtFor(Sport.badminton, CourtType.standard)!;
    final more = await repo.saveCourt('f-hcm-thientrieu', badminton.copyWith(courtCount: 8));
    expect(more.courtFor(Sport.badminton, CourtType.standard)!.courtCount, 8);
  });

  test('khóa loại sân: chặn nếu còn lượt đặt; đang khóa không sửa được; mở khóa lại được', () async {
    // Hoa Lư còn đơn bóng đá OW1004 chưa diễn ra.
    expect(
      () => repo.lockCourt('f-hcm-hoalu', Sport.football, CourtType.football7),
      throwsOwner(OwnerFacilityStrings.lockBlocked(1)),
    );

    final locked = await repo.lockCourt('f-hcm-hoalu', Sport.basketball, CourtType.basketballFull);
    final court = locked.courtFor(Sport.basketball, CourtType.basketballFull)!;
    expect(court.isLocked, isTrue);
    expect(locked.bookableCourts.any((c) => c.sameKind(Sport.basketball, CourtType.basketballFull)), isFalse);
    expect(
      locked.toFacility().offerings.any((o) => o.courtType == CourtType.basketballFull),
      isFalse,
    );

    expect(
      () => repo.lockCourt('f-hcm-hoalu', Sport.basketball, CourtType.basketballFull),
      throwsOwner(OwnerFacilityStrings.courtLocked),
    );
    expect(
      () => repo.saveCourt('f-hcm-hoalu', court.copyWith(courtCount: 2)),
      throwsOwner(OwnerFacilityStrings.courtLocked),
    );

    final reopened = await repo.unlockCourt('f-hcm-hoalu', Sport.basketball, CourtType.basketballFull);
    expect(reopened.courtFor(Sport.basketball, CourtType.basketballFull)!.isLocked, isFalse);
    expect(reopened.bookableCourts.any((c) => c.sameKind(Sport.basketball, CourtType.basketballFull)), isTrue);
    expect(
      () => repo.unlockCourt('f-hcm-hoalu', Sport.basketball, CourtType.basketballFull),
      throwsOwner(OwnerFacilityStrings.notLocked),
    );
  });

  test('tạm đóng bị chặn nếu khoảng ngày đã có lượt đặt', () async {
    // Thiên Triều hôm nay còn 4 đơn hiệu lực (đang chơi, đã thanh toán, vãng lai, chờ góp tiền).
    expect(
      () => repo.addClosure('f-hcm-thientrieu', from: now, to: now, reason: 'Bảo trì'),
      throwsOwner(OwnerFacilityStrings.closureBlocked(4)),
    );
    expect(
      () => repo.addClosure('f-hcm-thientrieu', sport: Sport.pickleball, from: now, to: now, reason: ''),
      throwsOwner(OwnerFacilityStrings.missingInfo),
    );

    // Pickleball không có đơn nào -> đóng được.
    final closed = await repo.addClosure(
      'f-hcm-thientrieu',
      sport: Sport.pickleball,
      from: now,
      to: now.add(const Duration(days: 2)),
      reason: 'Sơn lại sân',
    );
    final closure = closed.closures.single;
    expect(closure.courtType, CourtType.standard);
    expect(closure.blocks(Sport.pickleball, CourtType.standard, DateTime(2026, 10, 17, 8), DateTime(2026, 10, 17, 9)), isTrue);
    expect(closure.blocks(Sport.badminton, CourtType.standard, DateTime(2026, 10, 16, 8), DateTime(2026, 10, 16, 9)), isFalse);
    expect(closure.blocks(Sport.pickleball, CourtType.standard, DateTime(2026, 10, 18, 8), DateTime(2026, 10, 18, 9)), isFalse);

    final reopened = await repo.removeClosure('f-hcm-thientrieu', closure.id);
    expect(reopened.closures, isEmpty);
  });
}
