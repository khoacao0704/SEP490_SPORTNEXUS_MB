import 'package:flutter/material.dart';

import '../../core/strings/match_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/match_scoring.dart';
import '../../models/owner_court.dart';
import '../../models/organized_tournament.dart';
import '../../models/player_report.dart';
import '../../models/tournament_listing.dart';
import '../../models/tournament_management.dart';
import '../../screens/tournament/match_score_screen.dart';
import '../../screens/tournament/tournament_bracket_screen.dart';
import '../../theme/app_colors.dart';

// Các mục thi đấu của BTC (giải đấu đợt 4): lịch sân, xếp sân & trọng tài, bảng xếp hạng, khiếu nại kết quả.

void _toast(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));
}

const TextStyle _titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain);
const TextStyle _mutedStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);

Widget _card(List<Widget> children) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(top: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.cardBorder),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
);

String _sideName(String name) => name == BracketMatch.unknownSide ? MatchStrings.tbd : name;

// ======================= Lịch sân + xếp sân & trọng tài =======================

/// "Lịch sân & lịch thi đấu" theo ngày (sân đang giữ, trận nào đá sân nào lúc mấy giờ) và bảng
/// "Xếp sân & trọng tài" (tự xếp ca, xếp sân từng trận, phân trọng tài). Chỉ hiện khi đã có sơ đồ.
class CourtScheduleSection extends StatefulWidget {
  final OrganizedTournament tournament;

  /// BTC: có bảng xếp sân & trọng tài. false = chủ sân xem giải người khác tại sân mình (chỉ xem lịch).
  final bool manage;

  /// Báo tên sân đang có ca giữ cho giải (để form giữ ca đánh dấu).
  final ValueChanged<Set<String>>? onHeldCourts;

  const CourtScheduleSection({super.key, required this.tournament, this.manage = true, this.onHeldCourts});

  @override
  State<CourtScheduleSection> createState() => _CourtScheduleSectionState();
}

class _CourtScheduleSectionState extends State<CourtScheduleSection> {
  CourtSchedule? _schedule;
  List<BracketMatch> _matches = const [];
  List<TournamentStaffMember> _referees = const [];
  final Map<String, String?> _pickedReferee = {};
  String? _error;
  bool _scheduling = false;

  OrganizedTournament get _t => widget.tournament;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AppRepositories.hostTournament;
    try {
      final results = await Future.wait([
        repo.getCourtSchedule(_t.id),
        repo.getBracket(_t.id),
        repo.getStaff(_t.id),
      ]);
      if (!mounted) return;
      widget.onHeldCourts?.call({for (final b in (results[0] as CourtSchedule).blocks) b.courtName});
      setState(() {
        _schedule = results[0] as CourtSchedule;
        _matches = [for (final m in results[1] as List<BracketMatch>) if (m.id.isNotEmpty) m];
        _referees = [
          for (final s in results[2] as List<TournamentStaffMember>)
            if (s.role == StaffRole.referee) s,
        ];
        _error = null;
      });
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _auto() async {
    setState(() => _scheduling = true);
    try {
      await AppRepositories.hostTournament.autoSchedule(_t.id);
      if (mounted) _toast(context, MatchStrings.autoScheduled);
      await _load();
    } on TournamentException catch (e) {
      if (mounted) _toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  Future<void> _setReferee(BracketMatch m, String? staffId) async {
    setState(() => _pickedReferee[m.id] = staffId);
    try {
      await AppRepositories.hostTournament.assignOfficials(m.id, staffId == null ? const [] : [staffId]);
      if (mounted) _toast(context, staffId == null ? MatchStrings.refereeCleared : MatchStrings.refereeSet);
    } on TournamentException catch (e) {
      if (mounted) _toast(context, e.message, error: true);
    }
  }

  Future<void> _assign(BracketMatch m, ScheduledMatch? current) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignCourtScreen(tournament: _t, match: m, initialDate: current?.start ?? m.start ?? _t.start),
      ),
    );
    if (done == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    if (schedule == null) {
      return _error == null ? const SizedBox.shrink() : _card([Text(_error!, style: const TextStyle(color: Colors.red))]);
    }
    final closed = _t.isClosed;
    return Column(
      children: [
        _card([
          const Text(MatchStrings.scheduleTitle, style: _titleStyle),
          const SizedBox(height: 4),
          const Text(MatchStrings.courtHint, style: _mutedStyle),
          const SizedBox(height: 8),
          ..._days(schedule),
        ]),
        if (widget.manage && _matches.isNotEmpty)
        _card([
          // Nút nằm dưới tiêu đề để máy nhỏ / chữ to không tràn.
          const Text(MatchStrings.assignTitle, style: _titleStyle),
          if (!closed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                onPressed: _scheduling ? null : _auto,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(_scheduling ? MatchStrings.autoScheduling : MatchStrings.autoSchedule),
              ),
            ),
          if (_referees.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(MatchStrings.refereeNote, style: _mutedStyle),
            ),
          const SizedBox(height: 8),
          for (final m in _matches) _matchRow(m, schedule.of(m.id), closed),
        ]),
      ],
    );
  }

