enum TransactionType {
  topUp('TopUp', 'Nạp Điểm', isCredit: true),
  withdrawal('Withdrawal', 'Đổi Điểm ra tiền', isCredit: false),
  bookingPayment('BookingPayment', 'Thanh toán đặt sân', isCredit: false),
  lfgDeposit('LfgDeposit', 'Cọc tạo kèo LFG', isCredit: false),
  flashClaim('FlashClaim', 'Cọc tham gia kèo LFG', isCredit: false),
  tournamentFee('TournamentFee', 'Lệ phí giải đấu', isCredit: false),
  refund('Refund', 'Hoàn Điểm', isCredit: true),

  // Loại giao dịch của BE (ví thật), xem ApiWalletRepository.typeFromApi
  deposit('Deposit', 'Điểm vào Ví điểm', isCredit: true),
  hold('Hold', 'Tạm giữ Điểm', isCredit: false),
  holdRelease('HoldRelease', 'Giải ngân Điểm tạm giữ', isCredit: false),
  walletPayment('WalletPayment', 'Thanh toán', isCredit: false),
  prize('Prize', 'Thưởng giải đấu', isCredit: true),

  // Phía Chủ sân
  escrowRelease('EscrowRelease', 'Giải ngân Điểm đặt sân', isCredit: true),
  penaltyIncome('PenaltyIncome', 'Điểm phạt hủy / vắng mặt', isCredit: true),
  listingFee('ListingFee', 'Phí duy trì hàng tháng', isCredit: false);

  const TransactionType(this.apiValue, this.label, {required this.isCredit});

  final String apiValue;
  final String label;

  /// true: cộng vào Ví điểm; false: trừ khỏi ví.
  final bool isCredit;

  static TransactionType fromApi(String value) =>
      TransactionType.values.firstWhere((t) => t.apiValue == value);
}

enum TransactionStatus {
  /// Nạp Điểm: chờ người dùng chuyển khoản. Đổi Điểm ra tiền: chờ xử lý.
  pending('Pending'),
  success('Success'),
  failed('Failed'),

  /// Nạp Điểm quá hạn mà chưa nhận được tiền.
  expired('Expired'),
  cancelled('Cancelled'),

  /// Hủy muộn nên không được hoàn Điểm (BE ghi giao dịch hoàn 0đ).
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

  /// Ghi chú thêm của BE, vd. "Mã giao dịch ngân hàng: …" khi Admin chuyển tiền rút xong.
  final String? note;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.description,
    this.reference,
    this.note,
  });

  /// Lệnh rút đang chờ Admin xử lý: người dùng còn hủy được (tiền trả lại Ví điểm).
  bool get isPendingWithdrawal => type == TransactionType.withdrawal && status == TransactionStatus.pending;

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
        note: note,
      );

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: json['id'] as String,
        type: TransactionType.fromApi(json['type'] as String),
        amount: (json['amount'] as num).toInt(),
        status: TransactionStatus.fromApi(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        description: json['description'] as String,
        reference: json['reference'] as String?,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.apiValue,
        'amount': amount,
        'status': status.apiValue,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
        'reference': reference,
        'note': note,
      };
}
