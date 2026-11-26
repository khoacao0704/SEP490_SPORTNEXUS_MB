import '../../core/constants/owner_rules.dart';
import '../../core/strings/owner_slot_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../models/booking.dart' show CancelReason;
import '../../models/owner_booking.dart';
import '../../models/owner_court.dart';
import '../repositories/owner_repository.dart';

/// Sân con giả lập của một cơ sở (sửa được).
class _MockCourt {
  final String id;
  String categoryId;
  String name;
  String sport;
  int price;
  bool active;
  String? courtType;
  bool? isIndoor;
  String? surfaceType;
  int? maxPlayers;
  int? teamSize;
  int? slotMinutes;

  _MockCourt(this.id, this.name, this.sport, this.price, {this.active = true, required this.categoryId, this.teamSize});

  OwnerCourt toOwnerCourt({int defaultMinutes = 60}) => OwnerCourt(
        id: id,
        categoryId: categoryId,
        categoryName: sport,
        name: name,
        status: active ? 'ACTIVE' : 'INACTIVE',
        defaultPrice: price,
        courtType: courtType,
        isIndoor: isIndoor,
        surfaceType: surfaceType,
        maxPlayers: maxPlayers,
        teamSize: teamSize,
        slotMinutes: slotMinutes,
        effectiveSlotMinutes: slotMinutes ?? defaultMinutes,
      );
}

/// Đơn giả lập kèm các ca nó giữ.
class _MockBooking {
  OwnerBooking booking;
  final List<String> slotIds;

  _MockBooking(this.booking, this.slotIds);
}

/// Vận hành Chủ sân giả lập (sân con, lưới ca, đơn, vãng lai, check-in) để chạy app / test khi chưa có BE.
/// Mỗi ngày có sẵn ca 1 giờ từ giờ mở tới giờ đóng cửa (coi như đã sinh); xóa ca thì ca biến mất
/// tới khi sinh lại. Đơn mẫu đặt quanh giờ hiện tại.
class MockOwnerBookingData {
  final DateTime Function() _now;
  final Map<String, List<_MockCourt>> _courts;
  final List<_MockBooking> _bookings = [];
  final Set<String> _locked = {};
  final Set<String> _deleted = {};
  final Map<String, int> _prices = {};
  final Map<String, (int, int)> _hours = {};
  final Map<String, List<PricePeriod>> _periods = {};
  int _counter = 0;

  static const String thienTrieu = 'f-hcm-thientrieu';
  static const String hoaLu = 'f-hcm-hoalu';
  static const int openHour = 6;
  static const int closeHour = 22;

  static const List<SportCategory> sports = [
    SportCategory(id: 'sp-badminton', name: 'Cầu Lông', defaultSlotMinutes: 60),
    SportCategory(id: 'sp-pickleball', name: 'Pickleball', defaultSlotMinutes: 60),
    SportCategory(id: 'sp-tennis', name: 'Tennis', defaultSlotMinutes: 60),
    SportCategory(id: 'sp-football', name: 'Bóng Đá', defaultSlotMinutes: 90),
    SportCategory(id: 'sp-basketball', name: 'Bóng Rổ', defaultSlotMinutes: 60),
  ];

  /// Mã vé đơn [bookingId] để thử nhập tay ở màn quét QR.
  static String ticketCode(String bookingId) => 'SPN-BK-$bookingId';

  static const List<CancelReason> cancelReasons = [
    CancelReason(code: 1, label: 'Thay đổi lịch trình / Bận việc đột xuất'),
    CancelReason(code: 2, label: 'Không đủ người chơi / Đồng đội hủy kèo'),
    CancelReason(code: 3, label: 'Thời tiết xấu / Không thuận lợi di chuyển'),
    CancelReason(code: 4, label: 'Đặt nhầm ngày, khung giờ hoặc nhầm sân'),
    CancelReason(code: 5, label: 'Vấn đề sức khỏe / Chấn thương'),
    CancelReason(code: 6, label: 'Khác (Tự nhập lý do)', isCustom: true),
  ];

