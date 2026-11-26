import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_booking.dart';
import '../../theme/app_colors.dart';
import 'owner_badges.dart';
import 'owner_cancel_dialog.dart';
import 'stat_grid.dart';
import 'walk_in_sheet.dart';

String _hm(DateTime d) => Formatters.time(d);

/// Giờ kết thúc của ca; ca kết thúc lúc nửa đêm ghi 24:00 (như Web).
String _endHm(ScheduleSlot s) {
  final t = _hm(s.end);
  return t == '00:00' ? '24:00' : t;
}

int _minutes(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Ghép "từ giờ – đến giờ" thành các ca trống liên tiếp của một sân (slotsForRange của Web).
/// Trả về danh sách ca, hoặc câu lỗi.
({List<CourtSlot>? items, String? error}) slotsForRange(ScheduleCourt? court, String? from, String? to) {
  if (court == null) return (items: null, error: OwnerStrings.rangeNoCourt);
  if (from == null || to == null) return (items: null, error: OwnerStrings.rangeNoTime);
  if (_minutes(to) <= _minutes(from)) return (items: null, error: OwnerStrings.rangeOrder);
  final inRange = court.slots
      .where((s) => _minutes(_hm(s.start)) >= _minutes(from) && _minutes(_endHm(s)) <= _minutes(to))
      .toList();
  if (inRange.isEmpty) return (items: null, error: OwnerStrings.rangeNone(court.name, from, to));
  final first = _hm(inRange.first.start);
  final last = _endHm(inRange.last);
  if (first != from || last != to) return (items: null, error: OwnerStrings.rangeMisaligned(first, last));
  for (var i = 1; i < inRange.length; i++) {
    if (inRange[i].start != inRange[i - 1].end) {
      return (items: null, error: OwnerStrings.rangeGap(_endHm(inRange[i - 1]), _hm(inRange[i].start)));
    }
  }
  final taken = inRange.where((s) => s.state != SlotCellState.available).firstOrNull;
  if (taken != null) return (items: null, error: OwnerStrings.rangeTaken(_hm(taken.start), _endHm(taken)));
  return (items: [for (final s in inRange) (court: court, slot: s)], error: null);
}

/// Lưới lịch một ngày của cơ sở (BookingSchedule của Web): sân con theo cột, giờ theo dòng.
/// Bấm ô trống → nhận khách vãng lai; ô đã đặt → chi tiết, check-in thủ công, hủy; ô bảo trì → mở lại.
class ScheduleGridView extends StatefulWidget {
  final String facilityId;
  final int revision;
  final ValueChanged<String> onOpenBooking;
  final VoidCallback onChanged;

  const ScheduleGridView({
    super.key,
    required this.facilityId,
    required this.revision,
    required this.onOpenBooking,
    required this.onChanged,
  });

  @override
  State<ScheduleGridView> createState() => _ScheduleGridViewState();
}

class _ScheduleGridViewState extends State<ScheduleGridView> {
  static const double _timeColWidth = 56;
  static const double _cellWidth = 112;
  static const double _cellHeight = 64;

  /// Ô cao theo cỡ chữ người dùng chọn (chữ phóng to không bị cắt).
  double _rowHeight = _cellHeight;

  late DateTime _date = _today();
  String _sport = '';
  FacilityDaySchedule? _data;
  String? _error;
  bool _loading = true;
  int _seq = 0;

  bool _multi = false;
  final List<CourtSlot> _picks = [];

  bool _manualOpen = false;
  String? _manualCourtId;
  String? _manualFrom;
  String? _manualTo;
  String? _manualError;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ScheduleGridView old) {
    super.didUpdateWidget(old);
    if (old.facilityId != widget.facilityId) {
      _picks.clear();
      _data = null;
    }
    if (old.facilityId != widget.facilityId || old.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AppRepositories.owner.getDaySchedule(widget.facilityId, _date);
      if (mounted && seq == _seq) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && seq == _seq) {
        setState(() {
          _loading = false;
          _error = ownerErrorMessage(e);
        });
      }
    }
  }

  void _setDate(DateTime d) {
    setState(() {
      _date = DateTime(d.year, d.month, d.day);
      _picks.clear();
      _data = null;
    });
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) _setDate(picked);
  }

  List<ScheduleCourt> get _courts =>
      (_data?.courts ?? const <ScheduleCourt>[]).where((c) => _sport.isEmpty || c.sport == _sport).toList();

  Future<void> _afterChange(bool changed) async {
    if (!changed) return;
    setState(() {
      _picks.clear();
      _multi = false;
    });
    widget.onChanged();
  }

  Future<void> _tapCell(ScheduleCourt court, ScheduleSlot slot) async {
    final state = slot.state;
    if (_multi) {
      if (state != SlotCellState.available) return;
      setState(() {
        final i = _picks.indexWhere((p) => p.slot.id == slot.id);
        i >= 0 ? _picks.removeAt(i) : _picks.add((court: court, slot: slot));
      });
      return;
    }
    switch (state) {
      case SlotCellState.past:
      case SlotCellState.reserved:
        return;
      case SlotCellState.available:
        await _afterChange(await showWalkInSheet(context, items: [(court: court, slot: slot)], date: _date));
      case SlotCellState.maintenance:
        await _afterChange(await _showMaintenance(court, slot));
      case SlotCellState.checkedIn:
      case SlotCellState.paid:
      case SlotCellState.pending:
        await _afterChange(await _showBooked(court, slot));
    }
  }

  Future<void> _bookPicked() async {
    if (_picks.isEmpty) return;
    final items = [..._picks]
      ..sort((a, b) {
        final byCourt = a.court.name.compareTo(b.court.name);
        return byCourt != 0 ? byCourt : a.slot.start.compareTo(b.slot.start);
      });
    await _afterChange(await showWalkInSheet(context, items: items, date: _date));
  }

  Future<void> _submitManual() async {
    final court = _courts.where((c) => c.id == _manualCourtId).firstOrNull;
    final r = slotsForRange(court, _manualFrom, _manualTo);
    if (r.error != null) {
      setState(() => _manualError = r.error);
      return;
    }
    setState(() => _manualError = null);
    await _afterChange(await showWalkInSheet(context, items: r.items!, date: _date));
  }

  Future<void> _pickTime({required bool from}) async {
    final current = from ? _manualFrom : _manualTo;
    final initial = current == null
        ? const TimeOfDay(hour: 17, minute: 0)
        : TimeOfDay(hour: _minutes(current) ~/ 60 % 24, minute: _minutes(current) % 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      // Chọn 00:00 ở ô "Đến giờ" nghĩa là hết ngày.
      if (from) {
        _manualFrom = value;
      } else {
        _manualTo = value == '00:00' ? '24:00' : value;
      }
      _manualError = null;
    });
  }

  // ---------------- Popup ca đã đặt / ca đang khóa ----------------

  Future<bool> _showMaintenance(ScheduleCourt court, ScheduleSlot slot) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _ActionSheet(
        title: OwnerStrings.maintenanceTitle,
        body: Text(OwnerStrings.maintenanceBody(court.name, Formatters.timeRange(slot.start, slot.end), Formatters.date(_date))),
        actions: [
          _SheetAction(
            label: slot.isPast ? OwnerStrings.slotPast : OwnerStrings.unlockSlot,
            enabled: !slot.isPast,
            run: () => AppRepositories.owner.setSlotLocked(slot.id, locked: false),
            success: OwnerStrings.slotUnlocked,
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _showBooked(ScheduleCourt court, ScheduleSlot slot) async {
    final state = slot.state;
    final bookingId = slot.bookingId;
    var openDetail = false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        final colors = cellColors(state);
        return _ActionSheet(
          title: OwnerStrings.slotBookingTitle(court.name),
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(6)),
            child: Text(
              OwnerStrings.slotStatusLabel(state),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.chip),
            ),
          ),
          body: Column(
            children: [
              for (final (label, value) in [
                (OwnerStrings.rowBooker, '${slot.customerName ?? '—'}${slot.isWalkIn ? OwnerStrings.rowWalkInSuffix : ''}'),
                (OwnerStrings.rowPhone, slot.customerPhone ?? '—'),
                (OwnerStrings.rowTime, '${Formatters.timeRange(slot.start, slot.end)} • ${Formatters.date(_date)}'),
                (OwnerStrings.rowPrice, Formatters.vnd(slot.price)),
                (
                  OwnerStrings.rowCode,
                  (bookingId ?? '—').substring(0, (bookingId ?? '—').length.clamp(0, 8)).toUpperCase()
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(value,
                            textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              if (state == SlotCellState.checkedIn)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(OwnerStrings.checkedInNoCancel, style: TextStyle(color: AppColors.textSecondary)),
                ),
            ],
          ),
          actions: [
            if (bookingId != null)
              _SheetAction(
                label: OwnerStrings.openBooking,
                outlined: true,
                closeOnly: true,
                onClose: () => openDetail = true,
              ),
            if (state == SlotCellState.paid && bookingId != null)
              _SheetAction(
                label: OwnerStrings.manualCheckIn,
                busyLabel: OwnerStrings.checkingIn,
                run: () => AppRepositories.owner.checkInBooking(bookingId),
                success: OwnerStrings.manualCheckInDone,
              ),
            if (state != SlotCellState.checkedIn && bookingId != null)
              _SheetAction(
                label: OwnerStrings.cancelSlotBooking,
                danger: true,
                custom: (ctx) async {
                  final ok = await showOwnerCancelDialog(
                    ctx,
                    OwnerCancelTarget(
                      bookingId: bookingId,
                      courtName: court.name,
                      customerName: slot.customerName,
                      start: slot.start,
                      end: slot.end,
                      totalAmount: slot.bookingTotalAmount ?? slot.price,
                      isWalkIn: slot.isWalkIn,
                    ),
                  );
                  return ok;
                },
              ),
          ],
        );
      },
    );
    if (openDetail && bookingId != null) widget.onOpenBooking(bookingId);
    return result ?? false;
  }

  // ---------------- Giao diện ----------------

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final courts = _courts;
    final sports = {for (final c in data?.courts ?? const <ScheduleCourt>[]) c.sport}.toList();
    final times = {for (final c in courts) for (final s in c.slots) _hm(s.start)}.toList()..sort();

    var total = 0, booked = 0, checkedIn = 0, revenue = 0;
    for (final c in courts) {
      for (final s in c.slots) {
        total++;
        if (s.isBooked) {
          booked++;
          revenue += s.price;
          if (s.state == SlotCellState.checkedIn) checkedIn++;
        }
      }
    }
    final occupancy = total == 0 ? 0 : (booked * 100 / total).round();
    final pickedTotal = _picks.fold(0, (sum, p) => sum + p.slot.price);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  OwnerStrings.scheduleTitle(Formatters.date(_date)),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                if (data != null)
                  Text(
                    OwnerStrings.gridScale(data.totalSlots, data.availableSlots, data.lockedSlots),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 8),
                _dateBar(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: sports.contains(_sport) ? _sport : '',
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem(value: '', child: Text(OwnerStrings.allSports)),
                        for (final s in sports) DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _sport = v ?? ''),
                    ),
                    FilterChip(
                      label: Text(_multi ? OwnerStrings.multiModeExit : OwnerStrings.multiMode),
                      selected: _multi,
                      onSelected: (_) => setState(() {
                        _multi = !_multi;
                        _picks.clear();
                      }),
                    ),
                    FilterChip(
                      label: const Text(OwnerStrings.manualRange),
                      selected: _manualOpen,
                      onSelected: (_) => setState(() {
                        _manualOpen = !_manualOpen;
                        _manualError = null;
                      }),
                    ),
                  ],
                ),
                if (_manualOpen) _manualForm(courts),
                const SizedBox(height: 12),
                StatGrid(
                  spacing: 8,
                  children: [
                    _stat(OwnerStrings.statOccupancy, '$occupancy%', OwnerStrings.statOccupancySub(booked, total)),
                    _stat(OwnerStrings.statCheckedInGrid, OwnerStrings.statCheckedInValue(checkedIn),
                        OwnerStrings.statWaitingSub(booked - checkedIn)),
                    _stat(OwnerStrings.statRevenue, Formatters.vnd(revenue), OwnerStrings.statRevenueSub),
                    _stat(
                      OwnerStrings.statCourts,
                      OwnerStrings.statCourtsValue(courts.where((c) => c.isActive).length, courts.length),
                      OwnerStrings.statCourtsSub,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _legend(),
                const SizedBox(height: 12),
                if (_loading && data == null)
                  _message(Icons.hourglass_empty, OwnerStrings.gridLoading, null)
                else if (_error != null && data == null)
                  _message(Icons.error_outline, OwnerStrings.gridError, _error)
                else if (times.isEmpty)
                  _message(Icons.event_busy, OwnerStrings.gridEmpty, OwnerStrings.gridEmptyHint)
                else
                  _grid(courts, times),
              ],
            ),
          ),
        ),
        if (_multi) _multiBar(pickedTotal),
      ],
    );
  }

  Widget _dateBar() => Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _setDate(_date.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(
                    '${Formatters.weekday(_date)}, ${Formatters.date(_date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _setDate(_date.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => _setDate(_today()), child: const Text(OwnerStrings.today)),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ],
      );

  Widget _manualForm(List<ScheduleCourt> courts) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: courts.any((c) => c.id == _manualCourtId) ? _manualCourtId : null,
              isExpanded: true,
              hint: const Text(OwnerStrings.manualCourtHint),
              decoration: const InputDecoration(
                labelText: OwnerStrings.manualCourt,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [for (final c in courts) DropdownMenuItem(value: c.id, child: Text('${c.name} • ${c.sport}'))],
              onChanged: (v) => setState(() {
                _manualCourtId = v;
                _manualError = null;
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(from: true),
                    child: Text('${OwnerStrings.manualFrom}: ${_manualFrom ?? '--:--'}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(from: false),
                    child: Text('${OwnerStrings.manualTo}: ${_manualTo ?? '--:--'}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitManual,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                child: const Text(OwnerStrings.manualSubmit),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _manualError ?? OwnerStrings.manualHelp(Formatters.date(_date)),
              style: TextStyle(fontSize: 12, color: _manualError != null ? Colors.red : AppColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _legend() => Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (final (color, label) in [
            (const Color(0xFF10B981), OwnerStrings.legendCheckedIn),
            (const Color(0xFFF59E0B), OwnerStrings.legendPaid),
            (const Color(0xFF3B82F6), OwnerStrings.legendPending),
            (const Color(0xFF8B5CF6), OwnerStrings.legendReserved),
            (const Color(0xFF94A3B8), OwnerStrings.legendMaintenance),
            (AppColors.cardBorder, OwnerStrings.legendFree),
          ])
            Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
                  TextSpan(text: label),
                ],
              ),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
        ],
      );

  Widget _grid(List<ScheduleCourt> courts, List<String> times) {
    _rowHeight = MediaQuery.textScalerOf(context).scale(_cellHeight).clamp(_cellHeight, _cellHeight * 2.2);
    final byTime = [for (final c in courts) {for (final s in c.slots) _hm(s.start): s}];
    final pickedIds = {for (final p in _picks) p.slot.id};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: _timeColWidth),
              for (final c in courts)
                Container(
                  width: _cellWidth,
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      Text(
                        '${c.sport}${c.isActive ? '' : ' • ${OwnerStrings.courtSuspended}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.isActive ? AppColors.textSecondary : const Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          for (final t in times)
            Row(
              children: [
                SizedBox(
                  width: _timeColWidth,
                  height: _rowHeight,
                  child: Center(
                    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                  ),
                ),
                for (var i = 0; i < courts.length; i++) _cell(courts[i], byTime[i][t], pickedIds),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(ScheduleCourt court, ScheduleSlot? slot, Set<String> pickedIds) {
    if (slot == null) {
      return Container(
        width: _cellWidth,
        height: _rowHeight,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(8)),
        child: const Text('—', style: TextStyle(color: AppColors.cardBorder)),
      );
    }
    final state = slot.state;
    final colors = cellColors(state);
    final picked = pickedIds.contains(slot.id);
    final clickable = _multi
        ? state == SlotCellState.available
        : state != SlotCellState.past && state != SlotCellState.reserved;
    final Widget content;
    if (slot.isBooked || state == SlotCellState.reserved) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            state == SlotCellState.reserved ? (slot.matchName ?? OwnerStrings.cellMatch) : (slot.customerName ?? OwnerStrings.cellCustomer),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          Text(
            '${OwnerStrings.cellLabel(state)}${slot.isWalkIn ? OwnerStrings.cellWalkIn : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.chip),
          ),
        ],
      );
    } else {
      final label = switch (state) {
        SlotCellState.available => picked ? OwnerStrings.cellPicked : (_multi ? OwnerStrings.cellPick : OwnerStrings.cellFree),
        _ => OwnerStrings.cellLabel(state),
      };
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: state == SlotCellState.available ? colors.chip : const Color(0xFF64748B))),
          if (state == SlotCellState.available)
            Text(Formatters.vnd(slot.price),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      );
    }
    return Opacity(
      opacity: _multi && !clickable ? 0.55 : 1,
      child: Container(
        width: _cellWidth,
        height: _rowHeight,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: picked ? const Color(0xFFD1FAE5) : colors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: picked ? const Color(0xFF10B981) : AppColors.divider, width: picked ? 2 : 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: clickable ? () => _tapCell(court, slot) : null,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: content),
          ),
        ),
      ),
    );
  }

  Widget _multiBar(int pickedTotal) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _picks.isEmpty ? OwnerStrings.multiHint : OwnerStrings.multiPicked(_picks.length, pickedTotal),
                style: const TextStyle(fontSize: 13, color: AppColors.textMain),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _picks.isEmpty ? null : () => setState(_picks.clear),
                      child: const Text(OwnerStrings.clearPicks),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _picks.isEmpty ? null : _bookPicked,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                      child: Text(OwnerStrings.bookPicked(_picks.length)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _stat(String label, String value, String sub) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            ),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _message(IconData icon, String title, String? sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.primaryGreen),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (sub != null)
              Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
}

