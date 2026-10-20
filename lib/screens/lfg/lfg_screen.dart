import 'package:flutter/material.dart';
import '../../core/constants/vietnam_cities.dart';
import '../../core/strings/lfg_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/court_type.dart';
import '../../models/lfg_match.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/lfg/lfg_actions.dart';
import '../../widgets/lfg/lfg_match_card.dart';
import '../../widgets/main_drawer.dart';
import '../../widgets/review/fair_play_guard.dart';
import 'create_lfg_match_screen.dart';
import 'lfg_match_detail_screen.dart';

/// Tab "Ghép Trận LFG": bảng tin kèo đang tìm người + kèo của tôi.
class LfgScreen extends StatefulWidget {
  final int initialTab;

  const LfgScreen({super.key, this.initialTab = 0});

  @override
  State<LfgScreen> createState() => _LfgScreenState();
}

class _LfgScreenState extends State<LfgScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

  /// Tăng lên mỗi khi dữ liệu có thể đã đổi (vào/rời/tạo kèo, đổi tab) để các tab tải lại.
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

  void _changed() => setState(() => _revision++);

  Future<void> _create() async {
    if (!await ensureCanJoinLfg(context) || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateLfgMatchScreen()));
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const MainDrawer(selectedIndex: 2),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          LfgStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 16),
              label: const Text(LfgStrings.createButton, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [Tab(text: LfgStrings.tabFeed), Tab(text: LfgStrings.tabMine)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          LfgFeedView(revision: _revision, onChanged: _changed),
          MyLfgMatchesView(revision: _revision, onChanged: _changed),
        ],
      ),
    );
  }
}

/// Mở chi tiết kèo, sau khi quay lại thì báo [onChanged] để tải lại.
Future<void> _openDetail(BuildContext context, LfgMatch match, VoidCallback onChanged) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LfgMatchDetailScreen(matchId: match.id, initial: match)),
  );
  onChanged();
}

class LfgFeedView extends StatefulWidget {
  final int revision;
  final VoidCallback onChanged;

  const LfgFeedView({super.key, required this.revision, required this.onChanged});

  @override
  State<LfgFeedView> createState() => _LfgFeedViewState();
}

class _LfgFeedViewState extends State<LfgFeedView> {
  String _city = VietnamCities.hoChiMinh.name;
  String? _district;
  Sport? _sport;
  LfgFormat? _format;
  CourtType? _courtType;
  List<LfgFeedItem> _items = [];
  String? _myId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LfgFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await AppRepositories.lfg.getFeed(
        LfgFeedQuery(city: _city, district: _district, sport: _sport, format: _format, courtType: _courtType),
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
        _error = LfgStrings.loadError;
      });
    }
  }

  Future<void> _pickLocation() async {
    final picked = await showModalBottomSheet<({String city, String? district})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _LocationSheet(city: _city, district: _district),
    );
    if (picked == null) return;
    setState(() {
      _city = picked.city;
      _district = picked.district;
    });
    _load();
  }

  Future<void> _claim(LfgMatch match) async {
    final joined = await flashClaimMatch(context, match);
    if (joined != null) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final formats = _sport == null ? LfgFormat.values : LfgFormat.forSport(_sport!);
    final courtTypes = _sport == null || !AppRepositories.lfgFacility.supportsCourtTypes
        ? const <CourtType>[]
        : CourtType.forSport(_sport!).where((t) => !t.isStandard).toList();
    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // BE chưa lọc được theo tỉnh/quận: ẩn chọn khu vực.
                    if (AppRepositories.lfg.supportsAreaFilter) ...[
                      _chip(
                        label: _district == null ? _city : '$_district, $_city',
                        icon: Icons.location_on,
                        selected: true,
                        onTap: _pickLocation,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (courtTypes.isNotEmpty) ...[
                      // Bóng đá / bóng rổ: chỉ có Team vs Team, lọc theo số người mỗi đội.
                      _chip(
                        label: LfgStrings.allCourtTypes,
                        selected: _courtType == null,
                        onTap: () {
                          setState(() => _courtType = null);
                          _load();
                        },
                      ),
                      for (final t in courtTypes) ...[
                        const SizedBox(width: 8),
                        _chip(
                          label: t.matchup,
                          selected: t == _courtType,
                          onTap: () {
                            setState(() => _courtType = t);
                            _load();
                          },
                        ),
                      ],
                    ] else ...[
                      _chip(
                        label: LfgStrings.allFormats,
                        selected: _format == null,
                        onTap: () {
                          setState(() => _format = null);
                          _load();
                        },
                      ),
                      for (final f in formats) ...[
                        const SizedBox(width: 8),
                        _chip(
                          label: f.label,
                          selected: f == _format,
                          onTap: () {
                            setState(() => _format = f);
                            _load();
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip(
                      label: LfgStrings.allSports,
                      icon: Icons.sports,
                      selected: _sport == null,
                      onTap: () {
                        setState(() {
                          _sport = null;
                          _courtType = null;
                        });
                        _load();
                      },
                    ),
                    for (final s in Sport.values) ...[
                      const SizedBox(width: 8),
                      _chip(
                        label: s.label,
                        icon: sportIcon(s),
                        selected: s == _sport,
                        onTap: () {
                          setState(() {
                            _sport = s;
                            _courtType = null;
                            if (_format != null && !LfgFormat.forSport(s).contains(_format)) _format = null;
                          });
                          _load();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return _Message(icon: Icons.cloud_off, title: _error!, action: TextButton(onPressed: _load, child: const Text(LfgStrings.retry)));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 60),
          _Message(icon: Icons.search_off, title: LfgStrings.emptyFeed, subtitle: LfgStrings.emptyFeedHint),
        ]),
      );
    }
    final now = DateTime.now();
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return LfgMatchCard(
            match: item.match,
            now: now,
            myUserId: _myId,
            distanceKm: item.distanceKm,
            onTap: () => _openDetail(context, item.match, widget.onChanged),
            onClaim: () => _claim(item.match),
          );
        },
      ),
    );
  }
}

