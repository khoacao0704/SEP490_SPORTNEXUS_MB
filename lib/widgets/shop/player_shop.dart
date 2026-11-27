import 'package:flutter/material.dart';

import '../../core/strings/player_shop_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_shop_repository.dart';
import '../../models/owner_shop.dart';
import '../../screens/shop/my_shop_orders_screen.dart';
import '../../theme/app_colors.dart';
import '../owner/photo_picker.dart' show OwnerImage;

/// Người dùng có đơn đặt sân ở cơ sở này, chưa check-in (luật app: shop chỉ mở cho người đã đặt sân trên app).
Future<bool> canUseShopAt(String facilityId, String facilityName) async {
  final now = DateTime.now();
  final bookings = await AppRepositories.booking.getMyBookings();
  return bookings.any((b) => b.allowsShopAt(facilityId: facilityId, facilityName: facilityName, now: now));
}

/// Mục "Shop tại sân" ở chi tiết sân (như Web). Ẩn khi người dùng chưa có đơn ở cơ sở này / đã check-in,
/// khi cơ sở không có sản phẩm đang bán, hoặc khi tải lỗi.
class FacilityShopSection extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const FacilityShopSection({super.key, required this.facilityId, required this.facilityName});

  @override
  State<FacilityShopSection> createState() => _FacilityShopSectionState();
}

class _FacilityShopSectionState extends State<FacilityShopSection> {
  List<ShopProduct>? _products;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!await canUseShopAt(widget.facilityId, widget.facilityName)) return;
      final products = await AppRepositories.playerShop.getProducts(widget.facilityId);
      if (mounted) setState(() => _products = products);
    } catch (_) {
      // Lỗi thì ẩn mục shop (như Web).
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    if (products == null || products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text(PlayerShopStrings.sectionTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                TextButton(
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyShopOrdersScreen())),
                  child: const Text(PlayerShopStrings.myOrders),
                ),
              ],
            ),
            const Text(PlayerShopStrings.sectionNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            ShopProductList(products: products, onOrdered: _load),
          ],
        ),
      ),
    );
  }
}

/// Danh sách sản phẩm đang bán: ảnh, tên, giá, mô tả, nút Đặt / nhãn Hết hàng.
class ShopProductList extends StatelessWidget {
  final List<ShopProduct> products;
  final VoidCallback onOrdered;

  const ShopProductList({super.key, required this.products, required this.onOrdered});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in products)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: p.imageUrl == null
                      ? Container(
                          width: 48,
                          height: 48,
                          color: AppColors.lightGreen,
                          child: const Icon(Icons.storefront_outlined, color: AppColors.primaryGreen),
                        )
                      : OwnerImage(p.imageUrl!, width: 48, height: 48),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${Formatters.vnd(p.price)}${p.description == null ? '' : ' · ${p.description}'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (p.stock > 0)
                  OutlinedButton(
                    onPressed: () async {
                      if (await showShopOrderSheet(context, p) == true) onOrdered();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(PlayerShopStrings.order),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(10)),
                    child: const Text(PlayerShopStrings.outOfStock,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Form đặt trước một sản phẩm (OrderModal của Web). Trả `true` khi đã đặt.
Future<bool?> showShopOrderSheet(BuildContext context, ShopProduct product) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _OrderSheet(product: product),
    );

class _OrderSheet extends StatefulWidget {
  final ShopProduct product;

  const _OrderSheet({required this.product});

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  final _note = TextEditingController();
  int _quantity = 1;
  bool _busy = false;

  int get _max => widget.product.stock.clamp(0, PlayerShopRepository.maxQuantity);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await AppRepositories.playerShop.order(productId: widget.product.id, quantity: _quantity, note: _note.text);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(PlayerShopStrings.ordered(_quantity, widget.product.name)),
          backgroundColor: AppColors.primaryGreen,
        ));
      navigator.pop(true);
      return;
    } on PlayerShopException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(PlayerShopStrings.orderError), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(PlayerShopStrings.orderTitle(p.name), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(PlayerShopStrings.orderSubtitle(p.price, p.stock),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              const Text(PlayerShopStrings.quantity, style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _quantity > 1 ? () => setState(() => _quantity = (_quantity - 1).clamp(1, _max)) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton.outlined(
                    // Bấm nhanh nhiều lần trước khi nút kịp khóa cũng không vượt tồn kho / 50.
                    onPressed: _quantity < _max ? () => setState(() => _quantity = (_quantity + 1).clamp(1, _max)) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLength: PlayerShopRepository.maxNote,
                decoration: InputDecoration(
                  labelText: PlayerShopStrings.note,
                  hintText: PlayerShopStrings.noteHint,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Text(PlayerShopStrings.subtotal(_quantity * p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context, false),
                      child: const Text(PlayerShopStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy || _max < 1 ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                      child: Text(_busy ? PlayerShopStrings.submitting : PlayerShopStrings.submit),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shop của một cơ sở, mở từ thẻ đơn sắp tới trong "Đơn của tôi" (nút "Đặt đồ tại sân").
class FacilityShopScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const FacilityShopScreen({super.key, required this.facilityId, required this.facilityName});

  @override
  State<FacilityShopScreen> createState() => _FacilityShopScreenState();
}

class _FacilityShopScreenState extends State<FacilityShopScreen> {
  List<ShopProduct>? _products;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final list = await AppRepositories.playerShop.getProducts(widget.facilityId);
      if (mounted) setState(() => _products = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(PlayerShopStrings.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 17)),
            Text(widget.facilityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: PlayerShopStrings.myOrders,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyShopOrdersScreen())),
          ),
        ],
      ),
      body: _failed
          ? Center(
              child: TextButton(onPressed: _load, child: const Text(PlayerShopStrings.retry)),
            )
          : products == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(PlayerShopStrings.sectionNote,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    if (products.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(PlayerShopStrings.shopEmpty, style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      ShopProductList(products: products, onOrdered: _load),
                  ],
                ),
    );
  }
}
