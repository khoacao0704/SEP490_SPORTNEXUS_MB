import 'package:flutter/material.dart';
import '../../core/strings/player_tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';

/// Sơ đồ loại trực tiếp của một nội dung: các trận gom theo vòng, theo thứ tự trận.
class TournamentBracketScreen extends StatefulWidget {
  final String divisionId;
  final String title;

  const TournamentBracketScreen({super.key, required this.divisionId, required this.title});

  @override
  State<TournamentBracketScreen> createState() => _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> {
  List<BracketMatch>? _matches;

  /// Bảng xếp hạng vòng bảng (rỗng khi giải chỉ đấu loại trực tiếp).
  List<StandingGroup> _standings = const [];
  bool _showStandings = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final matches = await AppRepositories.playerTournament.getBracket(widget.divisionId);
      var standings = const <StandingGroup>[];
      if (matches.any((m) => m.stage == MatchStage.group)) {
        try {
          standings = await AppRepositories.playerTournament.getStandings(widget.divisionId);
        } catch (_) {
          // Chỉ ảnh hưởng phần bảng xếp hạng.
        }
      }
      if (mounted) {
        setState(() {
          _matches = matches;
          _standings = standings;
          if (standings.isEmpty) _showStandings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = PlayerTournamentStrings.loadError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          '${PlayerTournamentStrings.bracket} • ${widget.title}',
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _load, child: const Text(PlayerTournamentStrings.retry)),
                ],
              ),
            )
          : matches == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: matches.isEmpty
                    ? const [
                        SizedBox(height: 60),
                        Icon(Icons.account_tree_outlined, size: 64, color: AppColors.cardBorder),
                        SizedBox(height: 12),
                        Text(
                          PlayerTournamentStrings.bracketEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ]
                    : [
                        if (_standings.isNotEmpty) ...[
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text(PlayerTournamentStrings.matchesTab)),
                              ButtonSegment(value: true, label: Text(PlayerTournamentStrings.standingsTab)),
                            ],
                            selected: {_showStandings},
                            onSelectionChanged: (v) => setState(() => _showStandings = v.first),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_showStandings)
                          for (final g in _standings) _StandingTable(group: g)
                        else
                        for (final round in _rounds(matches)) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              round.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                            ),
                          ),
                          for (final m in round.matches) _MatchCard(match: m),
                        ],
                      ],
              ),
            ),
    );
  }

  /// Gom theo bảng (vòng bảng) hoặc tên vòng (loại trực tiếp), giữ thứ tự xuất hiện (BE trả mảng phẳng).
  static List<({String name, List<BracketMatch> matches})> _rounds(List<BracketMatch> matches) {
    final order = <String>[];
    final byRound = <String, List<BracketMatch>>{};
    for (final m in matches) {
      final key = m.stage == MatchStage.group && m.groupName.isNotEmpty
          ? PlayerTournamentStrings.groupHeading(m.groupName)
          : m.roundName;
      if (!byRound.containsKey(key)) order.add(key);
      byRound.putIfAbsent(key, () => []).add(m);
    }
    return [for (final name in order) (name: name, matches: byRound[name]!)];
  }
}

class _MatchCard extends StatelessWidget {
  final BracketMatch match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final m = match;
    final start = m.start;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _side(m.sideA, [for (final s in m.scores) s.a], m.isFinished && m.winner == m.sideA),
          const Divider(height: 12, color: AppColors.divider),
          _side(m.sideB, [for (final s in m.scores) s.b], m.isFinished && m.winner == m.sideB),
          if (m.resultType != MatchResultType.normal) ...[
            const SizedBox(height: 6),
            Text(
              m.resultType.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.tagOrangeText),
            ),
          ],
          if (start != null || m.courtName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (start != null) '${Formatters.time(start)} ${Formatters.weekdayDayMonth(start)}',
                if (m.courtName.isNotEmpty) m.courtName,
              ].join(' • '),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _side(String name, List<int> scores, bool winner) {
    final unknown = name == BracketMatch.unknownSide;
    return Row(
      children: [
        if (winner) const Icon(Icons.emoji_events, size: 16, color: Colors.amber) else const SizedBox(width: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            unknown ? 'Chưa xác định' : name,
            style: TextStyle(
              fontWeight: winner ? FontWeight.bold : FontWeight.w500,
              color: unknown ? AppColors.textSecondary : AppColors.textMain,
              fontStyle: unknown ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
        for (final s in scores)
          SizedBox(
            width: 28,
            child: Text(
              '$s',
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: winner ? FontWeight.bold : FontWeight.normal),
            ),
          ),
      ],
    );
  }
}

/// Bảng xếp hạng một bảng đấu: hạng, tên, số trận, thắng-hoà-thua, hiệu số, điểm.
class _StandingTable extends StatelessWidget {
  final StandingGroup group;

  const _StandingTable({required this.group});

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary);
    Widget cell(String text, {TextStyle? style, double width = 30}) =>
        SizedBox(width: width, child: Text(text, textAlign: TextAlign.center, style: style));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.name.isNotEmpty) ...[
            Text(
              PlayerTournamentStrings.groupHeading(group.name),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              cell('#', style: head, width: 24),
              const Expanded(child: Text(PlayerTournamentStrings.standingName, style: head)),
              cell(PlayerTournamentStrings.standingPlayed, style: head),
              cell(PlayerTournamentStrings.standingRecord, style: head, width: 56),
              cell(PlayerTournamentStrings.standingDiff, style: head, width: 36),
              cell(PlayerTournamentStrings.standingPoints, style: head, width: 36),
            ],
          ),
          const Divider(height: 12, color: AppColors.divider),
          for (final r in group.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  cell('${r.position}', width: 24),
                  Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  cell('${r.played}'),
                  cell('${r.won}-${r.drawn}-${r.lost}', width: 56),
                  cell(r.difference > 0 ? '+${r.difference}' : '${r.difference}', width: 36),
                  cell('${r.points}', width: 36, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
