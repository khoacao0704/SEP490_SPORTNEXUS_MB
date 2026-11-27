import 'package:flutter/material.dart';

import '../../core/strings/community_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/community_post.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';
import '../../widgets/community/post_card.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/main_drawer.dart';
import 'compose_post_screen.dart';

/// Bảng tin cộng đồng (trang Cộng đồng của Web): tab Bảng tin / Bài viết của tôi; Bảng tin có sắp xếp
/// Mới nhất / Nổi bật, lọc môn, tìm kiếm; bấm tên người đăng để xem bài của người đó; kéo xuống cuối để tải thêm.
class CommunityScreen extends StatefulWidget {
  /// Mở thẳng bài của một người (bấm tên người đăng).
  final String? authorId;
  final String? authorName;

  const CommunityScreen({super.key, this.authorId, this.authorName});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _mine = false;
  PostSort _sort = PostSort.newest;
  Sport? _sport;
  String _keyword = '';
  final _search = TextEditingController();

  final List<CommunityPost> _posts = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _failed = false;
  int _request = 0;

  bool get _byAuthor => widget.authorId != null;

  PostQuery get _query => PostQuery(
        sort: _sort,
        sport: _sport,
        keyword: _keyword,
        mine: _mine && !_byAuthor,
        authorId: widget.authorId,
      );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_request;
    setState(() {
      _posts.clear();
      _page = 0;
      _hasMore = false;
      _loading = true;
      _failed = false;
    });
    await _fetch(request);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    await _fetch(_request);
  }

  Future<void> _fetch(int request) async {
    try {
      final page = await AppRepositories.community.getPosts(_query, page: _page + 1);
      if (!mounted || request != _request) return;
      setState(() {
        _page++;
        _posts.addAll(page.items.where((p) => !_posts.any((x) => x.id == p.id)));
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    }
    if (mounted && request == _request) setState(() => _loading = false);
  }

  Future<void> _compose() async {
    final created = await Navigator.push<CommunityPost>(
      context,
      MaterialPageRoute(builder: (_) => const ComposePostScreen()),
    );
    if (created != null && mounted) _reload();
  }

  void _openAuthor(String id, String name) {
    if (_byAuthor || id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommunityScreen(authorId: id, authorName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _byAuthor ? null : const MainDrawer(selectedIndex: 7),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          _byAuthor ? CommunityStrings.authorPosts(widget.authorName ?? '') : CommunityStrings.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      floatingActionButton: _byAuthor
          ? null
          : FloatingActionButton.extended(
              onPressed: _compose,
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_outlined),
              label: const Text(CommunityStrings.newPost),
            ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _reload,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) _loadMore();
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              if (!_byAuthor) ..._buildFilters(),
              if (_posts.isEmpty && _loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                )
              else if (_posts.isEmpty && _failed)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      const Text(CommunityStrings.loadError, style: TextStyle(color: AppColors.textSecondary)),
                      TextButton(onPressed: _reload, child: const Text(CommunityStrings.retry)),
                    ],
                  ),
                )
              else if (_posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      const Icon(Icons.forum_outlined, size: 56, color: AppColors.cardBorder),
                      const SizedBox(height: 12),
                      Text(_mine ? CommunityStrings.emptyMine : CommunityStrings.emptyFeed,
                          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              else ...[
                for (final p in _posts)
                  PostCard(
                    key: ValueKey(p.id),
                    post: p,
                    now: now,
                    onAuthor: _byAuthor ? null : _openAuthor,
                    onChanged: (updated) => setState(() {
                      final i = _posts.indexWhere((x) => x.id == updated.id);
                      if (i >= 0) _posts[i] = updated;
                    }),
                    onRemoved: (id) => setState(() {
                      final i = _posts.indexWhere((x) => x.id == id);
                      if (i < 0) return;
                      // "Bài viết của tôi" vẫn giữ bài đã xóa (nhãn Đã xóa), như Web.
                      if (_mine) {
                        _posts[i] = _posts[i].copyWith(status: PostStatus.deleted);
                      } else {
                        _posts.removeAt(i);
                      }
                    }),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                  )
                else if (_failed)
                  Center(child: TextButton(onPressed: _loadMore, child: const Text(CommunityStrings.retry))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFilters() => [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text(CommunityStrings.tabFeed), icon: Icon(Icons.dynamic_feed)),
            ButtonSegment(value: true, label: Text(CommunityStrings.tabMine), icon: Icon(Icons.person_outline)),
          ],
          selected: {_mine},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            setState(() => _mine = s.first);
            _reload();
          },
        ),
        if (!_mine) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              setState(() => _keyword = v.trim());
              _reload();
            },
            decoration: InputDecoration(
              hintText: CommunityStrings.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _keyword.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _keyword = '');
                        _reload();
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in PostSort.values) ...[
                  _chip(s == PostSort.newest ? CommunityStrings.sortNewest : CommunityStrings.sortHot, _sort == s, () {
                    setState(() => _sort = s);
                    _reload();
                  }, icon: s == PostSort.newest ? Icons.schedule : Icons.local_fire_department_outlined),
                  const SizedBox(width: 8),
                ],
                Container(width: 1, height: 24, color: AppColors.cardBorder),
                const SizedBox(width: 8),
                _chip(CommunityStrings.allSports, _sport == null, () {
                  setState(() => _sport = null);
                  _reload();
                }),
                for (final s in Sport.values) ...[
                  const SizedBox(width: 8),
                  _chip(s.label, _sport == s, () {
                    setState(() => _sport = s);
                    _reload();
                  }, icon: sportIcon(s)),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
      ];

  static Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) => ChoiceChip(
        showCheckmark: false,
        avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primaryGreen),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryGreen,
        backgroundColor: AppColors.white,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textMain),
        side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
}
