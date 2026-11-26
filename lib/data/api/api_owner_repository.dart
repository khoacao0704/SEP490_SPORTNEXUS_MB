import '../../core/constants/owner_rules.dart';
import '../../core/strings/owner_strings.dart';
import '../../models/booking.dart' show CancelReason;
import '../../models/owner_booking.dart';
import '../../models/owner_complaint.dart';
import '../../models/owner_dashboard.dart';
import '../../models/owner_promotion.dart';
import '../../models/owner_shop.dart';
import '../../models/owner_court.dart';
import '../../core/strings/owner_review_strings.dart';
import '../../core/strings/owner_slot_strings.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_review.dart';             // ← ReportReason is here
import '../../models/geo_point.dart';
import '../../models/owner_facility.dart';
import '../../models/owner_finance.dart';
import '../../models/sport.dart';
import '../repositories/owner_repository.dart';
import 'api_client.dart';

/// OwnerRepository gọi Backend thật.
/// Đã nối: cơ sở, vận hành (đơn, lưới lịch, vãng lai, check-in, kết thúc ca, khóa/đổi giá ca, quét QR, hủy đơn).
/// Các hàm còn lại tạm báo "đang phát triển" — nối theo từng đợt.
class ApiOwnerRepository implements OwnerRepository {
  final ApiClient _api;

  ApiOwnerRepository(this._api);

  // ==================== A. Facilities list ====================

