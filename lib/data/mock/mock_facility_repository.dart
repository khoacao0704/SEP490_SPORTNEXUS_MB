import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/utils/text_utils.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_search.dart';
import '../../models/sport.dart';
import '../../models/time_slot.dart';
import '../repositories/facility_repository.dart';
import 'mock_facility_data.dart';

/// Bản giả lập [FacilityRepository].
///
/// - Khung giờ sinh theo giờ mở/đóng cửa của cơ sở; giờ từ 17:00 là giờ cao điểm (giá x1.4).
/// - Số sân đã đặt sinh ngẫu nhiên nhưng cố định theo (cơ sở, môn, ngày, giờ) để mỗi lần mở đều giống nhau.
/// - Giữ chỗ lưu trong bộ nhớ, tự hết hạn sau [holdDuration].
class MockFacilityRepository implements FacilityRepository {
  static const Duration holdDuration = Duration(minutes: 10);

  final Duration latency;
  final DateTime Function() _now;
  final List<Facility> _facilities;
  final List<_Hold> _holds = [];
  int _holdCounter = 0;

  MockFacilityRepository({
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? now,
    List<Facility>? facilities,
  })  : _now = now ?? DateTime.now,
        _facilities = facilities ?? MockFacilityData.facilities;

  @override
  Future<List<FacilitySearchResult>> searchFacilities(FacilitySearchQuery query) async {
    await _delay();
    final sport = query.sport;

    final results = _facilities
        .where((f) => f.city == query.city)
        .where((f) => query.district == null || f.district == query.district)
        .where((f) => sport == null || f.offeringFor(sport) != null)
        .where((f) =>
            TextUtils.containsIgnoringDiacritics(f.name, query.keyword) ||
            TextUtils.containsIgnoringDiacritics(f.address, query.keyword))
        .map((f) => FacilitySearchResult(
              facility: f,
              distanceKm: query.userLocation == null ? null : GeoUtils.distanceKm(query.userLocation!, f.location),
            ))
        .toList();

    int priceOf(FacilitySearchResult r) =>
        sport == null ? r.facility.priceFrom : r.facility.offeringFor(sport)!.priceFrom;

    switch (query.sort) {
      case FacilitySort.distance:
        if (query.userLocation != null) {
          results.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
        } else {
          results.sort((a, b) => b.facility.rating.compareTo(a.facility.rating));
        }
      case FacilitySort.priceLowToHigh:
        results.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
      case FacilitySort.rating:
        results.sort((a, b) => b.facility.rating.compareTo(a.facility.rating));
    }
    return results;
  }

  @override
  Future<List<String>> getDistricts(String city) async {
    final districts = _facilities.where((f) => f.city == city).map((f) => f.district).toSet().toList();
    districts.sort();
    return districts;
  }

  @override
  Future<Facility> getFacility(String facilityId) async {
    await _delay();
    return _findFacility(facilityId);
  }

  @override
  Future<List<TimeSlot>> getTimeSlots(String facilityId, Sport sport, DateTime date, {CourtType? courtType}) async {
    await _delay();
    final facility = _findFacility(facilityId);
    final offering = facility.offeringFor(sport, courtType: courtType);
    if (offering == null) return [];

    _purgeExpiredHolds();
    final day = DateTime(date.year, date.month, date.day);
    final slotMinutes = _slotMinutesFor(sport);
    final open = _minutesOf(facility.openTime);
    final close = _minutesOf(facility.closeTime);

    final slots = <TimeSlot>[];
    for (var m = _roundUpToHour(open); m + slotMinutes <= close; m += slotMinutes) {
      final start = day.add(Duration(minutes: m));
      final end = start.add(Duration(minutes: slotMinutes));
      final type = offering.courtType.isStandard ? '' : '${offering.courtType.apiValue}|';
      final id = '${facility.id}|${sport.apiValue}|$type${start.toIso8601String()}';
      final isPeak = start.hour >= 17;
      final booked = _bookedCourts(id, offering.courtCount, isPeak);
      final held = _holds.where((h) => h.slotIds.contains(id)).length;

      slots.add(TimeSlot(
        id: id,
        facilityId: facility.id,
        sport: sport,
        courtType: offering.courtType,
        start: start,
        end: end,
        price: isPeak ? _roundTo10k(offering.priceFrom * 1.4) : offering.priceFrom,
        totalCourts: offering.courtCount,
        availableCourts: (offering.courtCount - booked - held).clamp(0, offering.courtCount),
      ));
    }
    return slots;
  }

