class BankAccount {
  final String id;
  final String bankCode;
  final String bankName;
  final String accountNumber;

  /// Tên chủ tài khoản: in hoa, không dấu (đúng như ngân hàng in trên thẻ).
  final String accountHolder;

  const BankAccount({
    required this.id,
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
  });

  /// "•••• 6789"
  String get maskedNumber {
    final n = accountNumber;
    return n.length <= 4 ? n : '•••• ${n.substring(n.length - 4)}';
  }

  /// "VCB •••• 6789"
  String get shortLabel => '$bankCode $maskedNumber';

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: json['id'] as String,
        bankCode: json['bankCode'] as String,
        bankName: json['bankName'] as String,
        accountNumber: json['accountNumber'] as String,
        accountHolder: json['accountHolder'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bankCode': bankCode,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountHolder': accountHolder,
      };
}

/// Lệnh nạp tiền qua VietQR: người dùng chuyển khoản đúng số tiền + nội dung, BE xác nhận rồi mới cộng ví.
class TopUpOrder {
  /// Mã lệnh nạp (BE: orderCode của PayOS) để hỏi trạng thái / hủy.
  final String transactionId;
  final int amount;

  /// Thông tin chuyển khoản thủ công; `null` khi cổng thanh toán không cung cấp (PayOS chỉ trả mã QR + trang thanh toán).
  final String? transferContent;
  final String? receiverBankName;
  final String? receiverAccountNumber;
  final String? receiverAccountName;

  /// Chuỗi dữ liệu vẽ mã QR.
  final String qrData;

  /// Trang thanh toán của cổng PayOS (mở bằng trình duyệt); `null` nếu không có.
  final String? checkoutUrl;

  /// Hết thời gian này mà chưa nhận được tiền thì app hủy lệnh.
  final DateTime expiresAt;

  const TopUpOrder({
    required this.transactionId,
    required this.amount,
    this.transferContent,
    this.receiverBankName,
    this.receiverAccountNumber,
    this.receiverAccountName,
    required this.qrData,
    this.checkoutUrl,
    required this.expiresAt,
  });

  bool get hasTransferInfo => receiverAccountNumber != null;
}