  List<Widget> _days(CourtSchedule s) {
    DateTime key(DateTime d) => DateTime(d.year, d.month, d.day);
    final days = <DateTime>{for (final b in s.blocks) key(b.start), for (final m in s.matches) key(m.start)}.toList()
      ..sort();
    if (days.isEmpty) return const [Text(MatchStrings.scheduleEmpty, style: _mutedStyle)];
    final byId = {for (final m in _matches) m.id: m};
    return [
      for (final day in days)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Formatters.weekdayDayMonth(day), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(MatchStrings.heldCourts, style: _mutedStyle),
                  if (!s.blocks.any((b) => key(b.start) == day))
                    const Text(MatchStrings.none, style: _mutedStyle)
                  else
                    for (final b in s.blocks.where((b) => key(b.start) == day).toList()
                      ..sort((x, y) => x.start.compareTo(y.start)))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          MatchStrings.block(b.courtName, b.start, b.end, b.slotCount),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 6),
              if (!s.matches.any((m) => key(m.start) == day))
                const Text(MatchStrings.noMatchesToday, style: _mutedStyle)
              else
                for (final sm in s.matches.where((m) => key(m.start) == day).toList()
                  ..sort((x, y) => x.start.compareTo(y.start)))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        sm.end == null
                            ? Formatters.time(sm.start)
                            : '${Formatters.time(sm.start)} – ${Formatters.time(sm.end!)}',
                        sm.courtName,
                        [
                          if ((sm.roundName.isNotEmpty ? sm.roundName : byId[sm.matchId]?.roundName ?? '').isNotEmpty)
                            '${sm.roundName.isNotEmpty ? sm.roundName : byId[sm.matchId]!.roundName}:',
                          byId[sm.matchId] == null
                              ? ''
                              : MatchStrings.versus(
                                  _sideName(byId[sm.matchId]!.sideA),
                                  _sideName(byId[sm.matchId]!.sideB),
                                ),
                        ].join(' '),
                        if (sm.isFinished) MatchStrings.done,
                      ].where((x) => x.trim().isNotEmpty).join(' • '),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
            ],
          ),
        ),
    ];
  }

  Widget _matchRow(BracketMatch m, ScheduledMatch? slot, bool closed) {
    final done = m.isFinished;
    final courtText = slot != null
        ? '${slot.courtName} • ${Formatters.dateTime(slot.start)}'
        : m.courtName.isNotEmpty && m.start != null
        ? '${m.courtName} • ${Formatters.dateTime(m.start!)}'
        : MatchStrings.notScheduled;
    final scheduled = slot != null || m.courtName.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.roundName, style: _mutedStyle),
          Text(
            MatchStrings.versus(_sideName(m.sideA), _sideName(m.sideB)),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            courtText,
            style: TextStyle(fontSize: 12, color: scheduled ? AppColors.textMain : AppColors.textSecondary),
          ),
          if (!done && !closed) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _referees.isEmpty
                      ? const Text(MatchStrings.noReferee, style: _mutedStyle)
                      : DropdownButtonFormField<String?>(
                          initialValue: _pickedReferee[m.id],
                          isExpanded: true,
                          hint: const Text(MatchStrings.pickReferee),
                          decoration: InputDecoration(
                            labelText: MatchStrings.referee,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text(MatchStrings.pickReferee)),
                            for (final r in _referees)
                              DropdownMenuItem<String?>(
                                value: r.id,
                                child: Text(r.fullName, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => _setReferee(m, v),
                        ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _t.facilityId.isEmpty ? null : () => _assign(m, slot),
                  child: Text(scheduled ? MatchStrings.changeCourt : MatchStrings.assignCourt),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Chọn ca sân cho một trận: ca đã giữ cho giải này hoặc ca còn trống, chưa qua (như AssignCourtModal của Web).
class AssignCourtScreen extends StatefulWidget {
  final OrganizedTournament tournament;
  final BracketMatch match;
  final DateTime? initialDate;

  const AssignCourtScreen({super.key, required this.tournament, required this.match, this.initialDate});

  @override
  State<AssignCourtScreen> createState() => _AssignCourtScreenState();
}

class _AssignCourtScreenState extends State<AssignCourtScreen> {
  late DateTime _date;
  List<AssignableSlot>? _slots;
  String? _error;
  String? _slotId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate ?? DateTime.now();
    _date = DateTime(d.year, d.month, d.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _slots = null;
      _error = null;
      _slotId = null;
    });
    try {
      final slots = await AppRepositories.hostTournament.getAssignableSlots(
        widget.tournament.facilityId,
        widget.tournament.id,
        _date,
      );
      if (mounted) setState(() => _slots = slots);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _shift(int days) {
    _date = _date.add(Duration(days: days));
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.subtract(const Duration(days: 365)),
      lastDate: _date.add(const Duration(days: 365)),
    );
    if (picked != null) {
      _date = picked;
      _load();
    }
  }

  Future<void> _submit() async {
    final id = _slotId;
    if (id == null) {
      _toast(context, MatchStrings.pickSlot, error: true);
      return;
    }
    final slot = _slots!.firstWhere((s) => s.id == id);
    setState(() => _busy = true);
    try {
      await AppRepositories.hostTournament.assignCourt(widget.match.id, id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(MatchStrings.assigned(slot.courtName, slot.start))));
    } on TournamentException catch (e) {
      if (mounted) _toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final slots = _slots;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          MatchStrings.assignCourtTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                [if (m.roundName.isNotEmpty) '${m.roundName}:', MatchStrings.versus(_sideName(m.sideA), _sideName(m.sideB))]
                    .join(' '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MatchStrings.prevDay,
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _pickDate,
                      child: Text(Formatters.weekdayDayMonth(_date), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  IconButton(
                    tooltip: MatchStrings.nextDay,
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : slots == null
                  ? const Center(child: CircularProgressIndicator())
                  : slots.isEmpty
                  ? const Center(child: Text(MatchStrings.noSlots, style: _mutedStyle))
                  : RadioGroup<String>(
                      groupValue: _slotId,
                      onChanged: (v) => setState(() => _slotId = v),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final s in slots)
                            RadioListTile<String>(
                              value: s.id,
                              title: Text('${Formatters.time(s.start)} – ${Formatters.time(s.end)} • ${s.courtName}'),
                              subtitle: Text(
                                s.reservedForTournament ? MatchStrings.reserved : MatchStrings.free,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: s.reservedForTournament ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy || _slotId == null ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(MatchStrings.assignCourt),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= Bảng xếp hạng =======================

/// Bảng xếp hạng vòng bảng / vòng tròn (ẩn khi không có).
class TournamentStandingsSection extends StatefulWidget {
  final String tournamentId;

  const TournamentStandingsSection({super.key, required this.tournamentId});

  @override
  State<TournamentStandingsSection> createState() => _TournamentStandingsSectionState();
}

class _TournamentStandingsSectionState extends State<TournamentStandingsSection> {
  List<StandingGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await AppRepositories.playerTournament.getStandings(widget.tournamentId);
      if (mounted) setState(() => _groups = [for (final g in groups) if (g.rows.isNotEmpty) g]);
    } catch (_) {
      // Không có bảng xếp hạng (loại trực tiếp) hoặc lỗi tải: ẩn mục.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) return const SizedBox.shrink();
    return _card([
      const Text(MatchStrings.standingsTitle, style: _titleStyle),
      const SizedBox(height: 8),
      for (final g in _groups) StandingTable(group: g),
    ]);
  }
}

// ======================= Khiếu nại kết quả trận (BTC) =======================

/// BTC xử lý khiếu nại: giữ kết quả / chấp nhận (kèm lý do) hoặc sửa tỉ số & đóng.
/// Người khiếu nại có 24 giờ chuyển Admin; đã chuyển Admin thì BE không cho BTC xử lý nữa.
class MatchComplaintsSection extends StatefulWidget {
  final OrganizedTournament tournament;
  final VoidCallback onChanged;

  const MatchComplaintsSection({super.key, required this.tournament, required this.onChanged});

  @override
  State<MatchComplaintsSection> createState() => _MatchComplaintsSectionState();
}

class _MatchComplaintsSectionState extends State<MatchComplaintsSection> {
  bool _openOnly = true;
  List<MatchComplaintItem>? _items;
  Map<String, String> _reasons = const {};
  String? _error;
  String? _actingId;
  bool _accepting = false;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadReasons();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await AppRepositories.hostTournament.getMatchComplaints(widget.tournament.id, openOnly: _openOnly);
      if (mounted) setState(() => _items = items);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadReasons() async {
    try {
      final reasons = await AppRepositories.report.getReasons(ReportTarget.match);
      if (mounted) setState(() => _reasons = {for (final r in reasons) r.code: r.title});
    } catch (_) {
      // Thiếu lý do thì hiện mã.
    }
  }

  void _startAct(MatchComplaintItem c, bool accept) {
    _note.clear();
    setState(() {
      _actingId = c.id;
      _accepting = accept;
    });
  }

  Future<void> _decide(MatchComplaintItem c) async {
    if (_note.text.trim().isEmpty) {
      _toast(context, MatchStrings.noteRequired, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppRepositories.hostTournament.decideComplaint(c.id, accept: _accepting, note: _note.text);
      if (!mounted) return;
      _toast(context, _accepting ? MatchStrings.accepted : MatchStrings.kept);
      setState(() => _actingId = null);
      await _load();
      widget.onChanged();
    } on TournamentException catch (e) {
      if (mounted) _toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fix(MatchComplaintItem c) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MatchScoreScreen(
          matchId: c.matchId,
          title: MatchStrings.fixTitle,
          submitLabel: MatchStrings.fixScore,
          withNote: true,
          onSubmit: (score, note) => AppRepositories.hostTournament.resolveComplaintWithScore(c.id, score, note),
        ),
      ),
    );
    if (done != true || !mounted) return;
    _toast(context, MatchStrings.fixed);
    await _load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return _card([
      Text(MatchStrings.complaintsTitle(_openOnly ? items?.length ?? 0 : 0), style: _titleStyle),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text(MatchStrings.open)),
          ButtonSegment(value: false, label: Text(MatchStrings.all)),
        ],
        selected: {_openOnly},
        onSelectionChanged: (v) {
          setState(() {
            _openOnly = v.first;
            _items = null;
          });
          _load();
        },
      ),
      const SizedBox(height: 8),
      if (_error != null && items == null)
        Text(_error!, style: const TextStyle(color: Colors.red))
      else if (items == null)
        const Center(child: CircularProgressIndicator())
      else if (items.isEmpty)
        Text(_openOnly ? MatchStrings.noOpenComplaints : MatchStrings.noComplaints, style: _mutedStyle)
      else
        for (final c in items) _item(c),
    ]);
  }

  Widget _item(MatchComplaintItem c) {
    final acting = _actingId == c.id;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(MatchStrings.versus(c.sideA, c.sideB), style: const TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (c.roundName.isNotEmpty) Text(c.roundName, style: _mutedStyle),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                child: Text(c.statusLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF92400E))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              c.reporterName.isEmpty ? MatchStrings.player : c.reporterName,
              _reasons[c.reason] ?? c.reason,
              if (c.createdAt != null) Formatters.dateTime(c.createdAt!),
            ].join(' · '),
            style: const TextStyle(fontSize: 13),
          ),
          if (c.winnerName.isNotEmpty) Text(MatchStrings.currentResult(c.winnerName), style: _mutedStyle),
          if (c.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(c.description, style: const TextStyle(fontSize: 13)),
            ),
          if (c.evidenceUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final u in c.evidenceUrls)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        u,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(width: 64, height: 64, color: AppColors.cardBorder),
                      ),
                    ),
                ],
              ),
            ),
          if (c.resolutionNote.isNotEmpty) Text(MatchStrings.conclusion(c.resolutionNote), style: _mutedStyle),
          if (c.canAct && !acting)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(onPressed: () => _startAct(c, false), child: const Text(MatchStrings.keepResult)),
                  OutlinedButton(onPressed: () => _startAct(c, true), child: const Text(MatchStrings.accept)),
                  ElevatedButton(onPressed: () => _fix(c), child: const Text(MatchStrings.fixScore)),
                ],
              ),
            ),
          if (acting) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: _accepting ? MatchStrings.acceptHint : MatchStrings.keepHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _actingId = null),
                  child: const Text(MatchStrings.back),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _decide(c),
                  child: Text(_accepting ? MatchStrings.confirmAccept : MatchStrings.confirmKeep),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Mở màn nhập tỉ số cho BTC (áp luật điểm danh); true nếu đã lưu.