  @override
  Future<List<OwnerFacility>> getOwnerFacilities() async {
    try {
      final data = await _api.get('/api/v1/facilities/my-facilities');
      return _parseList(data);
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
  }

  @override
  Future<List<Facility>> getMyFacilities() async {
    final all = await getOwnerFacilities();
    return all.where((f) => f.isApproved).map((f) => f.toFacility()).toList();
  }

  @override
  Future<List<FacilityAmenity>> getAmenities() => _run(() async => [
        for (final e in _listOf(await _api.get('/api/v1/master-data/amenities')).whereType<Map>())
          FacilityAmenity(id: '${e['id'] ?? ''}', name: '${e['name'] ?? ''}'),
      ]);

  @override
  Future<OwnerFacility> getOwnerFacility(String facilityId) async {
    try {
      final data = await _api.get('/api/v1/facilities/$facilityId');
      if (data is! Map<String, dynamic>) {
        throw const OwnerException(OwnerStrings.loadError);
      }
      return _mapOwnerFacility(data);
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
  }

  // ---------------- Mapping helpers ----------------

  List<OwnerFacility> _parseList(dynamic data) {
    if (data == null) return [];
    final list = data is List ? data : (data is Map && data['items'] is List ? data['items'] as List : null);
    if (list == null) return [];
    return list
        .whereType<Map>()
        .map((e) => _mapOwnerFacility(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// FacilityResponse của BE → OwnerFacility (theo cách Web đọc: streetAddress + provinceName/wardName,
  /// imageItems có id / ảnh bìa, amenities là object, rules là chuỗi nhiều dòng).
  OwnerFacility _mapOwnerFacility(Map<String, dynamic> json) {
    String s(Object? v) => (v ?? '').toString().trim();
    final id = s(json['id'] ?? json['facilityId']);
    final street = json.containsKey('streetAddress') ? s(json['streetAddress']) : null;
    final city = s(json['provinceName'] ?? json['city'] ?? json['province']);
    final ward = s(json['wardName'] ?? json['ward'] ?? json['district']);
    final address = street != null
        ? [street, ward, city].where((p) => p.isNotEmpty).join(', ')
        : s(json['address']);

    final lat = (json['latitude'] as num?)?.toDouble() ??
        (json['location'] is Map ? (json['location']['latitude'] as num?)?.toDouble() : null) ??
        0.0;
    final lng = (json['longitude'] as num?)?.toDouble() ??
        (json['location'] is Map ? (json['location']['longitude'] as num?)?.toDouble() : null) ??
        0.0;

    final photos = [
      for (final e in (json['imageItems'] as List? ?? const []).whereType<Map>())
        FacilityPhoto(id: s(e['id']), url: s(e['url']), isThumbnail: e['isThumbnail'] == true),
    ];
    final imageUrls = photos.isNotEmpty ? [for (final p in photos) p.url] : _stringList(json['imageUrls'] ?? json['images']);
    final amenityItems = [
      for (final e in (json['amenities'] as List? ?? const []))
        if (e is Map) FacilityAmenity(id: s(e['id']), name: s(e['name'])) else FacilityAmenity(id: '', name: '$e'),
    ];
    final rulesRaw = json['rules'];
    final rules = rulesRaw is List
        ? _stringList(rulesRaw)
        : s(rulesRaw).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final discount = json['recurringDiscountPercent'] as num? ?? (json['isBulkDiscountEnabled'] == true ? 10 : 0);

    return OwnerFacility(
      id: id,
      status: _mapStatus(s(json['approvalStatus']).isEmpty ? 'Pending' : s(json['approvalStatus'])),
      profile: FacilityProfile(
        name: s(json['name']),
        city: city.isEmpty ? '—' : city,
        ward: ward.isEmpty ? '—' : ward,
        address: address.isEmpty ? '—' : address,
        location: GeoPoint(lat, lng),
        licenseNumber: s(json['licenseNumber']),
        licenseImages: _stringList(json['licenseImages']),
      ),
      operations: FacilityOperations(
        phone: s(json['phone']),
        openMinutes: _safeParseMinutes(s(json['openTime']).isEmpty ? '06:00' : s(json['openTime'])),
        closeMinutes: _safeParseMinutes(s(json['closeTime']).isEmpty ? '22:00' : s(json['closeTime'])),
        description: s(json['description']),
        amenities: [for (final a in amenityItems) a.name],
        rules: rules,
        images: imageUrls,
      ),
      courts: _mapCourts(json),
      closures: const [],
      submittedAt: _parseDate(json['createdAt'] ?? json['submittedAt']) ?? DateTime.now(),
      rejectReason: json['rejectReason'] as String?,
      rating: (json['averageRating'] as num? ?? json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      recurringDiscountPercent: discount.round().clamp(0, 100),
      isSuspended: json['isSuspended'] == true,
      streetAddress: street,
      provinceCode: json['provinceCode'] == null ? null : s(json['provinceCode']),
      wardCode: json['wardCode'] == null ? null : s(json['wardCode']),
      autoGenerateSlots: json['autoGenerateSlots'] != false,
      isLocked: json['isLocked'] == true,
      lockedReason: json['lockedReason'] as String?,
      photos: photos,
      amenityItems: amenityItems,
      courtCount: json['courts'] is List ? (json['courts'] as List).length : null,
    );
  }

  ApprovalStatus _mapStatus(String value) {
    final v = value.toLowerCase();
    if (v.contains('pend')) return ApprovalStatus.pending;
    if (v.contains('reject')) return ApprovalStatus.rejected;
    return ApprovalStatus.approved;
  }

  List<CourtConfig> _mapCourts(Map<String, dynamic> json) {
    final raw = json['courts'] ?? json['offerings'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return CourtConfig(
        sport: Sport.fromApi((m['sport'] ?? m['sportName'] ?? 'football').toString()),
        courtType: CourtType.fromApi(m['courtType'] as String?),
        courtCount: (m['courtCount'] as num?)?.toInt() ?? (m['quantity'] as num?)?.toInt() ?? 1,
        pricing: null, // giá nối sau
      );
    }).toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int _safeParseMinutes(String hhmm) {
    try {
      return parseMinutes(hhmm);
    } catch (_) {
      return 6 * 60; // fallback 06:00
    }
  }

  // ==================== Sân & giá, Ca sân ====================

  static const String sportsPath = '/api/v1/master-data/sports';
  static String courtsPath(String facilityId) => '/api/v1/facilities/$facilityId/courts';
  static String courtPath(String facilityId, String courtId) => '${courtsPath(facilityId)}/$courtId';
  static String regeneratePath(String courtId) => '/api/v1/courts/$courtId/slots/regenerate-from';
  static String courtGeneratePath(String courtId) => '/api/v1/courts/$courtId/slots/generate';
  static String facilityGeneratePath(String facilityId) => '/api/v1/facilities/$facilityId/slots/generate';
  static String slotsRangePath(String facilityId) => '/api/v1/facilities/$facilityId/slots/range';
  static String bulkPath(String facilityId) => '/api/v1/facilities/$facilityId/slots/bulk';
  static String bulkDeletePath(String facilityId) => '/api/v1/facilities/$facilityId/slots/bulk-delete';
  static String slotPath(String slotId) => '/api/v1/slots/$slotId';
  static String availabilityPath(String facilityId) => '/api/v1/facilities/$facilityId/availability';
  static String pricePeriodsPath(String facilityId) => '/api/v1/facilities/$facilityId/price-periods';

  static List _listOf(Object? data) =>
      data is List ? data : (data is Map ? (data['items'] ?? data['data'] ?? data['results']) as List? : null) ?? const [];

  @override
  Future<List<SportCategory>> getSports() => _run(() async => [
        for (final e in _listOf(await _api.get(sportsPath)).whereType<Map>())
          SportCategory.fromJson(Map<String, dynamic>.from(e)),
      ]);

  @override
  Future<List<OwnerCourt>> getCourts(String facilityId) => _run(() async => [
        for (final e in _listOf(await _api.get(courtsPath(facilityId))).whereType<Map>())
          OwnerCourt.fromJson(Map<String, dynamic>.from(e)),
      ]);

  @override
  Future<OwnerCourt> getCourt(String facilityId, String courtId) => _run(() async {
        final data = await _api.get(courtPath(facilityId, courtId));
        if (data is! Map) throw const OwnerException(OwnerStrings.loadError);
        return OwnerCourt.fromJson(Map<String, dynamic>.from(data));
      });

  @override
  Future<void> createCourt(String facilityId, CourtInput input) =>
      _run(() => _api.post(courtsPath(facilityId), body: input.toJson(editing: false)));

  @override
  Future<void> updateCourt(String facilityId, OwnerCourt previous, CourtInput input) => _run(() => _api.put(
        courtPath(facilityId, previous.id),
        body: input.toJson(editing: true, previousIsIndoor: previous.isIndoor),
      ));

  @override
  Future<int> deleteCourt(String facilityId, String courtId) => _run(() async {
        final data = await _api.delete(courtPath(facilityId, courtId));
        return data is Map && data['removedFutureSlots'] is num ? (data['removedFutureSlots'] as num).toInt() : 0;
      });

  @override
  Future<void> regenerateCourtSlots(String courtId) =>
      _run(() => _api.post(regeneratePath(courtId), body: {'fromDate': null}));

  @override
  Future<void> updateOpenHours(String facilityId, {required String openTime, required String closeTime}) =>
      _run(() => _api.put('/api/v1/facilities/$facilityId', body: {
            'openTime': timeSpanOf(openTime),
            'closeTime': timeSpanOf(closeTime),
          }));

  @override
  Future<SlotsRange> getSlotsRange(String facilityId, {required DateTime from, required DateTime to}) => _run(() async =>
      SlotsRange.fromJson(await _api.get(slotsRangePath(facilityId), query: {'from': dayKey(from), 'to': dayKey(to)})));

  @override
  Future<FacilityAvailability> getAvailability(String facilityId, DateTime date) => _run(() async =>
      FacilityAvailability.fromJson(await _api.get(availabilityPath(facilityId), query: {'date': dayKey(date)})));

  @override
  Future<List<GenerateResultRow>> generateSlots(
    String facilityId,
    GenerateSlotsRequest request, {
    Map<String, String> courtNames = const {},
  }) =>
      _run(() async {
        if (request.courtIds.length == 1) {
          final id = request.courtIds.single;
          final data = await _api.post(courtGeneratePath(id), body: request.toJson(withCourts: false));
          return [
            GenerateResultRow.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {},
                courtId: id, courtName: courtNames[id]),
          ];
        }
        final data = await _api.post(facilityGeneratePath(facilityId), body: request.toJson());
        return [
          for (final e in _listOf(data).whereType<Map>())
            GenerateResultRow.fromJson(Map<String, dynamic>.from(e)),
        ];
      });

  @override
  Future<BulkSlotResult> bulkSlots(String facilityId, BulkSlotRequest request) => _run(() async => BulkSlotResult.fromJson(
        request.action == BulkSlotAction.delete
            ? await _api.post(bulkDeletePath(facilityId), body: request.filterJson())
            : await _api.put(bulkPath(facilityId), body: request.updateJson()),
      ));

  @override
  Future<void> deleteSlot(String slotId) => _run(() => _api.delete(slotPath(slotId)));

  /// Như Web: BE trả 404 / 405 nghĩa là chưa có API đợt giá.
  Future<T> _runPeriods<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        throw const OwnerException(OwnerSlotStrings.periodsUnavailableSave, unavailable: true);
      }
      throw OwnerException(e.message);
    }
  }

  @override
  Future<List<PricePeriod>> getPricePeriods(String facilityId, {DateTime? from, DateTime? to}) => _runPeriods(() async => [
        for (final e in _listOf(await _api.get(pricePeriodsPath(facilityId), query: {
          if (from != null) 'from': dayKey(from),
          if (to != null) 'to': dayKey(to),
        })).whereType<Map>())
          PricePeriod.fromJson(Map<String, dynamic>.from(e)),
      ]);

  @override
  Future<PricePeriodResult> savePricePeriod(String facilityId, PricePeriod period) => _runPeriods(() async =>
      PricePeriodResult.fromJson(period.id.isEmpty
          ? await _api.post(pricePeriodsPath(facilityId), body: period.toJson())
          : await _api.put('${pricePeriodsPath(facilityId)}/${period.id}', body: period.toJson())));

  @override
  Future<void> deletePricePeriod(String facilityId, String periodId) =>
      _runPeriods(() => _api.delete('${pricePeriodsPath(facilityId)}/$periodId'));

  // ==================== Vận hành: đơn, lịch, check-in ====================

  Never _todo() => throw Exception('Tính năng đang phát triển');

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const String bookingsPath = '/api/v1/bookings/owner';
  static String bookingPath(String id) => '$bookingsPath/$id';
  static const String walkInPath = '$bookingsPath/walk-in';
  static String checkInPath(String id) => '$bookingsPath/$id/check-in';
  static String endPath(String id) => '$bookingsPath/$id/end';
  static String cancelBookingPath(String bookingId) => '$bookingsPath/$bookingId/cancel';
  static String daySlotsPath(String facilityId) => '/api/v1/facilities/$facilityId/slots';
  static String slotStatusPath(String slotId) => '/api/v1/slots/$slotId/status';
  static const String scanPath = '/api/v1/checkin/scan';
  static const String cancelReasonsPath = '/api/v1/bookings/cancellation-reasons';

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
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
  }) =>
      _run(() async {
        final data = await _api.get(bookingsPath, query: {
          'FacilityId': facilityId,
          if (date != null) 'Date': _day(date),
          if (from != null) 'DateFrom': _day(from),
          if (to != null) 'DateTo': _day(to),
          if (status != null && status.isNotEmpty) 'Status': status,
          if (search != null && search.trim().isNotEmpty) 'Search': search.trim(),
          'Page': page,
          'PageSize': pageSize,
        });
        return OwnerBookingPage.fromJson(data, pageSize: pageSize);
      });

