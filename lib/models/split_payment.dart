enum SplitStatus {
  /// Đang chờ những người nhận link trả phần của mình (trong 30 phút).
  pending,

  /// Đã đủ tất cả các phần: đặt sân thành công.
  completed,

  /// Hết 30 phút mà chưa đủ: đã hủy đặt sân và hoàn đủ cho những người đã trả.
  expired,
}

/// Một phần tiền trong lượt chia. Phần số 0 luôn là của người đặt.
class SplitShare {
  final int index;
  final int amount;
  final String? payerId;
  final String? payerName;
  final DateTime? paidAt;

  const SplitShare({required this.index, required this.amount, this.payerId, this.payerName, this.paidAt});

  bool get isPaid => payerId != null;

  SplitShare paidBy(String userId, String name, DateTime at) =>
      SplitShare(index: index, amount: amount, payerId: userId, payerName: name, paidAt: at);

  factory SplitShare.fromJson(Map<String, dynamic> json) => SplitShare(
        index: (json['index'] as num).toInt(),
        amount: (json['amount'] as num).toInt(),
        payerId: json['payerId'] as String?,
        payerName: json['payerName'] as String?,
        paidAt: json['paidAt'] == null ? null : DateTime.parse(json['paidAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'amount': amount,
        'payerId': payerId,
        'payerName': payerName,
        'paidAt': paidAt?.toIso8601String(),
      };
}

/// Một khung giờ trong lượt chia tiền.
class SplitSlot {
  final String id;
  final DateTime start;
  final DateTime end;
  final int price;

  const SplitSlot({required this.id, required this.start, required this.end, required this.price});

  factory SplitSlot.fromJson(Map<String, dynamic> json) => SplitSlot(
        id: json['id'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        price: (json['price'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'price': price,
      };
}

/// Lượt chia tiền một lần đặt sân: người đặt trả phần của mình trước, chia link/mã cho nhóm
/// cùng trả trong 30 phút. Khung giờ được giữ suốt thời gian chờ.
class SplitPayment {
  final String id;

  /// Mã ngắn để nhập trong app (link chia sẻ chứa mã này).
  final String code;
  final String bookerId;
  final String bookerName;
  final String facilityName;
  final String sportLabel;
  final String location;

  /// Mô tả lịch đã đặt, vd. "Thứ 5, 16/10 • 18:00 - 19:00".
  final String schedule;

  /// Các khung giờ đã giữ; đủ tiền thì mỗi khung thành một lượt đặt riêng.
  final List<SplitSlot> slots;
  final int totalAmount;
  final int parts;
  final List<SplitShare> shares;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// BE đã hủy đặt sân và hoàn tiền vì hết giờ.
  final bool refunded;

  const SplitPayment({
    required this.id,
    required this.code,
    required this.bookerId,
    required this.bookerName,
    required this.facilityName,
    required this.sportLabel,
    required this.location,
    required this.schedule,
    required this.slots,
    required this.totalAmount,
    required this.parts,
    required this.shares,
    required this.createdAt,
    required this.expiresAt,
    this.refunded = false,
  });

  DateTime get start => slots.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime get end => slots.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);

  bool get isFullyPaid => shares.every((s) => s.isPaid);

  int get paidCount => shares.where((s) => s.isPaid).length;

  int get amountPaid => shares.where((s) => s.isPaid).fold(0, (sum, s) => sum + s.amount);

  SplitShare? get nextUnpaid => shares.where((s) => !s.isPaid).firstOrNull;

  bool hasPaid(String userId) => shares.any((s) => s.payerId == userId);

  bool involves(String userId) => bookerId == userId || hasPaid(userId);

  SplitStatus status(DateTime now) {
    if (isFullyPaid) return SplitStatus.completed;
    if (refunded || !now.isBefore(expiresAt)) return SplitStatus.expired;
    return SplitStatus.pending;
  }

  String get shareLink => 'https://sportnexus.vn/chia-tien/$code';

  /// Mã lượt đặt được tạo khi đủ tiền (nhiều khung giờ thì thêm hậu tố -1, -2...).
  String get bookingId => id.replaceFirst('split-', '').toUpperCase();

  SplitPayment copyWith({List<SplitShare>? shares, bool? refunded}) => SplitPayment(
        id: id,
        code: code,
        bookerId: bookerId,
        bookerName: bookerName,
        facilityName: facilityName,
        sportLabel: sportLabel,
        location: location,
        schedule: schedule,
        slots: slots,
        totalAmount: totalAmount,
        parts: parts,
        shares: shares ?? this.shares,
        createdAt: createdAt,
        expiresAt: expiresAt,
        refunded: refunded ?? this.refunded,
      );

  factory SplitPayment.fromJson(Map<String, dynamic> json) => SplitPayment(
        id: json['id'] as String,
        code: json['code'] as String,
        bookerId: json['bookerId'] as String,
        bookerName: json['bookerName'] as String,
        facilityName: json['facilityName'] as String,
        sportLabel: json['sportLabel'] as String,
        location: json['location'] as String,
        schedule: json['schedule'] as String,
        slots: (json['slots'] as List).map((e) => SplitSlot.fromJson(e as Map<String, dynamic>)).toList(),
        totalAmount: (json['totalAmount'] as num).toInt(),
        parts: (json['parts'] as num).toInt(),
        shares: (json['shares'] as List).map((e) => SplitShare.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        refunded: json['refunded'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'bookerId': bookerId,
        'bookerName': bookerName,
        'facilityName': facilityName,
        'sportLabel': sportLabel,
        'location': location,
        'schedule': schedule,
        'slots': slots.map((s) => s.toJson()).toList(),
        'totalAmount': totalAmount,
        'parts': parts,
        'shares': shares.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'refunded': refunded,
      };
}