Future<bool> openOrganizerScore(BuildContext context, BracketMatch m) async {
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => MatchScoreScreen(
        matchId: m.id,
        requireCheckIn: true,
        onSubmit: (payload, _) => AppRepositories.hostTournament.updateScore(m.id, payload),
      ),
    ),
  );
  if (saved == true && context.mounted) _toast(context, MatchStrings.scoreSaved);
  return saved == true;
}

/// Khung "Nhà vô địch" khi giải đã kết thúc: người thắng trận cuối cùng.
Widget? championBanner(OrganizedTournament t, List<BracketMatch> bracket) {
  if (!t.isFinished || bracket.isEmpty) return null;
  final last = groupBracketRounds(bracket).last.matches.first;
  final winner = last.winner;
  if (winner == null || winner.isEmpty || winner == BracketMatch.unknownSide) return null;
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFB45309)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.emoji_events, color: Colors.white, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            MatchStrings.champion(winner),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}


// ======================= Chủ sân giữ / trả ca cho giải =======================

/// Chủ sân chọn sân, ngày, giờ → Giữ sân cho giải (ca đã có khách bị bỏ qua, hiện trong danh sách xung đột);
/// Trả ca: bỏ trống sân và giờ = trả mọi ca chưa tới giờ của giải (như CourtBlockForm của Web).
class CourtBlockSection extends StatefulWidget {
  final OrganizedTournament tournament;

