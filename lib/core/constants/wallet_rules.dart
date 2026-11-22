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
class WithdrawalPolicy {
  final int minAmount;

  /// Phí xử lý mỗi lệnh, trừ THÊM vào ví ngoài số đổi (ví bị trừ số đổi + phí).
  final int fee;

  /// Phải eKYC được duyệt mới đổi được.
  final bool requiresIdentity;

  const WithdrawalPolicy({required this.minAmount, this.fee = 0, this.requiresIdentity = false});

  /// Chủ sân: luật hiện tại của BE (tối thiểu 50.000, không phí).
  static const WithdrawalPolicy owner =
      WithdrawalPolicy(minAmount: WalletRules.minWithdrawal, fee: WalletRules.withdrawalFee);

  /// Người chơi (thẻ 41) — TẠM, BE CHƯA làm (22/11/2026): Player vẫn 403, chưa có phí, tối thiểu vẫn 50.000, chưa chặn eKYC.
  /// Nhóm chưa chốt: phí trừ vào số rút hay cộng thêm (đang để cộng thêm), chờ duyệt eKYC có được rút không (đang để
  /// phải ĐÃ duyệt). Nút đổi ra tiền của Player chỉ hiện khi ví hỗ trợ (bản API đang tắt).
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
