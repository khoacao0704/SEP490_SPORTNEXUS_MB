/// Quy định ví.
///
/// TẠM THỜI — nhóm chưa chốt hạn mức/phí rút tiền. Khi chốt chỉ cần sửa ở đây
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