  /// Gọi sau khi giữ / trả để tải lại lịch sân.
  final VoidCallback onChanged;

  /// Tên sân đang có ca giữ cho giải (đánh dấu "✓ đã giữ").
  final Set<String> heldCourtNames;

  const CourtBlockSection({
    super.key,
    required this.tournament,
    required this.onChanged,
    this.heldCourtNames = const {},
  });

  @override
  State<CourtBlockSection> createState() => _CourtBlockSectionState();
}

class _CourtBlockSectionState extends State<CourtBlockSection> {
  List<OwnerCourt>? _courts;
  final Set<String> _picked = {};
  late DateTime _from;
  late DateTime _to;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _busy;
  List<CourtBlockConflict> _conflicts = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = widget.tournament.start;
    final end = widget.tournament.end;
    // Mặc định các ngày thi đấu của giải (không lùi về trước hôm nay).
    _from = start != null && start.isAfter(today) ? DateTime(start.year, start.month, start.day) : today;
    _to = end != null && end.isAfter(_from) ? DateTime(end.year, end.month, end.day) : _from;
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    try {
      final courts = await AppRepositories.owner.getCourts(widget.tournament.facilityId);
      if (mounted) setState(() => _courts = courts);
    } catch (_) {
      if (mounted) setState(() => _courts = const []);
    }
  }

  static String? _hhmm(TimeOfDay? t) =>
      t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool from) async {
    final initial = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.subtract(const Duration(days: 365)),
      lastDate: initial.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (start ? _startTime : _endTime) ?? TimeOfDay(hour: start ? 8 : 22, minute: 0),
    );
    if (picked != null) setState(() => start ? _startTime = picked : _endTime = picked);
  }

  Future<void> _run(bool block) async {
    if (_to.isBefore(_from)) {
      _toast(context, MatchStrings.dateOrder, error: true);
      return;
    }
    if (block && _picked.isEmpty) {
      _toast(context, MatchStrings.pickCourt, error: true);
      return;
    }
    final request = CourtBlockRequest(
      courtIds: _picked.toList(),
      dateFrom: _from,
      dateTo: _to,
      startTime: _hhmm(_startTime),
      endTime: _hhmm(_endTime),
    );
    setState(() => _busy = block ? 'block' : 'release');
    try {
      final repo = AppRepositories.hostTournament;
      final r = block
          ? await repo.blockCourts(widget.tournament.id, request)
          : await repo.releaseCourts(widget.tournament.id, request);
      if (!mounted) return;
      setState(() => _conflicts = r.conflicts);
      _toast(context, block ? MatchStrings.blocked(r.slots, r.alreadyBlocked) : MatchStrings.released(r.slots));
      widget.onChanged();
    } on TournamentException catch (e) {
      if (mounted) _toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courts = _courts;
    Widget pickButton(String label, String value, VoidCallback onTap, {VoidCallback? onClear}) => Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        OutlinedButton(onPressed: onTap, child: Text(value)),
        if (onClear != null)
          IconButton(icon: const Icon(Icons.close, size: 18), tooltip: MatchStrings.anyTime, onPressed: onClear),
      ],
    );
    return _card([
      const Text(MatchStrings.blockTitle, style: _titleStyle),
      const SizedBox(height: 8),
      if (courts == null)
        const Center(child: CircularProgressIndicator())
      else if (courts.isEmpty)
        const Text(MatchStrings.noCourts, style: _mutedStyle)
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in courts)
              FilterChip(
                label: Text('${c.name}${widget.heldCourtNames.contains(c.name) ? MatchStrings.heldMark : ''}'),
                selected: _picked.contains(c.id),
                onSelected: (on) => setState(() => on ? _picked.add(c.id) : _picked.remove(c.id)),
              ),
          ],
        ),
      const SizedBox(height: 8),
      pickButton(MatchStrings.fromDate, Formatters.date(_from), () => _pickDate(true)),
      pickButton(MatchStrings.toDate, Formatters.date(_to), () => _pickDate(false)),
      pickButton(
        MatchStrings.fromTime,
        _hhmm(_startTime) ?? MatchStrings.anyTime,
        () => _pickTime(true),
        onClear: _startTime == null ? null : () => setState(() => _startTime = null),
      ),
      pickButton(
        MatchStrings.toTime,
        _hhmm(_endTime) ?? MatchStrings.anyTime,
        () => _pickTime(false),
        onClear: _endTime == null ? null : () => setState(() => _endTime = null),
      ),
      const SizedBox(height: 6),
      const Text(MatchStrings.releaseHint, style: _mutedStyle),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton(onPressed: _busy != null ? null : () => _run(false), child: const Text(MatchStrings.release)),
          ElevatedButton(
            onPressed: _busy != null ? null : () => _run(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white),
            child: const Text(MatchStrings.blockAction),
          ),
        ],
      ),
      if (_conflicts.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MatchStrings.conflictsTitle(_conflicts.length),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
              ),
              for (final c in _conflicts.take(8))
                Text(
                  [
                    c.courtName,
                    if (c.start != null) Formatters.dateTime(c.start!),
                    if (c.reason.isNotEmpty) c.reason,
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
            ],
          ),
        ),
    ]);
  }
}
