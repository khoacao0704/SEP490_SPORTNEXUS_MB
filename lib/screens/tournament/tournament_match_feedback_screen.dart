import 'package:flutter/material.dart';

import '../../core/strings/player_tournament_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_tournament_repository.dart';
import '../../data/repositories/rating_repository.dart';
import '../../models/sport_rating.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';

/// Nhận xét trình độ người cùng trận giải (đối thủ và đồng đội) trong 72 giờ sau trận.
/// 3 người cùng nhận xét lệch một phía thì Elo người đó được điều chỉnh. Pop `true` khi đã gửi.
class TournamentMatchFeedbackScreen extends StatefulWidget {
  final MyTournamentMatch match;

  const TournamentMatchFeedbackScreen({super.key, required this.match});

  @override
  State<TournamentMatchFeedbackScreen> createState() => _TournamentMatchFeedbackScreenState();
}

class _TournamentMatchFeedbackScreenState extends State<TournamentMatchFeedbackScreen> {
  List<MatchPlayer>? _players;
  String? _error;
  final Map<String, SkillVerdict> _verdicts = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final players = await AppRepositories.playerTournament.getMatchPlayers(widget.match.matchId);
      if (mounted) setState(() => _players = players);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    String? error;
    var sent = 0;
    for (final entry in _verdicts.entries) {
      try {
        await AppRepositories.rating.sendSkillFeedback(
          revieweeId: entry.key,
          contextId: widget.match.matchId,
          verdict: entry.value,
        );
        sent++;
      } on RatingException catch (e) {
        // Vd. người đó chưa có Elo môn này: bỏ qua người đó, gửi tiếp người khác.
        error ??= e.message;
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    final messenger = ScaffoldMessenger.of(context);
    if (sent > 0) {
      if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
      messenger.showSnackBar(const SnackBar(content: Text(PlayerTournamentStrings.feedbackSent)));
      Navigator.pop(context, true);
    } else if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = _players;
    final m = widget.match;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          PlayerTournamentStrings.feedbackTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: players == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(onPressed: _load, child: const Text(PlayerTournamentStrings.retry)),
                      ],
                    ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  PlayerTournamentStrings.versus(m.mySide, m.opponent),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  PlayerTournamentStrings.feedbackNote,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (players.isEmpty)
                  const Text(PlayerTournamentStrings.feedbackNoPlayers, style: TextStyle(color: AppColors.textSecondary)),
                for (final p in players)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            p.isTeammate ? PlayerTournamentStrings.teammate : p.sideName,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final v in SkillVerdict.values)
                                ChoiceChip(
                                  label: Text(v.label, style: const TextStyle(fontSize: 12)),
                                  selected: _verdicts[p.userId] == v,
                                  onSelected: _sending
                                      ? null
                                      : (_) => setState(() {
                                          _verdicts[p.userId] == v ? _verdicts.remove(p.userId) : _verdicts[p.userId] = v;
                                        }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: players == null || players.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _sending || _verdicts.isEmpty ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.authPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _sending
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                        : const Text(PlayerTournamentStrings.feedbackSend, style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
    );
  }
}
