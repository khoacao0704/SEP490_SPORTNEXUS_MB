import 'package:flutter/material.dart';

import '../../core/strings/rating_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/rating_repository.dart';
import '../../models/sport.dart';
import '../../models/sport_rating.dart';
import '../../theme/app_colors.dart';
import '../../widgets/rating/rank_badge.dart';

/// Bảng xếp hạng Elo theo môn, cá nhân hoặc đội; kéo xuống cuối thì tải trang tiếp.
class LeaderboardScreen extends StatefulWidget {
  final Sport initialSport;
  final RatingType initialType;

  /// Đánh dấu dòng của mình / đội mình.
  final Set<String> highlightIds;

  const LeaderboardScreen({
    super.key,
    this.initialSport = Sport.badminton,
    this.initialType = RatingType.personal,
    this.highlightIds = const {},
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Sport _sport = widget.initialSport;
  late RatingType _type = widget.initialType;
  final List<(int, SportRating)> _rows = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  /// Lượt tải hiện tại: đổi môn / loại thì bỏ kết quả của lượt cũ.
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _seq++;
    setState(() {
      _rows.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final seq = _seq;
    setState(() => _loading = true);
    try {
      final page = await AppRepositories.rating.getLeaderboard(_sport, type: _type, page: _page + 1);
      if (!mounted || seq != _seq) return;
      setState(() {
        _page = page.page;
        _hasMore = page.hasMore;
        for (var i = 0; i < page.items.length; i++) {
          _rows.add((page.positionOf(i), page.items[i]));
        }
        _loading = false;
      });
    } on RatingException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _hasMore = false;
      });
    }
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
          RatingStrings.leaderboardTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in Sport.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(s.label),
                            selected: _sport == s,
                            onSelected: (_) {
                              if (_sport == s) return;
                              _sport = s;
                              _reload();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SegmentedButton<RatingType>(
                  segments: [for (final t in RatingType.values) ButtonSegment(value: t, label: Text(t.label))],
                  selected: {_type},
                  onSelectionChanged: (v) {
                    _type = v.first;
                    _reload();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _list() {
    if (_rows.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? RatingStrings.emptyLeaderboard, textAlign: TextAlign.center),
              if (_error != null) TextButton(onPressed: _reload, child: const Text(RatingStrings.retry)),
            ],
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
        itemBuilder: (context, i) {
          if (i >= _rows.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: Text(RatingStrings.loadMore, style: TextStyle(color: AppColors.textSecondary))),
            );
          }
          final (position, row) = _rows[i];
          final mine = widget.highlightIds.contains(row.ownerId);
          // Hàng tự cao theo nội dung (ListTile cao cố định nên tràn khi chữ to).
          return Container(
            color: mine ? AppColors.lightGreen : AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    '#$position',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: position <= 3 ? AppColors.tagOrangeText : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine ? '${row.ownerName} ${RatingStrings.you}' : row.ownerName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        RatingStrings.ratedMatches(row.ratedMatches),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${row.rating}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    RankBadge(rank: row.rankLabel),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
