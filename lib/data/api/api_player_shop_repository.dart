import '../../models/check_in_record.dart';
import '../../models/owner_shop.dart';
import '../repositories/player_shop_repository.dart';
import 'api_client.dart';

/// [PlayerShopRepository] + [CheckInHistoryRepository] gọi Backend thật (cùng API Web dùng):
/// - GET /shop/facilities/{id}/products → mảng hoặc {items}; chỉ giữ sản phẩm đang bán.
/// - POST /shop/orders {productId, quantity, note}; GET /shop/orders/me; POST /shop/orders/{id}/cancel.
/// - GET /checkin/history?page&pageSize → {items, totalItems}.
///
/// BE không gắn đơn shop với đơn đặt sân: app chỉ mở shop cho người có đơn ở cơ sở đó, chưa check-in
/// ([Booking.allowsShopAt]).
class ApiPlayerShopRepository implements PlayerShopRepository, CheckInHistoryRepository {
  static String productsPath(String facilityId) => '/api/v1/shop/facilities/$facilityId/products';
  static const String ordersPath = '/api/v1/shop/orders';
  static const String myOrdersPath = '/api/v1/shop/orders/me';
  static String cancelPath(String orderId) => '/api/v1/shop/orders/$orderId/cancel';
  static const String historyPath = '/api/v1/checkin/history';

  final ApiClient _api;

  ApiPlayerShopRepository({required this._api});

  @override
  Future<List<ShopProduct>> getProducts(String facilityId) async {
    final data = await _call(() => _api.get(productsPath(facilityId)));
    return [for (final p in _list(data)) ShopProduct.fromJson(p)].where((p) => p.isActive).toList();
  }

  @override
  Future<void> order({required String productId, required int quantity, String note = ''}) {
    final text = note.trim();
    return _call(
      () => _api.post(
        ordersPath,
        body: {'productId': productId, 'quantity': quantity, 'note': text.isEmpty ? null : text},
      ),
    );
  }

  @override
  Future<List<ShopOrder>> getMyOrders() async {
    final data = await _call(() => _api.get(myOrdersPath, query: const {'page': 1, 'pageSize': 100}));
    return [for (final o in _list(data)) ShopOrder.fromJson(o)]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> cancelOrder(String orderId) => _call(() => _api.post(cancelPath(orderId)));

  @override
  Future<CheckInHistoryPage> getHistory({int page = 1}) async {
    final data = await _call(
      () => _api.get(historyPath, query: {'page': page, 'pageSize': CheckInHistoryRepository.pageSize}),
    );
    final items = [for (final r in _list(data)) CheckInRecord.fromJson(r)];
    final total = data is Map ? (data['totalItems'] as num?)?.toInt() : null;
    return CheckInHistoryPage(items: items, totalItems: total ?? items.length);
  }

  static List<Map<String, dynamic>> _list(Object? data) {
    final list = data is Map ? data['items'] : data;
    return list is List
        ? [
            for (final e in list)
              if (e is Map) Map<String, dynamic>.from(e),
          ]
        : const [];
  }

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw PlayerShopException.fromApi(e);
    }
  }
}