  MockOwnerBookingData(this._now)
      : _courts = {
          thienTrieu: [
            _MockCourt('c-tt-1', 'Sân 1', 'Cầu Lông', 80000, categoryId: 'sp-badminton', teamSize: 2),
            _MockCourt('c-tt-2', 'Sân 2', 'Cầu Lông', 80000, categoryId: 'sp-badminton', teamSize: 2),
            _MockCourt('c-tt-3', 'Sân 3', 'Cầu Lông', 80000, categoryId: 'sp-badminton', teamSize: 2),
          ],
          hoaLu: [
            _MockCourt('c-hl-1', 'Sân 1', 'Bóng Đá', 500000, categoryId: 'sp-football', teamSize: 5),
            _MockCourt('c-hl-2', 'Sân 2', 'Bóng Đá', 500000, active: false, categoryId: 'sp-football', teamSize: 5),
          ],
        } {
    _seed();
  }

  // ---------------- Ca sân ----------------

  static String _dayKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static String slotId(String courtId, DateTime day, int hour) => 'sl-$courtId-${_dayKey(day)}-$hour';

  ({_MockCourt court, String facilityId, DateTime start, DateTime end})? _parseSlot(String id) {
    final m = RegExp(r'^sl-(.+)-(\d{8})-(\d+)$').firstMatch(id);
    if (m == null) return null;
    for (final entry in _courts.entries) {
      final court = entry.value.where((c) => c.id == m.group(1)).firstOrNull;
      if (court == null) continue;
      final d = m.group(2)!;
      final start = DateTime(int.parse(d.substring(0, 4)), int.parse(d.substring(4, 6)), int.parse(d.substring(6)),
          int.parse(m.group(3)!));
      return (court: court, facilityId: entry.key, start: start, end: start.add(const Duration(hours: 1)));
    }
    return null;
  }

  _MockBooking? _holder(String slotId) => _bookings
      .where((b) => b.booking.status != OwnerBookingStatus.cancelled && b.slotIds.contains(slotId))
      .firstOrNull;

  int _priceOf(String slotId, _MockCourt court) => _prices[slotId] ?? court.price;

  (int, int) _hoursOf(String facilityId) => _hours[facilityId] ?? (openHour, closeHour);

  List<_MockCourt> _courtsOf(String facilityId) => _courts[facilityId] ?? const [];

  _MockCourt _court(String facilityId, String courtId) => _courtsOf(facilityId).firstWhere((c) => c.id == courtId,
      orElse: () => throw const OwnerException('Không tìm thấy sân.'));

  /// Các giờ bắt đầu ca của [court] trong ngày [day] (bỏ ca đã xóa).
  Iterable<int> _hoursFor(String facilityId, _MockCourt court, DateTime day) sync* {
    final (open, close) = _hoursOf(facilityId);
    for (var h = open; h < close; h++) {
      if (!_deleted.contains(slotId(court.id, day, h))) yield h;
    }
  }

  ScheduleCourt _scheduleCourt(String facilityId, _MockCourt c, DateTime day, DateTime now) => ScheduleCourt(
        id: c.id,
        name: c.name,
        sport: c.sport,
        status: c.active ? 'ACTIVE' : 'INACTIVE',
        slots: [for (final h in _hoursFor(facilityId, c, day)) _slot(c, day, h, now)],
      );

  FacilityDaySchedule daySchedule(String facilityId, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final now = _now();
    final courts = [for (final c in _courtsOf(facilityId)) _scheduleCourt(facilityId, c, day, now)];
    final all = courts.expand((c) => c.slots).toList();
    return FacilityDaySchedule(
      facilityName: facilityId == thienTrieu ? 'Sân Cầu Lông Thiên Triều' : 'Sân Bóng Hoa Lư',
      totalSlots: all.length,
      availableSlots: all.where((s) => s.state == SlotCellState.available).length,
      lockedSlots: all.where((s) => s.state == SlotCellState.maintenance).length,
      courts: courts,
    );
  }

