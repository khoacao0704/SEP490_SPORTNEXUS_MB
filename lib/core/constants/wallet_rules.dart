/// Quy định ví.
///
/// TẠM THỜI — nhóm chưa chốt hạn mức/phí đổi Điểm ra tiền. Khi chốt chỉ cần sửa ở đây
/// (về lâu dài nên lấy từ BE để đổi không cần phát hành lại app).
class WalletRules {
  WalletRules._();

  static const int minWithdrawal = 50000;
  static const int withdrawalFee = 0;

  static const int minTopUp = 10000;
  static const int maxTopUp = 50000000;

  /// Thời gian chờ người dùng chuyển khoản cho một lệnh nạp VietQR.
  static const Duration topUpExpiry = Duration(minutes: 15);
}

/// Luật đổi Điểm ra tiền của từng vai trò.
/// Điều kiện rút do BE trả (GET /wallet/withdrawals/config): mức tối thiểu, phí, số dư, có rút được không và lý do.
class WithdrawalConfig {
  final int minAmount;

  /// Phí mỗi lệnh, TRỪ VÀO số rút (thực nhận = số rút − phí).
  final int fee;
  final int balance;
  final bool canWithdraw;

  /// KYC_REQUIRED, NO_BANK_ACCOUNT, FACILITY_SUSPENDED, PENDING_REQUEST, NEGATIVE_BALANCE, INSUFFICIENT_BALANCE.
  final String? blockedCode;
  final String? blockedReason;

  const WithdrawalConfig({
    required this.minAmount,
    required this.fee,
    required this.balance,
    required this.canWithdraw,
    this.blockedCode,
    this.blockedReason,
  });

  static const String kycRequired = 'KYC_REQUIRED';
  static const String noBankAccount = 'NO_BANK_ACCOUNT';
}

class WithdrawalPolicy {
  final int minAmount;

  /// Phí xử lý mỗi lệnh, TRỪ VÀO số đổi (BE 27/11: thực nhận = số đổi − phí; ví chỉ bị trừ đúng số đổi).
  final int fee;

  /// Phải eKYC được duyệt mới đổi được.
  final bool requiresIdentity;

  const WithdrawalPolicy({required this.minAmount, this.fee = 0, this.requiresIdentity = false});

  /// Chủ sân: luật hiện tại của BE (tối thiểu 50.000, không phí).
  static const WithdrawalPolicy owner =
      WithdrawalPolicy(minAmount: WalletRules.minWithdrawal, fee: WalletRules.withdrawalFee);

  /// Người chơi (BE 27/11/2026): tối thiểu 200.000, phí 5.000 trừ vào số rút, eKYC phải được Admin duyệt.
  /// Bản API đọc lại các số này từ [WithdrawalConfig] của BE.
  static const WithdrawalPolicy player = WithdrawalPolicy(minAmount: 200000, fee: 5000, requiresIdentity: true);
}

class VietnamBank {
  final String code;
  final String name;

  const VietnamBank(this.code, this.name);
}

class VietnamBanks {
  VietnamBanks._();

  static const List<VietnamBank> all = [
    VietnamBank('VCB', 'Vietcombank'),
    VietnamBank('TCB', 'Techcombank'),
    VietnamBank('BIDV', 'BIDV'),
    VietnamBank('CTG', 'VietinBank'),
    VietnamBank('VBA', 'Agribank'),
    VietnamBank('MB', 'MB Bank'),
    VietnamBank('ACB', 'ACB'),
    VietnamBank('VPB', 'VPBank'),
    VietnamBank('TPB', 'TPBank'),
    VietnamBank('STB', 'Sacombank'),
    VietnamBank('VIB', 'VIB'),
    VietnamBank('SHB', 'SHB'),
    VietnamBank('HDB', 'HDBank'),
    VietnamBank('OCB', 'OCB'),
  ];
}
