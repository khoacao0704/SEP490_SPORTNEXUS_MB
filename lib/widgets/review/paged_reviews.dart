import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../models/review.dart';
import '../../theme/app_colors.dart';

/// Danh sách đánh giá cơ sở có phân trang: kéo để tải lại, cuộn tới cuối thì tải trang sau.
/// Đổi [key] để tải lại từ đầu (vd. khi đổi bộ lọc).
class PagedReviews extends StatefulWidget {
  final Future<FacilityReviewPage> Function(int page) fetch;
  final Widget Function(FacilityReviewItem review) itemBuilder;
  final Widget? header;
  final String emptyText;

  const PagedReviews({super.key, required this.fetch, required this.itemBuilder, required this.emptyText, this.header});

  @override
  State<PagedReviews> createState() => _PagedReviewsState();
}

class _PagedReviewsState extends State<PagedReviews> {
  final ScrollController _scroll = ScrollController();
  List<FacilityReviewItem> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await widget.fetch(1);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _page = 1;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ReviewStrings.loadError;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await widget.fetch(_page + 1);
      if (!mounted) return;
      final known = _items.map((r) => r.id).toSet();
      setState(() {
        _items = [..._items, ...page.items.where((r) => !known.contains(r.id))];
        _page++;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      // Cuộn tới cuối lần nữa sẽ thử lại.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_isLoading) {
      content = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    } else if (_error != null) {
      content = Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text(ReviewStrings.retry)),
          ],
        ),
      );
    } else if (_items.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(40),
        child: Text(widget.emptyText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
      );
    } else {
      content = Container(
        color: AppColors.white,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.divider),
              widget.itemBuilder(_items[i]),
            ],
            if (_hasMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [?widget.header, content],
      ),
    );
  }
}
