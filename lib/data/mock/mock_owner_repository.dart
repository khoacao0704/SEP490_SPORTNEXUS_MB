import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/booking_rules.dart';
import '../../core/constants/owner_rules.dart';
import '../../core/strings/owner_facility_strings.dart';
import '../../core/strings/owner_finance_strings.dart';
import '../../core/strings/owner_review_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../models/booking.dart' show CancelReason;
import '../../models/owner_booking.dart';
import '../../models/owner_court.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_review.dart';
import '../../models/geo_point.dart';
import '../../models/owner_facility.dart';
import '../../models/owner_finance.dart';
import '../../models/sport.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/owner_repository.dart';
import '../repositories/wallet_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_owner_booking_data.dart';
import 'mock_owner_facility_data.dart';
import 'mock_owner_finance_data.dart';
import 'mock_owner_review_data.dart';
import 'mock_wallet_repository.dart';

/// Bản giả lập [OwnerRepository].
///
/// - Chủ sân demo có Thiên Triều, Hoa Lư (đã duyệt), một hồ sơ chờ duyệt và một hồ sơ bị từ chối.
/// - Đơn và lưới ca mẫu ở [MockOwnerBookingData], tạo theo giờ hiện tại. Tất cả chỉ lưu trong bộ nhớ.
/// - Admin duyệt trên Web nên bản giả lập không tự duyệt: hồ sơ mới nộp nằm ở "Chờ duyệt".
/// - Lệ phí giải đấu cộng vào Ví điểm giả lập của Chủ sân ([wallet]).
/// - Chưa nối với phía Player (tìm sân / đặt sân): khi có BE, cả hai cùng đọc một nguồn.
class MockOwnerRepository implements OwnerRepository {
  final Duration latency;
  final DateTime Function() _now;

  /// ownerId -> cơ sở của chủ sân đó.
  final Map<String, List<OwnerFacility>> _facilities = {};
  int _counter = 0;

  static const String ownerWalletPrefix = 'owner_';

  /// Ví giả lập của Chủ sân (tách với ví người chơi).
  final MockWalletRepository wallet;
  List<RevenueItem>? _revenue;


  /// billId -> thời điểm trả.
  Map<String, DateTime>? _paidFees;
  List<FacilityReview>? _reviews;

  MockOwnerRepository({
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? now,
    MockWalletRepository? wallet,
  })  : _now = now ?? DateTime.now,
        wallet = wallet ??
            MockWalletRepository(latency: Duration.zero, now: now, keyPrefix: ownerWalletPrefix, initialBalance: 3200000);

  @override
  Future<List<Facility>> getMyFacilities() async {
    await _delay();
    return (await _mine()).where((f) => f.isApproved).map((f) => f.toFacility()).toList();
  }

  // ---------------- Vận hành: đơn, lịch, check-in ----------------

  /// Đơn + lưới ca giả lập (chỉ trong bộ nhớ).
  late final MockOwnerBookingData ops = MockOwnerBookingData(_now);

  Future<void> _requireFacility(String facilityId) async {
    if (!(await _myFacilityIds()).contains(facilityId)) throw const OwnerException(OwnerFacilityStrings.notFound);
  }

  Future<OwnerBooking> _myBooking(String bookingId) async {
    final b = ops.find(bookingId);
    await _requireFacility(b.facilityId);
    return b;
  }

  @override
  Future<OwnerBookingPage> getBookings({
    required String facilityId,
    DateTime? date,
    DateTime? from,
    DateTime? to,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 15,
  }) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.page(
      facilityId: facilityId,
      date: date,
      from: from,
      to: to,
      status: status,
      search: search,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<OwnerBooking> getBooking(String bookingId) async {
    await _delay();
    return _myBooking(bookingId);
  }

  @override
  Future<FacilityDaySchedule> getDaySchedule(String facilityId, DateTime date) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.daySchedule(facilityId, date);
  }

  @override
  Future<void> createWalkIn(WalkInRequest request) async {
    await _delay();
    ops.walkIn(request);
  }