  ScheduleSlot _slot(_MockCourt c, DateTime day, int hour, DateTime now) {
    final id = slotId(c.id, day, hour);
    final start = DateTime(day.year, day.month, day.day, hour);
    final end = start.add(const Duration(hours: 1));
    final holder = _holder(id);
    final b = holder?.booking;
    return ScheduleSlot(
      id: id,
      start: start,
      end: end,
      status: b != null
          ? 'BOOKED'
          : _locked.contains(id)
              ? 'MAINTENANCE'
              : 'AVAILABLE',
      bookingStatus: b?.status ?? '',
      bookingId: b?.id,
      price: _priceOf(id, c),
      isPast: !end.isAfter(now),
      isWalkIn: b?.isWalkIn ?? false,
      customerName: b?.customerName,
      customerPhone: b?.customerPhone,
      bookingTotalAmount: b?.totalAmount,
    );
  }

  void setLocked(String slotId, bool locked) {
    final slot = _parseSlot(slotId);
    if (slot == null) throw const OwnerException(OwnerStrings.loadError);
    if (_holder(slotId) != null) throw const OwnerException('Ca đã có khách đặt, không đổi được trạng thái.');
    locked ? _locked.add(slotId) : _locked.remove(slotId);
  }

  void setPrice(String slotId, int price) {
    if (price < 1000) throw const OwnerException(OwnerStrings.priceTooLow);
    if (_parseSlot(slotId) == null) throw const OwnerException(OwnerStrings.loadError);
    if (_holder(slotId) != null) throw const OwnerException('Ca đã có khách đặt, không đổi được giá.');
    _prices[slotId] = price;
  }

  void deleteSlot(String slotId) {
    final slot = _parseSlot(slotId);
    if (slot == null) throw const OwnerException(OwnerStrings.loadError);
    if (_holder(slotId) != null) throw const OwnerException('Ca đã có khách đặt, không xóa được.');
    _deleted.add(slotId);
    _locked.remove(slotId);
  }

  // ---------------- Sân con ----------------

  List<OwnerCourt> courts(String facilityId) => [
        for (final c in _courtsOf(facilityId))
          c.toOwnerCourt(defaultMinutes: sports.where((s) => s.id == c.categoryId).firstOrNull?.defaultSlotMinutes ?? 60),
      ];

  OwnerCourt court(String facilityId, String courtId) {
    final c = _court(facilityId, courtId).toOwnerCourt();
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    var free = 0;
    for (var d = 0; d < 7; d++) {
      final day = today.add(Duration(days: d));
      free += _scheduleCourt(facilityId, _court(facilityId, courtId), day, now)
          .slots
          .where((s) => s.state == SlotCellState.available)
          .length;
    }
    return OwnerCourt(
      id: c.id,
      categoryId: c.categoryId,
      categoryName: c.categoryName,
      name: c.name,
      status: c.status,
      defaultPrice: c.defaultPrice,
      courtType: c.courtType,
      isIndoor: c.isIndoor,
      surfaceType: c.surfaceType,
      maxPlayers: c.maxPlayers,
      teamSize: c.teamSize,
      slotMinutes: c.slotMinutes,
      effectiveSlotMinutes: c.effectiveSlotMinutes,
      availableSlotsNext7Days: free,
      minUpcomingPrice: c.defaultPrice,
      maxUpcomingPrice: c.defaultPrice,
    );
  }

  void _apply(_MockCourt c, CourtInput input) {
    final sport = sports.where((s) => s.id == input.categoryId).firstOrNull;
    c
      ..categoryId = input.categoryId
      ..sport = sport?.name ?? c.sport
      ..name = input.name
      ..price = input.defaultPrice
      ..courtType = input.courtType
      ..isIndoor = input.isIndoor
      ..surfaceType = input.surfaceType
      ..maxPlayers = input.maxPlayers
      ..teamSize = input.teamSize
      ..slotMinutes = input.slotMinutes;
    if (input.status != null) c.active = input.status == 'ACTIVE';
  }

  void createCourt(String facilityId, CourtInput input) {
    if (input.name.trim().isEmpty) throw const OwnerException(OwnerSlotStrings.errName);
    final c = _MockCourt('c-new-${++_counter}', input.name, '', input.defaultPrice, categoryId: input.categoryId);
    _apply(c, input);
    _courts.putIfAbsent(facilityId, () => []).add(c);
  }

