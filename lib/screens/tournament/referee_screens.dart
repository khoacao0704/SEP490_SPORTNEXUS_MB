import 'package:flutter/material.dart';

import '../../core/constants/tournament_rules.dart';
import '../../core/strings/match_strings.dart';
import '../../core/strings/organizer_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../models/match_scoring.dart';
import '../../models/tournament_management.dart';
import '../../theme/app_colors.dart';
import 'match_score_screen.dart';

// Trận tôi làm trọng tài (giải đấu đợt 5, luồng 26/11 mục 6): danh sách chia theo giải; mở một giải có hai tab
// Nhập tỉ số và Điểm danh. Trận miễn đấu bị ẩn vì tự có kết quả.

void _toast(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));
}

Widget _badge(String text, Color bg, Color fg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
  child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
);

/// Một giải tôi làm nhân sự, gom từ các trận.
class RefereeTournamentGroup {
  final String tournamentId;
  final String name;
  final String facilityName;
  final List<StaffMatch> matches;

  const RefereeTournamentGroup({
    required this.tournamentId,
    required this.name,
    required this.facilityName,
    required this.matches,
  });

  int get waiting => matches.where((m) => m.isReady).length;
  int get done => matches.where((m) => m.isFinished).length;

  static List<RefereeTournamentGroup> group(List<StaffMatch> all) {
    final order = <String>[];
    final byId = <String, List<StaffMatch>>{};
    for (final m in all) {
      if (m.isBye) continue;
      if (!byId.containsKey(m.tournamentId)) order.add(m.tournamentId);
      byId.putIfAbsent(m.tournamentId, () => []).add(m);
    }
    return [
      for (final id in order)
        RefereeTournamentGroup(
          tournamentId: id,
          name: byId[id]!.first.tournamentName,
          facilityName: byId[id]!.first.facilityName,
          matches: byId[id]!,
        ),
    ];
  }
}

/// Tab "Trận tôi làm trọng tài": thẻ từng giải (số trận chờ nhập, số trận đã có kết quả).
class RefereeMatchesTab extends StatelessWidget {
  final List<StaffMatch> matches;
  final Future<void> Function() onRefresh;

