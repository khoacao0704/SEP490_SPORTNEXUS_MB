import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings/owner_slot_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_court.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/court_form_sheet.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart';
import '../../widgets/owner/slot_pickers.dart';

/// Hỏi áp dụng cấu hình mới (giá / thời lượng ca) cho ca trống từ ngày mai; có thì sinh lại từng sân.
Future<void> offerRegenerateSlots(BuildContext context, List<OwnerCourt> courts) async {
  if (courts.isEmpty) return;
  final ok = await confirmOwner(
    context,
    OwnerSlotStrings.regenerateBody,
    title: OwnerSlotStrings.regenerateTitle,
    confirmLabel: OwnerSlotStrings.regenerateYes,
    cancelLabel: OwnerSlotStrings.regenerateNo,
    danger: false,
  );
  if (!ok || !context.mounted) return;
  final errors = <String>[];
  for (final c in courts) {
    try {
      await AppRepositories.owner.regenerateCourtSlots(c.id);
    } catch (e) {
      errors.add(ownerErrorMessage(e));
    }
  }
  if (!context.mounted) return;
  errors.isEmpty
      ? showOwnerSnack(context, OwnerSlotStrings.regenerated(OwnerSlotStrings.regenerateTarget(courts.length, courts.first.name)))
      : showOwnerSnack(context, OwnerSlotStrings.regenerateFailed(errors.length, courts.length, errors.first), error: true);
}

/// Khu sân = các sân cùng môn.
class _Zone {
  final String id;
  final String sport;
  final List<OwnerCourt> courts;

  _Zone(this.id, this.sport, this.courts);

  String get name => OwnerSlotStrings.zoneName(sport);
  int get basePrice => courts.map((c) => c.defaultPrice).reduce((a, b) => a < b ? a : b);
}

/// Trang "Sân & giá" (CourtManage của Web): Sân theo khu vực · Bảng giá · Giờ mở cửa.
class OwnerCourtsScreen extends StatefulWidget {
  final OwnerFacility facility;

  const OwnerCourtsScreen({super.key, required this.facility});

  @override
  State<OwnerCourtsScreen> createState() => _OwnerCourtsScreenState();
}

class _OwnerCourtsScreenState extends State<OwnerCourtsScreen> {
  List<SportCategory> _sports = const [];
  List<OwnerCourt>? _courts;
  String? _error;
  String? _selectedZone;
  String? _busy;
  final Map<String, TextEditingController> _zonePrices = {};
  late String _open = formatMinutes(widget.facility.operations.openMinutes);
  late String _close = formatMinutes(widget.facility.operations.closeMinutes);
  String? _previewCourtId;

  String get _facilityId => widget.facility.id;

  @override
  void initState() {
    super.initState();
    AppRepositories.owner.getSports().then((s) {
      if (mounted) setState(() => _sports = s);
    }).catchError((_) {});
    _reload();
  }

