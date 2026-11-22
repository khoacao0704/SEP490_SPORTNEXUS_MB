import 'package:flutter/material.dart';
import '../../core/strings/voucher_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/voucher_repository.dart';
import '../../models/voucher.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/system_bottom_inset.dart';

/// "Voucher của tôi": mã giảm giá chia theo trạng thái, mỗi tab gọi BE với trạng thái đó. Chỉ xem.
class MyVouchersScreen extends StatelessWidget {
  final VoucherRepository? repository;

  const MyVouchersScreen({super.key, this.repository});

  static const _tabs = [
    (status: VoucherStatus.active, label: VoucherStrings.tabActive, empty: VoucherStrings.emptyActive),
    (status: VoucherStatus.used, label: VoucherStrings.tabUsed, empty: VoucherStrings.emptyUsed),
    (status: VoucherStatus.expired, label: VoucherStrings.tabExpired, empty: VoucherStrings.emptyExpired),
  ];

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AppRepositories.voucher;
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: const Text(VoucherStrings.title, style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryGreen,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: [for (final t in _tabs) Tab(text: t.label)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final t in _tabs) _VoucherList(repository: repo, status: t.status, emptyText: t.empty),
          ],
        ),
      ),
    );
  }
}

class _VoucherList extends StatefulWidget {
  final VoucherRepository repository;
  final VoucherStatus status;
  final String emptyText;

  const _VoucherList({required this.repository, required this.status, required this.emptyText});

  @override
  State<_VoucherList> createState() => _VoucherListState();
}

class _VoucherListState extends State<_VoucherList> with AutomaticKeepAliveClientMixin {
  List<Voucher> _vouchers = const [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.getMyVouchers(status: widget.status);
      if (!mounted) return;
      setState(() {
        _vouchers = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = VoucherStrings.loadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading && _vouchers.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              TextButton(onPressed: _load, child: const Text(VoucherStrings.retry)),
            ],
          ),
        ),
      );
    }
    if (_vouchers.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.confirmation_number_outlined, size: 64, color: AppColors.cardBorder),
            const SizedBox(height: 12),
            Text(widget.emptyText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, kScrollEndGap),
        itemCount: _vouchers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _VoucherCard(voucher: _vouchers[i]),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final Voucher voucher;

  const _VoucherCard({required this.voucher});

  static String _date(DateTime d) => '${Formatters.dayMonth(d)}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final active = voucher.status == VoucherStatus.active;
    final accent = active ? AppColors.primaryGreen : AppColors.textSecondary;
    final badge = switch (voucher.status) {
      VoucherStatus.active => null,
      VoucherStatus.used => VoucherStrings.statusUsed,
      VoucherStatus.expired => VoucherStrings.statusExpired,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.primaryGreen.withValues(alpha: 0.4) : AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.confirmation_number_outlined, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        VoucherStrings.discount(voucher.discountPercent),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: active ? AppColors.textMain : AppColors.textSecondary),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                        child: Text(badge, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ),
                    ],
                  ],
                ),
                if (voucher.sourceBookingId != null) ...[
                  const SizedBox(height: 4),
                  const Text(VoucherStrings.compensation, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text(
                      VoucherStrings.expiresOn(_date(voucher.expiresAt)),
                      style: TextStyle(fontSize: 12, color: active ? AppColors.tagOrangeText : AppColors.textSecondary),
                    ),
                    Text(VoucherStrings.receivedOn(_date(voucher.createdAt)), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
