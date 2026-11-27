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

  /// Các trận đã xếp sân / giờ (lịch các trận; màn người chơi không hiện sơ đồ, như luồng 26/11).
  List<BracketMatch> _matches = [];
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
        repo.getBracket(details.info.id).catchError((_) => <BracketMatch>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _details = details;
        _participants = results[0] as List<TournamentParticipant>;
        _mine = results[1] as List<TournamentRegistrationItem>;
        _matches = (results[2] as List<BracketMatch>).where((m) => m.start != null || m.courtName.isNotEmpty).toList()
          ..sort((a, b) => (a.start ?? DateTime(9999)).compareTo(b.start ?? DateTime(9999)));
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
                  _section(PlayerTournamentStrings.infoTitle, _buildInfo(d)),
                  _section(
                    d.divisions.length == 1 ? PlayerTournamentStrings.registerSection : PlayerTournamentStrings.divisions,
                    d.divisions.isEmpty
                        ? const Text(
                            PlayerTournamentStrings.noDivisions,
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        : Column(children: [for (final division in d.divisions) _buildDivision(d, division)]),
                  ),
                  _section(
                    '${PlayerTournamentStrings.prizes} ${PlayerTournamentStrings.prizesNote}',
                    _prizesOf(d).isEmpty
                        ? const Text(PlayerTournamentStrings.noPrizes, style: TextStyle(color: AppColors.textSecondary))
                        : _PrizeList(prizes: _prizesOf(d)),
                  ),
                  if (d.info.description.isNotEmpty)
                    _section(PlayerTournamentStrings.introTitle, _paragraph(d.info.description)),
                  _section(PlayerTournamentStrings.scheduleTitle, _buildSchedule()),
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
                _infoRow(
                  t.sport == null ? Icons.sports : sportIcon(t.sport!),
                  [t.sportLabel, ?t.tier?.label, ?t.purpose?.label].where((s) => s.isNotEmpty).join(' • '),
                ),
                if (t.isInviteOnly)
                  _infoRow(Icons.mail_lock_outlined, PlayerTournamentStrings.inviteOnlyNote),
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

  List<TournamentPrizeItem> _prizesOf(TournamentDetails d) =>
      d.prizes.isNotEmpty ? d.prizes : (d.divisions.length == 1 ? d.divisions.first.prizes : const []);

  /// Đủ các ô của form tạo giải (trừ file PDF gửi Admin), như màn chi tiết của Web.
  Widget _buildInfo(TournamentDetails d) {
    final t = d.info;
    final division = d.divisions.length == 1 ? d.divisions.first : null;
    var registered = 0;
    if (division != null) {
      final groups = TournamentEntryGroup.group(_participants.where((p) => p.divisionId == division.id)).length;
      registered = groups > division.registeredCount ? groups : division.registeredCount;
    }
    final rows = <(String, String)>[
      (PlayerTournamentStrings.organizer, t.organizerName),
      (PlayerTournamentStrings.venue, [t.facilityName, t.facilityAddress].where((x) => x.isNotEmpty).join(' · ')),
      (
        PlayerTournamentStrings.playTime,
        t.startDate == null && t.endDate == null
            ? PlayerTournamentStrings.notAnnounced
            : PlayerTournamentStrings.dateRange(t.startDate, t.endDate),
      ),
      (
        PlayerTournamentStrings.regDeadline,
        t.registrationDeadline == null
            ? PlayerTournamentStrings.notAnnounced
            : Formatters.dateTime(t.registrationDeadline!),
      ),
      (PlayerTournamentStrings.tierTitle, t.tier?.label ?? ''),
      (PlayerTournamentStrings.purposeTitle, t.purpose?.label ?? ''),
      if (division != null)
        (
          PlayerTournamentStrings.registrationType,
          [
            division.typeLabel,
            if (division.type.needsTeam) PlayerTournamentStrings.teamRange(division.minTeamSize, division.maxTeamSize),
          ].join(', '),
        ),
      if (division != null)
        (PlayerTournamentStrings.playersTitle, PlayerTournamentStrings.playersCount(registered, division.maxEntries)),
      (PlayerTournamentStrings.formatTitle, PlayerTournamentStrings.formatLabel(t.format)),
      if (division != null) (PlayerTournamentStrings.entryFee, PlayerTournamentStrings.fee(division.entryFee)),
      if (t.hasEloCondition)
        (
          PlayerTournamentStrings.eloTitle,
          PlayerTournamentStrings.eloCondition(t.minRating, t.maxRating, t.minRatedMatches),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Trận đã xếp sân: ai gặp ai, vòng, sân, giờ.
  Widget _buildSchedule() {
    if (_matches.isEmpty) {
      return const Text(PlayerTournamentStrings.noSchedule, style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      children: [
        for (final m in _matches)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m.sideA} vs ${m.sideB}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  [
                    if (m.roundName.isNotEmpty) m.roundName,
                    if (m.courtName.isNotEmpty) m.courtName,
                    if (m.start != null) Formatters.dateTime(m.start!),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDivision(TournamentDetails d, TournamentDivision division) {
    final groups = TournamentEntryGroup.group(_participants.where((p) => p.divisionId == division.id));
    final mine = _mine.where((r) => r.divisionId == division.id).firstOrNull;
    final registered = groups.length > division.registeredCount ? groups.length : division.registeredCount;
    final full = division.isFull || (division.maxEntries > 0 && registered >= division.maxEntries);

    final Widget action;
    if (mine != null) {
      action = TournamentRegistrationCard(registration: mine, showTournament: false, onWithdrawn: _load);
    } else if (d.info.isInviteOnly) {
      // Giải nội bộ: BE từ chối đăng ký trực tiếp (403), chỉ nhận lời mời.
      action = const Text(
        PlayerTournamentStrings.inviteOnlyNote,
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      );
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
                    PlayerTournamentStrings.entries(registered, division.maxEntries, division.type),
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
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    Formatters.vnd(p.amount),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: compact ? 12 : 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
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