  @override
  void dispose() {
    for (final c in _zonePrices.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await AppRepositories.owner.getCourts(_facilityId);
      if (!mounted) return;
      setState(() {
        _courts = list;
        _error = null;
        for (final c in _zonePrices.values) {
          c.dispose();
        }
        _zonePrices.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = ownerErrorMessage(e));
    }
  }

  List<_Zone> get _zones {
    final groups = <String, List<OwnerCourt>>{};
    for (final c in _courts ?? const <OwnerCourt>[]) {
      groups.putIfAbsent(c.categoryId, () => []).add(c);
    }
    return [
      for (final e in groups.entries)
        _Zone(e.key, _sports.where((s) => s.id == e.key).firstOrNull?.name ?? e.value.first.categoryName, e.value),
    ];
  }

  Future<void> _run(String busy, Future<void> Function() action, {String? success}) async {
    setState(() => _busy = busy);
    try {
      await action();
      if (mounted && success != null) showOwnerSnack(context, success);
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _toggle(OwnerCourt c) async {
    final next = c.isActive ? 'INACTIVE' : 'ACTIVE';
    try {
      await _run(
        c.id,
        () => AppRepositories.owner.updateCourt(_facilityId, c, c.toInput().copyWith(status: next)),
        success: OwnerSlotStrings.courtToggled(next == 'ACTIVE', c.name),
      );
      await _reload();
    } catch (_) {}
  }

  Future<void> _delete(OwnerCourt c) async {
    if (!await confirmOwner(context, OwnerSlotStrings.deleteCourtConfirm(c.name))) return;
    setState(() => _busy = c.id);
    try {
      final removed = await AppRepositories.owner.deleteCourt(_facilityId, c.id);
      if (mounted) showOwnerSnack(context, OwnerSlotStrings.courtDeleted(c.name, removed));
      await _reload();
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    }
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _openForm({OwnerCourt? court, String? sportId}) async {
    var editing = court;
    if (court != null) {
      // Lấy chi tiết sân (số ca trống, giá sắp tới) như Web; lỗi thì dùng dữ liệu danh sách.
      try {
        editing = await AppRepositories.owner.getCourt(_facilityId, court.id);
      } catch (_) {}
    }
    if (!mounted) return;
    final zone = _zones.where((z) => z.id == sportId).firstOrNull;
    final input = await showCourtForm(
      context,
      sports: _sports,
      court: editing,
      defaultSportId: sportId ?? _sports.firstOrNull?.id,
      defaultPrice: zone?.basePrice,
    );
    if (input == null || !mounted) return;
    try {
      await _run(
        'form',
        () => editing == null
            ? AppRepositories.owner.createCourt(_facilityId, input)
            : AppRepositories.owner.updateCourt(_facilityId, editing, input),
        success: editing == null ? OwnerSlotStrings.courtAdded(input.name) : OwnerSlotStrings.courtUpdated(input.name),
      );
    } catch (_) {
      return;
    }
    setState(() => _selectedZone = input.categoryId);
    await _reload();
    // Sửa sân mà đổi thời lượng ca hoặc giá chuẩn thì hỏi áp dụng cho ca đã sinh.
    if (editing != null &&
        mounted &&
        (input.slotMinutes != editing.slotMinutes || input.defaultPrice != editing.defaultPrice)) {
      await offerRegenerateSlots(context, [editing]);
    }
  }

  Future<void> _saveZonePrice(_Zone zone) async {
    final price = int.tryParse(_zonePrices[zone.id]?.text.trim() ?? '');
    if (price == null || price < 0) {
      showOwnerSnack(context, OwnerSlotStrings.errPrice, error: true);
      return;
    }
    final changed = zone.courts.where((c) => c.defaultPrice != price).toList();
    if (changed.isEmpty) return;
    try {
      await _run(zone.id, () async {
        for (final c in changed) {
          await AppRepositories.owner.updateCourt(_facilityId, c, c.toInput().copyWith(defaultPrice: price));
        }
      }, success: OwnerSlotStrings.zonePriceSaved(zone.name, price));
    } catch (_) {
      await _reload();
      return;
    }
    await _reload();
    if (mounted) await offerRegenerateSlots(context, changed);
  }

  Future<void> _changeSlotMinutes(OwnerCourt c, int? minutes) async {
    setState(() => _previewCourtId = c.id);
    try {
      await _run(
        c.id,
        () => AppRepositories.owner.updateCourt(
          _facilityId,
          c,
          minutes == null ? c.toInput().copyWith(clearSlotMinutes: true) : c.toInput().copyWith(slotMinutes: minutes),
        ),
        success: OwnerSlotStrings.slotMinutesChanged(c.name, minutes),
      );
    } catch (_) {
      return;
    }
    await _reload();
    if (mounted) await offerRegenerateSlots(context, [c]);
  }

  Future<void> _saveHours() async {
    if (parseMinutes(_close) <= parseMinutes(_open)) {
      showOwnerSnack(context, OwnerSlotStrings.hoursInvalid, error: true);
      return;
    }
    try {
      await _run(
        'hours',
        () => AppRepositories.owner.updateOpenHours(_facilityId, openTime: _open, closeTime: _close),
        success: OwnerSlotStrings.hoursSaved,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.facility;
    final courts = _courts;
    final active = courts?.where((c) => c.isActive).length ?? 0;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: const Text(OwnerSlotStrings.courtsTitle,
              style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryGreen,
            tabs: [
              Tab(text: OwnerSlotStrings.tabZones),
              Tab(text: OwnerSlotStrings.tabPricing),
              Tab(text: OwnerSlotStrings.tabTimeGrid),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy == null ? () => _openForm(sportId: _selectedZone ?? _zones.firstOrNull?.id) : null,
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text(OwnerSlotStrings.addCourt),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    OwnerSlotStrings.courtsSubtitle(f.profile.name, _zones.length, active, courts?.length ?? 0),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (f.status == ApprovalStatus.pending)
                    const OwnerBadge(OwnerSlotStrings.pendingFacility, tone: BadgeTone.amber),
                  if (f.status == ApprovalStatus.rejected)
                    const OwnerBadge(OwnerSlotStrings.rejectedFacility, tone: BadgeTone.red),
                ],
              ),
            ),
            Expanded(
              child: courts == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    )
                  : TabBarView(children: [_zonesTab(), _pricingTab(), _timeGridTab()]),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Tab Sân theo khu vực ----------------

  Widget _zonesTab() {
    final zones = _zones;
    if (zones.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 60),
            Text(OwnerSlotStrings.noCourts, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final zone = zones.where((z) => z.id == _selectedZone).firstOrNull ?? zones.first;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final z in zones)
                ChoiceChip(
                  label: Text('${z.name} • ${z.courts.length}'),
                  selected: z.id == zone.id,
                  onSelected: (_) => setState(() => _selectedZone = z.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _card([
            Text(zone.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(OwnerSlotStrings.zoneTotal(zone.courts.length), style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text(OwnerSlotStrings.zonePriceLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(OwnerSlotStrings.zoneDefaultPrice(zone.basePrice), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openForm(sportId: zone.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(OwnerSlotStrings.addCourtInZone),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(OwnerSlotStrings.zoneCourtsTitle(zone.name), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final c in zone.courts) _courtTile(c),
        ],
      ),
    );
  }

  Widget _courtTile(OwnerCourt c) {
    final busy = _busy == c.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              OwnerBadge(
                c.isActive ? OwnerSlotStrings.courtActive : OwnerSlotStrings.courtInactive,
                tone: c.isActive ? BadgeTone.green : BadgeTone.gray,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${c.surfaceType ?? c.courtType ?? OwnerSlotStrings.noSurface} • ${Formatters.vnd(c.defaultPrice)}/h',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              OutlinedButton(
                onPressed: busy ? null : () => _toggle(c),
                child: Text(c.isActive ? OwnerSlotStrings.suspendCourt : OwnerSlotStrings.reopenCourt),
              ),
              OutlinedButton(onPressed: busy ? null : () => _openForm(court: c, sportId: c.categoryId), child: const Text(OwnerSlotStrings.edit)),
              IconButton(
                tooltip: '${OwnerSlotStrings.delete} ${c.name}',
                onPressed: busy ? null : () => _delete(c),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- Tab Bảng giá ----------------

  Widget _pricingTab() {
    final zones = _zones;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
            child: const Text(OwnerSlotStrings.pricingNote, style: TextStyle(fontSize: 12.5, color: Color(0xFF1D4ED8))),
          ),
          const SizedBox(height: 12),
          const Text(OwnerSlotStrings.pricingTitle, style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (zones.isEmpty)
            const Text(OwnerSlotStrings.pricingEmpty, style: TextStyle(color: AppColors.textSecondary))
          else
            for (final z in zones)
              _card([
                Text(z.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(OwnerSlotStrings.pricingCourts(z.courts.length), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _zonePrices.putIfAbsent(z.id, () => TextEditingController(text: '${z.basePrice}')),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: OwnerSlotStrings.pricingPriceLabel,
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _busy == null ? () => _saveZonePrice(z) : null,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                      child: Text(_busy == z.id ? OwnerSlotStrings.saving : OwnerSlotStrings.savePrice),
                    ),
                  ],
                ),
              ], margin: 10),
        ],
      ),
    );
  }

  // ---------------- Tab Giờ mở cửa ----------------

  Widget _timeGridTab() {
    final courts = _courts ?? const <OwnerCourt>[];
    final preview = courts.where((c) => c.id == _previewCourtId).firstOrNull ?? courts.firstOrNull;
    final minutes = preview?.effectiveSlotMinutes ?? 120;
    final open = parseMinutes(_open);
    final close = parseMinutes(_close);
    final previewSlots = <String>[
      for (var m = open; m + minutes <= close; m += minutes) '${formatMinutes(m)}–${formatMinutes(m + minutes)}',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _card([
          const Text(OwnerSlotStrings.timeGridTitle, style: TextStyle(fontWeight: FontWeight.bold)),
          const Text(OwnerSlotStrings.timeGridHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          TimeButton(
            label: '${OwnerSlotStrings.openTime} • ${OwnerSlotStrings.openTimeHint}',
            value: _open,
            clearable: false,
            onChanged: (v) => setState(() => _open = v ?? _open),
          ),
          const SizedBox(height: 8),
          TimeButton(
            label: '${OwnerSlotStrings.closeTime} • ${OwnerSlotStrings.closeTimeHint}',
            value: _close,
            clearable: false,
            onChanged: (v) => setState(() => _close = v ?? _close),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy == null ? _saveHours : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
              child: Text(_busy == 'hours' ? OwnerSlotStrings.saving : OwnerSlotStrings.saveHours),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _card([
          const Text(OwnerSlotStrings.slotMinutesTitle, style: TextStyle(fontWeight: FontWeight.bold)),
          const Text(OwnerSlotStrings.slotMinutesHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Text(OwnerSlotStrings.mergeNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          for (final c in courts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text('${c.name} • ${c.categoryName}', overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: DropdownButton<int?>(
                      value: c.slotMinutes,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(value: null, child: Text(OwnerSlotStrings.bySport(c.effectiveSlotMinutes))),
                        for (final m in {...OwnerSlotStrings.slotMinuteOptions, ?c.slotMinutes})
                          DropdownMenuItem(value: m, child: Text(OwnerSlotStrings.minutes(m))),
                      ],
                      onChanged: _busy == null ? (v) => _changeSlotMinutes(c, v) : null,
                    ),
                  ),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 12),
        _card([
          Text(
            OwnerSlotStrings.previewTitle(_open, _close, preview?.name, minutes),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in previewSlots)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(6)),
                  child: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.darkGreen)),
                ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _card(List<Widget> children, {double margin = 0}) => Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: margin),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}
