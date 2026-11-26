// Sân con, sinh ca, thao tác ca hàng loạt, lịch 7 ngày và đợt giá đặc biệt phía Chủ sân
// (trang "Sân & giá" và "Ca sân" của Web: src/CourtOwner/Courts, src/CourtOwner/Slots).

import 'owner_booking.dart';

int _int(Object? v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

int? _intOrNull(Object? v) => v == null ? null : _int(v);

String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// "17:30:00" / "17:30" → "17:30"; rỗng → null.
String? clockOf(Object? v) {
  final s = _str(v);
  if (s == null || !RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) return null;
  return s.substring(0, s.indexOf(':') + 3).padLeft(5, '0');
}

/// "17:30" → "17:30:00" (TimeSpan của BE); null → null.
String? timeSpanOf(String? hhmm) => hhmm == null || hhmm.isEmpty ? null : (hhmm.length == 5 ? '$hhmm:00' : hhmm);

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Thứ trong tuần theo .NET DayOfWeek (0 = Chủ nhật) như BE nhận; thứ tự hiển thị T2 → CN.
abstract final class WeekDays {
  static const List<int> ordered = [1, 2, 3, 4, 5, 6, 0];
  static const Map<int, String> short = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 0: 'CN'};
  static const Map<int, String> full = {
    1: 'Thứ 2',
    2: 'Thứ 3',
    3: 'Thứ 4',
    4: 'Thứ 5',
    5: 'Thứ 6',
    6: 'Thứ 7',
    0: 'Chủ nhật',
  };

  /// DateTime.weekday (1 = T2 … 7 = CN) → .NET DayOfWeek.
  static int ofDate(DateTime d) => d.weekday % 7;

  /// "Mọi ngày" khi trống / đủ 7 ngày; dãy liền nhau ≥ 3 ngày ghi "T2 – T6"; còn lại liệt kê.
  static String summary(List<int> days) {
    if (days.isEmpty || days.length >= 7) return 'Mọi ngày';
    final sorted = [...days]..sort((a, b) => ordered.indexOf(a).compareTo(ordered.indexOf(b)));
    var contiguous = sorted.length >= 3;
    for (var i = 1; i < sorted.length && contiguous; i++) {
      if (ordered.indexOf(sorted[i]) != ordered.indexOf(sorted[i - 1]) + 1) contiguous = false;
    }
    return contiguous ? '${short[sorted.first]} – ${short[sorted.last]}' : sorted.map((d) => short[d]).join(', ');
  }
}

/// Môn thể thao (master-data/sports).
class SportCategory {
  final String id;
  final String name;

  /// Thời lượng ca mặc định của môn (phút).
  final int defaultSlotMinutes;

  const SportCategory({required this.id, required this.name, this.defaultSlotMinutes = 120});

  factory SportCategory.fromJson(Map<String, dynamic> j) => SportCategory(
        id: _str(j['id']) ?? '',
        name: _str(j['name']) ?? '—',
        defaultSlotMinutes: _int(j['defaultSlotMinutes']) > 0 ? _int(j['defaultSlotMinutes']) : 120,
      );
}

/// Một sân con của cơ sở (CourtResponse).
class OwnerCourt {
  final String id;
  final String categoryId;
  final String categoryName;
  final String name;

  /// ACTIVE | INACTIVE (tạm ngưng / bảo trì).
  final String status;
  final int defaultPrice;
  final String? courtType;
  final bool? isIndoor;
  final String? surfaceType;
  final int? maxPlayers;
  final int? teamSize;

  /// Thời lượng ca chủ sân chọn; null = theo môn.
  final int? slotMinutes;
  final int effectiveSlotMinutes;

  // Chỉ có ở GET chi tiết sân.
  final int? availableSlotsNext7Days;
  final int? minUpcomingPrice;
  final int? maxUpcomingPrice;

  const OwnerCourt({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    this.status = 'ACTIVE',
    required this.defaultPrice,
    this.courtType,
    this.isIndoor,
    this.surfaceType,
    this.maxPlayers,
    this.teamSize,
    this.slotMinutes,
    this.effectiveSlotMinutes = 120,
    this.availableSlotsNext7Days,
    this.minUpcomingPrice,
    this.maxUpcomingPrice,
  });

  bool get isActive => status == 'ACTIVE';