  @override
  Future<SlotHold> holdSlots(List<TimeSlot> slots) async {
    await _delay();
    if (slots.isEmpty) throw const FacilityException(FacilityStrings.noSlotSelected);
    final now = _now();

    // Bỏ khung trùng, sắp theo giờ bắt đầu.
    final unique = {for (final s in slots) s.id: s}.values.toList()..sort((a, b) => a.start.compareTo(b.start));

    // Kiểm tra hết rồi mới giữ: một khung lỗi thì không giữ khung nào.
    final fresh = <TimeSlot>[];
    for (final slot in unique) {
      final label = Formatters.slotLabel(slot.start, slot.end);
      if (slot.hasStarted(now)) throw FacilityException(FacilityStrings.slotStarted(label));

      // Đọc lại số sân trống mới nhất, tránh giữ trùng khi nhiều người cùng bấm.
      final latest = (await getTimeSlots(slot.facilityId, slot.sport, slot.start, courtType: slot.courtType))
          .where((s) => s.id == slot.id)
          .firstOrNull;
      if (latest == null || latest.isFull) throw FacilityException(FacilityStrings.slotJustFull(label));
      fresh.add(latest);
    }

    final hold = _Hold('hold-${++_holdCounter}', fresh, now.add(holdDuration));
    _holds.add(hold);
    return SlotHold(holdId: hold.id, slots: fresh, expiresAt: hold.expiresAt);
  }

  @override
  Future<void> releaseHold(String holdId) async {
    _holds.removeWhere((h) => h.id == holdId);
  }

  @override
  Future<SlotHold> transferHold(String holdId, {required DateTime until, List<String>? slotIds}) async {
    _purgeExpiredHolds();
    final old = _holds.where((h) => h.id == holdId).firstOrNull;
    final moving = old == null
        ? const <TimeSlot>[]
        : slotIds == null
            ? old.slots
            : old.slots.where((s) => slotIds.contains(s.id)).toList();
    if (old == null || moving.isEmpty) throw const FacilityException(FacilityStrings.holdExpired);

    _holds.remove(old);
    final rest = old.slots.where((s) => !moving.contains(s)).toList();
    if (rest.isNotEmpty) _holds.add(_Hold(old.id, rest, old.expiresAt));
    final hold = _Hold('hold-${++_holdCounter}', moving, until);
    _holds.add(hold);
    return SlotHold(holdId: hold.id, slots: moving, expiresAt: until);
  }

  Facility _findFacility(String id) {
    return _facilities.firstWhere(
      (f) => f.id == id,
      orElse: () => throw const FacilityException(FacilityStrings.facilityNotFound),
    );
  }

  void _purgeExpiredHolds() {
    final now = _now();
    _holds.removeWhere((h) => !h.expiresAt.isAfter(now));
  }

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  /// Bóng đá 90 phút/trận, các môn khác 60 phút.
  static int _slotMinutesFor(Sport sport) => sport == Sport.football ? 90 : 60;

  static int _minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static int _roundUpToHour(int minutes) => ((minutes + 59) ~/ 60) * 60;

  static int _roundTo10k(double value) => ((value / 10000).round()) * 10000;

  /// Số sân đã có người đặt, cố định theo [slotId]. Giờ cao điểm đông hơn.
  static int _bookedCourts(String slotId, int courtCount, bool isPeak) {
    var hash = 0;
    for (final unit in slotId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final base = hash % (courtCount + 1);
    return isPeak ? (base + 1).clamp(0, courtCount) : base;
  }
}

class _Hold {
  final String id;
  final List<TimeSlot> slots;
  final DateTime expiresAt;

  _Hold(this.id, this.slots, this.expiresAt);

  List<String> get slotIds => slots.map((s) => s.id).toList();
}