class MyLfgMatchesView extends StatefulWidget {
  final int revision;
  final VoidCallback onChanged;

  const MyLfgMatchesView({super.key, this.revision = 0, required this.onChanged});

  @override
  State<MyLfgMatchesView> createState() => _MyLfgMatchesViewState();
}

class _MyLfgMatchesViewState extends State<MyLfgMatchesView> {
  List<LfgMatch> _items = [];
  String? _myId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MyLfgMatchesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await AppRepositories.lfg.getMyMatches();
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
        _error = LfgStrings.loadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return _Message(icon: Icons.cloud_off, title: _error!, action: TextButton(onPressed: _load, child: const Text(LfgStrings.retry)));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 60),
          _Message(icon: Icons.groups_outlined, title: LfgStrings.emptyMine, subtitle: LfgStrings.emptyMineHint),
        ]),
      );
    }
    final now = DateTime.now();
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final match = _items[index];
          return LfgMatchCard(
            match: match,
            now: now,
            myUserId: _myId,
            onTap: () => _openDetail(context, match, () {
              _load();
              widget.onChanged();
            }),
          );
        },
      ),
    );
  }
}

/// Mở riêng "Kèo của tôi" (vd. từ thông báo).
class MyLfgMatchesScreen extends StatelessWidget {
  const MyLfgMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(LfgStrings.tabMine, style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
      ),
      body: MyLfgMatchesView(onChanged: () {}),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const _Message({required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 60, color: AppColors.cardBorder),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          ?action,
        ],
      ),
    );
  }
}

class _LocationSheet extends StatefulWidget {
  final String city;
  final String? district;

  const _LocationSheet({required this.city, required this.district});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  late String _city = widget.city;
  List<String> _districts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final districts = await AppRepositories.lfgFacility.getDistricts(_city);
    if (mounted) setState(() => _districts = districts);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(LfgStrings.chooseCity, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in VietnamCities.all)
                  _chip(
                    label: c.name,
                    selected: c.name == _city,
                    onTap: () {
                      setState(() {
                        _city = c.name;
                        _districts = [];
                      });
                      _load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(LfgStrings.chooseDistrict, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ListTile(
              title: const Text(LfgStrings.allDistricts),
              trailing: _city == widget.city && widget.district == null
                  ? const Icon(Icons.check, color: AppColors.primaryGreen)
                  : null,
              onTap: () => Navigator.pop(context, (city: _city, district: null)),
            ),
            for (final d in _districts)
              ListTile(
                title: Text(d),
                trailing: _city == widget.city && widget.district == d
                    ? const Icon(Icons.check, color: AppColors.primaryGreen)
                    : null,
                onTap: () => Navigator.pop(context, (city: _city, district: d)),
              ),
          ],
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
