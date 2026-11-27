import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/player_shop_strings.dart';
import '../../models/check_in_record.dart';
import '../../models/owner_shop.dart';
import '../repositories/player_shop_repository.dart';
import 'mock_facility_data.dart';

/// Bản giả lập shop tại sân phía người chơi + lịch sử check-in.
/// Sản phẩm mẫu cho vài cơ sở; đơn và tồn kho đã bán lưu trong máy. Lịch sử check-in là [historyCount] lượt mẫu.
class MockPlayerShopRepository implements PlayerShopRepository, CheckInHistoryRepository {
  static const String keyOrders = 'player_shop_orders_v1';

  final Duration latency;
  final DateTime Function() _now;

  /// Số lượt check-in mẫu (đủ để thử tải thêm trang 2).
  final int historyCount;

  MockPlayerShopRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    this.historyCount = 26,
  }) : _now = now ?? DateTime.now;

  static const List<ShopProduct> products = [
    ShopProduct(
      id: 'p-tt-1',
      facilityId: 'f-hcm-thientrieu',
      name: 'Nước suối Aquafina 500ml',
      price: 10000,
      stock: 40,
    ),
    ShopProduct(
      id: 'p-tt-2',
      facilityId: 'f-hcm-thientrieu',
      name: 'Ống cầu lông Thành Công (12 quả)',
      description: 'Cầu lông thi đấu',
      price: 220000,
      stock: 6,
    ),
    ShopProduct(id: 'p-tt-3', facilityId: 'f-hcm-thientrieu', name: 'Quấn cán vợt', price: 25000, stock: 0),
    ShopProduct(id: 'p-hl-1', facilityId: 'f-hcm-hoalu', name: 'Revive chanh muối', price: 15000, stock: 60),
    ShopProduct(id: 'p-hl-2', facilityId: 'f-hcm-hoalu', name: 'Thuê áo bib (bộ 7 cái)', price: 50000, stock: 4),
  ];

  @override
  Future<List<ShopProduct>> getProducts(String facilityId) async {
    await _delay();
    final orders = await _load();
    return [
      for (final p in products)
        if (p.facilityId == facilityId) _withStock(p, orders),
    ];
  }

  /// Tồn kho trừ các đơn chưa hủy.
  static ShopProduct _withStock(ShopProduct p, List<ShopOrder> orders) {
    final sold = orders
        .where((o) => o.productId == p.id && o.status != ShopOrderStatus.cancelled)
        .fold(0, (sum, o) => sum + o.quantity);
    return ShopProduct(
      id: p.id,
      facilityId: p.facilityId,
      name: p.name,
      description: p.description,
      price: p.price,
      stock: (p.stock - sold).clamp(0, p.stock),
      imageUrl: p.imageUrl,
    );
  }

  @override
  Future<void> order({required String productId, required int quantity, String note = ''}) async {
    await _delay();
    final orders = await _load();
    final base = products.where((p) => p.id == productId).firstOrNull;
    if (base == null) throw const PlayerShopException(PlayerShopStrings.productNotFound);
    final product = _withStock(base, orders);
    if (quantity < 1 || quantity > product.stock || quantity > PlayerShopRepository.maxQuantity) {
      throw PlayerShopException(PlayerShopStrings.quantityRange(product.stock));
    }
    final facility = MockFacilityData.facilities.where((f) => f.id == product.facilityId).firstOrNull;
    final text = note.trim();
    orders.insert(
      0,
      ShopOrder(
        id: 'so-${_now().microsecondsSinceEpoch}',
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        totalAmount: quantity * product.price,
        status: ShopOrderStatus.pending,
        createdAt: _now(),
        note: text.isEmpty ? null : text,
        facilityName: facility?.name,
      ),
    );
    await _save(orders);
  }

  @override
  Future<List<ShopOrder>> getMyOrders() async {
    await _delay();
    return _load();
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    await _delay();
    final orders = await _load();
    final i = orders.indexWhere((o) => o.id == orderId);
    if (i < 0 || orders[i].status != ShopOrderStatus.pending) {
      throw const PlayerShopException(PlayerShopStrings.cannotCancel);
    }
    orders[i] = orders[i].copyWith(status: ShopOrderStatus.cancelled);
    await _save(orders);
  }

  @override
  Future<CheckInHistoryPage> getHistory({int page = 1}) async {
    await _delay();
    final now = _now();
    const facilities = [('Sân Cầu Lông Thiên Triều', 'Sân 2', 'Cầu Lông'), ('Sân Bóng Hoa Lư', 'Sân 1', 'Bóng Đá')];
    final all = [
      for (var i = 0; i < historyCount; i++)
        () {
          final (facility, court, sport) = facilities[i % facilities.length];
          final type = CheckInTicketType.values[i % 3];
          final start = DateTime(now.year, now.month, now.day - i - 1, 18);
          return CheckInRecord(
            id: 'ci-$i',
            type: type,
            rawType: type.apiValue,
            checkedInAt: start.add(Duration(minutes: i % 4 == 0 ? 20 : -5)),
            facilityName: facility,
            courtName: court,
            sportName: sport,
            start: start,
            end: start.add(const Duration(hours: 1)),
            tournamentName: type == CheckInTicketType.tournament ? 'Giải Cầu Lông Mùa Đông' : null,
            isLate: i % 4 == 0,
          );
        }(),
    ];
    final from = (page - 1) * CheckInHistoryRepository.pageSize;
    final items = from >= all.length
        ? <CheckInRecord>[]
        : all.skip(from).take(CheckInHistoryRepository.pageSize).toList();
    return CheckInHistoryPage(items: items, totalItems: all.length);
  }

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<List<ShopOrder>> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(keyOrders);
    if (raw == null) return [];
    return [for (final e in jsonDecode(raw) as List) ShopOrder.fromJson(Map<String, dynamic>.from(e as Map))];
  }

  Future<void> _save(List<ShopOrder> orders) async =>
      (await SharedPreferences.getInstance()).setString(keyOrders, jsonEncode([for (final o in orders) o.toJson()]));
}