  factory OwnerCourt.fromJson(Map<String, dynamic> j) => OwnerCourt(
        id: _str(j['id'] ?? j['courtId']) ?? '',
        categoryId: _str(j['categoryId']) ?? '',
        categoryName: _str(j['categoryName'] ?? j['sportName']) ?? 'Khác',
        name: _str(j['name'] ?? j['courtName']) ?? '—',
        status: (_str(j['status']) ?? 'ACTIVE').toUpperCase(),
        defaultPrice: _int(j['defaultPrice']),
        courtType: _str(j['courtType']),
        isIndoor: j['isIndoor'] is bool ? j['isIndoor'] as bool : null,
        surfaceType: _str(j['surfaceType']),
        maxPlayers: _intOrNull(j['maxPlayers']),
        teamSize: _intOrNull(j['teamSize']),
        slotMinutes: _intOrNull(j['slotMinutes']) == 0 ? null : _intOrNull(j['slotMinutes']),
        effectiveSlotMinutes: _int(j['effectiveSlotMinutes']) > 0 ? _int(j['effectiveSlotMinutes']) : 120,
        availableSlotsNext7Days: _intOrNull(j['availableSlotsNext7Days']),
        minUpcomingPrice: _intOrNull(j['minUpcomingPrice']),
        maxUpcomingPrice: _intOrNull(j['maxUpcomingPrice']),
      );

  OwnerCourt copyWith({String? status, int? defaultPrice, int? slotMinutes, bool clearSlotMinutes = false}) => OwnerCourt(
        id: id,
        categoryId: categoryId,
        categoryName: categoryName,
        name: name,
        status: status ?? this.status,
        defaultPrice: defaultPrice ?? this.defaultPrice,
        courtType: courtType,
        isIndoor: isIndoor,
        surfaceType: surfaceType,
        maxPlayers: maxPlayers,
        teamSize: teamSize,
        slotMinutes: clearSlotMinutes ? null : (slotMinutes ?? this.slotMinutes),
        effectiveSlotMinutes: effectiveSlotMinutes,
      );

  /// Body PUT sân đủ trường (như courtPayload của Web), chỉ thay phần đổi.
  CourtInput toInput() => CourtInput(
        categoryId: categoryId,
        name: name,
        defaultPrice: defaultPrice,
        courtType: courtType,
        isIndoor: isIndoor,
        surfaceType: surfaceType,
        maxPlayers: maxPlayers,
        teamSize: teamSize,
        slotMinutes: slotMinutes,
        status: status,
      );
}

/// Dữ liệu thêm / sửa sân (CreateCourtRequest / UpdateCourtRequest).
class CourtInput {
  final String categoryId;
  final String name;
  final int defaultPrice;
  final String? courtType;
  final bool? isIndoor;
  final String? surfaceType;
  final int? maxPlayers;
  final int? teamSize;

  /// null = theo môn.
  final int? slotMinutes;

  /// Chỉ khi sửa: ACTIVE | INACTIVE.
  final String? status;

  const CourtInput({
    required this.categoryId,
    required this.name,
    required this.defaultPrice,
    this.courtType,
    this.isIndoor,
    this.surfaceType,
    this.maxPlayers,
    this.teamSize,
    this.slotMinutes,
    this.status,
  });

  CourtInput copyWith({String? status, int? defaultPrice, int? slotMinutes, bool clearSlotMinutes = false}) => CourtInput(
        categoryId: categoryId,
        name: name,
        defaultPrice: defaultPrice ?? this.defaultPrice,
        courtType: courtType,
        isIndoor: isIndoor,
        surfaceType: surfaceType,
        maxPlayers: maxPlayers,
        teamSize: teamSize,
        slotMinutes: clearSlotMinutes ? null : (slotMinutes ?? this.slotMinutes),
        status: status ?? this.status,
      );

  /// Như Web: thêm mới gửi null cho ô trống; sửa gửi "" để xóa chữ cũ, 0 để thời lượng ca về theo môn
  /// và clearIsIndoor khi bỏ khai báo trong nhà / ngoài trời.
  Map<String, dynamic> toJson({required bool editing, bool? previousIsIndoor}) => {
        'categoryId': categoryId,
        'name': name,
        'defaultPrice': defaultPrice,
        'courtType': courtType ?? (editing ? '' : null),
        'surfaceType': surfaceType ?? (editing ? '' : null),
        'isIndoor': isIndoor,
        'maxPlayers': maxPlayers,
        'teamSize': teamSize,
        'slotMinutes': slotMinutes ?? (editing ? 0 : null),
        if (editing) 'status': status,
        if (editing) 'clearIsIndoor': isIndoor == null && previousIsIndoor != null,
      };
}

/// Khung giá riêng (giờ vàng / cuối tuần) khi sinh ca.
class SlotPriceRule {
  /// .NET DayOfWeek; rỗng = mọi ngày.
  final List<int> daysOfWeek;
  final String startTime;
  final String endTime;
  final int price;

  const SlotPriceRule({this.daysOfWeek = const [], required this.startTime, required this.endTime, required this.price});

