int _int(Object? v) => (v as num?)?.round() ?? 0;
String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// Gói đẩy tin đang bán (GET /promotions/packages?targetType=FACILITY).
class PromotionPackage {
  final String id;
  final String name;
  final String? description;
  final String targetType;
  final int durationDays;
  final int price;

  const PromotionPackage({
    required this.id,
    required this.name,
    required this.targetType,
    required this.durationDays,
    required this.price,
    this.description,
  });

  factory PromotionPackage.fromJson(Map<String, dynamic> j) => PromotionPackage(
        id: '${j['id'] ?? ''}',
        name: _str(j['name']) ?? '',
        description: _str(j['description']),
        targetType: '${j['targetType'] ?? 'FACILITY'}'.toUpperCase(),
        durationDays: _int(j['durationDays']),
        price: _int(j['price']),
      );
}

/// Trạng thái lượt quảng bá, nhãn như Web (shared.js).
enum PromotionStatus {
  scheduled('SCHEDULED', 'Chờ chạy'),
  active('ACTIVE', 'Đang chạy'),
  expired('EXPIRED', 'Hết hạn'),
  cancelled('CANCELLED', 'Đã hủy'),
  unknown('', '—');

  const PromotionStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PromotionStatus fromApi(Object? v) {
    final key = '${v ?? ''}'.toUpperCase();
    return values.firstWhere((s) => s.apiValue == key && s != unknown, orElse: () => unknown);
  }
}

/// Lượt quảng bá đã mua (GET /promotions/mine).
class OwnerPromotion {
  final String id;
  final String packageName;
  final String? targetName;
  final String targetType;
  final DateTime? startAt;
  final DateTime? endAt;
  final int price;
  final PromotionStatus status;

  const OwnerPromotion({
    required this.id,
    required this.packageName,
    required this.targetType,
    required this.price,
    required this.status,
    this.targetName,
    this.startAt,
    this.endAt,
  });

  /// Số ngày còn lại (làm tròn lên), 0 khi đã hết hạn.
  int daysLeft(DateTime now) {
    final end = endAt;
    if (end == null) return 0;
    final ms = end.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / Duration.millisecondsPerDay).ceil();
  }

  factory OwnerPromotion.fromJson(Map<String, dynamic> j) => OwnerPromotion(
        id: '${j['id'] ?? ''}',
        packageName: _str(j['packageName']) ?? '',
        targetName: _str(j['targetName']),
        targetType: '${j['targetType'] ?? 'FACILITY'}'.toUpperCase(),
        startAt: _date(j['startAt']),
        endAt: _date(j['endAt']),
        price: _int(j['price']),
        status: PromotionStatus.fromApi(j['status']),
      );
}
