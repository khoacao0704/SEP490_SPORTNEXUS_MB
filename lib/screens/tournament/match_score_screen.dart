import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/tournament_rules.dart';
import '../../core/strings/match_strings.dart';
import '../../core/strings/organizer_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/match_scoring.dart';
import '../../models/tournament_listing.dart';
import '../../models/tournament_management.dart';
import '../../theme/app_colors.dart';

/// Nhập tỉ số một trận giải (BTC, trọng tài; BTC sửa tỉ số khi xử lý khiếu nại), như MatchScoreModal của Web.
/// [requireCheckIn]: trận chưa có kết quả thì áp luật điểm danh (thiếu một bên chỉ được xử thắng, thiếu cả hai không lưu).
/// Màn này không điểm danh hộ, chỉ báo và hướng dẫn sang chỗ điểm danh (luồng 26/11 mục 8).
/// [onSubmit] nhận body PUT /matches/{id}/score và ghi chú; lưu xong màn đóng và trả về true.
class MatchScoreScreen extends StatefulWidget {
  final String matchId;
  final String title;
  final String submitLabel;
  final bool withNote;
  final bool requireCheckIn;
  final Future<void> Function(Map<String, dynamic> payload, String note) onSubmit;

  const MatchScoreScreen({
    super.key,
    required this.matchId,
    required this.onSubmit,
    this.title = MatchStrings.scoreTitle,
    this.submitLabel = MatchStrings.saveScore,
    this.withNote = false,
    this.requireCheckIn = false,
  });

  @override
  State<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _SetRow {
  final TextEditingController a;
  final TextEditingController b;

  _SetRow([String x = '', String y = '']) : a = TextEditingController(text: x), b = TextEditingController(text: y);

  void dispose() {
    a.dispose();
    b.dispose();
  }
}

class _MatchScoreScreenState extends State<MatchScoreScreen> {
  MatchDetail? _match;
  String? _error;
  CheckInGate? _gate;
  bool _gateLoading = false;
  final List<_SetRow> _sets = [];
  final _tbA = TextEditingController();
  final _tbB = TextEditingController();
  final _note = TextEditingController();
  ScoreKind _kind = ScoreKind.normal;
  String? _winnerId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final s in _sets) {
      s.dispose();
    }
    _tbA.dispose();
    _tbB.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await AppRepositories.hostTournament.getMatch(widget.matchId);
      if (!mounted) return;
      setState(() {
        _match = m;
        for (final s in m.sets) {
          _sets.add(_SetRow('${s.a}', '${s.b}'));
        }
        if (_sets.isEmpty) _sets.add(_SetRow());
        if (m.resultType == MatchResultType.walkover) _kind = ScoreKind.walkover;
        if (m.resultType == MatchResultType.retired) _kind = ScoreKind.retired;
        _winnerId = m.winnerId;
        if (m.tiebreakA != null) _tbA.text = '${m.tiebreakA}';
        if (m.tiebreakB != null) _tbB.text = '${m.tiebreakB}';
      });
      if (widget.requireCheckIn && !m.isFinished && m.tournamentId.isNotEmpty) await _loadGate(m);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadGate(MatchDetail m) async {
    setState(() => _gateLoading = true);
    List<OrganizerParticipant>? roster;
    try {
      roster = await AppRepositories.hostTournament.getParticipants(m.tournamentId);
    } on TournamentException {
      roster = null; // Không tải được danh sách: để BE quyết.
    }
    if (!mounted) return;
    final gate = TournamentRules.checkInGate(m.sides, roster);
    setState(() {
      _gate = gate;
      _gateLoading = false;
      if (gate?.mode == CheckInGateMode.walkoverOnly) {
        _kind = ScoreKind.walkover;
        _winnerId = gate!.present.first.id;
      }
    });
  }

  CheckInGateMode get _gateMode => _gate?.mode ?? CheckInGateMode.ok;

  (int, int) get _totals {
    var a = 0, b = 0;
    for (final s in _sets) {
      a += int.tryParse(s.a.text) ?? 0;
      b += int.tryParse(s.b.text) ?? 0;
    }
    return (a, b);
  }

  bool get _filled => _sets.any((s) => s.a.text.isNotEmpty || s.b.text.isNotEmpty);

  /// Bóng đá, thi đấu bình thường, tỉ số bằng nhau.
  bool get _footballLevel {
    final m = _match;
    final (a, b) = _totals;
    return m != null && m.isFootball && _kind == ScoreKind.normal && _filled && a == b;
  }

