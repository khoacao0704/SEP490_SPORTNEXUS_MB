int _int(Object? v) => (v as num?)?.round() ?? 0;
String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// Sản phẩm bán tại quầy của cơ sở (GET /shop/facilities/{id}/products).
class ShopProduct {
  final String id;
  final String facilityId;
  final String name;
  final String? description;
  final int price;
  final int stock;
  final String? imageUrl;
  final bool isActive;

  const ShopProduct({
    required this.id,
    required this.facilityId,
    required this.name,
    required this.price,
    required this.stock,
    this.description,
    this.imageUrl,
    this.isActive = true,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> j) => ShopProduct(
        id: '${j['id'] ?? ''}',
        facilityId: '${j['facilityId'] ?? ''}',
        name: _str(j['name']) ?? '',
        description: _str(j['description']),
        price: _int(j['price']),
        stock: _int(j['stock']),
        imageUrl: _str(j['imageUrl']),
        isActive: j['isActive'] != false,
      );
}

/// UpsertProductRequest: name, description, price, stock, imageUrl, isActive.
class ShopProductInput {
  final String name;
  final String? description;
  final int price;
  final int stock;
  final String? imageUrl;
  final bool isActive;

  const ShopProductInput({
    required this.name,
    required this.price,
    required this.stock,
    this.description,
    this.imageUrl,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
        'price': price,
        'stock': stock,
        'imageUrl': imageUrl,
        'isActive': isActive,
      };
}

/// Trạng thái đơn shop (SHOP_ORDER_STATUS của Web): PENDING → READY → PICKED_UP, hoặc CANCELLED.
enum ShopOrderStatus {
  pending('PENDING', 'Chờ chuẩn bị'),
  ready('READY', 'Sẵn sàng lấy'),
  pickedUp('PICKED_UP', 'Đã nhận hàng'),
  cancelled('CANCELLED', 'Đã hủy');

  const ShopOrderStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Bước tiếp theo và nhãn nút (NEXT_STATUS của Web).
  (ShopOrderStatus, String)? get next => switch (this) {
        pending => (ready, 'Báo đã chuẩn bị xong'),
        ready => (pickedUp, 'Khách đã nhận & trả tiền'),
        _ => null,
      };

  bool get canCancel => this == pending || this == ready;

  static ShopOrderStatus fromApi(Object? v) {
    final key = '${v ?? ''}'.replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}').toUpperCase();
    return values.firstWhere((s) => s.apiValue == key, orElse: () => pending);
  }
}

/// Đơn khách đặt trước tại cơ sở; trả tiền tại quầy, không qua ví.
class ShopOrder {
  final String id;
  final String productId;
  final String productName;
  final String? customerName;
  final String? customerPhone;
  final int quantity;
  final int totalAmount;
  final ShopOrderStatus status;
  final String? note;
  final DateTime createdAt;

  const ShopOrder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.note,
  });

  ShopOrder copyWith({ShopOrderStatus? status}) => ShopOrder(
        id: id,
        productId: productId,
        productName: productName,
        quantity: quantity,
        totalAmount: totalAmount,
        status: status ?? this.status,
        createdAt: createdAt,
        customerName: customerName,
        customerPhone: customerPhone,
        note: note,
      );

  factory ShopOrder.fromJson(Map<String, dynamic> j) => ShopOrder(
        id: '${j['id'] ?? ''}',
        productId: '${j['productId'] ?? ''}',
        productName: _str(j['productName']) ?? '',
        customerName: _str(j['customerName']),
        customerPhone: _str(j['customerPhone']),
        quantity: _int(j['quantity']),
        totalAmount: _int(j['totalAmount']),
        status: ShopOrderStatus.fromApi(j['status']),
        note: _str(j['note']),
        createdAt: DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
      );
}
