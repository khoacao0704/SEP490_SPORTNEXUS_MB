import 'package:flutter/material.dart';
import '../../widgets/owner/owner_shell.dart';

import '../../core/strings/owner_dashboard_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_booking.dart';
import '../../models/owner_court.dart';
import '../../models/owner_dashboard.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/dashboard_charts.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart';
import '../../widgets/owner/slot_pickers.dart' show DateButton;
import '../../widgets/owner/stat_grid.dart';
import 'listing_fee_screen.dart';
import 'owner_booking_detail_screen.dart';
import 'owner_complaints_screen.dart';
import 'owner_courts_screen.dart';

const _periods = [7, 30, 90];
const _todayLimit = 6;

String _pct(double? v) => v == null ? OwnerDashboardStrings.dash : '${v.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')}%';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tổng quan của cơ sở đang chọn (như Dashboard Web): kỳ 7/30/90 ngày, 4 thẻ chỉ số, doanh thu theo ngày,
/// việc cần xử lý, so sánh tháng / quý, số đơn từng sân, khách hôm nay, hiệu quả từng sân, bảng doanh thu sân con.
/// Mobile giữ thêm banner phí duy trì.
class OwnerOverviewScreen extends StatefulWidget {
  final String ownerName;
  final String? facilityId;
  final int revision;
  final Widget facilitySelector;
  final VoidCallback onChanged;
  final VoidCallback onOpenSchedule;
  final VoidCallback? onOpenScan;
  final VoidCallback? onOpenFacilities;

  /// Chuông thông báo trên AppBar.
  final Widget? notificationBell;

  const OwnerOverviewScreen({
    super.key,
    required this.ownerName,
    required this.facilityId,
    required this.revision,
    required this.facilitySelector,
    required this.onChanged,
    required this.onOpenSchedule,
    this.onOpenScan,
    this.onOpenFacilities,
    this.notificationBell,
  });

  @override
  State<OwnerOverviewScreen> createState() => _OwnerOverviewScreenState();
}

class _OwnerOverviewScreenState extends State<OwnerOverviewScreen> {
  int _periodDays = 30;

