import 'package:flutter/material.dart';

import '../../core/strings/owner_slot_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/owner_booking.dart';
import '../../models/owner_court.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart';
import '../../widgets/owner/slot_pickers.dart';
import '../../widgets/owner/stat_grid.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Sân sẽ thao tác: sân đã chọn; không chọn mà đang lọc môn thì mọi sân của môn đó; không lọc thì rỗng = mọi sân.
List<String> _targetIds(List<String> selected, List<OwnerCourt> courts, {required bool scoped}) {
  final visible = selected.where((id) => courts.any((c) => c.id == id)).toList();
  if (visible.isNotEmpty) return visible;
  return scoped ? [for (final c in courts) c.id] : const [];
}

/// Trang "Ca sân" (OwnerSlots của Web): lịch 7 ngày, đợt giá đặc biệt, sinh ca hàng loạt, thao tác hàng loạt.
class OwnerSlotsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const OwnerSlotsScreen({super.key, required this.facilityId, required this.facilityName});

  @override
  State<OwnerSlotsScreen> createState() => _OwnerSlotsScreenState();
}

class _OwnerSlotsScreenState extends State<OwnerSlotsScreen> {
  late DateTime _from = _today();
  List<OwnerCourt> _courts = const [];
  SlotsRange? _range;
  FacilityAvailability? _availability;
  String? _error;
  String _sport = '';

  @override
  void initState() {
    super.initState();
    _loadCourts();
    _refresh();
  }