  @override
  Future<void> checkInBooking(String bookingId) async {
    await _delay();
    await _myBooking(bookingId);
    ops.checkIn(bookingId);
  }

  @override
  Future<void> endBooking(String bookingId) async {
    await _delay();
    await _myBooking(bookingId);
    ops.end(bookingId);
  }

  @override
  Future<void> setSlotLocked(String slotId, {required bool locked}) async {
    await _delay();
    ops.setLocked(slotId, locked);
  }

  @override
  Future<void> setSlotPrice(String slotId, int price) async {
    await _delay();
    ops.setPrice(slotId, price);
  }

  @override
  Future<ScanResult> scanQr({required String facilityId, required String qrCode}) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.scan(facilityId, qrCode);
  }

  @override
  Future<List<CancelReason>> getCancelReasons() async {
    await _delay();
    return MockOwnerBookingData.cancelReasons;
  }

  /// Bản giả lập: đánh dấu hủy và trả Điểm phạt tính theo [OwnerCancelRules]; không trừ ví giả lập.
  @override
  Future<OwnerCancelResult> cancelBooking(String bookingId, {int? reasonCode, String? reason, bool lockSlot = false}) async {
    await _delay();
    await _myBooking(bookingId);
    return ops.cancel(bookingId, reason: reason, lockSlot: lockSlot);
  }

  // ---------------- Sân & giá, Ca sân ----------------

  @override
  Future<List<SportCategory>> getSports() async {
    await _delay();
    return MockOwnerBookingData.sports;
  }

  @override
  Future<List<OwnerCourt>> getCourts(String facilityId) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.courts(facilityId);
  }

  @override
  Future<OwnerCourt> getCourt(String facilityId, String courtId) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.court(facilityId, courtId);
  }

  @override
  Future<void> createCourt(String facilityId, CourtInput input) async {
    await _delay();
    await _requireFacility(facilityId);
    ops.createCourt(facilityId, input);
  }

  @override
  Future<void> updateCourt(String facilityId, OwnerCourt previous, CourtInput input) async {
    await _delay();
    await _requireFacility(facilityId);
    ops.updateCourt(facilityId, previous.id, input);
  }

  @override
  Future<int> deleteCourt(String facilityId, String courtId) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.deleteCourt(facilityId, courtId);
  }

  @override
  Future<void> regenerateCourtSlots(String courtId) async => _delay();

  @override
  Future<void> updateOpenHours(String facilityId, {required String openTime, required String closeTime}) async {
    await _delay();
    await _requireFacility(facilityId);
    ops.setHours(facilityId, openTime, closeTime);
  }

  @override
  Future<SlotsRange> getSlotsRange(String facilityId, {required DateTime from, required DateTime to}) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.range(facilityId, from, to);
  }

  @override
  Future<FacilityAvailability> getAvailability(String facilityId, DateTime date) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.availability(facilityId, date);
  }

  @override
  Future<List<GenerateResultRow>> generateSlots(
    String facilityId,
    GenerateSlotsRequest request, {
    Map<String, String> courtNames = const {},
  }) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.generate(facilityId, request);
  }

  @override
  Future<BulkSlotResult> bulkSlots(String facilityId, BulkSlotRequest request) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.bulk(facilityId, request);
  }

  @override
  Future<void> deleteSlot(String slotId) async {
    await _delay();
    ops.deleteSlot(slotId);
  }

  @override
  Future<List<PricePeriod>> getPricePeriods(String facilityId, {DateTime? from, DateTime? to}) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.periods(facilityId, from: from);
  }

  @override
  Future<PricePeriodResult> savePricePeriod(String facilityId, PricePeriod period) async {
    await _delay();
    await _requireFacility(facilityId);
    return ops.savePeriod(facilityId, period);
  }

  @override
  Future<void> deletePricePeriod(String facilityId, String periodId) async {
    await _delay();
    ops.deletePeriod(facilityId, periodId);
  }

  // ---------------- Quản lý cơ sở & sân ----------------

  @override
  Future<List<OwnerFacility>> getOwnerFacilities() async {
    await _delay();
    return List.of(await _mine());
  }

  @override
  Future<OwnerFacility> getOwnerFacility(String facilityId) async {
    await _delay();
    return _facility(await _mine(), facilityId);
  }

  // ---------------- Cơ sở của tôi (giống Web) ----------------

  static const List<FacilityAmenity> amenities = [
    FacilityAmenity(id: 'am-parking', name: 'Bãi đỗ xe'),
    FacilityAmenity(id: 'am-shower', name: 'Phòng tắm'),
    FacilityAmenity(id: 'am-locker', name: 'Tủ đồ'),
    FacilityAmenity(id: 'am-wifi', name: 'Wifi'),
    FacilityAmenity(id: 'am-canteen', name: 'Căn tin'),
  ];

  static const List<AreaOption> provinces = [
    AreaOption(code: '79', name: 'Hồ Chí Minh'),
    AreaOption(code: '01', name: 'Hà Nội'),
    AreaOption(code: '48', name: 'Đà Nẵng'),
  ];

  static const Map<String, List<AreaOption>> wards = {
    '79': [
      AreaOption(code: '26734', name: 'Phường Sài Gòn'),
      AreaOption(code: '26737', name: 'Phường Tân Định'),
      AreaOption(code: '26740', name: 'Phường Thạnh Mỹ Tây'),
      AreaOption(code: '26743', name: 'Phường Tân Sơn Hòa'),
      AreaOption(code: '26746', name: 'Phường Hòa Hưng'),
    ],
    '01': [AreaOption(code: '00004', name: 'Phường Ba Đình'), AreaOption(code: '00008', name: 'Phường Hoàn Kiếm')],
    '48': [AreaOption(code: '20194', name: 'Phường Hải Châu'), AreaOption(code: '20197', name: 'Phường Sơn Trà')],
  };


  @override
  Future<List<FacilityAmenity>> getAmenities() async {
    await _delay();
    return amenities;
  }

  @override
  Future<List<AreaOption>> getProvinces() async {
    await _delay();
    return provinces;
  }

  @override
  Future<List<AreaOption>> getWards(String provinceCode) async {
    await _delay();
    return wards[provinceCode] ?? const [];
  }

  static String _nameOf(List<AreaOption> list, String code) =>
      list.where((a) => a.code == code).firstOrNull?.name ?? '—';

  OwnerFacility _withInput(OwnerFacility base, FacilityInput input) {
    final city = _nameOf(provinces, input.provinceCode);
    final ward = _nameOf(wards[input.provinceCode] ?? const [], input.wardCode);
    final location = input.latitude != null && input.longitude != null
        ? GeoPoint(input.latitude!, input.longitude!)
        : base.profile.location;
    return OwnerFacility(
      id: base.id,
      status: base.status,
      profile: FacilityProfile(
        name: input.name,
        city: city,
        ward: ward,
        address: '${input.streetAddress}, $ward, $city',
        location: location,
        licenseNumber: base.profile.licenseNumber,
        licenseImages: base.profile.licenseImages,
      ),
      operations: FacilityOperations(
        phone: input.phone ?? '',
        openMinutes: parseMinutes(input.openTime),
        closeMinutes: parseMinutes(input.closeTime),
        description: input.description ?? '',
        amenities: base.operations.amenities,
        rules: (input.rules ?? '').split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList(),
        images: base.operations.images,
      ),
      courts: base.courts,
      closures: base.closures,
      submittedAt: base.submittedAt,
      rejectReason: base.rejectReason,
      rating: base.rating,
      reviewCount: base.reviewCount,
      recurringDiscountPercent: input.recurringDiscountPercent,
      isSuspended: base.isSuspended,
      streetAddress: input.streetAddress,
      provinceCode: input.provinceCode,
      wardCode: input.wardCode,
      autoGenerateSlots: input.autoGenerateSlots,
      isLocked: base.isLocked,
      lockedReason: base.lockedReason,
      photos: base.photos,
      amenityItems: base.amenityItems,
      courtCount: base.courtCount,
    );
  }

  void _validateInput(FacilityInput input) {
    if (input.name.trim().isEmpty) throw const OwnerException(OwnerFacilityStrings.errName);
    if (input.streetAddress.trim().isEmpty || input.provinceCode.isEmpty || input.wardCode.isEmpty) {
      throw const OwnerException(OwnerFacilityStrings.errAddress);
    }
    if (parseMinutes(input.closeTime) <= parseMinutes(input.openTime)) {
      throw const OwnerException(OwnerFacilityStrings.errHours);
    }
  }

  @override
  Future<OwnerFacility> createFacility(FacilityInput input) async {
    await _delay();
    _validateInput(input);
    final mine = await _mine();
    final blank = OwnerFacility(
      id: 'f-own-${_now().millisecondsSinceEpoch}-${++_counter}',
      status: ApprovalStatus.pending,
      profile: const FacilityProfile(
        name: '',
        city: '',
        ward: '',
        address: '',
        location: GeoPoint(10.7769, 106.7009),
        licenseNumber: '',
        licenseImages: [],
      ),
      operations: const FacilityOperations(phone: '', openMinutes: 360, closeMinutes: 1320),
      courts: const [],
      submittedAt: _now(),
    );
    final created = _withInput(blank, input).copyWith(
      amenityItems: [for (final a in amenities) if (input.amenityIds.contains(a.id)) a],
    );
    mine.insert(0, created);
    return created;
  }

  @override
  Future<OwnerFacility> updateFacility(String facilityId, FacilityInput input) async {
    await _delay();
    _validateInput(input);
    final mine = await _mine();
    return _save(mine, _withInput(_facility(mine, facilityId), input));
  }

  @override
  Future<void> deleteFacility(String facilityId) async {
    await _delay();
    final mine = await _mine();
    _facility(mine, facilityId);
    final upcoming = ops.activeBookingsIn(facilityId, _now(), DateTime(9999));
    if (upcoming > 0) throw OwnerException(OwnerFacilityStrings.closeBlocked(upcoming));
    mine.removeWhere((f) => f.id == facilityId);
  }

  List<FacilityPhoto> _photosOf(OwnerFacility f) => f.photos.isNotEmpty
      ? f.photos
      : [
          for (var i = 0; i < f.operations.images.length; i++)
            FacilityPhoto(id: '${f.id}-img-$i', url: f.operations.images[i], isThumbnail: i == 0),
        ];

  OwnerFacility _savePhotos(List<OwnerFacility> mine, OwnerFacility f, List<FacilityPhoto> photos) {
    final list = [...photos];
    if (list.isNotEmpty && !list.any((p) => p.isThumbnail)) {
      list[0] = FacilityPhoto(id: list[0].id, url: list[0].url, isThumbnail: true);
    }
    return _save(
      mine,
      f.copyWith(photos: list, operations: f.operations.copyWithImages([for (final p in list) p.url])),
    );
  }

  @override
  Future<void> uploadFacilityPhotos(String facilityId, List<String> filePaths) async {
    await _delay();
    final mine = await _mine();
    final f = _facility(mine, facilityId);
    final photos = _photosOf(f);
    if (photos.length + filePaths.length > OwnerFacilityStrings.maxPhotos) {
      throw OwnerException(OwnerFacilityStrings.tooManyPhotos(OwnerFacilityStrings.maxPhotos));
    }
    _savePhotos(mine, f, [
      ...photos,
      for (final p in filePaths) FacilityPhoto(id: 'img-${++_counter}', url: p),
    ]);
  }

  @override
  Future<void> deleteFacilityPhoto(String facilityId, String photoId) async {
    await _delay();
    final mine = await _mine();
    final f = _facility(mine, facilityId);
    _savePhotos(mine, f, _photosOf(f).where((p) => p.id != photoId).toList());
  }

  @override
  Future<void> setFacilityThumbnail(String facilityId, String photoId) async {
    await _delay();
    final mine = await _mine();
    final f = _facility(mine, facilityId);
    _savePhotos(mine, f, [
      for (final p in _photosOf(f)) FacilityPhoto(id: p.id, url: p.url, isThumbnail: p.id == photoId),
    ]);
  }

  @override
  Future<void> updateFacilityAmenities(String facilityId, List<String> amenityIds) async {
    await _delay();
    final mine = await _mine();
    final f = _facility(mine, facilityId);
    final items = [for (final a in amenities) if (amenityIds.contains(a.id)) a];
    _save(mine, f.copyWith(amenityItems: items, operations: f.operations.copyWithAmenities([for (final a in items) a.name])));
  }

  @override
  Future<OwnerFacility> updateRecurringDiscount(String facilityId, int percent) async {
    await _delay();
    if (percent < 0 || percent > RecurringBookingRules.maxDiscountPercent) {
      throw const OwnerException(OwnerFacilityStrings.discountOutOfRange);
    }
    final mine = await _mine();
    final f = _facility(mine, facilityId);
    // Như BE: cơ sở bị từ chối, sửa gì cũng chuyển về chờ duyệt lại.
    return _save(
      mine,
      f.copyWith(
        recurringDiscountPercent: percent,
        status: f.status == ApprovalStatus.rejected ? ApprovalStatus.pending : null,
      ),
    );
  }

  @override
  Future<OwnerFacility> saveCourt(String facilityId, CourtConfig court) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    if (f.courtFor(court.sport, court.courtType)?.isLocked ?? false) {
      throw const OwnerException(OwnerFacilityStrings.courtLocked);
    }
    if (court.courtCount < 1) throw const OwnerException(OwnerFacilityStrings.invalidCourtCount);
    final p = court.pricing;
    if (p != null) {
      if ([p.weekdayPrice, p.weekdayPeakPrice, p.weekendPrice, p.weekendPeakPrice].any((x) => x <= 0)) {
        throw const OwnerException(OwnerFacilityStrings.invalidPrice);
      }
      if (p.peakEnd <= p.peakStart ||
          p.peakStart < f.operations.openMinutes ||
          p.peakEnd > f.operations.closeMinutes) {
        throw const OwnerException(OwnerFacilityStrings.invalidPeak);
      }
    }

    final exists = f.courtFor(court.sport, court.courtType) != null;
    return _save(
      mine,
      f.copyWith(
        courts: exists
            ? [for (final c in f.courts) c.sameKind(court.sport, court.courtType) ? court : c]
            : [...f.courts, court],
      ),
    );
  }

  @override
  Future<OwnerFacility> lockCourt(String facilityId, Sport sport, CourtType courtType) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    final court = f.courtFor(sport, courtType);
    if (court == null) throw const OwnerException(OwnerFacilityStrings.notFound);
    if (court.isLocked) throw const OwnerException(OwnerFacilityStrings.courtLocked);

    final now = _now();
    final upcoming = ops.activeBookingsIn(facilityId, now, DateTime(9999), sportLabel: sport.label);
    if (upcoming > 0) throw OwnerException(OwnerFacilityStrings.lockBlocked(upcoming));

    return _save(
      mine,
      f.copyWith(courts: [for (final c in f.courts) c.sameKind(sport, courtType) ? c.copyWith(lockedAt: now) : c]),
    );
  }

  @override
  Future<OwnerFacility> unlockCourt(String facilityId, Sport sport, CourtType courtType) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    final court = f.courtFor(sport, courtType);
    if (court == null) throw const OwnerException(OwnerFacilityStrings.notFound);
    if (!court.isLocked) throw const OwnerException(OwnerFacilityStrings.notLocked);
    return _save(
      mine,
      f.copyWith(courts: [for (final c in f.courts) c.sameKind(sport, courtType) ? c.copyWith(unlock: true) : c]),
    );
  }

  @override
  Future<OwnerFacility> addClosure(
    String facilityId, {
    Sport? sport,
    CourtType? courtType,
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    if (reason.trim().isEmpty || to.isBefore(from)) throw const OwnerException(OwnerFacilityStrings.missingInfo);

    final closure = FacilityClosure(
      id: 'cl-${_now().millisecondsSinceEpoch}-${++_counter}',
      sport: sport,
      courtType: sport == null ? null : (courtType ?? CourtType.standard),
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      reason: reason.trim(),
    );
    final booked = ops.activeBookingsIn(
      facilityId,
      closure.from,
      DateTime(closure.to.year, closure.to.month, closure.to.day + 1),
      sportLabel: sport?.label,
    );
    if (booked > 0) throw OwnerException(OwnerFacilityStrings.closureBlocked(booked));
    return _save(mine, f.copyWith(closures: [...f.closures, closure]));
  }

  @override
  Future<OwnerFacility> removeClosure(String facilityId, String closureId) async {
    await _delay();
    final mine = await _mine();
    final f = _requireApproved(mine, facilityId);
    return _save(mine, f.copyWith(closures: f.closures.where((c) => c.id != closureId).toList()));
  }

  // ---------------- Doanh thu & phí duy trì ----------------

  @override
  Future<MonthlyRevenue> getMonthlyRevenue(DateTime month, {String? facilityId}) async {
    await _delay();
    final ids = await _myFacilityIds();
    return MonthlyRevenue(
      month: DateTime(month.year, month.month, 1),
      items: _revenueItems()
          .where((i) => ids.contains(i.facilityId) && (facilityId == null || i.facilityId == facilityId))
          .where((i) => i.date.year == month.year && i.date.month == month.month)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  @override
  Future<List<ListingFeeBill>> getListingFees() async {
    await _delay();
    return _bills(await _myFacilityIds());
  }

  @override
  Future<ListingFeeBill> payListingFee(String billId) async {
    await _delay();
    final bill = _bills(await _myFacilityIds()).where((b) => b.id == billId).firstOrNull;
    if (bill == null) throw const OwnerException(OwnerFinanceStrings.billNotFound);
    if (bill.paidAt != null) throw const OwnerException(OwnerFinanceStrings.alreadyPaid);
    try {
      await wallet.pay(
        amount: bill.amount,
        type: TransactionType.listingFee,
        description: 'Phí duy trì ${OwnerFinanceStrings.monthShort(bill.month)}',
        reference: bill.id,
      );
    } on WalletException catch (e) {
      throw OwnerException(e.message);
    }
    final now = _now();
    _fees()[bill.id] = now;
    return bill.copyWith(paidAt: now);
  }

  /// Lệ phí giải đấu về Ví điểm Chủ sân khi giải kết thúc và tính vào doanh thu.
  /// Chỉ bản giả lập giải đấu gọi; bản thật do BE tự làm.
  Future<void> recordTournamentPayout({
    required String tournamentId,
    required String tournamentName,
    required String facilityId,
    required String facilityName,
    required int amount,
  }) async {
    if (amount <= 0) return;
    _revenueItems().add(RevenueItem(
      id: 'rv-tour-$tournamentId',
      date: _now(),
      facilityId: facilityId,
      facilityName: facilityName,
      kind: RevenueKind.tournamentFee,
      amount: amount,
      viaApp: amount,
      description: 'Lệ phí giải $tournamentName',
    ));
    await wallet.credit(
      type: TransactionType.escrowRelease,
      amount: amount,
      description: 'Lệ phí giải $tournamentName',
      reference: tournamentId,
    );
  }

  // ---------------- Đánh giá ----------------

  @override
  Future<List<FacilityReview>> getFacilityReviews({String? facilityId}) async {
    await _delay();
    final ids = await _myFacilityIds();
    return _allReviews()
        .where((r) => ids.contains(r.facilityId) && (facilityId == null || r.facilityId == facilityId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<FacilityReview> replyToReview(String reviewId, String text) async {
    await _delay();
    final review = await _findReview(reviewId);
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const OwnerException(OwnerReviewStrings.replyEmpty);
    if (!review.canReply) throw const OwnerException(OwnerReviewStrings.cannotReplyHidden);
    final cut = trimmed.length > OwnerReviewStrings.replyMaxLength
        ? trimmed.substring(0, OwnerReviewStrings.replyMaxLength)
        : trimmed;
    return _saveReview(review.copyWith(reply: ReviewReply(text: cut, updatedAt: _now())));
  }

  @override
  Future<FacilityReview> reportReview(String reviewId, ReportReason reason, {String note = ''}) async {
    await _delay();
    final review = await _findReview(reviewId);
    if (!review.canReport) throw const OwnerException(OwnerReviewStrings.alreadyReported);
    return _saveReview(
      review.copyWith(report: ReviewReport(reason: reason, note: note.trim(), createdAt: _now())),
    );
  }

  List<FacilityReview> _allReviews() => _reviews ??= MockOwnerReviewData.seed(_now());

  Future<FacilityReview> _findReview(String reviewId) async {
    final ids = await _myFacilityIds();
    final r = _allReviews().where((r) => r.id == reviewId && ids.contains(r.facilityId)).firstOrNull;
    if (r == null) throw const OwnerException(OwnerReviewStrings.notFound);
    return r;
  }

  FacilityReview _saveReview(FacilityReview updated) {
    final list = _allReviews();
    list[list.indexWhere((r) => r.id == updated.id)] = updated;
    return updated;
  }

  List<RevenueItem> _revenueItems() => _revenue ??= [
        ...MockOwnerFinanceData.seed(_now()),
      ];

  /// Mặc định: phí tháng đầu tiên đã trả, các tháng sau chưa trả.
  Map<String, DateTime> _fees() {
    final first = MockOwnerFinanceData.firstMonth(_now());
    return _paidFees ??= {_billId(first): DateTime(first.year, first.month + 1, 3, 9)};
  }

  static String _billId(DateTime month) => 'fee-${month.year}-${month.month.toString().padLeft(2, '0')}';

  /// Hóa đơn cho các tháng đã kết thúc, mới nhất trước.
  List<ListingFeeBill> _bills(Set<String> facilityIds) {
    final now = _now();
    final current = DateTime(now.year, now.month, 1);
    final items = _revenueItems().where((i) => facilityIds.contains(i.facilityId)).toList();
    if (items.isEmpty) return [];
    final earliest = items.map((i) => i.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final bills = <ListingFeeBill>[];
    for (var m = DateTime(earliest.year, earliest.month, 1); m.isBefore(current); m = DateTime(m.year, m.month + 1, 1)) {
      final revenue = items
          .where((i) => i.date.year == m.year && i.date.month == m.month)
          .fold(0, (sum, i) => sum + i.amount);
      final id = _billId(m);
      bills.add(ListingFeeBill(
        id: id,
        month: m,
        revenue: revenue,
        amount: ListingFeeRules.feeFor(revenue),
        paidAt: _fees()[id],
      ));
    }
    return bills.reversed.toList();
  }

  // ---------------------------------------------------------------------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<String> _requireOwnerId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) throw const OwnerException(OwnerStrings.loginRequired);
    return (jsonDecode(raw) as Map<String, dynamic>)['id'] as String;
  }

  /// Cơ sở của chủ sân đang đăng nhập (danh sách sửa trực tiếp được).
  Future<List<OwnerFacility>> _mine() async {
    final ownerId = await _requireOwnerId();
    return _facilities.putIfAbsent(
      ownerId,
      () => ownerId == MockAuthRepository.ownerId ? MockOwnerFacilityData.seed(_now()) : [],
    );
  }

  /// Lượt sân chỉ thuộc cơ sở đã duyệt.
  Future<Set<String>> _myFacilityIds() async =>
      (await _mine()).where((f) => f.isApproved).map((f) => f.id).toSet();

  OwnerFacility _facility(List<OwnerFacility> mine, String id) {
    final f = mine.where((f) => f.id == id).firstOrNull;
    if (f == null) throw const OwnerException(OwnerFacilityStrings.notFound);
    return f;
  }

  OwnerFacility _requireApproved(List<OwnerFacility> mine, String id) {
    final f = _facility(mine, id);
    if (!f.isApproved) throw const OwnerException(OwnerFacilityStrings.notApproved);
    return f;
  }

  OwnerFacility _save(List<OwnerFacility> mine, OwnerFacility updated) {
    mine[mine.indexWhere((f) => f.id == updated.id)] = updated;
    return updated;
  }
}
