import 'package:flutter/material.dart';
import '../../core/constants/vietnam_cities.dart';
import '../../core/strings/tournament_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/sport.dart';
import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/tournament/tournament_card.dart';
import 'tournament_detail_screen.dart';

/// Giải đấu: khám phá giải theo thành phố / môn / trạng thái và các giải đã đăng ký.
class TournamentsScreen extends StatefulWidget {
  final int initialTab;

  const TournamentsScreen({super.key, this.initialTab = 0});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

  /// Tăng lên khi dữ liệu có thể đã đổi (đăng ký / rút, đổi tab) để các tab tải lại.
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() => _revision++);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
          TournamentStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [Tab(text: TournamentStrings.tabExplore), Tab(text: TournamentStrings.tabMine)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ExploreView(revision: _revision, onChanged: () => setState(() => _revision++)),
          _MyTournamentsView(revision: _revision, onChanged: () => setState(() => _revision++)),
        ],
      ),
    );
  }
}

Future<void> _openDetail(BuildContext context, Tournament t, VoidCallback onChanged) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: t.id, initial: t)),
  );
  onChanged();
}

class _ExploreView extends StatefulWidget {
  final int revision;
  final VoidCallback onChanged;

  const _ExploreView({required this.revision, required this.onChanged});

  @override
  State<_ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<_ExploreView> {
  String _city = VietnamCities.hoChiMinh.name;
  Sport? _sport;
  TournamentStatus? _status;
  List<Tournament> _items = [];
  String? _myId;
  bool _isLoading = true;
  String? _error;

  static const _statusFilters = [
    TournamentStatus.registrationOpen,
    TournamentStatus.upcoming,
    TournamentStatus.ongoing,
    TournamentStatus.finished,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ExploreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await AppRepositories.tournament.getTournaments(
        TournamentQuery(city: _city, sport: _sport, status: _status),
      );
      final user = await AppRepositories.auth.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _items = items;
        _myId = user?.id;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = TournamentStrings.loadError;
      });
    }
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in VietnamCities.all)
              ListTile(
                title: Text(c.name),
                trailing: c.name == _city ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                onTap: () => Navigator.pop(sheetContext, c.name),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == _city) return;
    setState(() => _city = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Column(
            children: [
              _chipRow([
                _chip(label: _city, icon: Icons.location_on, selected: true, onTap: _pickCity),
                _chip(
                  label: TournamentStrings.allStatuses,
                  selected: _status == null,
                  onTap: () {
                    setState(() => _status = null);
                    _load();
                  },
                ),
                for (final s in _statusFilters)
                  _chip(
                    label: tournamentStatusFilterLabel(s),
                    selected: _status == s,
                    onTap: () {
                      setState(() => _status = s);
                      _load();
                    },
                  ),
              ]),
              const SizedBox(height: 8),
              _chipRow([
                _chip(
                  label: TournamentStrings.allSports,
                  icon: Icons.sports,
                  selected: _sport == null,
                  onTap: () {
                    setState(() => _sport = null);
                    _load();
                  },
                ),
                for (final s in Sport.values)
                  _chip(
                    label: s.label,
                    icon: sportIcon(s),
                    selected: _sport == s,
                    onTap: () {
                      setState(() => _sport = s);
                      _load();
                    },
                  ),
              ]),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: _TournamentList(
            items: _items,
            myId: _myId,
            isLoading: _isLoading,
            error: _error,
            emptyTitle: TournamentStrings.emptyExplore,
            emptyHint: TournamentStrings.emptyExploreHint,
            emptyIcon: Icons.search_off,
            onRefresh: _load,
            onOpen: (t) => _openDetail(context, t, widget.onChanged),
          ),
        ),
      ],
    );
  }

  Widget _chipRow(List<Widget> chips) => SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => chips[i],
        ),
      );
}

class _MyTournamentsView extends StatefulWidget {
  final int revision;
  final VoidCallback onChanged;

  const _MyTournamentsView({required this.revision, required this.onChanged});

  @override
  State<_MyTournamentsView> createState() => _MyTournamentsViewState();
}

class _MyTournamentsViewState extends State<_MyTournamentsView> {
  List<Tournament> _items = [];
  String? _myId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MyTournamentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await AppRepositories.tournament.getMyTournaments();
      final user = await AppRepositories.auth.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _items = items;
        _myId = user?.id;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = TournamentStrings.loadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TournamentList(
      items: _items,
      myId: _myId,
      isLoading: _isLoading,
      error: _error,
      emptyTitle: TournamentStrings.emptyMine,
      emptyHint: TournamentStrings.emptyMineHint,
      emptyIcon: Icons.emoji_events_outlined,
      onRefresh: _load,
      onOpen: (t) => _openDetail(context, t, widget.onChanged),
    );
  }
}

class _TournamentList extends StatelessWidget {
  final List<Tournament> items;
  final String? myId;
  final bool isLoading;
  final String? error;
  final String emptyTitle;
  final String emptyHint;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;
  final void Function(Tournament) onOpen;

  const _TournamentList({
    required this.items,
    required this.myId,
    required this.isLoading,
    required this.error,
    required this.emptyTitle,
    required this.emptyHint,
    required this.emptyIcon,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: onRefresh, child: const Text(TournamentStrings.retry)),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 40),
            Icon(emptyIcon, size: 60, color: AppColors.cardBorder),
            const SizedBox(height: 12),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 4),
            Text(emptyHint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final now = DateTime.now();
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => TournamentCard(
          tournament: items[index],
          now: now,
          myUserId: myId,
          onTap: () => onOpen(items[index]),
        ),
      ),
    );
  }
}

Widget _chip({required String label, required bool selected, required VoidCallback onTap, IconData? icon}) {
  return ChoiceChip(
    showCheckmark: false,
    avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primaryGreen),
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: AppColors.primaryGreen,
    backgroundColor: AppColors.white,
    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textMain),
    side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}
