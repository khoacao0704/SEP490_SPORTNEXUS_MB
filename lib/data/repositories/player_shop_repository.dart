import '../../models/check_in_record.dart';
import '../../models/owner_shop.dart';
import '../api/api_error_codes.dart';

/// Lỗi shop / lịch sử check-in phía người chơi; [message] sẵn sàng để hiển thị (câu của BE khi gọi API thật).
class PlayerShopException implements Exception, CodedError {
  @override
  final String message;

  @override
  final String? code;

  @override
  final Map<String, dynamic>? detail;

  const PlayerShopException(this.message, {this.code, this.detail});

  PlayerShopException.fromApi(CodedError e) : this(e.message, code: e.code, detail: e.detail);

  @override
  String toString() => 'PlayerShopException: $message';
}

/// Shop tại sân phía người chơi (như Web: đặt trước, nhận hàng và trả tiền tại quầy, không trừ ví).
abstract class PlayerShopRepository {
  /// Như Web: tối đa 50 mỗi đơn (và không quá tồn kho).
  static const int maxQuantity = 50;
  static const int maxNote = 300;

  /// Sản phẩm đang bán của cơ sở.
  Future<List<ShopProduct>> getProducts(String facilityId);

  Future<void> order({required String productId, required int quantity, String note = ''});

  /// Đơn mua tại sân của tôi, mới nhất trước.
  Future<List<ShopOrder>> getMyOrders();

  /// Hủy đơn còn "Chờ chuẩn bị".
  Future<void> cancelOrder(String orderId);
}

/// Lịch sử check-in của tôi (vé đặt sân, kèo LFG, giải đấu), mới nhất trước.
abstract class CheckInHistoryRepository {
  static const int pageSize = 20;

  /// [page] bắt đầu từ 1.
  Future<CheckInHistoryPage> getHistory({int page = 1});
}
