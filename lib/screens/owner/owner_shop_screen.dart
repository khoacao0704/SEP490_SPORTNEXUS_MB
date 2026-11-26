import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings/owner_shop_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/facility.dart';
import '../../models/owner_shop.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart' show ownerErrorMessage;
import '../../widgets/owner/photo_picker.dart';
import '../../widgets/owner/slot_pickers.dart' show confirmOwner, showOwnerSnack;

BadgeTone _tone(ShopOrderStatus s) => switch (s) {
      ShopOrderStatus.pending => BadgeTone.amber,
      ShopOrderStatus.ready => BadgeTone.blue,
      ShopOrderStatus.pickedUp => BadgeTone.green,
      ShopOrderStatus.cancelled => BadgeTone.gray,
    };

enum _Tab { orders, products }

/// Shop tại sân (như Web: OwnerShop.jsx): đơn của khách (chuẩn bị → khách nhận & trả tiền, hủy) và sản phẩm
/// (thêm / sửa / xóa, ảnh, tồn kho, ẩn). Trả tiền tại quầy, không qua ví. Đơn tự tải lại mỗi 30 giây.
class OwnerShopScreen extends StatefulWidget {
  /// Cơ sở mở sẵn (vd. cơ sở đang chọn ở khung chính).
  final String? initialFacilityId;

  const OwnerShopScreen({super.key, this.initialFacilityId});

  @override
  State<OwnerShopScreen> createState() => _OwnerShopScreenState();
}

class _OwnerShopScreenState extends State<OwnerShopScreen> {
  List<Facility>? _facilities;
  String? _facilityId;
  _Tab _tab = _Tab.orders;
  ShopOrderStatus? _status;

