import 'package:flutter/material.dart';

import '../../core/strings/owner_tournament_strings.dart';
import '../../core/strings/tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_form.dart';
import '../../widgets/tournament/tournament_bracket.dart';
import '../../widgets/tournament/tournament_card.dart';
import 'tournament_form_screen.dart';

/// Quản lý một giải: thông tin, đơn đăng ký, bốc thăm, xếp lịch và nhập kết quả từng trận, sửa / hủy giải.
class OwnerTournamentDetailScreen extends StatefulWidget {
  final Tournament tournament;

  const OwnerTournamentDetailScreen({super.key, required this.tournament});

  @override
  State<OwnerTournamentDetailScreen> createState() => _OwnerTournamentDetailScreenState();
}

class _OwnerTournamentDetailScreenState extends State<OwnerTournamentDetailScreen> {
  late Tournament _t = widget.tournament;
  bool _busy = false;

  bool _editable(DateTime now) => !_t.cancelled && _t.paidOutAt == null && _t.status(now) != TournamentStatus.finished;

  void _toast(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null));

  Future<void> _run(Future<Tournament> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _t = updated);
      _toast(success);
    } on TournamentException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action, {bool danger = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(OwnerTournamentStrings.keep),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger ? Colors.red : AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _edit() async {
    final updated = await Navigator.push<Tournament>(
      context,
      MaterialPageRoute(builder: (_) => TournamentFormScreen(tournament: _t)),
    );
    if (updated != null && mounted) setState(() => _t = updated);
  }

  Future<void> _cancel() async {
    final ok = await _confirm(
      OwnerTournamentStrings.cancelTitle,
      OwnerTournamentStrings.cancelConfirm(_t.entries.length, _t.entryFee),
      OwnerTournamentStrings.cancelTournament,
      danger: true,
    );
    if (ok) await _run(() => AppRepositories.organizer.cancelTournament(_t.id), OwnerTournamentStrings.cancelled);
  }

  Future<void> _draw() async {
    final active = _t.entries.where((e) => !e.withdrawn).length;
    final ok = await _confirm(
      OwnerTournamentStrings.drawTitle,
      OwnerTournamentStrings.drawConfirm(active, TournamentDraw.bracketSizeFor(active)),
      OwnerTournamentStrings.draw,
    );
    if (ok) await _run(() => AppRepositories.organizer.drawBracket(_t.id), OwnerTournamentStrings.drawn);
  }

  Future<void> _openMatch(TournamentMatch m) async {
    final updated = await showModalBottomSheet<Tournament>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MatchSheet(tournament: _t, match: m),
    );
    if (updated != null && mounted) setState(() => _t = updated);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final t = _t;
    final editable = _editable(now);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerTournamentStrings.detailTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (editable)
            IconButton(
              tooltip: OwnerTournamentStrings.edit,
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(t, now),
          const SizedBox(height: 12),
          _entriesCard(t),
          const SizedBox(height: 12),
          _bracketCard(t, now, editable),
          if (editable) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text(OwnerTournamentStrings.cancelTournament),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children, Widget? trailing}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _infoCard(Tournament t, DateTime now) {
    final collected = t.entryFee * t.entries.length;
    final champion = t.champion;
    return _card(
      title: t.name,
      trailing: TournamentStatusChip(tournament: t, now: now),
      children: [
        _line(Icons.storefront_outlined, t.facilityName),
        _line(
          Icons.sports,
          '${t.sport.label}${t.courtType.isStandard ? '' : ' • ${t.courtType.label}'} • ${t.entryType.label}',
        ),
        _line(
          Icons.event_available,
          '${OwnerTournamentStrings.deadline}: ${Formatters.weekdayDayMonth(t.registrationDeadline)} ${Formatters.time(t.registrationDeadline)}',
        ),
        _line(
          Icons.event,
          '${Formatters.weekdayDayMonth(t.startDate)} ${Formatters.time(t.startDate)} → '
          '${Formatters.weekdayDayMonth(t.endDate)} ${Formatters.time(t.endDate)}',
        ),
        _line(Icons.payments_outlined, OwnerTournamentStrings.feeLine(t.entryFee)),
        if (!t.cancelled)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t.paidOutAt != null
                  ? OwnerTournamentStrings.paidOut(collected)
                  : OwnerTournamentStrings.holding(collected),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: t.paidOutAt != null ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
            ),
          ),
        if (champion != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                const SizedBox(width: 6),
                Text(
                  OwnerTournamentStrings.champion(champion.name),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _entriesCard(Tournament t) => _card(
    title: '${OwnerTournamentStrings.entriesTitle} (${OwnerTournamentStrings.entries(t.entries.length, t.maxEntries)})',
    children: [
      if (t.entries.isEmpty)
        const Text(OwnerTournamentStrings.noEntries, style: TextStyle(color: AppColors.textSecondary))
      else
        for (final e in t.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.groups_outlined, size: 18, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (e.withdrawn)
                  Text(OwnerTournamentStrings.withdrawn, style: TextStyle(color: Colors.red.shade700, fontSize: 12))
                else if (t.entryType == TournamentEntryType.team)
                  Text(
                    OwnerTournamentStrings.members(e.members.length),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
    ],
  );

  Widget _bracketCard(Tournament t, DateTime now, bool editable) {
    if (!t.isDrawn) {
      final canDraw =
          editable &&
          !now.isBefore(t.registrationDeadline) &&
          t.entries.where((e) => !e.withdrawn).length >= TournamentDraw.minEntries;
      return _card(
        title: OwnerTournamentStrings.bracketTitle,
        children: [
          Text(
            OwnerTournamentStrings.drawHint(
              '${Formatters.weekdayDayMonth(t.registrationDeadline)} ${Formatters.time(t.registrationDeadline)}',
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (editable &&
              !now.isBefore(t.registrationDeadline) &&
              t.entries.where((e) => !e.withdrawn).length < TournamentDraw.minEntries)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(OwnerTournamentStrings.drawTooFew, style: TextStyle(fontSize: 13, color: Colors.red)),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: canDraw && !_busy ? _draw : null,
            icon: const Icon(Icons.shuffle),
            label: const Text(OwnerTournamentStrings.draw),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      );
    }

    return _card(
      title: OwnerTournamentStrings.bracketTitle,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: TournamentBracket(tournament: t),
        ),
        const SizedBox(height: 12),
        if (editable)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              OwnerTournamentStrings.tapToUpdate,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        for (var round = 1; round <= t.roundCount; round++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              TournamentStrings.roundName(round, t.roundCount),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
          ),
          for (final m in t.matchesInRound(round))
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: editable && !m.isBye ? () => _openMatch(m) : null,
              child: TournamentMatchTile(tournament: t, match: m),
            ),
        ],
      ],
    );
  }
}

/// Xếp lịch và nhập kết quả một trận.
class _MatchSheet extends StatefulWidget {
  final Tournament tournament;
  final TournamentMatch match;

  const _MatchSheet({required this.tournament, required this.match});

  @override
  State<_MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<_MatchSheet> {
  late final TournamentMatch _m = widget.match;
  late DateTime _at = _m.scheduledAt ?? widget.tournament.startDate;
  late final _court = TextEditingController(text: _m.court);
  late final _score = TextEditingController(text: _m.score);
  late String? _winner = _m.winnerId;
  bool _saving = false;
  String? _error;

  bool get _ready => _m.entryAId != null && _m.entryBId != null;

  @override
  void dispose() {
    _court.dispose();
    _score.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<Tournament> Function() action, String success) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      Navigator.pop(context, updated);
    } on TournamentException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(_at.year - 1),
      lastDate: DateTime(_at.year + 1),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _at.hour, minute: _at.minute),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (time != null) setState(() => _at = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final organizer = AppRepositories.organizer;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                TournamentStrings.roundName(_m.round, t.roundCount),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 4),
              Text(
                '${tournamentSideName(t, _m.entryAId, _m.round)}  vs  ${tournamentSideName(t, _m.entryBId, _m.round)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(OwnerTournamentStrings.schedule, style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: ownerInputDecoration(OwnerTournamentStrings.time),
                        child: Text('${Formatters.weekdayDayMonth(_at)} • ${Formatters.time(_at)}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _court,
                      decoration: ownerInputDecoration(OwnerTournamentStrings.court),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => _submit(
                        () => organizer.scheduleMatch(t.id, _m.id, at: _at, court: _court.text),
                        OwnerTournamentStrings.scheduleSaved,
                      ),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                child: const Text(OwnerTournamentStrings.saveSchedule),
              ),
              if (_ready) ...[
                const Divider(height: 28),
                const Text(OwnerTournamentStrings.result, style: TextStyle(fontWeight: FontWeight.w600)),
                RadioGroup<String>(
                  groupValue: _winner,
                  onChanged: (v) => setState(() => _winner = v),
                  child: Column(
                    children: [
                      for (final id in [_m.entryAId!, _m.entryBId!])
                        RadioListTile<String>(
                          value: id,
                          title: Text(tournamentSideName(t, id, _m.round)),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primaryGreen,
                        ),
                    ],
                  ),
                ),
                TextField(controller: _score, decoration: ownerInputDecoration(OwnerTournamentStrings.score)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _saving || _winner == null
                      ? null
                      : () => _submit(
                          () => organizer.recordResult(t.id, _m.id, winnerId: _winner!, score: _score.text),
                          OwnerTournamentStrings.resultSaved,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text(OwnerTournamentStrings.saveResult),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