  const RefereeMatchesTab({super.key, required this.matches, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final groups = RefereeTournamentGroup.group(matches);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(MatchStrings.refereeIntro(groups.length), style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RefereeTournamentScreen(group: g)),
                    );
                    await onRefresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined, color: AppColors.primaryGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              if (g.facilityName.isNotEmpty)
                                Text(g.facilityName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (g.waiting > 0)
                                    _badge(MatchStrings.waiting(g.waiting), const Color(0xFFFEF3C7), const Color(0xFF92400E)),
                                  _badge(
                                    MatchStrings.doneCount(g.done, g.matches.length),
                                    const Color(0xFFF1F5F9),
                                    const Color(0xFF475569),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Một giải tôi làm trọng tài: tab Nhập tỉ số và tab Điểm danh.
class RefereeTournamentScreen extends StatefulWidget {
  final RefereeTournamentGroup group;

  const RefereeTournamentScreen({super.key, required this.group});

  @override
  State<RefereeTournamentScreen> createState() => _RefereeTournamentScreenState();
}

class _RefereeTournamentScreenState extends State<RefereeTournamentScreen> {
  late List<StaffMatch> _matches = widget.group.matches;

  Future<void> _reload() async {
    try {
      final all = await AppRepositories.hostTournament.getMyStaffMatches();
      final mine = [
        for (final m in all)
          if (m.tournamentId == widget.group.tournamentId && !m.isBye) m,
      ];
      if (mounted) setState(() => _matches = mine);
    } on TournamentException {
      // Giữ danh sách cũ.
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                g.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (g.facilityName.isNotEmpty)
                Text(
                  g.facilityName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
            ],
          ),
          bottom: const TabBar(
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryGreen,
            tabs: [
              Tab(text: MatchStrings.tabScore),
              Tab(text: MatchStrings.tabCheckIn),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ScoreTab(matches: _matches, onSaved: _reload),
            _CheckInTab(tournamentId: g.tournamentId),
          ],
        ),
      ),
    );
  }
}

class _ScoreTab extends StatelessWidget {
  final List<StaffMatch> matches;
  final Future<void> Function() onSaved;

  const _ScoreTab({required this.matches, required this.onSaved});

  /// Chờ nhập tỉ số lên trước, rồi trận chưa đủ hai bên, rồi trận đã xong; cùng nhóm thì trận được phân công trước, rồi theo giờ.
  List<StaffMatch> get _sorted {
    int rank(StaffMatch m) => m.isReady ? 0 : (m.isFinished ? 2 : 1);
    final far = DateTime(9999);
    return [...matches]..sort((x, y) {
      final r = rank(x).compareTo(rank(y));
      if (r != 0) return r;
      final a = (y.isAssignedOfficial ? 1 : 0).compareTo(x.isAssignedOfficial ? 1 : 0);
      if (a != 0) return a;
      return (x.start ?? far).compareTo(y.start ?? far);
    });
  }

  Future<void> _score(BuildContext context, StaffMatch m) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MatchScoreScreen(
          matchId: m.matchId,
          title: MatchStrings.scoreOf(m.sideA, m.sideB),
          requireCheckIn: true,
          onSubmit: (payload, _) => AppRepositories.hostTournament.updateScore(m.matchId, payload),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      _toast(context, MatchStrings.refereeSaved);
      await onSaved();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(MatchStrings.refereeRule, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      for (final m in _sorted)
        Container(
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
              Text(
                [
                  m.start == null ? MatchStrings.noTime : Formatters.dateTime(m.start!),
                  m.courtName.isEmpty ? MatchStrings.noCourt : m.courtName,
                ].join(' • '),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                MatchStrings.versus(
                  m.sideA.isEmpty ? MatchStrings.tbd : m.sideA,
                  m.sideB.isEmpty ? MatchStrings.tbd : m.sideB,
                ),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (m.roundName.isNotEmpty)
                Text(m.roundName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (m.roleLabel.isNotEmpty) _badge(m.roleLabel, const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
                  if (m.isAssignedOfficial)
                    _badge(MatchStrings.assignedToYou, const Color(0xFFDCFCE7), const Color(0xFF15803D)),
                  if (m.isFinished) _badge(MatchStrings.hasResult, const Color(0xFFF1F5F9), const Color(0xFF475569)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: m.hasBothSides ? () => _score(context, m) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(m.isFinished ? MatchStrings.editScore : MatchStrings.enterScore),
                ),
              ),
              if (!m.hasBothSides)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(MatchStrings.notEnoughSides, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
    ],
  );
}

/// Điểm danh của giải: ô tìm tên, dòng "Đã điểm danh x/y", nút Điểm danh từng người / đội.
class _CheckInTab extends StatefulWidget {
  final String tournamentId;

  const _CheckInTab({required this.tournamentId});

  @override
  State<_CheckInTab> createState() => _CheckInTabState();
}

class _CheckInTabState extends State<_CheckInTab> with AutomaticKeepAliveClientMixin {
  List<OrganizerParticipant>? _people;
  String? _error;
  String _query = '';
  String? _busyId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await AppRepositories.hostTournament.getParticipants(widget.tournamentId);
      if (mounted) setState(() => _people = people);
    } on TournamentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _checkIn(OrganizerParticipant p) async {
    setState(() => _busyId = p.participantId);
    try {
      await AppRepositories.hostTournament.checkIn(widget.tournamentId, p.participantId);
      if (mounted) _toast(context, OrganizerStrings.checkedInDone(p.displayName));
      await _load();
    } on TournamentException catch (e) {
      if (mounted) _toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Gõ không dấu vẫn tìm được ("tuan" ra "Tuấn").
  static String _fold(String s) => TournamentRules.fold(s);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final people = _people;
    if (people == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    final q = _fold(_query.trim());
    final shown = [
      for (final p in people)
        if (q.isEmpty || _fold('${p.displayName} ${p.members.join(' ')}').contains(q)) p,
    ];
    final done = people.where((p) => p.isCheckedIn).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: MatchStrings.searchName,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          Text(MatchStrings.checkedInCount(done, people.length), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final p in shown)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.isCheckedIn ? const Color(0xFFF0FDF4) : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (p.members.isNotEmpty)
                    Text(p.members.join(', '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (p.paymentLabel.isNotEmpty)
                    Text(p.paymentLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  if (p.isCheckedIn)
                    const Text(
                      OrganizerStrings.checkedIn,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busyId != null ? null : () => _checkIn(p),
                      icon: const Icon(Icons.how_to_reg, size: 16),
                      label: const Text(OrganizerStrings.checkIn),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF15803D),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