  @override
  Future<OwnerBooking> getBooking(String bookingId) => _run(() async {
        final data = await _api.get(bookingPath(bookingId));
        if (data is! Map) throw const OwnerException(OwnerStrings.loadError);
        return OwnerBooking.fromJson(Map<String, dynamic>.from(data));
      });

  @override
  Future<FacilityDaySchedule> getDaySchedule(String facilityId, DateTime date) => _run(() async {
        final data = await _api.get(daySlotsPath(facilityId), query: {'date': _day(date)});
        return FacilityDaySchedule.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {});
      });

  @override
  Future<void> createWalkIn(WalkInRequest request) => _run(() => _api.post(walkInPath, body: request.toJson()));

  @override
  Future<void> checkInBooking(String bookingId) => _run(() => _api.post(
        checkInPath(bookingId),
        body: {'participantUserId': null, 'checkInAllParticipants': true},
      ));

  @override
  Future<void> endBooking(String bookingId) => _run(() => _api.post(endPath(bookingId)));

  @override
  Future<void> setSlotLocked(String slotId, {required bool locked}) => _run(() => _api.put(
        slotStatusPath(slotId),
        body: {'status': locked ? CourtSlotStatusCode.maintenance : CourtSlotStatusCode.available},
      ));

  @override
  Future<void> setSlotPrice(String slotId, int price) => _run(() => _api.put(
        slotStatusPath(slotId),
        body: {'status': CourtSlotStatusCode.available, 'price': price},
      ));

  @override
  Future<ScanResult> scanQr({required String facilityId, required String qrCode}) => _run(() async {
        final data = await _api.post(scanPath, query: {'facilityId': facilityId, 'qrCode': qrCode.trim()});
        // Như Web: hiện message BE (mô tả Booking / LFG, số tiền chuyển...), không có thì câu mặc định.
        return ScanResult.fromJson(data, _api.lastMessage ?? OwnerStrings.scanSuccessDefault);
      });

  @override
  Future<List<CancelReason>> getCancelReasons() => _run(() async {
        final data = await _api.get(cancelReasonsPath);
        final list = data is List ? data : (data is Map ? data['items'] as List? : null) ?? const [];
        return list
            .whereType<Map>()
            .map((r) => CancelReason(
                  code: (r['code'] as num?)?.toInt() ?? 0,
                  label: r['label']?.toString() ?? '',
                  isCustom: r['isCustom'] == true,
                ))
            .toList();
      });

  /// Body như Web: cancelReasonId (mã lý do), reason (chữ của lý do hoặc tự nhập), lockSlotAfterCancel.
  @override
  Future<OwnerCancelResult> cancelBooking(String bookingId, {int? reasonCode, String? reason, bool lockSlot = false}) =>
      _run(() async {
        final note = reason?.trim();
        final data = await _api.post(cancelBookingPath(bookingId), body: {
          'cancelReasonId': reasonCode,
          'reason': note == null || note.isEmpty ? null : note,
          'lockSlotAfterCancel': lockSlot,
        });
        final json = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
        int money(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
        final fairPlay = json['ownerFairPlayPenalty'] ?? json['fairPlayPenalty'];
        return OwnerCancelResult(
          penaltyAmount: money(json['ownerPenaltyAmount'] ?? json['penaltyAmount']),
          fairPlayPenalty: fairPlay is num
              ? fairPlay.abs().round()
              : fairPlay == true
                  ? OwnerCancelRules.lateFairPlayPenalty
                  : 0,
          refundAmount: money(json['refundAmount']),
        );
      });

  // ==================== Cơ sở của tôi ====================

  static const String facilitiesPath = '/api/v1/facilities';
  static String facilityPath(String id) => '$facilitiesPath/$id';
  static String facilityImagesPath(String id) => '${facilityPath(id)}/images';
  static String facilityAmenitiesPath(String id) => '${facilityPath(id)}/amenities';
  static const String provincesPath = '/api/v1/master-data/provinces';
  static String wardsPath(String provinceCode) => '$provincesPath/$provinceCode/wards';

  static List<AreaOption> _areas(Object? data) => [
        for (final e in _listOf(data).whereType<Map>())
          AreaOption(
            code: '${e['code'] ?? e['provinceCode'] ?? e['wardCode'] ?? ''}',
            name: '${e['name'] ?? e['provinceName'] ?? e['wardName'] ?? ''}',
          ),
      ];

  @override
  Future<List<AreaOption>> getProvinces() => _run(() async => _areas(await _api.get(provincesPath)));

  @override
  Future<List<AreaOption>> getWards(String provinceCode) => _run(() async => _areas(await _api.get(wardsPath(provinceCode))));

  Future<OwnerFacility> _fetch(String id) async {
    final data = await _api.get(facilityPath(id));
    if (data is! Map) throw const OwnerException(OwnerStrings.loadError);
    return _mapOwnerFacility(Map<String, dynamic>.from(data));
  }

  @override
  Future<OwnerFacility> createFacility(FacilityInput input) => _run(() async {
        final data = await _api.post(facilitiesPath, body: input.toJson(creating: true));
        final id = data is Map ? '${data['id'] ?? ''}' : '';
        if (id.isEmpty) throw const OwnerException(OwnerStrings.loadError);
        return _fetch(id);
      });

  @override
  Future<OwnerFacility> updateFacility(String facilityId, FacilityInput input) => _run(() async {
        await _api.put(facilityPath(facilityId), body: input.toJson(creating: false));
        return _fetch(facilityId);
      });

  @override
  Future<void> deleteFacility(String facilityId) => _run(() => _api.delete(facilityPath(facilityId)));

  @override
  Future<void> uploadFacilityPhotos(String facilityId, List<String> filePaths) =>
      _run(() => _api.uploadFiles(facilityImagesPath(facilityId), filePaths: filePaths, field: 'files'));

  @override
  Future<void> deleteFacilityPhoto(String facilityId, String photoId) =>
      _run(() => _api.delete('${facilityImagesPath(facilityId)}/$photoId'));

  @override
  Future<void> setFacilityThumbnail(String facilityId, String photoId) =>
      _run(() => _api.patch('${facilityImagesPath(facilityId)}/$photoId/thumbnail'));

  @override
  Future<void> updateFacilityAmenities(String facilityId, List<String> amenityIds) =>
      _run(() => _api.put(facilityAmenitiesPath(facilityId), body: {'amenityIds': amenityIds}));


  /// PUT /facilities/{id} là cập nhật từng phần: chỉ gửi recurringDiscountPercent (không gửi isBulkDiscountEnabled,
  /// không gửi amenityIds/imageUrls vì mảng rỗng = xoá hết). Đọc lại cơ sở để có trạng thái duyệt mới.
  @override
  Future<OwnerFacility> updateRecurringDiscount(String facilityId, int percent) async {
    try {
      await _api.put('/api/v1/facilities/$facilityId', body: {'recurringDiscountPercent': percent});
    } on ApiException catch (e) {
      throw OwnerException(e.message);
    }
    return getOwnerFacility(facilityId);
  }

  @override
  Future<OwnerFacility> saveCourt(String facilityId, CourtConfig court) async => _todo();

  @override
  Future<OwnerFacility> lockCourt(String facilityId, Sport sport, CourtType courtType) async => _todo();

  @override
  Future<OwnerFacility> unlockCourt(String facilityId, Sport sport, CourtType courtType) async => _todo();

  @override
  Future<OwnerFacility> addClosure(
      String facilityId, {
        Sport? sport,
        CourtType? courtType,
        required DateTime from,
        required DateTime to,
        required String reason,
      }) async =>
      _todo();

  @override
  Future<OwnerFacility> removeClosure(String facilityId, String closureId) async => _todo();

  @override
  Future<MonthlyRevenue> getMonthlyRevenue(DateTime month, {String? facilityId}) async => _todo();

  @override
  Future<List<ListingFeeBill>> getListingFees() async => _todo();

  @override
  Future<ListingFeeBill> payListingFee(String billId) async => _todo();

  // ==================== Đánh giá (như Web: src/api/owner/reviewApi.js) ====================

  static const String reviewsPath = '/api/v1/owner/facility-reviews';
  static const String reviewStatsPath = '/api/v1/owner/facility-reviews/statistics';
  static String reviewReplyPath(String reviewId) => '/api/v1/owner/facility-reviews/$reviewId/reply';

  @override
  Future<ReviewPage> getFacilityReviews({String? facilityId, int? rating, bool? replied, int page = 1, int pageSize = 10}) =>
      _run(() async => ReviewPage.fromJson(
            await _api.get(reviewsPath, query: {
              'FacilityId': ?facilityId,
              'Rating': ?rating,
              'Replied': ?replied,
              'Page': page,
              'PageSize': pageSize,
            }),
            pageSize: pageSize,
          ));

  @override
  Future<ReviewStats> getReviewStats({String? facilityId}) => _run(() async {
        final data = await _api.get(reviewStatsPath, query: {'facilityId': ?facilityId});
        return ReviewStats.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {});
      });

  @override
  Future<void> replyToReview(String reviewId, String text, {bool edit = false}) => _run(() => edit
      ? _api.put(reviewReplyPath(reviewId), body: {'reply': text.trim()})
      : _api.post(reviewReplyPath(reviewId), body: {'reply': text.trim()}));

  @override
  Future<void> deleteReviewReply(String reviewId) => _run(() => _api.delete(reviewReplyPath(reviewId)));

  /// BE chưa có API cho Chủ sân báo cáo đánh giá (ReportTargetType không có loại đánh giá).
  @override
  Future<FacilityReview> reportReview(String reviewId, ReportReason reason, {String note = ''}) async =>
      throw const OwnerException(OwnerReviewStrings.reportUnavailable, unavailable: true);

  // ==================== Tổng quan (như Web: getOwnerDashboard) ====================

  static const String dashboardPath = '/api/v1/owner/dashboard';

  @override
  Future<OwnerDashboard> getDashboard({required String facilityId, required DateTime from, required DateTime to}) =>
      _run(() async {
        final data = await _api.get(dashboardPath, query: {
          'FacilityId': facilityId,
          'From': dashboardDay(from),
          'To': dashboardDay(to),
        });
        return OwnerDashboard.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {});
      });

  // ==================== Quảng bá (như Web: promotionApi.js) ====================

  static const String promotionPackagesPath = '/api/v1/promotions/packages';
  static const String promotionsPath = '/api/v1/promotions';
  static const String myPromotionsPath = '/api/v1/promotions/mine';

  @override
  Future<List<PromotionPackage>> getPromotionPackages() => _run(() async => [
        for (final e in _listOf(await _api.get(promotionPackagesPath, query: const {'targetType': 'FACILITY'})).whereType<Map>())
          PromotionPackage.fromJson(Map<String, dynamic>.from(e)),
      ]);

  @override
  Future<void> purchasePromotion({required String packageId, required String facilityId}) =>
      _run(() => _api.post(promotionsPath, body: {'packageId': packageId, 'targetId': facilityId}));

  @override
  Future<List<OwnerPromotion>> getMyPromotions({bool activeOnly = false}) => _run(() async => [
        for (final e in _listOf(await _api.get(myPromotionsPath, query: {
          if (activeOnly) 'activeOnly': true,
          'page': 1,
          'pageSize': 50,
        })).whereType<Map>())
          OwnerPromotion.fromJson(Map<String, dynamic>.from(e)),
      ]);

  // ==================== Shop tại sân (như Web: shopApi.js) ====================

  static String shopProductsPath(String facilityId) => '/api/v1/shop/facilities/$facilityId/products';
  static String shopProductPath(String productId) => '/api/v1/shop/products/$productId';
  static String shopOrdersPath(String facilityId) => '/api/v1/shop/facilities/$facilityId/orders';
  static String shopOrderStatusPath(String orderId) => '/api/v1/shop/orders/$orderId/status';

  @override
  Future<List<ShopProduct>> getShopProducts(String facilityId) => _run(() async => [
        for (final e in _listOf(await _api.get(shopProductsPath(facilityId), query: const {'includeInactive': true})).whereType<Map>())
          ShopProduct.fromJson(Map<String, dynamic>.from(e)),
      ]);

  @override
  Future<void> createShopProduct(String facilityId, ShopProductInput input) =>
      _run(() => _api.post(shopProductsPath(facilityId), body: input.toJson()));

  @override
  Future<void> updateShopProduct(String productId, ShopProductInput input) =>
      _run(() => _api.put(shopProductPath(productId), body: input.toJson()));

  @override
  Future<void> deleteShopProduct(String productId) => _run(() => _api.delete(shopProductPath(productId)));

  /// POST /uploads/images?purpose=general (như Web).
  @override
  Future<String> uploadShopImage(String filePath) => _run(() async {
        final data = await _api.upload(uploadImagePath, filePath: filePath, query: const {'purpose': 'general'});
        final url = data is String ? data : (data is Map ? (data['url'] ?? data['imageUrl']) : null);
        if (url == null || '$url'.isEmpty) throw const OwnerException(OwnerComplaintStrings.uploadError);
        return '$url';
      });

  @override
  Future<List<ShopOrder>> getShopOrders(String facilityId, {ShopOrderStatus? status}) => _run(() async => [
        for (final e in _listOf(await _api.get(shopOrdersPath(facilityId), query: {'status': ?status?.apiValue})).whereType<Map>())
          ShopOrder.fromJson(Map<String, dynamic>.from(e)),
      ]);

  @override
  Future<void> updateShopOrderStatus(String orderId, ShopOrderStatus status) =>
      _run(() => _api.patch(shopOrderStatusPath(orderId), body: {'status': status.apiValue}));

  // ==================== Khiếu nại (như Web: src/api/owner/reportApi.js) ====================

  static const String complaintsPath = '/api/v1/reports/owner';
  static String complaintPath(String id) => '/api/v1/reports/owner/$id';
  static const String uploadImagePath = '/api/v1/uploads/images';

  @override
  Future<ComplaintPage> getComplaints({
    ComplaintStatus? status,
    String? facilityId,
    String? keyword,
    int page = 1,
    int pageSize = 10,
  }) =>
      _run(() async => ComplaintPage.fromJson(
            await _api.get(complaintsPath, query: {
              'Status': ?status?.apiValue,
              'FacilityId': ?facilityId,
              if (keyword != null && keyword.trim().isNotEmpty) 'SearchKeyword': keyword.trim(),
              'PageIndex': page,
              'PageSize': pageSize,
            }),
            pageSize: pageSize,
          ));

  @override
  Future<OwnerComplaint> getComplaint(String complaintId) => _run(() async {
        final data = await _api.get(complaintPath(complaintId));
        if (data is! Map) throw const OwnerException(OwnerComplaintStrings.notFound);
        return OwnerComplaint.fromJson(Map<String, dynamic>.from(data));
      });

  /// POST /uploads/images?purpose=report (field `file`) → url, như Web.
  @override
  Future<String> uploadEvidence(String filePath) => _run(() async {
        final data = await _api.upload(uploadImagePath, filePath: filePath, query: const {'purpose': 'report'});
        final url = data is String ? data : (data is Map ? (data['url'] ?? data['imageUrl']) : null);
        if (url == null || '$url'.isEmpty) throw const OwnerException(OwnerComplaintStrings.uploadError);
        return '$url';
      });

  @override
  Future<void> respondComplaint(String complaintId, {required String response, List<String> evidenceUrls = const []}) =>
      _run(() => _api.post('${complaintPath(complaintId)}/respond', body: {
            'ownerResponse': response.trim(),
            'ownerEvidenceUrls': evidenceUrls,
          }));

  @override
  Future<void> acceptComplaintRefund(
    String complaintId, {
    required String response,
    required int refundPercent,
    List<String> evidenceUrls = const [],
    bool lockSlot = false,
  }) =>
      _run(() => _api.post('${complaintPath(complaintId)}/accept-refund', body: {
            'ownerResponse': response.trim(),
            'ownerEvidenceUrls': evidenceUrls,
            'refundPercentage': refundPercent,
            'lockSlotForMaintenance': lockSlot,
          }));
}