  Future<void> _loadCourts() async {
    try {
      final courts = await AppRepositories.owner.getCourts(widget.facilityId);
      if (mounted) setState(() => _courts = courts);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final from = _from;
    try {
      final results = await Future.wait([
        AppRepositories.owner.getSlotsRange(widget.facilityId, from: from, to: from.add(const Duration(days: 6))),
        AppRepositories.owner.getAvailability(widget.facilityId, _today()),
      ]);
      if (!mounted || from != _from) return;
      setState(() {
        _range = results[0] as SlotsRange;
        _availability = results[1] as FacilityAvailability;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = ownerErrorMessage(e));
    }
  }

  void _setFrom(DateTime d) {
    setState(() {
      _from = DateTime(d.year, d.month, d.day);
      _range = null;
    });
    _refresh();
  }

  List<String> get _sportNames {
    final names = <String>{
      for (final c in _courts) c.categoryName,
      for (final d in _range?.days ?? const <SlotRangeDay>[]) for (final c in d.courts) c.sport,
    }.where((s) => s.isNotEmpty).toList()
      ..sort();
    return names;
  }

  @override
  Widget build(BuildContext context) {
    final sports = _sportNames;
    final active = sports.contains(_sport) ? _sport : '';
    final scoped = _courts.where((c) => active.isEmpty || c.categoryName == active).toList();
    final allLabel = active.isEmpty ? OwnerSlotStrings.allCourts : OwnerSlotStrings.allCourtsOf(active);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(OwnerSlotStrings.slotsTitle,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(OwnerSlotStrings.slotsSubtitle(widget.facilityName),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _weekCard(sports, active),
            const SizedBox(height: 12),
            _PricePeriodsCard(facilityId: widget.facilityId, courts: _courts, onDone: _refresh),
            const SizedBox(height: 12),
            _GenerateCard(
              key: ValueKey('gen-$active'),
              facilityId: widget.facilityId,
              courts: scoped,
              scoped: active.isNotEmpty,
              allLabel: allLabel,
              onDone: _refresh,
            ),
            const SizedBox(height: 12),
            _BulkCard(
              key: ValueKey('bulk-$active'),
              facilityId: widget.facilityId,
              courts: scoped,
              scoped: active.isNotEmpty,
              allLabel: allLabel,
              onDone: _refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekCard(List<String> sports, String active) {
    final r = _range;
    final days = r?.days ?? const <SlotRangeDay>[];
    final rows = <({String id, String name, String sport})>[
      if (days.isNotEmpty)
        for (final c in days.first.courts) (id: c.id, name: c.name, sport: c.sport)
      else
        for (final c in _courts) (id: c.id, name: c.name, sport: c.categoryName),
    ].where((row) => active.isEmpty || row.sport == active).toList()
      ..sort((a, b) => a.sport.compareTo(b.sport));
    final a = _availability;

    return _Card(
      children: [
        Row(
          children: [
            const Expanded(child: Text(OwnerSlotStrings.weekTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(
              tooltip: OwnerSlotStrings.prevWeek,
              onPressed: () => _setFrom(_from.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: OwnerSlotStrings.nextWeek,
              onPressed: () => _setFrom(_from.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: DateButton(label: OwnerSlotStrings.fromDate, value: _from, onChanged: _setFrom)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(onPressed: () => _setFrom(_today()), child: const Text(OwnerSlotStrings.today)),
            ),
          ],
        ),
        if (sports.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: Text(OwnerSlotStrings.allSportsChip(_courts.isNotEmpty ? _courts.length : rows.length)),
                selected: active.isEmpty,
                onSelected: (_) => setState(() => _sport = ''),
              ),
              for (final s in sports)
                ChoiceChip(
                  label: Text(OwnerSlotStrings.sportChip(s, _courts.where((c) => c.categoryName == s).length)),
                  selected: active == s,
                  onSelected: (_) => setState(() => _sport = s),
                ),
            ],
          ),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (a != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(OwnerSlotStrings.availabilityToday(a.availableSlots, a.bookableCourts, a.totalCourts),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        if (r != null && active.isNotEmpty)
          const Text(OwnerSlotStrings.wholeFacilityNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (r != null) ...[
          const SizedBox(height: 8),
          StatGrid(
            spacing: 8,
            children: [
              _stat(OwnerSlotStrings.statTotal, r.totalSlots),
              _stat(OwnerSlotStrings.statBooked, r.bookedSlots),
              _stat(OwnerSlotStrings.statFree, r.availableSlots),
              _stat(OwnerSlotStrings.statLocked, r.lockedSlots),
              _stat(OwnerSlotStrings.statReserved, r.reservedSlots),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (r == null && _error == null)
          const Text(OwnerSlotStrings.loadingWeek, style: TextStyle(color: AppColors.textSecondary))
        else if (rows.isEmpty)
          const Text(OwnerSlotStrings.noCourtsYet, style: TextStyle(color: AppColors.textSecondary))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.symmetric(inside: const BorderSide(color: AppColors.divider)),
              children: [
                TableRow(children: [
                  const SizedBox.shrink(),
                  for (final d in days)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text('${WeekDays.short[WeekDays.ofDate(d.date)]} ${Formatters.dayMonth(d.date)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ]),
                for (final row in rows)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(row.sport, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    for (final d in days) _dayCell(d, row.id),
                  ]),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(SlotRangeDay day, String courtId) {
    final court = day.courts.where((c) => c.id == courtId).firstOrNull;
    final slots = court?.slots ?? const <ScheduleSlot>[];
    if (court == null || slots.isEmpty) {
      return const Padding(padding: EdgeInsets.all(10), child: Text('—', style: TextStyle(color: AppColors.textSecondary)));
    }
    final booked = slots.where((s) => s.bookingId != null).length;
    final free = slots.where((s) => s.status == 'AVAILABLE' && !s.isPast).length;
    return InkWell(
      onTap: () => _openDay(day, court),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(OwnerSlotStrings.dayCell(slots.length), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryGreen)),
            Text(OwnerSlotStrings.dayCellSub(booked, free), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Future<void> _openDay(SlotRangeDay day, ScheduleCourt court) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FractionallySizedBox(heightFactor: 0.8, child: _DaySlotsSheet(day: day, court: court)),
    );
    if (changed == true) await _refresh();
  }

  Widget _stat(String label, int value) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text('$value', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

/// Danh sách ca của một sân trong một ngày; xóa được ca trống chưa qua giờ.
class _DaySlotsSheet extends StatefulWidget {
  final SlotRangeDay day;
  final ScheduleCourt court;

  const _DaySlotsSheet({required this.day, required this.court});

  @override
  State<_DaySlotsSheet> createState() => _DaySlotsSheetState();
}

class _DaySlotsSheetState extends State<_DaySlotsSheet> {
  late final List<ScheduleSlot> _slots = [...widget.court.slots];
  String? _busy;
  bool _changed = false;

  Future<void> _remove(ScheduleSlot s) async {
    if (!await confirmOwner(context, OwnerSlotStrings.deleteSlotConfirm(Formatters.timeRange(s.start, s.end)))) return;
    setState(() => _busy = s.id);
    try {
      await AppRepositories.owner.deleteSlot(s.id);
      _changed = true;
      if (mounted) {
        showOwnerSnack(context, OwnerSlotStrings.slotDeleted);
        setState(() => _slots.removeWhere((x) => x.id == s.id));
      }
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    }
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.pop(context, _changed);
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(OwnerSlotStrings.dayTitle(widget.court.name, Formatters.date(widget.day.date)),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(OwnerSlotStrings.daySlotsCount(_slots.length),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context, _changed), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    for (final s in _slots)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(Formatters.timeRange(s.start, s.end), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (s.isPast) const Text(OwnerSlotStrings.past, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  Text(Formatters.vnd(s.price), style: const TextStyle(fontSize: 12)),
                                  if (s.customerName != null || s.matchName != null)
                                    Text(s.customerName ?? s.matchName!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            OwnerBadge(OwnerSlotStrings.slotStatus(s.status), tone: toneForSlotStatus(s.status)),
                            if (!s.isPast && s.bookingId == null && s.status == 'AVAILABLE')
                              TextButton(
                                onPressed: _busy == null ? () => _remove(s) : null,
                                child: const Text(OwnerSlotStrings.delete),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ---------------- Đợt giá đặc biệt ----------------

class _PricePeriodsCard extends StatefulWidget {
  final String facilityId;
  final List<OwnerCourt> courts;
  final VoidCallback onDone;

  const _PricePeriodsCard({required this.facilityId, required this.courts, required this.onDone});

  @override
  State<_PricePeriodsCard> createState() => _PricePeriodsCardState();
}

class _PricePeriodsCardState extends State<_PricePeriodsCard> {
  List<PricePeriod>? _items;
  bool _unavailable = false;
  String? _error;
  PricePeriod? _editing;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await AppRepositories.owner.getPricePeriods(widget.facilityId, from: _today());
      items.sort((a, b) => a.fromDate.compareTo(b.fromDate));
      if (mounted) setState(() => _items = items);
    } on OwnerException catch (e) {
      if (mounted) {
        setState(() {
          _items = const [];
          _unavailable = e.unavailable;
          _error = e.unavailable ? null : e.message;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ownerErrorMessage(e));
    }
  }

  String _courtName(String id) => widget.courts.where((c) => c.id == id).firstOrNull?.name ?? OwnerSlotStrings.deletedCourt;

  Future<void> _save(PricePeriod p) async {
    setState(() => _busy = true);
    try {
      final r = await AppRepositories.owner.savePricePeriod(widget.facilityId, p);
      if (!mounted) return;
      showOwnerSnack(context, OwnerSlotStrings.periodSaved(p.id.isNotEmpty, p.name, r.updatedSlots, r.skippedBookedSlots));
      setState(() => _editing = null);
      await _load();
      widget.onDone();
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(PricePeriod p) async {
    if (!await confirmOwner(context, OwnerSlotStrings.deletePeriodConfirm(p.name))) return;
    try {
      await AppRepositories.owner.deletePricePeriod(widget.facilityId, p.id);
      if (!mounted) return;
      showOwnerSnack(context, OwnerSlotStrings.periodDeleted(p.name));
      await _load();
      widget.onDone();
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final today = _today();
    return _Card(
      children: [
        const Text(OwnerSlotStrings.periodsTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Text(OwnerSlotStrings.periodsHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (_editing == null && !_unavailable && items != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _editing = PricePeriod(
                    name: '',
                    fromDate: today,
                    toDate: today.add(const Duration(days: 2)),
                    price: 0,
                  )),
              child: const Text(OwnerSlotStrings.newPeriod),
            ),
          ),
        if (_editing != null)
          _PeriodForm(
            key: ValueKey(_editing!.id.isEmpty ? 'new' : _editing!.id),
            initial: _editing!,
            courts: widget.courts,
            busy: _busy,
            onCancel: () => setState(() => _editing = null),
            onSubmit: _save,
          ),
        const SizedBox(height: 8),
        if (items == null && _error == null)
          const Text(OwnerSlotStrings.periodsLoading, style: TextStyle(color: AppColors.textSecondary))
        else if (_unavailable)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
            child: const Text(OwnerSlotStrings.periodsUnavailable, style: TextStyle(color: Color(0xFF1D4ED8))),
          )
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red))
        else if (items!.isEmpty)
          const Text(OwnerSlotStrings.periodsEmpty, style: TextStyle(color: AppColors.textSecondary))
        else
          for (final p in items)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${Formatters.date(p.fromDate)} – ${Formatters.date(p.toDate)} • '
                      '${p.startTime != null && p.endTime != null ? '${p.startTime} – ${p.endTime}' : OwnerSlotStrings.wholeDay}'),
                  Text(p.courtIds.isEmpty ? OwnerSlotStrings.allCourts : p.courtIds.map(_courtName).join(', '),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Row(
                    children: [
                      Expanded(child: Text(Formatters.vnd(p.price), style: const TextStyle(fontWeight: FontWeight.bold))),
                      TextButton(onPressed: () => setState(() => _editing = p), child: const Text(OwnerSlotStrings.edit)),
                      TextButton(onPressed: () => _remove(p), child: const Text(OwnerSlotStrings.delete)),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _PeriodForm extends StatefulWidget {
  final PricePeriod initial;
  final List<OwnerCourt> courts;
  final bool busy;
  final VoidCallback onCancel;
  final ValueChanged<PricePeriod> onSubmit;

  const _PeriodForm({
    super.key,
    required this.initial,
    required this.courts,
    required this.busy,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  State<_PeriodForm> createState() => _PeriodFormState();
}

class _PeriodFormState extends State<_PeriodForm> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _price = TextEditingController(text: widget.initial.price > 0 ? '${widget.initial.price}' : '');
  late DateTime _fromDate = widget.initial.fromDate;
  late DateTime _toDate = widget.initial.toDate;
  late String? _start = widget.initial.startTime;
  late String? _end = widget.initial.endTime;
  late List<String> _courtIds = [...widget.initial.courtIds];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final price = int.tryParse(_price.text.trim()) ?? 0;
    String? error;
    if (_name.text.trim().isEmpty) {
      error = OwnerSlotStrings.errPeriodName;
    } else if (_toDate.isBefore(_fromDate)) {
      error = OwnerSlotStrings.errPeriodOrder;
    } else if ((_start == null) != (_end == null)) {
      error = OwnerSlotStrings.errPeriodTimes;
    } else if (_start != null && _end!.compareTo(_start!) <= 0) {
      error = OwnerSlotStrings.errPeriodTimeOrder;
    } else if (price <= 0) {
      error = OwnerSlotStrings.errPeriodPrice;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    widget.onSubmit(PricePeriod(
      id: widget.initial.id,
      name: _name.text.trim(),
      fromDate: _fromDate,
      toDate: _toDate,
      courtIds: _courtIds,
      startTime: _start,
      endTime: _end,
      price: price,
    ));
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: OwnerSlotStrings.periodName,
                hintText: OwnerSlotStrings.periodNameHint,
                border: OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            NumberField(label: OwnerSlotStrings.periodPrice, hint: OwnerSlotStrings.periodPriceHint, controller: _price),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DateButton(
                  label: OwnerSlotStrings.fromDate,
                  value: _fromDate,
                  firstDate: _today(),
                  onChanged: (d) => setState(() => _fromDate = d),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DateButton(
                  label: OwnerSlotStrings.toDate,
                  value: _toDate,
                  firstDate: _today(),
                  onChanged: (d) => setState(() => _toDate = d),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TimeButton(label: OwnerSlotStrings.periodFromTime, value: _start, onChanged: (v) => setState(() => _start = v))),
              const SizedBox(width: 8),
              Expanded(child: TimeButton(label: OwnerSlotStrings.periodToTime, value: _end, onChanged: (v) => setState(() => _end = v))),
            ]),
            const SizedBox(height: 8),
            CourtChips(courts: widget.courts, value: _courtIds, onChanged: (v) => setState(() => _courtIds = v)),
            const SizedBox(height: 6),
            const Text(OwnerSlotStrings.periodNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(onPressed: widget.busy ? null : widget.onCancel, child: const Text(OwnerSlotStrings.cancel)),
                ElevatedButton(
                  onPressed: widget.busy ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                  child: Text(widget.busy ? OwnerSlotStrings.saving : OwnerSlotStrings.savePeriod),
                ),
              ],
            ),
          ],
        ),
      );
}

// ---------------- Sinh ca hàng loạt ----------------

class _RuleDraft {
  List<int> days = const [];
  String? start = '17:00';
  String? end = '22:00';
  final price = TextEditingController();
}

class _GenerateCard extends StatefulWidget {
  final String facilityId;
  final List<OwnerCourt> courts;
  final bool scoped;
  final String allLabel;
  final VoidCallback onDone;

  const _GenerateCard({
    super.key,
    required this.facilityId,
    required this.courts,
    required this.scoped,
    required this.allLabel,
    required this.onDone,
  });

  @override
  State<_GenerateCard> createState() => _GenerateCardState();
}

class _GenerateCardState extends State<_GenerateCard> {
  List<String> _courtIds = const [];
  late DateTime _from = _today();
  late DateTime _to = _today().add(const Duration(days: 6));
  String? _open;
  String? _close;
  final _duration = TextEditingController();
  final _price = TextEditingController();
  final List<_RuleDraft> _rules = [];
  bool _busy = false;
  List<GenerateResultRow>? _result;

  @override
  void dispose() {
    _duration.dispose();
    _price.dispose();
    for (final r in _rules) {
      r.price.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    void fail(String m) => showOwnerSnack(context, m, error: true);
    if (_to.isBefore(_from)) return fail(OwnerSlotStrings.errDateOrder);
    if (_open != null && _close != null && _close!.compareTo(_open!) <= 0) return fail(OwnerSlotStrings.errHourOrder);
    final durationText = _duration.text.trim();
    final duration = durationText.isEmpty ? null : int.tryParse(durationText);
    if (durationText.isNotEmpty && (duration == null || duration < 15 || duration > 480)) return fail(OwnerSlotStrings.errDuration);
    final priceText = _price.text.trim();
    final price = priceText.isEmpty ? null : int.tryParse(priceText);
    if (priceText.isNotEmpty && price == null) return fail(OwnerSlotStrings.errSlotPrice);
    final rules = <SlotPriceRule>[];
    for (var i = 0; i < _rules.length; i++) {
      final r = _rules[i];
      if (r.start == null || r.end == null || r.end!.compareTo(r.start!) <= 0) return fail(OwnerSlotStrings.errRuleTime(i + 1));
      final p = int.tryParse(r.price.text.trim());
      if (p == null || p < 0) return fail(OwnerSlotStrings.errRulePrice(i + 1));
      rules.add(SlotPriceRule(daysOfWeek: r.days, startTime: r.start!, endTime: r.end!, price: p));
    }
    setState(() => _busy = true);
    try {
      final rows = await AppRepositories.owner.generateSlots(
        widget.facilityId,
        GenerateSlotsRequest(
          courtIds: _targetIds(_courtIds, widget.courts, scoped: widget.scoped),
          dateFrom: _from,
          dateTo: _to,
          openTime: _open,
          closeTime: _close,
          durationMinutes: duration,
          price: price,
          priceRules: rules,
        ),
        courtNames: {for (final c in widget.courts) c.id: c.name},
      );
      if (!mounted) return;
      setState(() => _result = rows);
      final failed = rows.where((r) => !r.success).length;
      final created = rows.fold(0, (s, r) => s + r.created);
      if (rows.isNotEmpty && failed == rows.length) {
        showOwnerSnack(context, OwnerSlotStrings.generateAllFailed, error: true);
      } else if (failed > 0) {
        showOwnerSnack(context, OwnerSlotStrings.generatePartial(created, failed));
      } else {
        showOwnerSnack(context, OwnerSlotStrings.generated(created));
      }
      widget.onDone();
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => _Card(
        children: [
          const Text(OwnerSlotStrings.generateTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          CourtChips(courts: widget.courts, value: _courtIds, allLabel: widget.allLabel, onChanged: (v) => setState(() => _courtIds = v)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DateButton(label: OwnerSlotStrings.fromDate, value: _from, firstDate: _today(), onChanged: (d) => setState(() => _from = d)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DateButton(label: OwnerSlotStrings.toDate, value: _to, firstDate: _today(), onChanged: (d) => setState(() => _to = d)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TimeButton(label: OwnerSlotStrings.openAt, value: _open, onChanged: (v) => setState(() => _open = v))),
            const SizedBox(width: 8),
            Expanded(child: TimeButton(label: OwnerSlotStrings.closeAt, value: _close, onChanged: (v) => setState(() => _close = v))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: NumberField(label: OwnerSlotStrings.duration, hint: OwnerSlotStrings.durationHint, controller: _duration)),
            const SizedBox(width: 8),
            Expanded(child: NumberField(label: OwnerSlotStrings.slotPrice, hint: OwnerSlotStrings.slotPriceHint, controller: _price)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(OwnerSlotStrings.priceRules, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              TextButton(onPressed: () => setState(() => _rules.add(_RuleDraft())), child: const Text(OwnerSlotStrings.addRule)),
            ],
          ),
          for (final r in _rules)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: TimeButton(label: OwnerSlotStrings.ruleFrom, value: r.start, onChanged: (v) => setState(() => r.start = v))),
                    const SizedBox(width: 8),
                    Expanded(child: TimeButton(label: OwnerSlotStrings.ruleTo, value: r.end, onChanged: (v) => setState(() => r.end = v))),
                  ]),
                  const SizedBox(height: 8),
                  NumberField(label: OwnerSlotStrings.rulePrice, hint: OwnerSlotStrings.rulePriceHint, controller: r.price),
                  const SizedBox(height: 8),
                  WeekDayPicker(value: r.days, onChanged: (v) => setState(() => r.days = v)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _rules.remove(r);
                        r.price.dispose();
                      }),
                      child: const Text(OwnerSlotStrings.delete),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _busy || widget.courts.isEmpty ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
              child: Text(_busy ? OwnerSlotStrings.generating : OwnerSlotStrings.generate),
            ),
          ),
          if (_result != null)
            for (final r in _result!)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.courtName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(OwnerSlotStrings.resultRow(r.created, r.updated, r.skipped, r.past),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (!r.success && r.message != null) Text(r.message!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                ),
              ),
        ],
      );
}

// ---------------- Thao tác hàng loạt ----------------

class _BulkCard extends StatefulWidget {
  final String facilityId;
  final List<OwnerCourt> courts;
  final bool scoped;
  final String allLabel;
  final VoidCallback onDone;

  const _BulkCard({
    super.key,
    required this.facilityId,
    required this.courts,
    required this.scoped,
    required this.allLabel,
    required this.onDone,
  });

  @override
  State<_BulkCard> createState() => _BulkCardState();
}

class _BulkCardState extends State<_BulkCard> {
  static const _labels = {
    BulkSlotAction.lock: OwnerSlotStrings.bulkLock,
    BulkSlotAction.unlock: OwnerSlotStrings.bulkUnlock,
    BulkSlotAction.setPrice: OwnerSlotStrings.bulkPrice,
    BulkSlotAction.delete: OwnerSlotStrings.bulkDelete,
  };
  static const _icons = {
    BulkSlotAction.lock: Icons.lock_outline,
    BulkSlotAction.unlock: Icons.lock_open,
    BulkSlotAction.setPrice: Icons.payments_outlined,
    BulkSlotAction.delete: Icons.delete_outline,
  };

  BulkSlotAction _action = BulkSlotAction.lock;
  List<String> _courtIds = const [];
  late DateTime _from = _today();
  late DateTime _to = _today();
  String? _start;
  String? _end;
  List<int> _days = const [];
  final _price = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_to.isBefore(_from)) return showOwnerSnack(context, OwnerSlotStrings.errDateOrder, error: true);
    final price = int.tryParse(_price.text.trim());
    if (_action == BulkSlotAction.setPrice && !(price != null && price > 0)) {
      return showOwnerSnack(context, OwnerSlotStrings.errNewPrice, error: true);
    }
    if (_action == BulkSlotAction.delete && !await confirmOwner(context, OwnerSlotStrings.bulkDeleteConfirm)) return;
    final ids = _targetIds(_courtIds, widget.courts, scoped: widget.scoped);
    // Đổi giá trùng đợt giá đặc biệt: báo trước; không tải được đợt (BE chưa có API) thì bỏ qua bước này.
    if (_action == BulkSlotAction.setPrice) {
      List<PricePeriod> periods;
      try {
        periods = await AppRepositories.owner.getPricePeriods(widget.facilityId, from: _from, to: _to);
      } catch (_) {
        periods = const [];
      }
      final overlapping = periods.where((p) => p.overlaps(courts: ids, from: _from, to: _to, start: _start, end: _end)).toList();
      if (overlapping.isNotEmpty && mounted) {
        String nameOf(String id) => widget.courts.where((c) => c.id == id).firstOrNull?.name ?? 'Sân';
        final lines = overlapping
            .map((p) => '• ${p.courtIds.isEmpty ? OwnerSlotStrings.allCourts : p.courtIds.map(nameOf).join(', ')}: '
                '"${p.name}" (${Formatters.date(p.fromDate)} – ${Formatters.date(p.toDate)})')
            .join('\n');
        final ok = await confirmOwner(
          context,
          OwnerSlotStrings.overlapBody(lines),
          title: OwnerSlotStrings.overlapTitle,
          confirmLabel: OwnerSlotStrings.overlapYes,
          cancelLabel: OwnerSlotStrings.overlapNo,
        );
        if (!ok) return;
      }
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final r = await AppRepositories.owner.bulkSlots(
        widget.facilityId,
        BulkSlotRequest(
          action: _action,
          courtIds: ids,
          dateFrom: _from,
          dateTo: _to,
          startTime: _start,
          endTime: _end,
          daysOfWeek: _days,
          price: price,
        ),
      );
      if (mounted) showOwnerSnack(context, OwnerSlotStrings.bulkDone(r.matched, r.affected, r.skipped));
      widget.onDone();
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => _Card(
        children: [
          const Text(OwnerSlotStrings.bulkTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in BulkSlotAction.values)
                ChoiceChip(
                  avatar: Icon(_icons[a], size: 16),
                  label: Text(_labels[a]!),
                  selected: _action == a,
                  onSelected: (_) => setState(() => _action = a),
                ),
            ],
          ),
          const SizedBox(height: 8),
          CourtChips(courts: widget.courts, value: _courtIds, allLabel: widget.allLabel, onChanged: (v) => setState(() => _courtIds = v)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DateButton(label: OwnerSlotStrings.fromDate, value: _from, firstDate: _today(), onChanged: (d) => setState(() => _from = d)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DateButton(label: OwnerSlotStrings.toDate, value: _to, firstDate: _today(), onChanged: (d) => setState(() => _to = d)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TimeButton(label: OwnerSlotStrings.ruleFrom, value: _start, onChanged: (v) => setState(() => _start = v))),
            const SizedBox(width: 8),
            Expanded(child: TimeButton(label: OwnerSlotStrings.ruleTo, value: _end, onChanged: (v) => setState(() => _end = v))),
          ]),
          if (_action == BulkSlotAction.setPrice) ...[
            const SizedBox(height: 8),
            NumberField(label: OwnerSlotStrings.newPrice, controller: _price),
          ],
          const SizedBox(height: 8),
          WeekDayPicker(value: _days, onChanged: (v) => setState(() => _days = v)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _busy || widget.courts.isEmpty ? null : _submit,
              icon: Icon(_icons[_action], size: 18),
              label: Text(_busy ? OwnerSlotStrings.processing : _labels[_action]!),
              style: ElevatedButton.styleFrom(
                backgroundColor: _action == BulkSlotAction.delete ? Colors.red : AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}