  void updateCourt(String facilityId, String courtId, CourtInput input) => _apply(_court(facilityId, courtId), input);

  /// Xóa sân và ca tương lai chưa có người đặt (7 ngày tới); trả số ca đã xóa.
  int deleteCourt(String facilityId, String courtId) {
    final c = _court(facilityId, courtId);
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    var removed = 0;
    for (var d = 0; d < 7; d++) {
      removed += _scheduleCourt(facilityId, c, today.add(Duration(days: d)), now)
          .slots
          .where((s) => s.state == SlotCellState.available)
          .length;
    }
    _courts[facilityId]!.remove(c);
    return removed;
  }

  void setHours(String facilityId, String open, String close) {
    int hourOf(String hhmm) => int.parse(hhmm.split(':').first);
    if (close.compareTo(open) <= 0) throw const OwnerException(OwnerSlotStrings.hoursInvalid);
    _hours[facilityId] = (hourOf(open), hourOf(close) == 0 ? 24 : hourOf(close));
  }

  SlotsRange range(String facilityId, DateTime from, DateTime to) {
    final now = _now();
    final days = <SlotRangeDay>[];
    for (var d = DateTime(from.year, from.month, from.day); !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      days.add(SlotRangeDay(date: d, courts: [for (final c in _courtsOf(facilityId)) _scheduleCourt(facilityId, c, d, now)]));
    }
    final all = days.expand((d) => d.courts).expand((c) => c.slots).toList();
    return SlotsRange(
      totalSlots: all.length,
      bookedSlots: all.where((s) => s.isBooked).length,
      availableSlots: all.where((s) => s.state == SlotCellState.available).length,
      lockedSlots: all.where((s) => s.state == SlotCellState.maintenance).length,
      reservedSlots: all.where((s) => s.state == SlotCellState.reserved).length,
      days: days,
    );
  }

  FacilityAvailability availability(String facilityId, DateTime date) {
    final day = daySchedule(facilityId, date);
    final active = day.courts.where((c) => c.isActive).toList();
    return FacilityAvailability(
      availableSlots: active.expand((c) => c.slots).where((s) => s.state == SlotCellState.available).length,
      bookableCourts: active.length,
      totalCourts: day.courts.length,
    );
  }

  Iterable<_MockCourt> _targets(String facilityId, List<String> ids) =>
      ids.isEmpty ? _courtsOf(facilityId).where((c) => c.active) : _courtsOf(facilityId).where((c) => ids.contains(c.id));

  static int _hourOf(String? hhmm, int fallback) => hhmm == null ? fallback : int.parse(hhmm.split(':').first);

  static bool _inTime(int hour, String? start, String? end) =>
      (start == null || hour >= _hourOf(start, 0)) && (end == null || hour < _hourOf(end, 24));

  List<GenerateResultRow> generate(String facilityId, GenerateSlotsRequest r) {
    final now = _now();
    final (open, close) = _hoursOf(facilityId);
    final from = _hourOf(r.openTime, open);
    final to = r.closeTime == null ? close : (_hourOf(r.closeTime, close) == 0 ? 24 : _hourOf(r.closeTime, close));
    final rows = <GenerateResultRow>[];
    for (final c in _targets(facilityId, r.courtIds)) {
      var created = 0, updated = 0, skipped = 0, past = 0;
      for (var d = DateTime(r.dateFrom.year, r.dateFrom.month, r.dateFrom.day);
          !d.isAfter(r.dateTo);
          d = d.add(const Duration(days: 1))) {
        for (var h = from; h < to; h++) {
          final id = slotId(c.id, d, h);
          final start = DateTime(d.year, d.month, d.day, h);
          if (!start.add(const Duration(hours: 1)).isAfter(now)) {
            past++;
            continue;
          }
          if (_holder(id) != null) {
            skipped++;
            continue;
          }
          _deleted.remove(id) ? created++ : updated++;
          final rule = r.priceRules
              .where((x) => (x.daysOfWeek.isEmpty || x.daysOfWeek.contains(WeekDays.ofDate(d))) && _inTime(h, x.startTime, x.endTime))
              .firstOrNull;
          final price = rule?.price ?? r.price;
          price == null ? _prices.remove(id) : _prices[id] = price;
        }
      }
      rows.add(GenerateResultRow(courtId: c.id, courtName: c.name, created: created, updated: updated, skipped: skipped, past: past));
    }
    return rows;
  }