  bool get _isGroup => _match?.stage == MatchStage.group;

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));

  Future<void> _submit() async {
    final gate = _gate;
    if (gate != null && gate.mode == CheckInGateMode.blocked) {
      _toast(gate.message);
      return;
    }
    if (gate != null &&
        gate.mode == CheckInGateMode.walkoverOnly &&
        (_kind != ScoreKind.walkover || _winnerId != gate.present.first.id)) {
      _toast(gate.message);
      return;
    }
    final withTiebreak = _footballLevel;
    if (withTiebreak && !_isGroup && (_tbA.text.isEmpty || _tbB.text.isEmpty || _tbA.text == _tbB.text)) {
      _toast(MatchStrings.knockoutDrawNeedsTiebreak);
      return;
    }
    final (payload, error) = TournamentRules.buildScorePayload(
      kind: _kind,
      sets: [for (final s in _sets) (s.a.text, s.b.text)],
      winnerId: _winnerId,
      tiebreak: withTiebreak ? (_tbA.text, _tbB.text) : ('', ''),
    );
    if (error != null) {
      _toast(error);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSubmit(payload!, _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on TournamentException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          widget.title,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: m == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            )
          : SafeArea(
              child: ListView(padding: const EdgeInsets.all(16), children: _form(m)),
            ),
    );
  }

  List<Widget> _form(MatchDetail m) {
    final nameA = m.sideA?.name ?? MatchStrings.sideA;
    final nameB = m.sideB?.name ?? MatchStrings.sideB;
    final gate = _gate;
    final locked = _gateMode != CheckInGateMode.ok;
    final winnerChoices = _gateMode == CheckInGateMode.walkoverOnly ? gate!.present : m.sides;
    final footballLevel = _footballLevel;
    return [
      if (m.tournamentName.isNotEmpty || m.roundName.isNotEmpty)
        Text(
          [m.tournamentName, m.roundName].where((s) => s.isNotEmpty).join(' · '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      const SizedBox(height: 4),
      Text(
        MatchStrings.versus(nameA, nameB),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
      ),
      const SizedBox(height: 6),
      const Text(MatchStrings.scoreHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      if (gate != null && locked)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gateMode == CheckInGateMode.blocked ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${gate.message} ${MatchStrings.goCheckIn}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _gateMode == CheckInGateMode.blocked ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
            ),
          ),
        ),
      const SizedBox(height: 14),
      DropdownButtonFormField<ScoreKind>(
        key: ValueKey('kind-${_kind.name}-$locked'),
        initialValue: _kind,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: MatchStrings.resultKind,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: [for (final k in ScoreKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
        onChanged: locked ? null : (v) => setState(() => _kind = v ?? ScoreKind.normal),
      ),
      if (_kind != ScoreKind.normal && _gateMode != CheckInGateMode.blocked) ...[
        const SizedBox(height: 12),
        Text(
          _kind == ScoreKind.walkover ? MatchStrings.walkoverWinner : MatchStrings.retiredWinner,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in winnerChoices)
              ChoiceChip(
                label: Text(MatchStrings.wins(s.name)),
                selected: _winnerId == s.id,
                onSelected: (_) => setState(() => _winnerId = s.id),
              ),
          ],
        ),
      ],
      if (_kind != ScoreKind.walkover) ...[
        const SizedBox(height: 14),
        Row(
          children: [
            const SizedBox(width: 64),
            Expanded(child: Text(nameA, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Expanded(child: Text(nameB, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 40),
          ],
        ),
        for (var i = 0; i < _sets.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(width: 64, child: Text(MatchStrings.setLabel(i + 1))),
                Expanded(child: _scoreField(_sets[i].a)),
                const SizedBox(width: 8),
                Expanded(child: _scoreField(_sets[i].b)),
                SizedBox(
                  width: 40,
                  child: _sets.length > 1
                      ? IconButton(
                          tooltip: MatchStrings.removeSet,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _sets.removeAt(i).dispose()),
                        )
                      : null,
                ),
              ],
            ),
          ),
        if (_sets.length < TournamentRules.maxSets)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _sets.add(_SetRow())),
              icon: const Icon(Icons.add),
              label: const Text(MatchStrings.addSet),
            ),
          ),
      ],
      if (footballLevel) ...[
        const SizedBox(height: 8),
        Text(
          _isGroup ? MatchStrings.tiebreakGroupHint : MatchStrings.tiebreak,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 64),
            Expanded(child: _scoreField(_tbA)),
            const SizedBox(width: 8),
            Expanded(child: _scoreField(_tbB)),
            const SizedBox(width: 40),
          ],
        ),
        if (_isGroup && _tbA.text.isEmpty && _tbB.text.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
            child: const Text(
              MatchStrings.drawNote,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
            ),
          ),
      ],
      if (widget.withNote) ...[
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          maxLines: 3,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: MatchStrings.note,
            hintText: MatchStrings.noteHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text(OrganizerStrings.keep),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _busy || _gateLoading || _gateMode == CheckInGateMode.blocked ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white),
              child: Text(_busy ? MatchStrings.saving : widget.submitLabel),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _scoreField(TextEditingController c) => TextField(
    controller: c,
    textAlign: TextAlign.center,
    keyboardType: TextInputType.number,
    maxLength: 3,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      isDense: true,
      counterText: '',
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
