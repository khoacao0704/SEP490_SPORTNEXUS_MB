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
      if (mounted) setState(() => _matches = matches);
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

  /// Gom theo tên vòng, giữ thứ tự xuất hiện (BE trả mảng phẳng, không có số vòng).
  static List<({String name, List<BracketMatch> matches})> _rounds(List<BracketMatch> matches) {
    final order = <String>[];
    final byRound = <String, List<BracketMatch>>{};
    for (final m in matches) {
      if (!byRound.containsKey(m.roundName)) order.add(m.roundName);
      byRound.putIfAbsent(m.roundName, () => []).add(m);
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