  OwnerDashboard? _data;
  String? _dataError;
  List<OwnerBooking>? _today;
  int? _balance;
  int? _frozen;
  List<OwnerFacility> _facilities = [];
  List<OwnerCourt> _courts = [];
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(OwnerOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facilityId != widget.facilityId || oldWidget.revision != widget.revision) _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadToday(), _loadWallet(), _loadFacilityInfo()]);
  }

  Future<void> _loadStats() async {
    final id = widget.facilityId;
    if (id == null) return;
    final seq = ++_seq;
    setState(() {
      _data = null;
      _dataError = null;
    });
    final today = _day(DateTime.now());
    try {
      final data = await AppRepositories.owner.getDashboard(
        facilityId: id,
        from: today.subtract(Duration(days: _periodDays - 1)),
        to: today,
      );
      if (mounted && seq == _seq) setState(() => _data = data);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _dataError = ownerErrorMessage(e));
    }
  }

  Future<void> _loadToday() async {
    final id = widget.facilityId;
    if (id == null) return;
    try {
      final page = await AppRepositories.owner.getBookings(facilityId: id, date: DateTime.now(), pageSize: 100);
      final list = page.items
          .where((b) => b.status == OwnerBookingStatus.paid || b.status == OwnerBookingStatus.checkedIn)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      if (mounted && id == widget.facilityId) setState(() => _today = list);
    } catch (_) {
      if (mounted) setState(() => _today = const []);
    }
  }

  Future<void> _loadWallet() async {
    try {
      final w = AppRepositories.ownerWallet;
      final values = await Future.wait([w.getBalance(), w.getFrozenBalance()]);
      if (mounted) {
        setState(() {
          _balance = values[0];
          _frozen = values[1];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFacilityInfo() async {
    final repo = AppRepositories.owner;
    try {
      final all = await repo.getOwnerFacilities();
      if (mounted) setState(() => _facilities = all);
    } catch (_) {}
    final id = widget.facilityId;
    if (id == null) return;
    try {
      final courts = await repo.getCourts(id);
      if (mounted && id == widget.facilityId) setState(() => _courts = courts);
    } catch (_) {}
  }

  void _setPeriod(int days) {
    if (days == _periodDays) return;
    setState(() => _periodDays = days);
    _loadStats();
  }

  OwnerFacility? get _facility => _facilities.where((f) => f.id == widget.facilityId).firstOrNull;

  Future<void> _openBooking(OwnerBooking b) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OwnerBookingDetailScreen(bookingId: b.id, onOpenSchedule: widget.onOpenSchedule)),
    );
    if (changed == true) widget.onChanged();
  }

  Future<void> _openCourts() async {
    final f = _facility;
    if (f == null) {
      widget.onOpenFacilities?.call();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerCourtsScreen(facility: f)));
    if (mounted) widget.onChanged();
  }

  Future<void> _openComplaints() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerComplaintsScreen()));
    if (mounted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leading: const OwnerMenuButton(),
        title: widget.facilitySelector,
        actions: [?widget.notificationBell],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: widget.facilityId == null ? _noFacility() : _content(),
        ),
      ),
    );
  }

  List<Widget> _header() {
    final d = _data;
    final name = _facility?.profile.name;
    return [
      Text(OwnerStrings.greeting(widget.ownerName), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      const Text(
        OwnerDashboardStrings.title,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain),
      ),
      const SizedBox(height: 2),
      Text(
        OwnerDashboardStrings.subtitle(name, _periodDays) +
            (d == null ? '' : OwnerDashboardStrings.subtitleStats(_pct(d.cancellationRate), d.reviewCount, d.averageRating.toStringAsFixed(1).replaceAll('.', ','))),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      if (_dataError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            OwnerDashboardStrings.loadError(_dataError!),
            style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final p in _periods) ButtonSegment(value: p, label: Text(OwnerDashboardStrings.periodDays(p)))],
            selected: {_periodDays},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: BadgeTone.green.background, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 16, color: BadgeTone.green.foreground),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    OwnerDashboardStrings.courtsReady(_courts.where((c) => c.isActive).length, _courts.length) +
                        ((d?.openReports ?? 0) > 0 ? OwnerDashboardStrings.openReportsPill(d!.openReports) : ''),
                    style: TextStyle(color: BadgeTone.green.foreground, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _noFacility() => [
        Text(OwnerStrings.greeting(widget.ownerName),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain)),
        const SizedBox(height: 16),
        ListingFeeBanner(revision: widget.revision),
        const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Text(OwnerStrings.noFacilityHint, textAlign: TextAlign.center),
        ),
      ];

  List<Widget> _content() {
    final d = _data;
    final days = _periodDays;
    final loading = d == null && _dataError == null;
    String value(String Function(OwnerDashboard) f) => d != null ? f(d) : (_dataError != null ? OwnerDashboardStrings.dash : '...');
    final peak = d?.peakHour;
    return [
      ..._header(),
      const SizedBox(height: 12),
      ListingFeeBanner(revision: widget.revision),
      StatGrid(
        children: [
          _Kpi(
            icon: Icons.account_balance_wallet_outlined,
            tone: BadgeTone.green,
            label: OwnerDashboardStrings.kpiBalance,
            value: _balance == null ? '...' : Formatters.vnd(_balance!),
            sub: OwnerDashboardStrings.kpiFrozen(_frozen == null ? OwnerDashboardStrings.dash : Formatters.vnd(_frozen!)),
          ),
          _Kpi(
            icon: Icons.receipt_long_outlined,
            tone: BadgeTone.amber,
            label: OwnerDashboardStrings.kpiBookings(days),
            value: value((d) => '${d.totalBookings} ${OwnerDashboardStrings.unitBookings}'),
            sub: d == null
                ? OwnerDashboardStrings.loading
                : OwnerDashboardStrings.kpiBookingsSub(d.checkedInBookings, d.cancelledBookings, d.upcomingTodayBookings),
          ),
          _Kpi(
            icon: Icons.pie_chart_outline,
            tone: BadgeTone.blue,
            label: OwnerDashboardStrings.kpiOccupancy(days),
            value: value((d) => '${_pct(d.occupancyRate)} ${OwnerDashboardStrings.occupancySlots(d.bookedSlots, d.sellableSlots)}'),
            sub: peak == null ? OwnerDashboardStrings.occupancyHint : OwnerDashboardStrings.peakHour(peak.$1, peak.$2),
          ),
          _Kpi(
            icon: Icons.trending_up,
            tone: BadgeTone.green,
            label: OwnerDashboardStrings.kpiRevenue(days),
            value: value((d) => Formatters.vnd(d.totalRevenue)),
            sub: d == null
                ? OwnerDashboardStrings.revenueHint
                : OwnerDashboardStrings.revenueSub(Formatters.vnd(d.onlineRevenue), Formatters.vnd(d.walkInRevenue)),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _RevenuePanel(days: d?.revenueByDay ?? const [], loading: loading, periodDays: days),
      const SizedBox(height: 16),
      _todoPanel(),
      const SizedBox(height: 16),
      _ComparisonPanel(key: ValueKey('cmp-${widget.facilityId}-${widget.revision}'), facilityId: widget.facilityId!),
      const SizedBox(height: 16),
      _courtBookingsPanel(d, loading),
      const SizedBox(height: 16),
      _todayPanel(),
      const SizedBox(height: 16),
      _courtPerfPanel(d),
      const SizedBox(height: 16),
      _CourtRevenueTable(
        key: ValueKey('tbl-${widget.facilityId}-$days-${widget.revision}'),
        facilityId: widget.facilityId!,
        periodDays: days,
        dashboardCourts: d?.revenueByCourt,
        dashboardLoading: loading,
        dashboardError: _dataError,
      ),
    ];
  }

  Widget _todoPanel() {
    final waiting = (_today ?? const []).where((b) => b.status == OwnerBookingStatus.paid).length;
    final open = _data?.openReports ?? 0;
    final rejected = _facilities.where((f) => f.status == ApprovalStatus.rejected).toList();
    final pending = _facilities.where((f) => f.status == ApprovalStatus.pending).toList();
    final inactive = _courts.where((c) => !c.isActive).length;
    final items = <_Todo>[
      if (waiting > 0)
        _Todo(Icons.qr_code_scanner, BadgeTone.blue, OwnerDashboardStrings.todoCheckin(waiting),
            OwnerDashboardStrings.todoCheckinDesc, OwnerDashboardStrings.actionScan, widget.onOpenScan),
      if (open > 0)
        _Todo(Icons.report_outlined, BadgeTone.red, OwnerDashboardStrings.todoReports(open),
            OwnerDashboardStrings.todoReportsDesc, OwnerDashboardStrings.actionView, _openComplaints),
      if (rejected.isNotEmpty)
        _Todo(Icons.block, BadgeTone.red, OwnerDashboardStrings.todoRejected(rejected.length),
            rejected.map((f) => f.profile.name).join(', '), OwnerDashboardStrings.actionReview, widget.onOpenFacilities),
      if (pending.isNotEmpty)
        _Todo(Icons.hourglass_top, BadgeTone.amber, OwnerDashboardStrings.todoPending(pending.length),
            pending.map((f) => f.profile.name).join(', '), OwnerDashboardStrings.actionView, widget.onOpenFacilities),
      if (inactive > 0)
        _Todo(Icons.build_outlined, BadgeTone.purple, OwnerDashboardStrings.todoInactive(inactive),
            OwnerDashboardStrings.todoInactiveDesc, OwnerDashboardStrings.actionOpenCourt, _openCourts),
    ];
    return _Panel(
      title: OwnerDashboardStrings.todoTitle,
      subtitle: OwnerDashboardStrings.todoSub,
      child: items.isEmpty
          ? _ToneBox(
              tone: BadgeTone.green,
              child: Row(
                children: [
                  Icon(Icons.task_alt, color: BadgeTone.green.foreground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(OwnerDashboardStrings.allGood,
                        style: TextStyle(color: BadgeTone.green.foreground, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : Column(children: [for (final t in items) _TodoTile(t)]),
    );
  }

  Widget _courtBookingsPanel(OwnerDashboard? d, bool loading) {
    final items = [
      for (final c in d?.revenueByCourt ?? const <CourtStat>[])
        (name: c.courtName, value: c.bookings, hint: OwnerDashboardStrings.occupancyHintPct(c.occupancy)),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final total = items.fold<int>(0, (s, e) => s + e.value);
    return _Panel(
      title: OwnerDashboardStrings.courtBookingsTitle,
      subtitle: OwnerDashboardStrings.courtBookingsSub(_periodDays, total, items.length),
      child: loading
          ? const _Muted(OwnerDashboardStrings.loading)
          : _dataError != null
              ? _Muted(OwnerDashboardStrings.compareError(_dataError!))
              : items.isEmpty
                  ? const _Muted(OwnerDashboardStrings.noCourts)
                  : total == 0
                      ? _Muted(OwnerDashboardStrings.noBookings(_periodDays))
                      : RankBars(items: items),
    );
  }

  Widget _todayPanel() {
    final list = _today;
    final waiting = (list ?? const []).where((b) => b.status == OwnerBookingStatus.paid).length;
    return _Panel(
      title: OwnerDashboardStrings.todayTitle,
      subtitle: list == null ? OwnerDashboardStrings.loading : OwnerDashboardStrings.todaySub(waiting, list.length - waiting),
      action: widget.onOpenScan == null ? null : (OwnerDashboardStrings.scanLink, widget.onOpenScan!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list != null && list.isEmpty) const _Muted(OwnerDashboardStrings.todayEmpty),
          for (final b in (list ?? const <OwnerBooking>[]).take(_todayLimit)) _guest(b),
          if (list != null && list.length > _todayLimit)
            TextButton(onPressed: widget.onOpenSchedule, child: Text(OwnerDashboardStrings.viewAllToday(list.length))),
        ],
      ),
    );
  }

  Widget _guest(OwnerBooking b) {
    final checked = b.status == OwnerBookingStatus.checkedIn;
    final name = (b.customerName ?? '').trim().isEmpty ? OwnerDashboardStrings.guest : b.customerName!.trim();
    final tone = checked ? BadgeTone.green : BadgeTone.amber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openBooking(b),
        borderRadius: BorderRadius.circular(12),
        child: _ToneBox(
          tone: tone,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.white,
                child: Text(name.characters.first.toUpperCase(),
                    style: TextStyle(color: tone.foreground, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name${b.isWalkIn ? OwnerStrings.walkInShort : ''}${b.customerPhone == null ? '' : ' (${b.customerPhone})'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    Text(b.courtName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(OwnerDashboardStrings.timeRange(Formatters.timeRange(b.start, b.end)), style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(Formatters.vnd(b.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (checked)
                          Text(OwnerDashboardStrings.checkedIn,
                              style: TextStyle(color: BadgeTone.green.foreground, fontWeight: FontWeight.w600, fontSize: 12))
                        else if (widget.onOpenScan != null)
                          OutlinedButton(
                            onPressed: widget.onOpenScan,
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text(OwnerDashboardStrings.scanNow),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _courtPerfPanel(OwnerDashboard? d) {
    final stats = [...?d?.revenueByCourt]..sort((a, b) => b.revenue.compareTo(a.revenue));
    return _Panel(
      title: OwnerDashboardStrings.courtPerfTitle,
      subtitle: OwnerDashboardStrings.courtPerfSub(_periodDays),
      action: (OwnerDashboardStrings.manageCourts, _openCourts),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (d == null) _Muted(_dataError != null ? OwnerDashboardStrings.dash : OwnerDashboardStrings.loading),
          if (d != null && stats.isEmpty) const _Muted(OwnerDashboardStrings.noCourtData),
          for (var i = 0; i < stats.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text('${i + 1}. ${stats[i].courtName}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      OwnerBadge(OwnerDashboardStrings.fillPct(stats[i].occupancy), tone: BadgeTone.blue),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: stats[i].occupancy.clamp(0, 100) / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEEF2F1),
                      color: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(OwnerDashboardStrings.courtMeta(stats[i].bookings, stats[i].bookedSlots, stats[i].sellableSlots),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(Formatters.vnd(stats[i].revenue), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: widget.onOpenSchedule,
            icon: const Icon(Icons.calendar_month),
            label: Text(OwnerDashboardStrings.viewGrid(_courts.length)),
          ),
        ],
      ),
    );
  }
}

// ---------------- Khối dùng chung ----------------

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final (String, VoidCallback)? action;
  final Widget child;

  const _Panel({required this.title, required this.child, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                if (action != null) TextButton(onPressed: action!.$2, child: Text(action!.$1)),
              ],
            ),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _Muted extends StatelessWidget {
  final String text;

  const _Muted(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
      );
}

class _ToneBox extends StatelessWidget {
  final BadgeTone tone;
  final Widget child;

  const _ToneBox({required this.tone, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(12)),
        child: child,
      );
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final BadgeTone tone;
  final String label;
  final String value;
  final String sub;

  const _Kpi({required this.icon, required this.tone, required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                Icon(icon, size: 18, color: tone.foreground),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            ),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _Todo {
  final IconData icon;
  final BadgeTone tone;
  final String title;
  final String desc;
  final String action;
  final VoidCallback? onTap;

  const _Todo(this.icon, this.tone, this.title, this.desc, this.action, this.onTap);
}

class _TodoTile extends StatelessWidget {
  final _Todo t;

  const _TodoTile(this.t);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: t.onTap,
          borderRadius: BorderRadius.circular(12),
          child: _ToneBox(
            tone: t.tone,
            child: Row(
              children: [
                Icon(t.icon, color: t.tone.foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, color: t.tone.foreground)),
                      Text(t.desc, style: const TextStyle(fontSize: 12, color: AppColors.textMain)),
                    ],
                  ),
                ),
                if (t.onTap != null) ...[
                  const SizedBox(width: 8),
                  Text(t.action, style: TextStyle(fontWeight: FontWeight.bold, color: t.tone.foreground)),
                ],
              ],
            ),
          ),
        ),
      );
}

class _RevenuePanel extends StatefulWidget {
  final List<DayStat> days;
  final bool loading;
  final int periodDays;

  const _RevenuePanel({required this.days, required this.loading, required this.periodDays});

  @override
  State<_RevenuePanel> createState() => _RevenuePanelState();
}

class _RevenuePanelState extends State<_RevenuePanel> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final total = days.fold<int>(0, (s, d) => s + d.revenue);
    DayStat? best;
    for (final d in days) {
      if (best == null || d.revenue > best.revenue) best = d;
    }
    final sub = widget.loading
        ? OwnerDashboardStrings.loading
        : days.isEmpty
            ? OwnerDashboardStrings.noDataPeriod
            : OwnerDashboardStrings.revenueChartSub(
                widget.periodDays,
                Formatters.vnd(total),
                best != null && best.revenue > 0 ? '${Formatters.dayMonth(best.date)}: ${Formatters.vnd(best.revenue)}' : null,
              );
    return _Panel(
      title: OwnerDashboardStrings.revenueChart,
      subtitle: sub,
      action: total > 0
          ? (_table ? OwnerDashboardStrings.showChart : OwnerDashboardStrings.showTable, () => setState(() => _table = !_table))
          : null,
      child: widget.loading
          ? const _Muted(OwnerDashboardStrings.loading)
          : total == 0
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.bar_chart, size: 36, color: Color(0xFFCBD5E1)),
                      Text(OwnerDashboardStrings.noRevenue(widget.periodDays),
                          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Text(OwnerDashboardStrings.noRevenueHint,
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : _table
                  ? _DayTable(days: days)
                  : RevenueBarChart(days: days),
    );
  }
}

class _DayTable extends StatelessWidget {
  final List<DayStat> days;

  const _DayTable({required this.days});

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    Widget row(String a, String b, String c, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(a, style: style)),
              Expanded(flex: 2, child: Text(b, textAlign: TextAlign.right, style: style)),
              Expanded(flex: 4, child: Text(c, textAlign: TextAlign.right, style: style ?? const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        );
    return Column(
      children: [
        row(OwnerDashboardStrings.colDay, OwnerDashboardStrings.colBookings, OwnerDashboardStrings.colRevenue, style: head),
        const Divider(height: 1),
        for (final d in days) row(Formatters.dayMonth(d.date), '${d.bookings}', Formatters.vnd(d.revenue)),
      ],
    );
  }
}

/// So sánh số đơn tháng này / tháng trước, quý này / quý trước (BookingComparisonPanel của Web).
class _ComparisonPanel extends StatefulWidget {
  final String facilityId;

  const _ComparisonPanel({super.key, required this.facilityId});

  @override
  State<_ComparisonPanel> createState() => _ComparisonPanelState();
}

class _ComparisonPanelState extends State<_ComparisonPanel> {
  CompareKind _kind = CompareKind.month;
  ComparisonSummary? _summary;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (ComparePeriod, ComparePeriod) get _periods => comparePeriods(_kind, DateTime.now());

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _summary = null;
      _error = null;
    });
    final (cur, prev) = _periods;
    try {
      final repo = AppRepositories.owner;
      final results = await Future.wait([
        repo.getDashboard(facilityId: widget.facilityId, from: prev.from, to: prev.to),
        repo.getDashboard(facilityId: widget.facilityId, from: cur.from, to: cur.to),
      ]);
      if (!mounted || seq != _seq) return;
      setState(() => _summary = ComparisonSummary.of(cur, prev, results[1].revenueByDay, results[0].revenueByDay));
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = ownerErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (cur, prev) = _periods;
    final unit = _kind.label.toLowerCase();
    final s = _summary;
    final change = s?.change;
    return _Panel(
      title: OwnerDashboardStrings.compareTitle(unit),
      subtitle: OwnerDashboardStrings.compareSub(prev.label, cur.label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<CompareKind>(
              showSelectedIcon: false,
              segments: [for (final k in CompareKind.values) ButtonSegment(value: k, label: Text(k.label))],
              selected: {_kind},
              onSelectionChanged: (v) {
                setState(() => _kind = v.first);
                _load();
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            _Muted(OwnerDashboardStrings.compareError(_error!))
          else if (s == null)
            const _Muted(OwnerDashboardStrings.compareLoading)
          else ...[
            StatGrid(
              spacing: 8,
              children: [
                _mini(OwnerDashboardStrings.compareCurrent(cur.label), OwnerDashboardStrings.bookingsCount(s.currentTotal)),
                _mini(OwnerDashboardStrings.comparePrevious(prev.label), OwnerDashboardStrings.bookingsCount(s.previousTotal)),
                _mini(
                  OwnerDashboardStrings.compareChange(unit),
                  change == null ? OwnerDashboardStrings.dash : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')}%',
                  color: change == null ? null : (change >= 0 ? BadgeTone.green.foreground : BadgeTone.red.foreground),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (s.currentTotal == 0 && s.previousTotal == 0)
              _Muted(OwnerDashboardStrings.compareEmpty(prev.label, cur.label))
            else
              ComparisonLineChart(
                previous: s.previous,
                current: s.current,
                length: cur.length > prev.length ? cur.length : prev.length,
                previousLabel: prev.label,
                currentLabel: cur.label,
              ),
            const SizedBox(height: 8),
            Text(
              OwnerDashboardStrings.compareNote(cur.label, s.previousSameDay, prev.label, cur.elapsed),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value, {Color? color}) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.textMain)),
          ],
        ),
      );
}

/// Bảng doanh thu từng sân con, chọn được khoảng ngày riêng (CourtRevenueTablePanel của Web).
class _CourtRevenueTable extends StatefulWidget {
  final String facilityId;
  final int periodDays;
  final List<CourtStat>? dashboardCourts;
  final bool dashboardLoading;
  final String? dashboardError;

  const _CourtRevenueTable({
    super.key,
    required this.facilityId,
    required this.periodDays,
    required this.dashboardCourts,
    required this.dashboardLoading,
    required this.dashboardError,
  });

  @override
  State<_CourtRevenueTable> createState() => _CourtRevenueTableState();
}

class _CourtRevenueTableState extends State<_CourtRevenueTable> {
  late DateTime _from = _defaultFrom;
  late DateTime _to = _defaultTo;
  List<CourtStat>? _custom;
  String? _customError;
  int _seq = 0;

  DateTime get _defaultTo => _day(DateTime.now());
  DateTime get _defaultFrom => _defaultTo.subtract(Duration(days: widget.periodDays - 1));
  bool get _isCustom => _from != _defaultFrom || _to != _defaultTo;
  bool get _invalid => _from.isAfter(_to);

  Future<void> _setRange(DateTime from, DateTime to) async {
    setState(() {
      _from = _day(from);
      _to = _day(to);
      _custom = null;
      _customError = null;
    });
    if (!_isCustom || _invalid) return;
    final seq = ++_seq;
    try {
      final d = await AppRepositories.owner.getDashboard(facilityId: widget.facilityId, from: _from, to: _to);
      if (mounted && seq == _seq) setState(() => _custom = d.revenueByCourt);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _customError = ownerErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = _isCustom;
    final loading = custom ? (!_invalid && _custom == null && _customError == null) : widget.dashboardLoading;
    final error = _invalid ? OwnerDashboardStrings.invalidRange : (custom ? _customError : widget.dashboardError);
    final rows = [...?(custom ? _custom : widget.dashboardCourts)]..sort((a, b) => b.revenue.compareTo(a.revenue));
    final booked = rows.fold<int>(0, (s, c) => s + c.bookedSlots);
    final sellable = rows.fold<int>(0, (s, c) => s + c.sellableSlots);
    final total = CourtStat(
      courtId: '',
      courtName: OwnerDashboardStrings.totalRow(rows.length),
      bookings: rows.fold<int>(0, (s, c) => s + c.bookings),
      bookedSlots: booked,
      sellableSlots: sellable,
      revenue: rows.fold<int>(0, (s, c) => s + c.revenue),
    );
    return _Panel(
      title: OwnerDashboardStrings.tableTitle,
      subtitle: OwnerDashboardStrings.tableSub(Formatters.date(_from), Formatters.date(_to)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: DateButton(label: OwnerDashboardStrings.fromDate, value: _from, onChanged: (d) => _setRange(d, _to))),
              const SizedBox(width: 8),
              Expanded(child: DateButton(label: OwnerDashboardStrings.toDate, value: _to, onChanged: (d) => _setRange(_from, d))),
            ],
          ),
          if (custom)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _setRange(_defaultFrom, _defaultTo),
                child: Text(OwnerDashboardStrings.resetRange(widget.periodDays)),
              ),
            ),
          const SizedBox(height: 8),
          if (error != null)
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB91C1C)))
          else if (loading && rows.isEmpty)
            const _Muted(OwnerDashboardStrings.tableLoading)
          else if (rows.isEmpty)
            const _Muted(OwnerDashboardStrings.tableEmpty)
          else ...[
            for (final c in rows) _CourtRow(stat: c),
            const Divider(),
            _CourtRow(stat: total, bold: true),
          ],
        ],
      ),
    );
  }
}

class _CourtRow extends StatelessWidget {
  final CourtStat stat;
  final bool bold;

  const _CourtRow({required this.stat, this.bold = false});

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              Text(stat.courtName.isEmpty ? '—' : stat.courtName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(Formatters.vnd(stat.revenue), style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.bold)),
            ],
          ),
          Text(
            '${OwnerDashboardStrings.colBookings}: ${stat.bookings} • ${OwnerDashboardStrings.colSlots}: '
            '${stat.bookedSlots} / ${stat.sellableSlots} • ${OwnerDashboardStrings.colOccupancy}: ${stat.occupancy}%',
            style: muted,
          ),
        ],
      ),
    );
  }
}