  Map<String, dynamic> toJson() => {
        'daysOfWeek': daysOfWeek.isEmpty ? null : daysOfWeek,
        'startTime': timeSpanOf(startTime),
        'endTime': timeSpanOf(endTime),
        'price': price,
      };
}

/// Sinh ca hàng loạt (GenerateCourtSlotsRequest / GenerateFacilitySlotsRequest).
class GenerateSlotsRequest {
  /// Rỗng = mọi sân đang dùng.
  final List<String> courtIds;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String? openTime;
  final String? closeTime;

  /// null = theo thời lượng ca của từng sân.
  final int? durationMinutes;

  /// null = giá mặc định của sân.
  final int? price;
  final List<SlotPriceRule> priceRules;

  const GenerateSlotsRequest({
    this.courtIds = const [],
    required this.dateFrom,
    required this.dateTo,
    this.openTime,
    this.closeTime,
    this.durationMinutes,
    this.price,
    this.priceRules = const [],
  });

  Map<String, dynamic> toJson({bool withCourts = true}) => {
        'dateFrom': dayKey(dateFrom),
        'dateTo': dayKey(dateTo),
        'openTime': timeSpanOf(openTime),
        'closeTime': timeSpanOf(closeTime),
        'durationMinutes': durationMinutes,
        'price': price,
        'priceRules': [for (final r in priceRules) r.toJson()],
        if (withCourts) 'courtIds': courtIds.isEmpty ? null : courtIds,
      };
}

/// Kết quả sinh ca của một sân.
class GenerateResultRow {
  final String courtId;
  final String courtName;
  final bool success;
  final String? message;
  final int created;
  final int updated;
  final int skipped;
  final int past;

  const GenerateResultRow({
    required this.courtId,
    required this.courtName,
    this.success = true,
    this.message,
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.past = 0,
  });

  factory GenerateResultRow.fromJson(Map<String, dynamic> j, {String? courtId, String? courtName}) => GenerateResultRow(
        courtId: _str(j['courtId']) ?? courtId ?? '',
        courtName: _str(j['courtName']) ?? courtName ?? 'Sân',
        success: j['success'] != false,
        message: _str(j['message']),
        created: _int(j['createdSlots']),
        updated: _int(j['updatedSlots']),
        skipped: _int(j['skippedSlots']),
        past: _int(j['pastSlots']),
      );
}

/// Thao tác ca hàng loạt.
enum BulkSlotAction {
  lock('LOCK'),
  unlock('UNLOCK'),
  setPrice('SET_PRICE'),
  delete('DELETE');

  const BulkSlotAction(this.apiValue);

  final String apiValue;
}

/// Bộ lọc + thao tác ca hàng loạt (BulkUpdateSlotsRequest / BulkSlotFilterRequest).
class BulkSlotRequest {
  final BulkSlotAction action;
  final List<String> courtIds;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String? startTime;
  final String? endTime;
  final List<int> daysOfWeek;
  final int? price;

  const BulkSlotRequest({
    required this.action,
    this.courtIds = const [],
    required this.dateFrom,
    required this.dateTo,
    this.startTime,
    this.endTime,
    this.daysOfWeek = const [],
    this.price,
  });

  Map<String, dynamic> filterJson() => {
        'courtIds': courtIds.isEmpty ? null : courtIds,
        'dateFrom': dayKey(dateFrom),
        'dateTo': dayKey(dateTo),
        'startTime': timeSpanOf(startTime),
        'endTime': timeSpanOf(endTime),
        'daysOfWeek': daysOfWeek.isEmpty ? null : daysOfWeek,
      };

  Map<String, dynamic> updateJson() => {
        ...filterJson(),
        'action': action.apiValue,
        'price': action == BulkSlotAction.setPrice ? price : null,
      };
}

/// Kết quả thao tác hàng loạt: khớp / đã áp dụng / bỏ qua.
class BulkSlotResult {
  final int matched;
  final int affected;
  final int skipped;

  const BulkSlotResult({required this.matched, required this.affected, required this.skipped});

  factory BulkSlotResult.fromJson(Object? data) {
    final j = data is Map ? data : const {};
    return BulkSlotResult(
      matched: _int(j['matchedSlots']),
      affected: _int(j['affectedSlots']),
      skipped: _int(j['skippedSlots']),
    );
  }
}

/// Một ngày trong lịch 7 ngày.
class SlotRangeDay {
  final DateTime date;
  final List<ScheduleCourt> courts;

  const SlotRangeDay({required this.date, required this.courts});
}

/// Lịch 7 ngày (GET /facilities/{id}/slots/range).
class SlotsRange {
  final int totalSlots;
  final int bookedSlots;
  final int availableSlots;
  final int lockedSlots;
  final int reservedSlots;
  final List<SlotRangeDay> days;

