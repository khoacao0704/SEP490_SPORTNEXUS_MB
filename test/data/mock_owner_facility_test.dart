import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_facility_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/court_type.dart';
import 'package:test1/models/geo_point.dart';
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

  const profile = FacilityProfile(
    name: 'Sân Mới',
    city: 'Hồ Chí Minh',
    ward: 'Phường Bến Nghé',
    address: '1 Lê Lợi',
    location: GeoPoint(10.77, 106.70),
    licenseNumber: '0311112222',
    licenseImages: ['/tmp/license.jpg'],
  );
  const operations = FacilityOperations(
    phone: '0901234567',
    openMinutes: 6 * 60,
    closeMinutes: 22 * 60,
    images: ['/tmp/court.jpg'],
  );
  const submission = FacilitySubmission(
    profile: profile,
    operations: operations,
    courts: [CourtConfig(sport: Sport.badminton, courtCount: 3)],
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

  test('đăng cơ sở mới phải đủ giấy phép, ảnh, loại sân; gửi xong ở trạng thái chờ duyệt', () async {
    expect(
      () => repo.submitFacility(FacilitySubmission(
        profile: FacilityProfile(
          name: profile.name,
          city: profile.city,
          ward: profile.ward,
          address: profile.address,
          location: profile.location,
          licenseNumber: profile.licenseNumber,
          licenseImages: const [],
        ),
        operations: operations,
        courts: submission.courts,
      )),
      throwsOwner(OwnerFacilityStrings.missingLicenseImage),
    );
    expect(
      () => repo.submitFacility(const FacilitySubmission(profile: profile, operations: operations, courts: [])),
      throwsOwner(OwnerFacilityStrings.missingCourt),
    );
    expect(
      () => repo.submitFacility(const FacilitySubmission(
        profile: profile,
        operations: operations,
        courts: [
          CourtConfig(sport: Sport.badminton, courtCount: 1),
          CourtConfig(sport: Sport.badminton, courtCount: 2),
        ],
      )),
      throwsOwner(OwnerFacilityStrings.duplicateCourt),
    );

    final created = await repo.submitFacility(submission);
    expect(created.status, ApprovalStatus.pending);
    expect(created.courts.single.pricing, isNull);
    expect((await repo.getOwnerFacilities()).first.id, created.id);
    expect((await repo.getMyFacilities()).any((f) => f.id == created.id), isFalse);
  });

  test('chưa duyệt thì chưa cài giá, khung giờ, tạm đóng', () async {
    expect(
      () => repo.saveCourt('f-own-pending', CourtConfig(sport: Sport.pickleball, courtCount: 4, pricing: pricing())),
      throwsOwner(OwnerFacilityStrings.notApproved),
    );
    expect(() => repo.updateOperations('f-own-pending', operations), throwsOwner(OwnerFacilityStrings.notApproved));
    expect(
      () => repo.addClosure('f-own-pending', from: now, to: now, reason: 'x'),
      throwsOwner(OwnerFacilityStrings.notApproved),
    );
  });

  test('hồ sơ bị từ chối được sửa và nộp lại; hồ sơ khác thì không', () async {
    final rejected = await repo.getOwnerFacility('f-own-rejected');
    expect(rejected.rejectReason, isNotNull);

    final again = await repo.resubmitFacility('f-own-rejected', submission);
    expect(again.status, ApprovalStatus.pending);
    expect(again.rejectReason, isNull);
    expect(again.profile.name, 'Sân Mới');

    expect(() => repo.resubmitFacility('f-hcm-hoalu', submission), throwsOwner(OwnerFacilityStrings.notRejected));
  });

  test('đổi tên / địa chỉ / giấy phép cần duyệt lại, trong lúc chờ giữ thông tin cũ', () async {
    final updated = await repo.requestProfileChange('f-hcm-hoalu', profile);
    expect(updated.hasPendingChange, isTrue);
    expect(updated.profile.name, 'Sân Bóng Hoa Lư');
    expect(updated.change!.profile.name, 'Sân Mới');
    expect(
      () => repo.requestProfileChange('f-hcm-hoalu', profile),
      throwsOwner(OwnerFacilityStrings.changeAlreadyPending),
    );
    // Vẫn hiện tên cũ cho bộ chọn cơ sở.
    expect((await repo.getMyFacilities()).map((f) => f.name), contains('Sân Bóng Hoa Lư'));
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

  test('thêm loại sân mới và không giảm số sân con dưới sân đang dùng', () async {
    final added = await repo.saveCourt(
      'f-hcm-thientrieu',
      CourtConfig(sport: Sport.tennis, courtCount: 2, pricing: pricing()),
    );
    expect(added.courts.map((c) => c.sport), contains(Sport.tennis));

    // Kèo LFG đang chơi ở Sân 2 cầu lông.
    final badminton = added.courtFor(Sport.badminton, CourtType.standard)!;
    expect(
      () => repo.saveCourt('f-hcm-thientrieu', badminton.copyWith(courtCount: 1)),
      throwsOwner(OwnerFacilityStrings.courtInUse),
    );
    final more = await repo.saveCourt('f-hcm-thientrieu', badminton.copyWith(courtCount: 8));
    expect(more.courtFor(Sport.badminton, CourtType.standard)!.courtCount, 8);
    expect(await repo.getFreeCourts('OW1001'), hasLength(7)); // 8 sân trừ Sân 2
  });

  test('khóa loại sân: chặn nếu còn lượt đặt; đang khóa không sửa được; mở khóa lại được', () async {
    // Bóng đá 7 người còn lượt OW1003 chưa check-out.
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
    // Thiên Triều hôm nay còn 2 lượt chưa check-out.
    expect(
      () => repo.addClosure('f-hcm-thientrieu', from: now, to: now, reason: 'Bảo trì'),
      throwsOwner(OwnerFacilityStrings.closureBlocked(2)),
    );
    expect(
      () => repo.addClosure('f-hcm-thientrieu', sport: Sport.pickleball, from: now, to: now, reason: ''),
      throwsOwner(OwnerFacilityStrings.missingInfo),
    );

    // Pickleball hôm nay chỉ có lượt đã check-out -> đóng được.
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