  List<ShopOrder>? _orders;
  String? _ordersError;
  List<ShopProduct>? _products;
  String? _productsError;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadOrders());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final list = await AppRepositories.owner.getMyFacilities();
      if (!mounted) return;
      setState(() {
        _facilities = list;
        _facilityId = list.any((f) => f.id == widget.initialFacilityId) ? widget.initialFacilityId : list.firstOrNull?.id;
      });
      _reload();
    } catch (e) {
      if (mounted) {
        setState(() {
          _facilities = const [];
          _ordersError = ownerErrorMessage(e);
        });
      }
    }
  }

  Future<void> _reload() => Future.wait([_loadOrders(), _loadProducts()]);

  Future<void> _loadOrders() async {
    final id = _facilityId;
    if (id == null) return;
    try {
      final list = await AppRepositories.owner.getShopOrders(id, status: _status);
      if (mounted && id == _facilityId) {
        setState(() {
          _orders = list;
          _ordersError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _ordersError = ownerErrorMessage(e));
    }
  }

  Future<void> _loadProducts() async {
    final id = _facilityId;
    if (id == null) return;
    try {
      final list = await AppRepositories.owner.getShopProducts(id);
      if (mounted && id == _facilityId) {
        setState(() {
          _products = list;
          _productsError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _productsError = ownerErrorMessage(e));
    }
  }

  Future<void> _act(Future<void> Function() action, String success, Future<void> Function() after) async {
    try {
      await action();
      if (!mounted) return;
      showOwnerSnack(context, success);
      await after();
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    }
  }

  Future<void> _edit([ShopProduct? product]) async {
    final id = _facilityId;
    if (id == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductSheet(facilityId: id, product: product),
    );
    if (saved == true && mounted) {
      showOwnerSnack(context, product == null ? OwnerShopStrings.created : OwnerShopStrings.updated);
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilities = _facilities;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerShopStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      floatingActionButton: _facilityId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(OwnerShopStrings.addProduct),
            ),
      body: facilities == null
          ? const Center(child: CircularProgressIndicator())
          : facilities.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(OwnerShopStrings.noFacility, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      const Text(OwnerShopStrings.subtitle, style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      if (facilities.length > 1) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _facilityId,
                          isExpanded: true,
                          decoration: _deco(null),
                          items: [
                            for (final f in facilities)
                              DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _facilityId = v;
                              _orders = null;
                              _products = null;
                            });
                            _reload();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _tabChip(_Tab.orders, Icons.receipt_outlined, _ordersLabel()),
                          _tabChip(_Tab.products, Icons.inventory_2_outlined, OwnerShopStrings.tabProducts(_products?.length ?? 0)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_tab == _Tab.orders) ..._ordersView() else ..._productsView(),
                    ],
                  ),
                ),
    );
  }

  String _ordersLabel() {
    final pending = (_orders ?? const <ShopOrder>[]).where((o) => o.status == ShopOrderStatus.pending).length;
    return pending > 0 ? '${OwnerShopStrings.tabOrders} ($pending)' : OwnerShopStrings.tabOrders;
  }

  Widget _tabChip(_Tab t, IconData icon, String label) => ChoiceChip(
        avatar: Icon(icon, size: 18, color: _tab == t ? AppColors.darkGreen : AppColors.textSecondary),
        label: Text(label),
        selected: _tab == t,
        selectedColor: AppColors.lightGreen,
        showCheckmark: false,
        labelStyle: TextStyle(color: _tab == t ? AppColors.darkGreen : AppColors.textMain, fontWeight: FontWeight.w600),
        onSelected: (_) => setState(() => _tab = t),
      );

  List<Widget> _ordersView() {
    final orders = _orders;
    return [
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<ShopOrderStatus?>(
              initialValue: _status,
              isExpanded: true,
              decoration: _deco(OwnerShopStrings.statusLabel),
              items: [
                const DropdownMenuItem<ShopOrderStatus?>(value: null, child: Text(OwnerShopStrings.allStatus)),
                for (final s in ShopOrderStatus.values) DropdownMenuItem<ShopOrderStatus?>(value: s, child: Text(s.label)),
              ],
              onChanged: (v) {
                setState(() => _status = v);
                _loadOrders();
              },
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _loadOrders, child: const Text(OwnerShopStrings.refresh)),
        ],
      ),
      const SizedBox(height: 12),
      if (_ordersError != null) _ToneText(_ordersError!, tone: BadgeTone.red),
      if (orders == null && _ordersError == null) const _Muted(OwnerShopStrings.loading),
      if (orders != null && orders.isEmpty) const _Muted(OwnerShopStrings.noOrders),
      for (final o in orders ?? const <ShopOrder>[]) _orderCard(o),
    ];
  }

  Widget _orderCard(ShopOrder o) {
    final next = o.status.next;
    const muted = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(o.customerName ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              OwnerBadge(o.status.label, tone: _tone(o.status)),
            ],
          ),
          if (o.customerPhone != null) Text(o.customerPhone!, style: muted),
          const SizedBox(height: 6),
          Text(OwnerShopStrings.line(o.quantity, o.productName)),
          if (o.note != null) Text(OwnerShopStrings.note(o.note!), style: muted),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              const Text('${OwnerShopStrings.collect}:', style: muted),
              Text(Formatters.vnd(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Text(Formatters.dateTime(o.createdAt), style: muted),
          if (next != null || o.status.canCancel) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (o.status.canCancel)
                  TextButton(
                    onPressed: () async {
                      if (!await confirmOwner(context,
                          OwnerShopStrings.cancelConfirm(o.quantity, o.productName, o.customerName ?? '—'))) {
                        return;
                      }
                      await _act(() => AppRepositories.owner.updateShopOrderStatus(o.id, ShopOrderStatus.cancelled),
                          OwnerShopStrings.orderCancelled, _loadOrders);
                    },
                    child: const Text(OwnerShopStrings.cancelOrder),
                  ),
                if (next != null)
                  ElevatedButton(
                    onPressed: () => _act(() => AppRepositories.owner.updateShopOrderStatus(o.id, next.$1),
                        OwnerShopStrings.orderUpdated, _loadOrders),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                    child: Text(next.$2),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _productsView() {
    final products = _products;
    return [
      if (_productsError != null) _ToneText(_productsError!, tone: BadgeTone.red),
      if (products == null && _productsError == null) const _Muted(OwnerShopStrings.loading),
      if (products != null && products.isEmpty) const _Muted(OwnerShopStrings.noProducts, icon: Icons.storefront_outlined),
      for (final p in products ?? const <ShopProduct>[]) _productCard(p),
    ];
  }

  Widget _productCard(ShopProduct p) => Opacity(
        opacity: p.isActive ? 1 : 0.65,
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: OwnerImage(p.imageUrl!, width: double.infinity, height: 140),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (!p.isActive) const OwnerBadge(OwnerShopStrings.hidden, tone: BadgeTone.gray),
                ],
              ),
              if (p.description != null) Text(p.description!, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(Formatters.vnd(p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                  OwnerBadge(OwnerShopStrings.inStock(p.stock), tone: p.stock > 0 ? BadgeTone.green : BadgeTone.red),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: () => _edit(p), child: const Text(OwnerShopStrings.edit)),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () async {
                      if (!await confirmOwner(context, OwnerShopStrings.deleteConfirm(p.name))) return;
                      await _act(() => AppRepositories.owner.deleteShopProduct(p.id), OwnerShopStrings.deleted, _loadProducts);
                    },
                    child: const Text(OwnerShopStrings.delete),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

InputDecoration _deco(String? label) => InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

/// Thêm / sửa sản phẩm (ProductModal của Web).
class _ProductSheet extends StatefulWidget {
  final String facilityId;
  final ShopProduct? product;

  const _ProductSheet({required this.facilityId, this.product});

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _description = TextEditingController(text: widget.product?.description ?? '');
  late final _price = TextEditingController(text: widget.product == null ? '' : '${widget.product!.price}');
  late final _stock = TextEditingController(text: widget.product == null ? '' : '${widget.product!.stock}');
  late String? _image = widget.product?.imageUrl;
  late bool _active = widget.product?.isActive ?? true;
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final paths = await pickPhotoPaths(context, multiple: false);
    if (paths.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await AppRepositories.owner.uploadShopImage(paths.first);
      if (mounted) setState(() => _image = url);
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim());
    final stock = int.tryParse(_stock.text.trim());
    final error = _name.text.trim().isEmpty
        ? OwnerShopStrings.errName
        : (price == null || price < 0)
            ? OwnerShopStrings.errPrice
            : (stock == null || stock < 0)
                ? OwnerShopStrings.errStock
                : null;
    if (error != null) {
      showOwnerSnack(context, error, error: true);
      return;
    }
    final input = ShopProductInput(
      name: _name.text,
      description: _description.text,
      price: price!,
      stock: stock!,
      imageUrl: _image,
      isActive: _active,
    );
    setState(() => _busy = true);
    try {
      final repo = AppRepositories.owner;
      if (widget.product == null) {
        await repo.createShopProduct(widget.facilityId, input);
      } else {
        await repo.updateShopProduct(widget.product!.id, input);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showOwnerSnack(context, ownerErrorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.product == null ? OwnerShopStrings.addProduct : OwnerShopStrings.editTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                maxLength: 200,
                decoration: _deco(OwnerShopStrings.fName).copyWith(hintText: OwnerShopStrings.fNameHint),
              ),
              TextField(
                controller: _description,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: _deco(OwnerShopStrings.fDescription),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: _deco(OwnerShopStrings.fPrice),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: _deco(OwnerShopStrings.fStock),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(OwnerShopStrings.fImage, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_image != null)
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: OwnerImage(_image!, width: 72, height: 72)),
                  OutlinedButton(
                    onPressed: _uploading ? null : _pickImage,
                    child: Text(_uploading
                        ? OwnerShopStrings.uploading
                        : (_image == null ? OwnerShopStrings.uploadImage : OwnerShopStrings.changeImage)),
                  ),
                ],
              ),
              CheckboxListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primaryGreen,
                title: const Text(OwnerShopStrings.fActive),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text(OwnerShopStrings.cancel)),
                  ElevatedButton(
                    onPressed: _busy || _uploading ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                    child: Text(_busy ? OwnerShopStrings.saving : OwnerShopStrings.save),
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

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );
}

class _Muted extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _Muted(this.text, {this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            if (icon != null) Icon(icon, size: 36, color: AppColors.textSecondary),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _ToneText extends StatelessWidget {
  final String text;
  final BadgeTone tone;

  const _ToneText(this.text, {required this.tone});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: tone.foreground)),
      );
}
