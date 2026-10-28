import '../core/constants/booking_rules.dart';
import '../core/constants/split_payment_rules.dart';

enum BookingPaymentType {
  full('Full', 'Thanh toán 100%'),
  split('Split', 'Chia tiền nhóm');

  const BookingPaymentType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static BookingPaymentType fromApi(String value) => values.firstWhere((t) => t.apiValue == value);
}

enum BookingStatus { upcoming, cancelled, completed }

/// Một người trong đơn chia tiền (người đặt + những người được mời góp).
class BookingParticipant {
  final String userId;
  final String name;

  /// Phần phải góp.
  final int amount;
  final bool isPaid;
  final bool isHost;

  const BookingParticipant({
    required this.userId,
    required this.name,
    required this.amount,
    required this.isPaid,
    this.isHost = false,
  });
}

/// Tài khoản tìm theo số điện thoại để mời góp tiền.
class PlayerLookup {
  final String id;
  final String fullName;

  /// SĐT đã che, vd. "******9952".
  final String phoneMasked;
  final String? avatarUrl;

  const PlayerLookup({required this.id, required this.fullName, required this.phoneMasked, this.avatarUrl});
}

/// Lý do hủy chọn sẵn; [isCustom] = mục "Khác" (người dùng tự nhập lý do).
class CancelReason {
  final int code;
  final String label;
  final bool isCustom;

  const CancelReason({required this.code, required this.label, this.isCustom = false});
}

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

  /// Sân con đã đặt, vd. "Sân 2" (`null` với dữ liệu cũ chưa có sân con).
  final String? courtName;

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

  /// Số tiền người dùng hiện tại được hoàn khi hủy (đơn chia tiền: chỉ phần của mình).
  final int refunded;

  /// Đã check-in tại sân (không hủy được nữa).
  final bool isCheckedIn;

  /// Đơn chia tiền đang chờ mọi người góp đủ (chưa có vé, hết hạn thì tự hủy và hoàn tiền).
  final bool awaitingPayment;

  /// Phần tiền của người dùng hiện tại trong đơn chia tiền (0 = không chia).
  final int myShare;

  /// Người đặt + người được mời góp; chỉ có khi tải chi tiết một đơn.
  final List<BookingParticipant> participants;

  const Booking({
    required this.id,
    required this.bookerId,
    required this.facilityName,
    required this.location,
    required this.sportLabel,
    this.courtName,
    required this.schedule,
    required this.start,
    required this.end,
    required this.totalPrice,
    required this.paymentType,
    required this.payments,
    required this.createdAt,
    this.cancelledAt,
    this.refunded = 0,
    this.isCheckedIn = false,
    this.awaitingPayment = false,
    this.myShare = 0,
    this.participants = const [],
  });

  /// Hạn góp tiền của đơn chia tiền: 30 phút sau khi tạo, nhưng không quá giờ bắt đầu.
  DateTime get splitDeadline {
    final byWindow = createdAt.add(SplitPaymentRules.window);
    return byWindow.isBefore(start) ? byWindow : start;
  }

  /// Người dùng [userId] còn phải góp phần của mình.
  bool owesShare(String userId) => participants.any((p) => p.userId == userId && !p.isPaid);

  /// "Cầu Lông • Sân 2" (chưa có sân con thì chỉ có môn).
  String get sportCourtLabel => courtName == null ? sportLabel : '$sportLabel • $courtName';

  int get amountPaid =>payments.fold(0, (sum, p) => sum + p.amount);

  /// Hủy trước mốc này được hoàn 100%.
  DateTime get freeCancelDeadline => start.subtract(BookingRules.freeCancelBeforeStart);

  bool isFreeCancel(DateTime now) => now.isBefore(freeCancelDeadline);

  /// Hủy lúc [now] được hoàn đủ: trước 24h, hoặc đơn chia tiền còn chờ góp (lúc nào hủy cũng hoàn đủ phần đã góp).
  bool refundsInFull(DateTime now) => awaitingPayment || isFreeCancel(now);

  /// Số tiền bị mất nếu hủy lúc [now]: được hoàn đủ thì không mất, còn lại mất toàn bộ số đã trả.
  int cancelFee(DateTime now) => refundsInFull(now) ? 0 : amountPaid;

  /// Tổng tiền được hoàn nếu hủy lúc [now].
  int refundIfCancelled(DateTime now) => amountPaid - cancelFee(now);

  BookingStatus status(DateTime now) {
    if (cancelledAt != null) return BookingStatus.cancelled;
    if (!end.isAfter(now)) return BookingStatus.completed;
    return BookingStatus.upcoming;
  }

  bool canCancel(DateTime now, String userId) =>
      bookerId == userId && !isCheckedIn && status(now) == BookingStatus.upcoming && now.isBefore(start);

  /// Mã QR check-in, tạo mới cho mỗi lần đặt; dùng tới khi chủ sân check-out.
  String get ticketCode => 'SPN-BK-$id';

  Booking copyWith({DateTime? cancelledAt, int? refunded}) => Booking(
        id: id,
        bookerId: bookerId,
        facilityName: facilityName,
        location: location,
        sportLabel: sportLabel,
        courtName: courtName,
        schedule: schedule,
        start: start,
        end: end,
        totalPrice: totalPrice,
        paymentType: paymentType,
        payments: payments,
        createdAt: createdAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        refunded: refunded ?? this.refunded,
        isCheckedIn: isCheckedIn,
        awaitingPayment: cancelledAt == null && awaitingPayment,
        myShare: myShare,
        participants: participants,
      );

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        bookerId: json['bookerId'] as String,
        facilityName: json['facilityName'] as String,
        location: json['location'] as String,
        sportLabel: json['sportLabel'] as String,
        courtName: json['courtName'] as String?,
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
        'courtName': courtName,
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
