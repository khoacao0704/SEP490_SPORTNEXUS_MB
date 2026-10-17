enum TransactionType {
  topUp('TopUp', 'Nạp tiền', isCredit: true),
  withdrawal('Withdrawal', 'Rút tiền', isCredit: false),
  bookingPayment('BookingPayment', 'Thanh toán đặt sân', isCredit: false),
  lfgDeposit('LfgDeposit', 'Cọc tạo kèo LFG', isCredit: false),
  flashClaim('FlashClaim', 'Cọc tham gia kèo LFG', isCredit: false),
  tournamentFee('TournamentFee', 'Lệ phí giải đấu', isCredit: false),
  refund('Refund', 'Hoàn tiền', isCredit: true),

  // Loại giao dịch của BE (ví thật), xem ApiWalletRepository.typeFromApi
  deposit('Deposit', 'Tiền vào ví', isCredit: true),
  hold('Hold', 'Tạm giữ tiền', isCredit: false),
  holdRelease('HoldRelease', 'Giải ngân tiền tạm giữ', isCredit: false),
  walletPayment('WalletPayment', 'Thanh toán', isCredit: false),
  prize('Prize', 'Thưởng giải đấu', isCredit: true),

  // Phía Chủ sân
  escrowRelease('EscrowRelease', 'Giải ngân tiền sân', isCredit: true),
  penaltyIncome('PenaltyIncome', 'Tiền phạt hủy / vắng mặt', isCredit: true),
  listingFee('ListingFee', 'Phí duy trì hàng tháng', isCredit: false);

  const TransactionType(this.apiValue, this.label, {required this.isCredit});

  final String apiValue;
  final String label;

  /// true: cộng vào ví; false: trừ khỏi ví.
  final bool isCredit;

  static TransactionType fromApi(String value) =>
      TransactionType.values.firstWhere((t) => t.apiValue == value);
}

enum TransactionStatus {
  /// Nạp tiền: chờ người dùng chuyển khoản. Rút tiền: chờ xử lý.
  pending('Pending'),
  success('Success'),
  failed('Failed'),

  /// Nạp tiền quá hạn mà chưa nhận được tiền.
  expired('Expired'),
  cancelled('Cancelled'),

  /// Hủy muộn nên không được hoàn tiền (BE ghi giao dịch hoàn 0đ).
  notRefunded('NotRefunded');

  const TransactionStatus(this.apiValue);

  final String apiValue;

  static TransactionStatus fromApi(String value) =>
      TransactionStatus.values.firstWhere((s) => s.apiValue == value);
}

class WalletTransaction {
  final String id;
  final TransactionType type;

  /// Số tiền luôn dương; chiều cộng/trừ xem ở [TransactionType.isCredit].
  final int amount;
  final TransactionStatus status;
  final DateTime createdAt;
  final String description;

  /// Mã tham chiếu: mã đặt sân, nội dung chuyển khoản, tài khoản nhận tiền rút...
  final String? reference;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.description,
    this.reference,
  });

  /// Số tiền có dấu theo chiều ảnh hưởng tới số dư (+ nạp/hoàn, - chi/rút).
  int get signedAmount => type.isCredit ? amount : -amount;

  WalletTransaction copyWith({TransactionStatus? status}) => WalletTransaction(
        id: id,
        type: type,
        amount: amount,
        status: status ?? this.status,
        createdAt: createdAt,
        description: description,
        reference: reference,
      );

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: json['id'] as String,
        type: TransactionType.fromApi(json['type'] as String),
        amount: (json['amount'] as num).toInt(),
        status: TransactionStatus.fromApi(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        description: json['description'] as String,
        reference: json['reference'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.apiValue,
        'amount': amount,
        'status': status.apiValue,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
        'reference': reference,
      };
}
