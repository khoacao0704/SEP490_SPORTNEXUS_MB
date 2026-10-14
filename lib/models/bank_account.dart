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
  final String transactionId;
  final int amount;

  /// Nội dung chuyển khoản bắt buộc để BE đối soát, ví dụ "SPN 8F3K2Q".
  final String transferContent;
  final String receiverBankName;
  final String receiverAccountNumber;
  final String receiverAccountName;

  /// Chuỗi dữ liệu vẽ mã QR (do BE cung cấp khi nối API).
  final String qrData;
  final DateTime expiresAt;

  const TopUpOrder({
    required this.transactionId,
    required this.amount,
    required this.transferContent,
    required this.receiverBankName,
    required this.receiverAccountNumber,
    required this.receiverAccountName,
    required this.qrData,
    required this.expiresAt,
  });
}
