import 'package:flutter/material.dart';
import '../../core/strings/tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/tournament/tournament_bracket.dart';
import '../../widgets/tournament/tournament_card.dart';
import 'tournament_register_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  /// Dữ liệu có sẵn từ danh sách để hiện ngay trong lúc tải lại.
  final Tournament? initial;

  const TournamentDetailScreen({super.key, required this.tournamentId, this.initial});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  Tournament? _tournament;
  String? _myId;
  String? _error;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _tournament = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await AppRepositories.tournament.getTournament(widget.tournamentId);
      final user = await AppRepositories.auth.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _tournament = t;
        _myId = user?.id;
        _error = null;
      });
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = TournamentStrings.loadError);
    }
  }

  TournamentEntry? get _myEntry => _myId == null ? null : _tournament?.entryOf(_myId!);

  Future<void> _register() async {
    final updated = await Navigator.push<Tournament>(
      context,
      MaterialPageRoute(builder: (_) => TournamentRegisterScreen(tournament: _tournament!)),
    );
    if (updated == null || !mounted) return;
    setState(() => _tournament = updated);
    _snack(TournamentStrings.registerSuccess, AppColors.primaryGreen);
  }

  Future<void> _withdraw() async {
    final t = _tournament!;
    final refundable = t.refundableOnWithdraw(DateTime.now());
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(TournamentStrings.confirmWithdrawTitle),
        content: Text(TournamentStrings.confirmWithdrawMessage(t.entryFee, refundable)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(TournamentStrings.keep)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(TournamentStrings.withdraw),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      final refund = await AppRepositories.tournament.withdraw(t.id);
      _snack(TournamentStrings.withdrawnMessage(refund), AppColors.textMain);
    });
  }

  Future<void> _simulateCancel() async {
    final repo = AppRepositories.tournament;
    if (repo is! SandboxTournamentSimulator) return;
    await _run(() async {
      await (repo as SandboxTournamentSimulator).simulateOrganizerCancelled(_tournament!.id);
      _snack(TournamentStrings.cancelledByOrganizer, AppColors.primaryGreen);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
      await _load();
    } on TournamentException catch (e) {
      _snack(e.message, Colors.red);
    } catch (_) {
      _snack(TournamentStrings.loadError, Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final t = _tournament;
    final now = DateTime.now();
    final status = t?.status(now);
    final canSimulate = AppRepositories.tournament is SandboxTournamentSimulator &&
        _myEntry != null &&
        (status == TournamentStatus.registrationOpen || status == TournamentStatus.upcoming);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: const Text(
            TournamentStrings.detailTitle,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (canSimulate)
              IconButton(
                tooltip: TournamentStrings.simulateCancel,
                onPressed: _isBusy ? null : _simulateCancel,
                icon: const Icon(Icons.event_busy_outlined),
              ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryGreen,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: TournamentStrings.tabOverview),
              Tab(text: TournamentStrings.tabSchedule),
              Tab(text: TournamentStrings.tabBracket),
            ],
          ),
        ),
        body: t == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                          TextButton(onPressed: _load, child: const Text(TournamentStrings.retry)),
                        ],
                      ),
              )
            : TabBarView(
                children: [
                  RefreshIndicator(
                    color: AppColors.primaryGreen,
                    onRefresh: _load,
                    child: _buildOverview(t, now),
                  ),
                  _buildSchedule(t),
                  t.matches.isEmpty ? _notDrawn() : TournamentBracket(tournament: t, myEntryId: _myEntry?.id),
                ],
              ),
        bottomNavigationBar: t == null ? null : _buildActions(t, now),
      ),
    );
  }

  // ---------------- Tổng quan ----------------

  Widget _buildOverview(Tournament t, DateTime now) {
    final myEntry = _myEntry;
    final champion = t.status(now) == TournamentStatus.finished ? t.champion : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
              const SizedBox(height: 8),
              TournamentStatusChip(tournament: t, now: now),
              const SizedBox(height: 12),
              _info(sportIcon(t.sport), TournamentStrings.format,
                  '${t.sport.label} • ${TournamentStrings.formatValue(t.entryType.label, t.minMembers, t.maxMembers)}'),
              _info(Icons.apartment_outlined, TournamentStrings.organizer, t.organizer),
              _info(Icons.location_on_outlined, TournamentStrings.venue, '${t.facilityName} • ${t.district}, ${t.city}'),
              _info(Icons.calendar_today_outlined, TournamentStrings.time, TournamentStrings.dateRange(t.startDate, t.endDate)),
              _info(Icons.event_available_outlined, TournamentStrings.registrationDeadline,
                  '${Formatters.time(t.registrationDeadline)} ${Formatters.weekdayDayMonth(t.registrationDeadline)}'),
              _info(Icons.payments_outlined, TournamentStrings.entryFee,
                  '${Formatters.vnd(t.entryFee)} / ${tournamentUnit(t).toLowerCase()}'),
              _info(Icons.groups_outlined, TournamentStrings.participantsLabel,
                  TournamentStrings.entries(t.entryCount, t.maxEntries)),
            ],
          ),
        ),
        if (champion != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(14)),
            child: Text(
              TournamentStrings.championBanner(champion.name),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
        if (myEntry != null) ...[
          const SizedBox(height: 12),
          _buildMyEntry(t, myEntry),
        ],
        if (t.description.isNotEmpty) ...[
          _section(TournamentStrings.about),
          _card(Text(t.description, style: const TextStyle(color: AppColors.textMain, height: 1.4))),
        ],
        if (t.prizes.isNotEmpty) ...[
          _section(TournamentStrings.prizes),
          _card(Column(
            children: [
              for (var i = 0; i < t.prizes.length; i++) ...[
                if (i > 0) const Divider(height: 16, color: AppColors.divider),
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: i == 0 ? const Color(0xFFF9A825) : AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.prizes[i].title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                          if (t.prizes[i].extra.isNotEmpty)
                            Text(t.prizes[i].extra, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.vnd(t.prizes[i].amount),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                  ],
                ),
              ],
            ],
          )),
        ],
        if (t.rules.isNotEmpty) ...[
          _section(TournamentStrings.rules),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < t.rules.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${i + 1}. ${t.rules[i]}', style: const TextStyle(color: AppColors.textMain, height: 1.4)),
                ),
            ],
          )),
        ],
        _section(TournamentStrings.feeRulesTitle),
        _card(Text(
          TournamentStrings.feeRules(t.entryFee, tournamentUnit(t).toLowerCase()),
          style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.5),
        )),
        _section(TournamentStrings.participantsTitle(t.entryCount, t.maxEntries)),
        _card(t.entries.isEmpty
            ? const Text(TournamentStrings.noParticipants, style: TextStyle(color: AppColors.textSecondary))
            : Column(
                children: [
                  for (var i = 0; i < t.entries.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text('${i + 1}.', style: const TextStyle(color: AppColors.textSecondary)),
                          ),
                          Expanded(
                            child: Text(
                              t.entries[i].name +
                                  (t.entries[i].id == myEntry?.id ? ' ${TournamentStrings.you}' : '') +
                                  (t.entries[i].withdrawn ? ' (${TournamentStrings.withdrawnTag})' : ''),
                              style: TextStyle(
                                fontWeight: t.entries[i].id == myEntry?.id ? FontWeight.bold : FontWeight.normal,
                                color: t.entries[i].withdrawn ? AppColors.textSecondary : AppColors.textMain,
                              ),
                            ),
                          ),
                          if (t.entryType == TournamentEntryType.team)
                            Text(
                              '${t.entries[i].members.length} người',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                ],
              )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMyEntry(Tournament t, TournamentEntry entry) {
    final unfinished = t.matches.where((m) => m.involves(entry.id) && !m.isFinished).toList()
      ..sort((a, b) => a.round.compareTo(b.round));
    final lost = t.matches.any((m) => m.involves(entry.id) && m.isFinished && m.winnerId != entry.id);
    final next = lost || entry.withdrawn ? null : unfinished.firstOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            TournamentStrings.yourEntry,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
          ),
          const SizedBox(height: 6),
          Text(
            entry.withdrawn ? '${entry.name} (${TournamentStrings.withdrawnTag})' : entry.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          if (entry.members.length > 1) ...[
            const SizedBox(height: 6),
            for (final m in entry.members)
              Text(
                '• ${m.name}${m.userId == entry.captainId ? ' – ${TournamentStrings.captain}' : ''}'
                '${m.userId == _myId ? ' ${TournamentStrings.you}' : ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.textMain),
              ),
          ],
          if (next != null) ...[
            const SizedBox(height: 10),
            Text(
              '${TournamentStrings.yourNextMatch} • ${TournamentStrings.roundName(next.round, t.roundCount)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
            ),
            const SizedBox(height: 6),
            TournamentMatchTile(tournament: t, match: next, myEntryId: entry.id),
          ] else if (lost) ...[
            const SizedBox(height: 8),
            const Text(TournamentStrings.eliminated, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  // ---------------- Lịch thi đấu ----------------

  Widget _buildSchedule(Tournament t) {
    if (t.matches.isEmpty) return _notDrawn();
    final myEntryId = _myEntry?.id;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var round = 1; round <= t.roundCount; round++)
          if (t.matchesInRound(round).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                TournamentStrings.roundName(round, t.roundCount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
              ),
            ),
            for (final m in t.matchesInRound(round)) TournamentMatchTile(tournament: t, match: m, myEntryId: myEntryId),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _notDrawn() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree_outlined, size: 60, color: AppColors.cardBorder),
              SizedBox(height: 12),
              Text(
                TournamentStrings.notDrawnYet,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );

  // ---------------- Nút hành động ----------------

  Widget? _buildActions(Tournament t, DateTime now) {
    final status = t.status(now);
    final entry = _myEntry;
    Widget? child;

    if (entry == null) {
      if (status == TournamentStatus.registrationOpen) {
        final open = t.slotsLeft > 0;
        child = Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TournamentStrings.feePer(tournamentUnit(t)),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  Text(
                    Formatters.vnd(t.entryFee),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: open && !_isBusy ? _register : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                open ? TournamentStrings.register : TournamentStrings.full,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      } else if (status == TournamentStatus.upcoming) {
        child = const Text(
          TournamentStrings.registrationClosed,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
        );
      }
    } else if (!entry.withdrawn &&
        (status == TournamentStatus.registrationOpen || status == TournamentStatus.upcoming)) {
      child = entry.captainId == _myId
          ? OutlinedButton(
              onPressed: _isBusy ? null : _withdraw,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isBusy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text(TournamentStrings.withdraw, style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : const Text(
              TournamentStrings.onlyCaptainWithdraws,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            );
    }

    if (child == null) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: child,
      ),
    );
  }

  // ---------------- Tiện ích ----------------

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
      );

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain)),
            ),
          ],
        ),
      );
}