/// Một nút trong popup của ô lưới.
class _SheetAction {
  final String label;
  final String? busyLabel;
  final Future<void> Function()? run;
  final String? success;

  /// Thao tác tự xử lý (vd. mở popup hủy đơn); trả về true nếu có thay đổi.
  final Future<bool> Function(BuildContext context)? custom;
  final bool danger;
  final bool outlined;
  final bool enabled;

  /// Chỉ đóng popup rồi gọi [onClose] (vd. mở chi tiết đơn).
  final bool closeOnly;
  final VoidCallback? onClose;

  const _SheetAction({
    required this.label,
    this.busyLabel,
    this.run,
    this.success,
    this.custom,
    this.danger = false,
    this.outlined = false,
    this.enabled = true,
    this.closeOnly = false,
    this.onClose,
  });
}

class _ActionSheet extends StatefulWidget {
  final String title;
  final Widget? badge;
  final Widget body;
  final List<_SheetAction> actions;

  const _ActionSheet({required this.title, this.badge, required this.body, required this.actions});

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  _SheetAction? _busy;

  Future<void> _press(_SheetAction a) async {
    if (a.closeOnly) {
      a.onClose?.call();
      Navigator.pop(context, false);
      return;
    }
    if (a.custom != null) {
      final changed = await a.custom!(context);
      if (changed && mounted) Navigator.pop(context, true);
      return;
    }
    setState(() => _busy = a);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await a.run!();
      messenger.showSnackBar(SnackBar(content: Text(a.success ?? '')));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ownerErrorMessage(e)), backgroundColor: Colors.red));
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.badge != null) ...[widget.badge!, const SizedBox(height: 8)],
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              widget.body,
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in widget.actions)
                    a.outlined
                        ? OutlinedButton(onPressed: _busy == null && a.enabled ? () => _press(a) : null, child: Text(a.label))
                        : ElevatedButton(
                            onPressed: _busy == null && a.enabled ? () => _press(a) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: a.danger ? Colors.red : AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(_busy == a ? (a.busyLabel ?? OwnerStrings.processing) : a.label),
                          ),
                ],
              ),
            ],
          ),
        ),
      );
}