  BulkSlotResult bulk(String facilityId, BulkSlotRequest r) {
    final now = _now();
    var matched = 0, affected = 0, skipped = 0;
    for (final c in _targets(facilityId, r.courtIds)) {
      for (var d = DateTime(r.dateFrom.year, r.dateFrom.month, r.dateFrom.day);
          !d.isAfter(r.dateTo);
          d = d.add(const Duration(days: 1))) {
        if (r.daysOfWeek.isNotEmpty && !r.daysOfWeek.contains(WeekDays.ofDate(d))) continue;
        for (final h in _hoursFor(facilityId, c, d).toList()) {
          if (!_inTime(h, r.startTime, r.endTime)) continue;
          matched++;
          final id = slotId(c.id, d, h);
          final free = _holder(id) == null && DateTime(d.year, d.month, d.day, h + 1).isAfter(now);
          final ok = switch (r.action) {
            BulkSlotAction.lock => free && _locked.add(id),
            BulkSlotAction.unlock => _locked.remove(id),
            BulkSlotAction.setPrice => free && !_locked.contains(id),
            BulkSlotAction.delete => free,
          };
          if (!ok) {
            skipped++;
            continue;
          }
          affected++;
          if (r.action == BulkSlotAction.setPrice) _prices[id] = r.price!;
          if (r.action == BulkSlotAction.delete) {
            _deleted.add(id);
            _locked.remove(id);
          }
        }
      }
    }
    return BulkSlotResult(matched: matched, affected: affected, skipped: skipped);
  }

  // ---------------- Đợt giá đặc biệt ----------------

  List<PricePeriod> periods(String facilityId, {DateTime? from}) => [
        for (final p in _periods[facilityId] ?? const <PricePeriod>[])
          if (from == null || !p.toDate.isBefore(DateTime(from.year, from.month, from.day))) p,
      ];

  PricePeriodResult savePeriod(String facilityId, PricePeriod p) {
    final list = _periods.putIfAbsent(facilityId, () => []);
    final saved = PricePeriod(
      id: p.id.isEmpty ? 'pp-${++_counter}' : p.id,
      name: p.name,
      fromDate: p.fromDate,
      toDate: p.toDate,
      courtIds: p.courtIds,
      startTime: p.startTime,
      endTime: p.endTime,
      price: p.price,
    );
    final i = list.indexWhere((x) => x.id == saved.id);
    i >= 0 ? list[i] = saved : list.add(saved);
    final result = bulk(
      facilityId,
      BulkSlotRequest(
        action: BulkSlotAction.setPrice,
        courtIds: p.courtIds,
        dateFrom: p.fromDate,
        dateTo: p.toDate,
        startTime: p.startTime,
        endTime: p.endTime,
        price: p.price,
      ),
    );
    return PricePeriodResult(updatedSlots: result.affected, skippedBookedSlots: result.skipped);
  }

  void deletePeriod(String facilityId, String id) => _periods[facilityId]?.removeWhere((p) => p.id == id);

  // ---------------- Đơn ----------------

  OwnerBooking find(String bookingId) {
    final b = _bookings.where((b) => b.booking.id == bookingId).firstOrNull;
    if (b == null) throw const OwnerException('Không tìm thấy đơn đặt sân.');
    return b.booking;
  }

  _MockBooking _entry(String bookingId) => _bookings.firstWhere((b) => b.booking.id == bookingId,
      orElse: () => throw const OwnerException('Không tìm thấy đơn đặt sân.'));

