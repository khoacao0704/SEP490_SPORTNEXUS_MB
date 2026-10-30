import 'package:flutter/material.dart';

import '../../core/strings/player_tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_tournament_repository.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/tournament/tournament_actions.dart';
import '../../widgets/tournament/tournament_list_card.dart';
import 'tournament_bracket_screen.dart';
import 'tournament_register_screen.dart';

/// Chi tiết một giải: thông tin chung, từng nội dung (đăng ký / vé / rút / sơ đồ / người tham gia),
/// giải thưởng và điều lệ.
class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  TournamentDetails? _details;
  List<TournamentParticipant> _participants = [];
  List<TournamentRegistrationItem> _mine = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final repo = AppRepositories.playerTournament;
    try {
      final details = await repo.getDetails(widget.tournamentId);
      final results = await Future.wait<Object>([
        repo.getParticipants(details.info.id).catchError((_) => <TournamentParticipant>[]),
        repo.getMyRegistrations().catchError((_) => <TournamentRegistrationItem>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _details = details;
        _participants = results[0] as List<TournamentParticipant>;
        _mine = results[1] as List<TournamentRegistrationItem>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is TournamentException ? e.message : PlayerTournamentStrings.loadError);
    }
  }

  Future<void> _register(TournamentDivision division) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentRegisterScreen(details: _details!, division: division),
      ),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(PlayerTournamentStrings.registerSuccess),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _details;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          d?.info.name ?? PlayerTournamentStrings.title,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(onPressed: _load, child: const Text(PlayerTournamentStrings.retry)),
                ],
              ),
            )
          : d == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _buildHeader(d.info),
                  _section(
                    PlayerTournamentStrings.divisions,
                    d.divisions.isEmpty
                        ? const Text(
                            PlayerTournamentStrings.noDivisions,
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        : Column(children: [for (final division in d.divisions) _buildDivision(d, division)]),
                  ),
                  if (d.prizes.isNotEmpty) _section(PlayerTournamentStrings.prizes, _PrizeList(prizes: d.prizes)),
                  if (d.rules.isNotEmpty) _section(PlayerTournamentStrings.rules, _paragraph(d.rules)),
                  if (d.sportRules.isNotEmpty) _section(PlayerTournamentStrings.sportRules, _paragraph(d.sportRules)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(TournamentListItem t) {
    return Container(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.imageUrl != null)
            Image.network(
              t.imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TournamentPhaseChip(phase: t.phase),
                const SizedBox(height: 8),
                Text(
                  t.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const SizedBox(height: 8),
                _infoRow(t.sport == null ? Icons.sports : sportIcon(t.sport!), t.sportLabel),
                _infoRow(
                  Icons.place_outlined,
                  [t.facilityName, t.facilityAddress].where((s) => s.isNotEmpty).join(' • '),
                ),
                _infoRow(Icons.event_outlined, PlayerTournamentStrings.dateRange(t.startDate, t.endDate)),
                if (t.registrationDeadline != null)
                  _infoRow(Icons.timer_outlined, PlayerTournamentStrings.deadline(t.registrationDeadline!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textMain)),
        ),
      ],
    ),
  );

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _paragraph(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
  );

  Widget _buildDivision(TournamentDetails d, TournamentDivision division) {
    final groups = TournamentEntryGroup.group(_participants.where((p) => p.divisionId == division.id));
    final mine = _mine.where((r) => r.divisionId == division.id).firstOrNull;
    final full = division.maxEntries > 0 && groups.length >= division.maxEntries;

    final Widget action;
    if (mine != null) {
      action = TournamentRegistrationCard(registration: mine, showTournament: false, onWithdrawn: _load);
    } else if (division.isRegistrationOpen && !full) {
      action = SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _register(division),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(PlayerTournamentStrings.register, style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    } else {
      action = Text(
        division.phase == TournamentPhase.open
            ? (full ? PlayerTournamentStrings.full : PlayerTournamentStrings.registrationClosed)
            : division.phase.label,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: mine != null ? AppColors.primaryGreen : AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      division.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                  ),
                  if (mine != null)
                    TournamentPhaseChip(phase: TournamentPhase.open, label: PlayerTournamentStrings.registered),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  division.typeLabel,
                  if (division.type.needsTeam)
                    PlayerTournamentStrings.teamSize(division.minTeamSize, division.maxTeamSize),
                  if (division.maxEntries > 0)
                    PlayerTournamentStrings.entries(groups.length, division.maxEntries, division.type),
                ].join(' • '),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                '${PlayerTournamentStrings.entryFee}: ${PlayerTournamentStrings.fee(division.entryFee)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
              ),
              if (division.guide.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(division.guide, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
              if (division.prizes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PrizeList(prizes: division.prizes, compact: true),
              ],
              const SizedBox(height: 10),
              action,
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentBracketScreen(divisionId: division.id, title: division.name),
                      ),
                    ),
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text(PlayerTournamentStrings.bracket),
                  ),
                ],
              ),
              _ParticipantsTile(groups: groups),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrizeList extends StatelessWidget {
  final List<TournamentPrizeItem> prizes;
  final bool compact;

  const _PrizeList({required this.prizes, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in prizes)
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 1 : 3),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: compact ? 16 : 20,
                  color: p.position == 1 ? Colors.amber : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    PlayerTournamentStrings.prizePosition(p.position),
                    style: TextStyle(fontSize: compact ? 12 : 14),
                  ),
                ),
                Text(
                  Formatters.vnd(p.amount),
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ParticipantsTile extends StatelessWidget {
  final List<TournamentEntryGroup> groups;

  const _ParticipantsTile({required this.groups});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          '${PlayerTournamentStrings.participants} (${groups.length})',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: [
          if (groups.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(PlayerTournamentStrings.noParticipants, style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          for (final g in groups)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.lightGreen,
                child: Icon(g.isTeam ? Icons.groups : Icons.person, size: 18, color: AppColors.primaryGreen),
              ),
              title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: g.isTeam ? Text(g.members.map((m) => m.name).join(', ')) : null,
              trailing: g.members.every((m) => m.isCheckedIn)
                  ? const Icon(Icons.verified, size: 18, color: AppColors.primaryGreen)
                  : null,
            ),
        ],
      ),
    );
  }
}
