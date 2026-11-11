import 'package:flutter/material.dart';

import '../../core/strings/rating_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_profile_repository.dart';
import '../../data/repositories/rating_repository.dart';
import '../../data/session_store.dart';
import '../../models/sport.dart';
import '../../models/sport_rating.dart';
import '../../theme/app_colors.dart';
import '../../widgets/rating/rank_badge.dart';
import 'leaderboard_screen.dart';
import 'skill_assessment_screen.dart';

/// Elo của tôi theo môn (cá nhân + đội), môn chưa có Elo (làm khảo sát trình độ), lối vào bảng xếp hạng.
class MyEloScreen extends StatefulWidget {
  const MyEloScreen({super.key});

  @override
  State<MyEloScreen> createState() => _MyEloScreenState();
}

class _MyEloScreenState extends State<MyEloScreen> {
  List<SportRating>? _ratings;
  List<Sport> _mySports = Sport.values;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final ratings = await AppRepositories.rating.getMyRatings();
      var sports = Sport.values.toList();
      try {
        final survey = await AppRepositories.playerProfile.getSurvey();
        if (survey.sports.isNotEmpty) sports = survey.sports.map((s) => s.sport).toList();
      } on PlayerProfileException {
        // Không tải được khảo sát: gợi ý mọi môn.
      }
      if (!mounted) return;
      setState(() {
        _ratings = ratings;
        _mySports = sports;
      });
    } on RatingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _assess(Sport sport) async {
    final result = await Navigator.push<SkillAssessment>(
      context,
      MaterialPageRoute(builder: (_) => SkillAssessmentScreen(sport: sport)),
    );
    if (result != null) _load();
  }

  Future<void> _openLeaderboard({Sport? sport, RatingType type = RatingType.personal}) async {
    final me = await SessionStore.readUser();
    if (!mounted) return;
    final ids = {
      ?me?.id,
      for (final r in _ratings ?? const <SportRating>[])
        if (r.type == RatingType.team) r.ownerId,
    };
    final first = (_ratings ?? const <SportRating>[]).map((r) => r.sport).nonNulls.firstOrNull;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(initialSport: sport ?? first ?? Sport.badminton, initialType: type, highlightIds: ids),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratings = _ratings;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(RatingStrings.myEloTitle, style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: RatingStrings.leaderboard,
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => _openLeaderboard(),
          ),
        ],
      ),
      body: ratings == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(onPressed: _load, child: const Text(RatingStrings.retry)),
                      ],
                    ),
            )
          : RefreshIndicator(onRefresh: _load, child: _body(ratings)),
    );
  }

  Widget _body(List<SportRating> ratings) {
    final personal = ratings.where((r) => r.type == RatingType.personal).toList();
    final teams = ratings.where((r) => r.type == RatingType.team).toList();
    final rated = personal.map((r) => r.sport).nonNulls.toSet();
    final missing = _mySports.where((s) => !rated.contains(s)).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(RatingStrings.eloExplain, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 16),
        _section(RatingStrings.personal),
        if (personal.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(RatingStrings.noRating, style: TextStyle(height: 1.4)),
          ),
        for (final r in personal) _ratingCard(r, onAssess: r.sport == null ? null : () => _assess(r.sport!)),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          _section(RatingStrings.sportsWithoutRating),
          for (final s in missing)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: FilledButton(onPressed: () => _assess(s), child: const Text(RatingStrings.takeAssessment)),
              ),
            ),
        ],
        const SizedBox(height: 8),
        _section(RatingStrings.teams),
        if (teams.isEmpty)
          const Text(RatingStrings.noTeamRating, style: TextStyle(color: AppColors.textSecondary))
        else
          for (final r in teams) _ratingCard(r, title: r.ownerName),
      ],
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  );

  Widget _ratingCard(SportRating r, {String? title, VoidCallback? onAssess}) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title == null ? r.sportLabel : '$title • ${r.sportLabel}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              RankBadge(rank: r.rankLabel),
            ],
          ),
          const SizedBox(height: 6),
          // Wrap: máy hẹp / chữ to thì số trận xuống dòng thay vì tràn.
          Wrap(
            spacing: 12,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${r.rating}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                    const TextSpan(text: '  Elo'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  RatingStrings.ratedMatches(r.ratedMatches),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if (r.isProvisional)
            const Text(
              '${RatingStrings.provisional} • ${RatingStrings.provisionalNote}',
              style: TextStyle(fontSize: 12, color: AppColors.tagOrangeText),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onAssess != null) TextButton(onPressed: onAssess, child: const Text(RatingStrings.retakeAssessment)),
              if (r.sport != null)
                TextButton(
                  onPressed: () => _openLeaderboard(sport: r.sport, type: r.type),
                  child: const Text(RatingStrings.leaderboard),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
