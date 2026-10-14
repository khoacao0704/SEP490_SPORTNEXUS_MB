import '../core/constants/booking_rules.dart';

enum BookingPaymentType {
  full('Full', 'Thanh toán 100%'),
  deposit('Deposit', 'Cọc 1/4, còn lại trả tại sân'),
  split('Split', 'Chia tiền nhóm');

  const BookingPaymentType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static BookingPaymentType fromApi(String value) => values.firstWhere((t) => t.apiValue == value);
}

enum BookingStatus { upcoming, cancelled, completed }

/// Một khoản đã trả cho lần đặt sân (chia tiền thì có nhiều người trả).
class BookingPayment {
  final String userId;
  final String name;
  final int amount;

  const BookingPayment({required this.userId, required this.name, required this.amount});

  factory BookingPayment.fromJson(Map<String, dynamic> json) => BookingPayment(
        userId: json['userId'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'userId': userId, 'name': name, 'amount': amount};
}

/// Một lần đặt sân thường (một hoặc nhiều khung giờ cùng cơ sở, cùng môn và loại sân).
class Booking {
  final String id;
  final String bookerId;
  final String facilityName;
  final String location;

  /// "Cầu Lông" hoặc "Bóng Đá • Sân 7 người".
  final String sportLabel;

  /// Mô tả lịch, vd. "Thứ 5, 16/10 • 18:00 - 19:00".
  final String schedule;

  /// Giờ bắt đầu khung sớm nhất / kết thúc khung muộn nhất.
  final DateTime start;
  final DateTime end;
  final int totalPrice;
  final BookingPaymentType paymentType;
  final List<BookingPayment> payments;
  final DateTime createdAt;
  final DateTime? cancelledAt;

  /// Tổng tiền đã hoàn khi hủy.
  final int refunded;

  const Booking({
    required this.id,
    required this.bookerId,
    required this.facilityName,
    required this.location,
    required this.sportLabel,
    required this.schedule,
    required this.start,
    required this.end,
    required this.totalPrice,
    required this.paymentType,
    required this.payments,
    required this.createdAt,
    this.cancelledAt,
    this.refunded = 0,
  });

  int get amountPaid => payments.fold(0, (sum, p) => sum + p.amount);

  /// Còn phải trả tại sân (với cọc 1/4).
  int get remainingAtCourt => (totalPrice - amountPaid).clamp(0, totalPrice);

  /// Hủy trước mốc này được hoàn 100%.
  DateTime get freeCancelDeadline => start.subtract(BookingRules.freeCancelBeforeStart);

  bool isFreeCancel(DateTime now) => now.isBefore(freeCancelDeadline);

  /// Số tiền bị mất nếu hủy lúc [now]: trước 24h không mất, trong 24h mất 1/4 tiền sân.
  int cancelFee(DateTime now) {
    if (isFreeCancel(now)) return 0;
    final fee = BookingRules.lateCancelFee(totalPrice);
    return fee > amountPaid ? amountPaid : fee;
  }

  /// Tổng tiền được hoàn nếu hủy lúc [now].
  int refundIfCancelled(DateTime now) => amountPaid - cancelFee(now);

  BookingStatus status(DateTime now) {
    if (cancelledAt != null) return BookingStatus.cancelled;
    if (!end.isAfter(now)) return BookingStatus.completed;
    return BookingStatus.upcoming;
  }

  bool canCancel(DateTime now, String userId) =>
      bookerId == userId && status(now) == BookingStatus.upcoming && now.isBefore(start);

  /// Mã QR check-in, tạo mới cho mỗi lần đặt; dùng tới khi chủ sân check-out.
  String get ticketCode => 'SPN-BK-$id';

  Booking copyWith({DateTime? cancelledAt, int? refunded}) => Booking(
        id: id,
        bookerId: bookerId,
        facilityName: facilityName,
        location: location,
        sportLabel: sportLabel,
        schedule: schedule,
        start: start,
        end: end,
        totalPrice: totalPrice,
        paymentType: paymentType,
        payments: payments,
        createdAt: createdAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        refunded: refunded ?? this.refunded,
      );

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        bookerId: json['bookerId'] as String,
        facilityName: json['facilityName'] as String,
        location: json['location'] as String,
        sportLabel: json['sportLabel'] as String,
        schedule: json['schedule'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        totalPrice: (json['totalPrice'] as num).toInt(),
        paymentType: BookingPaymentType.fromApi(json['paymentType'] as String),
        payments: (json['payments'] as List).map((e) => BookingPayment.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        cancelledAt: json['cancelledAt'] == null ? null : DateTime.parse(json['cancelledAt'] as String),
        refunded: (json['refunded'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookerId': bookerId,
        'facilityName': facilityName,
        'location': location,
        'sportLabel': sportLabel,
        'schedule': schedule,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'totalPrice': totalPrice,
        'paymentType': paymentType.apiValue,
        'payments': payments.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'cancelledAt': cancelledAt?.toIso8601String(),
        'refunded': refunded,
      };
}