  const SlotsRange({
    required this.totalSlots,
    required this.bookedSlots,
    required this.availableSlots,
    required this.lockedSlots,
    required this.reservedSlots,
    required this.days,
  });

  factory SlotsRange.fromJson(Object? data) {
    final j = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final days = [
      for (final d in (j['days'] as List? ?? const []).whereType<Map>())
        SlotRangeDay(
          date: DateTime.tryParse('${d['date']}'.substring(0, 10)) ?? DateTime.now(),
          courts: (d['courts'] as List? ?? const [])
              .whereType<Map>()
              .map((c) => ScheduleCourt.fromJson(Map<String, dynamic>.from(c)))
              .toList(),
        ),
    ];
    return SlotsRange(
      totalSlots: _int(j['totalSlots']),
      bookedSlots: _int(j['bookedSlots']),
      availableSlots: _int(j['availableSlots']),
      lockedSlots: _int(j['lockedSlots']),
      reservedSlots: _int(j['reservedSlots']),
      days: days,
    );
  }
}

/// Khách đặt được bao nhiêu ca hôm nay (GET /facilities/{id}/availability).
class FacilityAvailability {
  final int availableSlots;
  final int bookableCourts;
  final int totalCourts;

  const FacilityAvailability({required this.availableSlots, required this.bookableCourts, required this.totalCourts});

  factory FacilityAvailability.fromJson(Object? data) {
    final j = data is Map ? data : const {};
    final courts = (j['courts'] as List? ?? const []).whereType<Map>().toList();
    return FacilityAvailability(
      availableSlots: _int(j['availableSlots']),
      bookableCourts: courts.where((c) => c['isBookable'] == true).length,
      totalCourts: courts.length,
    );
  }
}

/// Tuần lễ vàng / giá ngày đặc biệt: giá cố định mỗi ca cho một khoảng ngày.
class PricePeriod {
  final String id;
  final String name;
  final DateTime fromDate;
  final DateTime toDate;

  /// Rỗng = mọi sân.
  final List<String> courtIds;

  /// null = cả ngày.
  final String? startTime;
  final String? endTime;
  final int price;

  const PricePeriod({
    this.id = '',
    required this.name,
    required this.fromDate,
    required this.toDate,
    this.courtIds = const [],
    this.startTime,
    this.endTime,
    required this.price,
  });

  factory PricePeriod.fromJson(Map<String, dynamic> j) => PricePeriod(
        id: _str(j['id']) ?? '',
        name: _str(j['name']) ?? '',
        fromDate: DateTime.tryParse('${j['fromDate']}'.padRight(10).substring(0, 10)) ?? DateTime.now(),
        toDate: DateTime.tryParse('${j['toDate']}'.padRight(10).substring(0, 10)) ?? DateTime.now(),
        courtIds: (j['courtIds'] as List? ?? const []).map((e) => '$e').toList(),
        startTime: clockOf(j['startTime']),
        endTime: clockOf(j['endTime']),
        price: _int(j['price']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'fromDate': dayKey(fromDate),
        'toDate': dayKey(toDate),
        'courtIds': courtIds.isEmpty ? null : courtIds,
        'startTime': timeSpanOf(startTime),
        'endTime': timeSpanOf(endTime),
        'price': price,
      };

  /// Trùng phạm vi một thao tác đổi giá (findOverlappingPeriods của Web).
  bool overlaps({required List<String> courts, required DateTime from, required DateTime to, String? start, String? end}) {
    if (toDate.isBefore(DateTime(from.year, from.month, from.day)) || fromDate.isAfter(DateTime(to.year, to.month, to.day))) {
      return false;
    }
    final courtsOverlap = courts.isEmpty || courtIds.isEmpty || courtIds.any(courts.contains);
    final timesOverlap = start == null || end == null || startTime == null || endTime == null ||
        (start.compareTo(endTime!) < 0 && startTime!.compareTo(end) < 0);
    return courtsOverlap && timesOverlap;
  }
}

/// Kết quả lưu đợt giá: số ca trống đã đổi giá / số ca có khách giữ nguyên.
class PricePeriodResult {
  final int? updatedSlots;
  final int? skippedBookedSlots;

  const PricePeriodResult({this.updatedSlots, this.skippedBookedSlots});

  factory PricePeriodResult.fromJson(Object? data) {
    final j = data is Map ? data : const {};
    return PricePeriodResult(
      updatedSlots: _intOrNull(j['updatedSlots']),
      skippedBookedSlots: _intOrNull(j['skippedBookedSlots']),
    );
  }
}
