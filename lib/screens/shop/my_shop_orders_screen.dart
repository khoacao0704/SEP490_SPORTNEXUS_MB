import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings/player_shop_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_shop_repository.dart';
import '../../models/owner_shop.dart';
import '../../theme/app_colors.dart';
import '../facility/facility_search_screen.dart';

/// Đơn mua tại sân của tôi (MyShopOrders của Web): tự tải lại mỗi 30 giây, hủy được khi đơn còn "Chờ chuẩn bị".
class MyShopOrdersScreen extends StatefulWidget {
  /// Tắt tự tải lại (test).
  final bool autoRefresh;

  const MyShopOrdersScreen({super.key, this.autoRefresh = true});

  @override
  State<MyShopOrdersScreen> createState() => _MyShopOrdersScreenState();
}

class _MyShopOrdersScreenState extends State<MyShopOrdersScreen> {
  static const Duration refreshEvery = Duration(seconds: 30);

  List<ShopOrder>? _orders;
  bool _failed = false;
  String? _cancellingId;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autoRefresh) _timer = Timer.periodic(refreshEvery, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _failed = false);
    try {
      final list = await AppRepositories.playerShop.getMyOrders();
      if (mounted) setState(() => _orders = list);
    } catch (_) {
      if (mounted && !quiet) setState(() => _failed = true);
    }
  }

  Future<void> _cancel(ShopOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(PlayerShopStrings.cancelConfirm(o.quantity, o.productName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(PlayerShopStrings.keep)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(PlayerShopStrings.cancel),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancellingId = o.id);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await AppRepositories.playerShop.cancelOrder(o.id);
      messenger.showSnackBar(const SnackBar(content: Text(PlayerShopStrings.cancelled)));
    } on PlayerShopException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(PlayerShopStrings.cancelError), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _cancellingId = null);
    await _load();
  }

  static ({Color bg, Color fg}) _colors(ShopOrderStatus s) => switch (s) {
        ShopOrderStatus.pending => (bg: AppColors.tagOrangeBg, fg: AppColors.tagOrangeText),
        ShopOrderStatus.ready => (bg: const Color(0xFFE0F2FE), fg: const Color(0xFF0369A1)),
        ShopOrderStatus.pickedUp => (bg: AppColors.tagGreenBg, fg: AppColors.tagGreenText),
        ShopOrderStatus.cancelled => (bg: AppColors.divider, fg: AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(PlayerShopStrings.ordersTitle,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final orders = _orders;
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(PlayerShopStrings.loadError, style: TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text(PlayerShopStrings.retry)),
          ],
        ),
      );
    }
    if (orders == null) return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(PlayerShopStrings.ordersSubtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 56, color: AppColors.cardBorder),
                  const SizedBox(height: 12),
                  const Text(PlayerShopStrings.ordersEmpty, style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(PlayerShopStrings.ordersEmptyHint,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilitySearchScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                    child: const Text(PlayerShopStrings.findCourt),
                  ),
                ],
              ),
            )
          else
            for (final o in orders) _buildOrder(o),
        ],
      ),
    );
  }

  Widget _buildOrder(ShopOrder o) {
    final colors = _colors(o.status);
    final meta = [
      ?o.facilityName,
      Formatters.dateTime(o.createdAt),
      ?o.note,
    ].join(' · ');
    return Container(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('${o.quantity} × ${o.productName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Text(Formatters.vnd(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Text(meta, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Text(o.status.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.fg)),
                ),
              ),
              const Spacer(),
              if (o.status == ShopOrderStatus.pending)
                TextButton(
                  onPressed: _cancellingId == null ? () => _cancel(o) : null,
                  style: TextButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                  child: const Text(PlayerShopStrings.cancel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
