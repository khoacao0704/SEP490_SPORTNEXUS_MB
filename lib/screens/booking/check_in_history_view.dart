import 'package:flutter/material.dart';

import '../../core/strings/player_shop_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/check_in_record.dart';
import '../../theme/app_colors.dart';

/// Tab "Lịch sử check-in" (như tab Lịch sử Check-in ở trang Check-in QR của Web): mới nhất trước,
/// 20 lượt một trang, kéo xuống cuối thì tải thêm.
class CheckInHistoryView extends StatefulWidget {
  final int revision;

  const CheckInHistoryView({super.key, this.revision = 0});

  @override
  State<CheckInHistoryView> createState() => _CheckInHistoryViewState();
}

class _CheckInHistoryViewState extends State<CheckInHistoryView> {
  final List<CheckInRecord> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  bool _failed = false;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(CheckInHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _total = 0;
      _page = 0;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await AppRepositories.checkInHistory.getHistory(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(page.items);
        // Trang rỗng: coi như hết (tránh gọi mãi khi totalItems của BE lệch).
        _total = page.items.isEmpty ? _items.length : page.totalItems;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 && _hasMore && !_loading && !_failed) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_items.isEmpty && _failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(PlayerShopStrings.historyError, style: TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _reload, child: const Text(PlayerShopStrings.retry)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.how_to_reg_outlined, size: 56, color: AppColors.cardBorder),
                    SizedBox(height: 12),
                    Text(PlayerShopStrings.historyEmpty, style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(PlayerShopStrings.historyEmptyHint,
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              )
            else ...[
              Text(PlayerShopStrings.historyCount(_total),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              for (final r in _items) _buildRecord(r),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                )
              else if (_failed)
                Center(child: TextButton(onPressed: _loadMore, child: const Text(PlayerShopStrings.retry))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecord(CheckInRecord r) {
    final location = [?r.facilityName, ?r.courtName].join(' · ');
    final detail = r.type == CheckInTicketType.tournament
        ? r.tournamentName ?? PlayerShopStrings.tournamentFallback
        : r.start != null && r.end != null
            ? PlayerShopStrings.slot(Formatters.time(r.start!), Formatters.time(r.end!))
            : null;
    final isBooking = r.type == CheckInTicketType.booking;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isBooking ? const Color(0xFFE0F7FA) : AppColors.lightGreen,
            child: Icon(Icons.qr_code_2, size: 18, color: isBooking ? const Color(0xFF00838F) : AppColors.primaryGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Formatters.dateTime(r.checkedInAt),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                Text(location.isEmpty ? '—' : location, style: const TextStyle(fontSize: 13)),
                Text(
                  [r.sportName ?? '—', ?detail].join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(r.type?.label ?? r.rawType, AppColors.lightGreen, AppColors.primaryGreen),
                    if (r.isLate) _chip(PlayerShopStrings.late, const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
      );
}
