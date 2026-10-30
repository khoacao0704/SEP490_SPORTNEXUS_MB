import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/strings/player_tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/sport.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/tournament/tournament_actions.dart';
import '../../widgets/tournament/tournament_list_card.dart';
import '../team/my_teams_screen.dart';
import 'tournament_detail_screen.dart';

/// Giải đấu: khám phá giải, các lượt đã đăng ký và lịch thi đấu của tôi.
class TournamentsScreen extends StatefulWidget {
  final int initialTab;

  const TournamentsScreen({super.key, this.initialTab = 0});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

  /// Tăng lên khi dữ liệu có thể đã đổi (đăng ký / rút) để các tab tải lại.
  int _revision = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openTournament(String id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: id)));
    if (mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          PlayerTournamentStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: PlayerTournamentStrings.myTeams,
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamsScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: PlayerTournamentStrings.tabExplore),
            Tab(text: PlayerTournamentStrings.tabMine),
            Tab(text: PlayerTournamentStrings.tabMatches),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ExploreTab(onOpen: _openTournament),
          _MyRegistrationsTab(key: ValueKey('mine-$_revision'), onOpen: _openTournament),
          _MyMatchesTab(key: ValueKey('matches-$_revision')),
        ],
      ),
    );
  }
}

// ---------------- Khám phá ----------------

class _ExploreTab extends StatefulWidget {
  final Future<void> Function(String id) onOpen;

  const _ExploreTab({required this.onOpen});

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _keyword = TextEditingController();
  Timer? _debounce;
  Sport? _sport;
  bool _openOnly = false;
  TournamentSort _sort = TournamentSort.newest;

  List<TournamentListItem> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _loadToken = 0;

  @override
  bool get wantKeepAlive => true;

  TournamentSearchQuery get _query => TournamentSearchQuery(
    keyword: _keyword.text,
    sport: _sport,
    registrationOpenOnly: _openOnly,
    sort: _sort,
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await AppRepositories.playerTournament.search(_query);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _items = page.items;
        _page = 1;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoading = false;
        _error = PlayerTournamentStrings.loadError;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final token = _loadToken;
    setState(() => _isLoadingMore = true);
    try {
      final page = await AppRepositories.playerTournament.search(_query, page: _page + 1);
      if (!mounted || token != _loadToken) return;
      final known = _items.map((t) => t.id).toSet();
      setState(() {
        _items = [..._items, ...page.items.where((t) => !known.contains(t.id))];
        _page++;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      // Cuộn tới cuối lần nữa sẽ thử lại.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onKeywordChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primaryGreen),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryGreen,
      backgroundColor: AppColors.white,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textMain),
      side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyword,
                  onChanged: _onKeywordChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: PlayerTournamentStrings.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              PopupMenuButton<TournamentSort>(
                tooltip: PlayerTournamentStrings.sortTooltip,
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (s) {
                  setState(() => _sort = s);
                  _load();
                },
                itemBuilder: (_) => [
                  for (final s in TournamentSort.values) PopupMenuItem(value: s, child: Text(s.label)),
                ],
              ),
            ],
          ),
        ),
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(PlayerTournamentStrings.registrationOpenOnly, _openOnly, () {
                  setState(() => _openOnly = !_openOnly);
                  _load();
                }),
                _chip(PlayerTournamentStrings.allSports, _sport == null, () {
                  setState(() => _sport = null);
                  _load();
                }),
                for (final s in Sport.values)
                  _chip(s.label, _sport == s, () {
                    setState(() => _sport = s);
                    _load();
                  }, icon: sportIcon(s)),
              ],
            ),
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            _EmptyView(
              icon: Icons.emoji_events_outlined,
              title: PlayerTournamentStrings.empty,
              hint: PlayerTournamentStrings.emptyHint,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2)),
            );
          }
          final item = _items[index];
          return TournamentListCard(item: item, onTap: () => widget.onOpen(item.id));
        },
      ),
    );
  }
}

// ---------------- Đã đăng ký ----------------

class _MyRegistrationsTab extends StatefulWidget {
  final Future<void> Function(String id) onOpen;

  const _MyRegistrationsTab({super.key, required this.onOpen});

  @override
  State<_MyRegistrationsTab> createState() => _MyRegistrationsTabState();
}

class _MyRegistrationsTabState extends State<_MyRegistrationsTab> {
  List<TournamentRegistrationItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await AppRepositories.playerTournament.getMyRegistrations();
      final far = DateTime(9999);
      items.sort((a, b) => (a.startDate ?? far).compareTo(b.startDate ?? far));
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = PlayerTournamentStrings.loadError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);
    if (items == null) return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (items.isEmpty)
            const _EmptyView(icon: Icons.how_to_reg_outlined, title: PlayerTournamentStrings.emptyMine)
          else
            for (final r in items)
              TournamentRegistrationCard(
                registration: r,
                onTap: () => widget.onOpen(r.tournamentId),
                onWithdrawn: _load,
              ),
        ],
      ),
    );
  }
}

// ---------------- Lịch đấu ----------------

class _MyMatchesTab extends StatefulWidget {
  const _MyMatchesTab({super.key});

  @override
  State<_MyMatchesTab> createState() => _MyMatchesTabState();
}

class _MyMatchesTabState extends State<_MyMatchesTab> {
  List<MyTournamentMatch>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await AppRepositories.playerTournament.getMyMatches();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = PlayerTournamentStrings.loadError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);
    if (items == null) return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (items.isEmpty)
            const _EmptyView(
              icon: Icons.sports_score_outlined,
              title: PlayerTournamentStrings.emptyMatches,
              hint: PlayerTournamentStrings.emptyMatchesHint,
            )
          else
            for (final m in items) _MyMatchTile(match: m),
        ],
      ),
    );
  }
}

class _MyMatchTile extends StatelessWidget {
  final MyTournamentMatch match;

  const _MyMatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final m = match;
    final start = m.start;
    final won = m.winner != null && m.winner == m.mySide;
    final lost = m.winner != null && m.winner!.isNotEmpty && m.winner != m.mySide;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [m.tournamentName, if (m.divisionName.isNotEmpty) m.divisionName].join(' • '),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            PlayerTournamentStrings.versus(m.mySide, m.opponent),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (m.roundName.isNotEmpty) m.roundName,
              if (start != null) '${Formatters.time(start)} ${Formatters.weekdayDayMonth(start)}',
              if (m.courtName.isNotEmpty) m.courtName,
              if (m.facilityName.isNotEmpty) m.facilityName,
            ].join(' • '),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (won || lost) ...[
            const SizedBox(height: 4),
            Text(
              PlayerTournamentStrings.winner(m.winner!),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: won ? AppColors.primaryGreen : Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------- Dùng chung ----------------

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;

  const _EmptyView({required this.icon, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 64, color: AppColors.cardBorder),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          TextButton(onPressed: onRetry, child: const Text(PlayerTournamentStrings.retry)),
        ],
      ),
    );
  }
}