  OwnerBookingPage page({
    required String facilityId,
    DateTime? date,
    DateTime? from,
    DateTime? to,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 15,
  }) {
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final q = search?.trim().toLowerCase() ?? '';
    final inRange = _bookings.map((b) => b.booking).where((b) {
      if (b.facilityId != facilityId) return false;
      if (date != null && !sameDay(b.start, date)) return false;
      if (from != null && b.start.isBefore(DateTime(from.year, from.month, from.day))) return false;
      if (to != null && !b.start.isBefore(DateTime(to.year, to.month, to.day + 1))) return false;
      if (q.isNotEmpty &&
          !(b.customerName ?? '').toLowerCase().contains(q) &&
          !(b.customerPhone ?? '').contains(q)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final filtered = status == null || status.isEmpty ? inRange : inRange.where((b) => b.status == status).toList();
    final pages = (filtered.length / pageSize).ceil().clamp(1, 1 << 30);
    final items = filtered.skip((page - 1) * pageSize).take(pageSize).toList();
    return OwnerBookingPage(
      items: items,
      total: filtered.length,
      totalPages: pages,
      revenue: inRange.where((b) => b.status != OwnerBookingStatus.cancelled).fold(0, (s, b) => s + b.totalAmount),
      paidCount: inRange.where((b) => b.status == OwnerBookingStatus.paid).length,
      checkedInCount: inRange.where((b) => b.status == OwnerBookingStatus.checkedIn).length,
      cancelledCount: inRange.where((b) => b.status == OwnerBookingStatus.cancelled).length,
    );
  }

  void walkIn(WalkInRequest r) {
    if (r.customerName.trim().isEmpty) throw const OwnerException(OwnerStrings.walkInNameRequired);
    final ids = r.courtSlotIds ?? _consecutive(r.courtSlotId!, r.numberOfSlots);
    final parsed = ids.map(_parseSlot).toList();
    if (parsed.contains(null) || ids.isEmpty) throw const OwnerException(OwnerStrings.loadError);
    final now = _now();
    for (var i = 0; i < ids.length; i++) {
      final p = parsed[i]!;
      if (_holder(ids[i]) != null || _locked.contains(ids[i]) || !p.end.isAfter(now)) {
        throw OwnerException('Ca ${_hm(p.start)} – ${_hm(p.end)} không còn trống.');
      }
    }
    final first = parsed.first!;
    final total = [for (var i = 0; i < ids.length; i++) _priceOf(ids[i], parsed[i]!.court)].fold(0, (a, b) => a + b);
    final id = 'WI${++_counter}';
    _bookings.add(_MockBooking(
      OwnerBooking(
        id: id,
        facilityId: first.facilityId,
        status: r.autoCheckIn ? OwnerBookingStatus.checkedIn : OwnerBookingStatus.paid,
        courtName: first.court.name,
        sportName: first.court.sport,
        start: parsed.map((p) => p!.start).reduce((a, b) => a.isBefore(b) ? a : b),
        end: parsed.map((p) => p!.end).reduce((a, b) => a.isAfter(b) ? a : b),
        totalAmount: total,
        paidAmount: total,
        createdAt: now,
        customerName: r.customerName.trim(),
        customerPhone: r.customerPhone,
        customerNote: r.note,
        isWalkIn: true,
        participantCount: 1,
        checkedInCount: r.autoCheckIn ? 1 : 0,
        participants: [
          OwnerBookingParticipant(
            userId: 'walkin-$id',
            fullName: r.customerName.trim(),
            phone: r.customerPhone,
            isHost: true,
            amountContributed: total,
            paymentStatus: 'PAID',
            isCheckedIn: r.autoCheckIn,
          ),
        ],
      ),
      ids,
    ));
  }

  List<String> _consecutive(String firstId, int n) {
    final p = _parseSlot(firstId);
    if (p == null) return const [];
    return [for (var i = 0; i < n; i++) slotId(p.court.id, p.start, p.start.hour + i)];
  }

  void checkIn(String bookingId) {
    final e = _entry(bookingId);
    final b = e.booking;
    if (b.status == OwnerBookingStatus.checkedIn) throw const OwnerException('Đơn này đã check-in.');
    if (b.status != OwnerBookingStatus.paid) throw const OwnerException('Đơn chưa thanh toán hoặc đã hủy, không check-in được.');
    e.booking = b.copyWith(
      status: OwnerBookingStatus.checkedIn,
      checkedInCount: b.participantCount,
      participants: [
        for (final p in b.participants)
          OwnerBookingParticipant(
            userId: p.userId,
            fullName: p.fullName,
            phone: p.phone,
            avatarUrl: p.avatarUrl,
            isHost: p.isHost,
            amountContributed: p.amountContributed,
            paymentStatus: p.paymentStatus,
            isCheckedIn: true,
          ),
      ],
    );
  }

  void end(String bookingId) {
    final e = _entry(bookingId);
    if (!e.booking.canEndEarly(_now())) throw const OwnerException(OwnerStrings.endEarlyFailed);
    e.booking = e.booking.copyWith(status: 'COMPLETED');
  }

  ScanResult scan(String facilityId, String code) {
    final m = RegExp(r'^SPN-BK-(.+)$', caseSensitive: false).firstMatch(code.trim());
    final b = m == null ? null : _bookings.where((b) => b.booking.id.toUpperCase() == m.group(1)!.toUpperCase()).firstOrNull;
    if (b == null || b.booking.facilityId != facilityId) {
      throw const OwnerException('Vé không hợp lệ hoặc không thuộc cơ sở này.');
    }
    checkIn(b.booking.id);
    final booking = b.booking;
    return ScanResult(
      message: OwnerStrings.scanSuccessDefault,
      ticketType: 'BOOKING',
      customerName: booking.customerName,
      courtName: booking.courtName,
      start: booking.start,
      end: booking.end,
      amount: booking.totalAmount,
    );
  }

  OwnerCancelResult cancel(String bookingId, {String? reason, bool lockSlot = false}) {
    final e = _entry(bookingId);
    final b = e.booking;
    if (!b.canCancel) throw const OwnerException('Đơn này không còn hủy được.');
    final now = _now();
    final late = OwnerCancelRules.isLate(b.start, now);
    final penalty = OwnerCancelRules.penaltyFor(b.totalAmount, late: late, walkIn: b.isWalkIn);
    e.booking = b.copyWith(
      status: OwnerBookingStatus.cancelled,
      cancellation: OwnerBookingCancellation(
        cancelledAt: now,
        reason: reason,
        refundAmount: b.paidAmount,
        penaltyAmount: penalty,
      ),
    );
    if (lockSlot) _locked.addAll(e.slotIds);
    return OwnerCancelResult(
      penaltyAmount: penalty,
      fairPlayPenalty: OwnerCancelRules.fairPlayFor(late: late, walkIn: b.isWalkIn),
      refundAmount: b.paidAmount,
    );
  }

  /// Số đơn còn hiệu lực của cơ sở chạm khoảng [from, to) (để chặn tạm đóng cơ sở).
  int activeBookingsIn(String facilityId, DateTime from, DateTime to, {String? sportLabel}) => _bookings
      .map((b) => b.booking)
      .where((b) =>
          b.facilityId == facilityId &&
          (b.status == OwnerBookingStatus.pending ||
              b.status == OwnerBookingStatus.paid ||
              b.status == OwnerBookingStatus.checkedIn) &&
          (sportLabel == null || b.sportName == sportLabel) &&
          b.start.isBefore(to) &&
          b.end.isAfter(from))
      .length;

  static String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---------------- Dữ liệu mẫu ----------------

  void _seed() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    // Giờ hiện tại kẹp trong giờ mở cửa để đơn mẫu luôn nằm trên lưới.
    final h = now.hour.clamp(openHour + 2, closeHour - 3);

    void add({
      required String id,
      required String facilityId,
      required String courtId,
      required DateTime day,
      required int hour,
      int slots = 1,
      required String status,
      required String customer,
      String? phone,
      bool walkIn = false,
      List<(String, bool)> players = const [],
      OwnerBookingLfg? lfg,
      String? note,
    }) {
      final court = _courts[facilityId]!.firstWhere((c) => c.id == courtId);
      final ids = [for (var i = 0; i < slots; i++) slotId(courtId, day, hour + i)];
      final total = court.price * slots;
      final checked = status == OwnerBookingStatus.checkedIn;
      final people = players.isEmpty ? [(customer, checked)] : players;
      final start = DateTime(day.year, day.month, day.day, hour);
      _bookings.add(_MockBooking(
        OwnerBooking(
          id: id,
          facilityId: facilityId,
          status: status,
          courtName: court.name,
          sportName: court.sport,
          start: start,
          end: start.add(Duration(hours: slots)),
          totalAmount: total,
          paidAmount: status == OwnerBookingStatus.pending ? total ~/ 2 : total,
          pendingAmount: status == OwnerBookingStatus.pending ? total - total ~/ 2 : 0,
          createdAt: now.subtract(const Duration(days: 1)),
          customerName: customer,
          customerPhone: phone,
          customerNote: note,
          isWalkIn: walkIn,
          participantCount: people.length,
          checkedInCount: people.where((p) => p.$2).length,
          participants: [
            for (var i = 0; i < people.length; i++)
              OwnerBookingParticipant(
                userId: 'u-$id-$i',
                fullName: people[i].$1,
                isHost: i == 0,
                amountContributed: total ~/ people.length,
                paymentStatus: status == OwnerBookingStatus.pending && i > 0 ? 'PENDING' : 'PAID',
                isCheckedIn: people[i].$2,
              ),
          ],
          lfg: lfg,
        ),
        ids,
      ));
    }

    add(
      id: 'OW1002',
      facilityId: thienTrieu,
      courtId: 'c-tt-2',
      day: today,
      hour: h - 1,
      slots: 2,
      status: OwnerBookingStatus.checkedIn,
      customer: 'Võ Thanh Tùng',
      phone: '0903******',
      players: const [('Võ Thanh Tùng', true), ('Ngô Mỹ Linh', true)],
      lfg: const OwnerBookingLfg(
        status: 'FILLED',
        totalSlots: 3,
        remainingSlots: 0,
        pricePerPerson: 20000,
        acceptedCount: 3,
        checkedInCount: 2,
        participants: [
          OwnerLfgPlayer(userId: 'u-lfg-12', fullName: 'Ngô Mỹ Linh', status: 'ACCEPTED', amountPaid: 20000, isCheckedIn: true),
          OwnerLfgPlayer(userId: 'u-lfg-13', fullName: 'Đặng Gia Huy', status: 'ACCEPTED', amountPaid: 20000),
          OwnerLfgPlayer(userId: 'u-lfg-14', fullName: 'Bùi Khánh Vy', status: 'LEFT'),
        ],
      ),
    );
    add(
      id: 'OW1001',
      facilityId: thienTrieu,
      courtId: 'c-tt-3',
      day: today,
      hour: h + 1,
      status: OwnerBookingStatus.paid,
      customer: 'Nguyễn Minh Anh',
      phone: '0912******',
      note: 'Cho mượn thêm 2 vợt',
    );
    add(
      id: 'OW1003',
      facilityId: thienTrieu,
      courtId: 'c-tt-1',
      day: today,
      hour: h + 2,
      slots: 2,
      status: OwnerBookingStatus.pending,
      customer: 'Trần Quốc Bảo',
      phone: '0987******',
      players: const [('Trần Quốc Bảo', false), ('Lê Văn Hải', false)],
    );
    add(
      id: 'WI100',
      facilityId: thienTrieu,
      courtId: 'c-tt-1',
      day: today,
      hour: h,
      status: OwnerBookingStatus.paid,
      customer: 'FC Hoàng Gia',
      phone: '0909123456',
      walkIn: true,
      note: 'Đã thu tiền mặt 100%',
    );
    add(
      id: 'OW1006',
      facilityId: thienTrieu,
      courtId: 'c-tt-1',
      day: tomorrow,
      hour: 18,
      status: OwnerBookingStatus.paid,
      customer: 'Hồ Thị Thu',
      phone: '0938******',
    );
    add(
      id: 'OW1004',
      facilityId: hoaLu,
      courtId: 'c-hl-1',
      day: today,
      hour: h + 1,
      status: OwnerBookingStatus.paid,
      customer: 'Phạm Đức Huy',
      phone: '0905******',
    );
    _locked.add(slotId('c-tt-3', today, h + 3));
  }
}
