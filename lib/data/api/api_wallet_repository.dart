import '../../core/constants/wallet_rules.dart';
import '../../core/strings/wallet_strings.dart';
import '../../models/bank_account.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/wallet_repository.dart';
import 'api_client.dart';

/// [WalletRepository] gọi Backend thật (ví của tài khoản đang đăng nhập).
///
/// - Số dư (GET /api/v1/wallet), lịch sử giao dịch (GET /api/v1/wallet/transactions).
/// - Nạp tiền qua PayOS: tạo lệnh → hiện mã QR / trang thanh toán → hỏi trạng thái tới khi BE nhận tiền.
///   Link PayOS hết hạn theo `expiresAt` của BE (mặc định 15 phút); hết giờ app gọi hủy để đồng bộ với PayOS.
///   BE tự chuyển lệnh quá hạn sang EXPIRED (≈25 phút sau khi tạo).
/// - Rút tiền: MỘT tài khoản ngân hàng (lưu = thay thế, không xóa), lệnh rút trừ tiền ngay, Admin duyệt / từ chối;
///   tối thiểu 50.000đ, mỗi lúc một lệnh chờ, hủy được khi còn chờ (tiền trả lại ví).
/// - BE chưa có: thanh toán bằng ví. Các luồng giải đấu chưa nối vẫn trừ tiền qua ví giả lập
///   ([AppRepositories.paymentWallet]).
class ApiWalletRepository implements WalletRepository {
  static const String walletPath = '/api/v1/wallet';
  static const String transactionsPath = '/api/v1/wallet/transactions';
  static const String depositPath = '/api/v1/wallet/deposit';
  static String depositStatusPath(String orderCode) => '/api/v1/wallet/deposits/$orderCode';
  static String depositCancelPath(String orderCode) => '/api/v1/wallet/deposits/$orderCode/cancel';
  static const String bankAccountPath = '/api/v1/wallet/bank-account';
  static const String withdrawalsPath = '/api/v1/wallet/withdrawals';
  static String transactionPath(String id) => '/api/v1/wallet/transactions/$id';
  static String withdrawalCancelPath(String id) => '/api/v1/wallet/withdrawals/$id/cancel';

  /// pageSize tối đa BE cho phép.
  static const int pageSize = 100;

  /// Giới hạn số trang tải về cho một lần xem lịch sử.
  static const int maxPages = 10;

  /// BE chỉ lưu một tài khoản ngân hàng, không có id riêng.
  static const String bankAccountId = 'default';

  final ApiClient _api;

  /// Lượt tải ví đang chạy: số dư và tiền tạm giữ gọi cùng lúc thì dùng chung một request.
  Future<Map<String, dynamic>>? _walletRequest;

  /// `false`: tắt rút tiền / tài khoản ngân hàng (UI báo "đang phát triển").
  @override
  final bool supportsWithdrawal;

  ApiWalletRepository({required this._api, this.supportsWithdrawal = true});

  @override
  bool get supportsTopUp => true;

  @override
  bool get singleBankAccount => true;

  @override
  Future<int> getBalance() async => _money((await _wallet())['availableBalance']);

  @override
  Future<int> getFrozenBalance() async => _money((await _wallet())['frozenBalance']);

  /// Tổng các lệnh rút PENDING. Tài khoản không được rút tiền (403) coi như 0.
  @override
  Future<int> getPendingWithdrawalAmount() async {
    if (!supportsWithdrawal) return 0;
    final Object? data;
    try {
      data = await _api.get(withdrawalsPath, query: {'page': 1, 'pageSize': pageSize});
    } on ApiException catch (e) {
      if (e.statusCode == 403) return 0;
      throw WalletException(e.message);
    }
    final items = data is Map<String, dynamic> ? (data['items'] as List? ?? const []) : const [];
    return items
        .cast<Map<String, dynamic>>()
        .where((w) => (w['status'] as String? ?? '').toUpperCase() == 'PENDING')
        .fold<int>(0, (sum, w) => sum + _money(w['amount']));
  }

  @override
  Future<List<WalletTransaction>> getTransactions() async {
    final result = <WalletTransaction>[];
    for (var page = 1; page <= maxPages; page++) {
      final data = await _call(() => _api.get(transactionsPath, query: {'page': page, 'pageSize': pageSize}))
          as Map<String, dynamic>;
      final items = (data['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      result.addAll(items.map(transactionFromApi));
      final total = (data['totalItems'] as num?)?.toInt() ?? 0;
      if (items.length < pageSize || result.length >= total) break;
    }
    return result;
  }

  /// Chỉ xem được giao dịch trong ví của mình; không có → 404.
  @override
  Future<WalletTransaction> getTransaction(String transactionId) async {
    final Object? data;
    try {
      data = await _api.get(transactionPath(transactionId));
    } on ApiException catch (e) {
      throw WalletException(e.statusCode == 404 ? WalletStrings.transactionNotFound : e.message);
    }
    return transactionFromApi(data as Map<String, dynamic>);
  }

  // ---------------- Nạp tiền (PayOS) ----------------

  @override
  Future<TopUpOrder> createTopUp(int amount) async {
    final data = await _call(() => _api.post(depositPath, body: {'amount': amount})) as Map<String, dynamic>;
    final checkoutUrl = data['checkoutUrl'] as String?;
    final expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '')?.toLocal();
    return TopUpOrder(
      transactionId: data['orderCode'].toString(),
      amount: _money(data['amount']),
      qrData: data['qrCode'] as String? ?? '',
      checkoutUrl: checkoutUrl == null || checkoutUrl.isEmpty ? null : checkoutUrl,
      expiresAt: expiresAt ?? DateTime.now().add(WalletRules.topUpExpiry),
    );
  }

  /// PENDING_PAYMENT → chờ, SUCCESS → đã cộng ví, CANCELLED / EXPIRED / FAILED → kết thúc.
  @override
  Future<TransactionStatus> getTopUpStatus(String orderId) async {
    final data = await _call(() => _api.get(depositStatusPath(orderId))) as Map<String, dynamic>;
    return statusFromApi(data['status'] as String? ?? '');
  }

  /// BE trả 400 khi lệnh không còn chờ thanh toán (đã nhận tiền / đã hủy): coi như xong.
  @override
  Future<void> cancelTopUp(String transactionId) async {
    try {
      await _api.post(depositCancelPath(transactionId));
    } on ApiException catch (e) {
      if (e.statusCode != 400) throw WalletException(e.message);
    }
  }

  // ---------------- Tài khoản ngân hàng & rút tiền ----------------

  /// Chưa lưu tài khoản: BE trả 200 với các trường null → danh sách rỗng.
  @override
  Future<List<BankAccount>> getBankAccounts() async {
    final data = await _call(() => _api.get(bankAccountPath));
    final account = data is Map<String, dynamic> ? bankAccountFromApi(data) : null;
    return account == null ? const [] : [account];
  }

  /// Lưu đè tài khoản nhận tiền (BE: số tài khoản 6–20 chữ số, tên chủ tài khoản tự viết hoa).
  @override
  Future<BankAccount> addBankAccount({
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    final data = await _call(() => _api.put(bankAccountPath, body: {
          'bankName': bankName,
          'bankAccountNumber': accountNumber.trim(),
          'bankAccountHolder': accountHolder.trim(),
        }));
    return (data is Map<String, dynamic> ? bankAccountFromApi(data) : null) ??
        BankAccount(
          id: bankAccountId,
          bankCode: bankCode,
          bankName: bankName,
          accountNumber: accountNumber.trim(),
          accountHolder: accountHolder.trim().toUpperCase(),
        );
  }

  /// BE không có xóa tài khoản ngân hàng (chỉ lưu đè).
  @override
  Future<void> removeBankAccount(String accountId) async =>
      throw const WalletException(WalletStrings.featureInDevelopment);

  /// BE rút về tài khoản đã lưu; [account] chỉ để hiển thị. Chặn khi chưa lưu tài khoản, số dư không đủ,
  /// ví âm hoặc đang có lệnh chờ xử lý (BE trả câu tiếng Việt).
  @override
  Future<WalletTransaction> requestWithdrawal({required int amount, required BankAccount account}) async {
    final data = await _call(() => _api.post(withdrawalsPath, body: {'amount': amount}));
    final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final createdAt = json['createdAt'] as String?;
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: TransactionType.withdrawal,
      amount: json.containsKey('amount') ? _money(json['amount']) : amount,
      status: TransactionStatus.pending,
      createdAt: createdAt == null ? DateTime.now() : DateTime.parse(createdAt).toLocal(),
      description: WalletStrings.withdrawTo(account.bankName),
      reference: '${account.bankCode} ${account.accountNumber} - ${account.accountHolder}',
    );
  }

  /// BE chỉ cho một lệnh chờ mỗi lúc và id lệnh rút khác id giao dịch: tìm lệnh PENDING rồi hủy.
  /// Lệnh vừa được Admin xử lý (không còn chờ) → BE báo lỗi, hiển thị nguyên văn.
  @override
  Future<void> cancelWithdrawal(WalletTransaction withdrawal) async {
    final data = await _call(() => _api.get(withdrawalsPath, query: {'page': 1, 'pageSize': pageSize}));
    final items = data is Map<String, dynamic> ? (data['items'] as List? ?? const []) : const [];
    final pending = items
        .cast<Map<String, dynamic>>()
        .where((w) => (w['status'] as String? ?? '').toUpperCase() == 'PENDING')
        .firstOrNull;
    if (pending == null) throw const WalletException(WalletStrings.noPendingWithdrawal);
    await _call(() => _api.post(withdrawalCancelPath(pending['id'].toString())));
  }

  @override
  Future<WalletTransaction> pay({
    required int amount,
    required TransactionType type,
    required String description,
    String? reference,
  }) async =>
      throw const WalletException(WalletStrings.featureInDevelopment);

  // ---------------- Chuyển đổi dữ liệu BE ----------------

  /// {bankName, bankAccountNumber, bankAccountHolder}; chưa lưu (số tài khoản null / rỗng) → null.
  static BankAccount? bankAccountFromApi(Map<String, dynamic> json) {
    final number = json['bankAccountNumber'] as String?;
    if (number == null || number.isEmpty) return null;
    final name = json['bankName'] as String? ?? '';
    final bank = VietnamBanks.all.where((b) => b.name == name || b.code == name).firstOrNull;
    return BankAccount(
      id: bankAccountId,
      bankCode: bank?.code ?? name,
      bankName: bank?.name ?? name,
      accountNumber: number,
      accountHolder: json['bankAccountHolder'] as String? ?? '',
    );
  }

  /// Một dòng của GET /api/v1/wallet/transactions → [WalletTransaction].
  static WalletTransaction transactionFromApi(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? '';
    final note = (json['note'] as String?)?.trim();
    return WalletTransaction(
      id: json['id'].toString(),
      type: typeFromApi(json['type'] as String? ?? '', status, json['balanceChange'] as num?),
      amount: _money(json['amount']).abs(),
      status: statusFromApi(status),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      description: json['description'] as String? ?? '',
      reference: json['referenceId']?.toString(),
      note: note == null || note.isEmpty ? null : note,
    );
  }

  /// amount của BE không mang dấu; chiều tiền theo type (PAYOUT còn xét status):
  /// - DEPOSIT: cộng (nạp tiền, nhận tiền kèo LFG / tiền bạn góp booking).
  /// - FREEZE: chuyển từ số dư khả dụng sang tạm giữ (vào kèo LFG, đóng phí giải) → trừ khỏi số dư khả dụng.
  /// - REFUND: cộng (hoàn kèo, hoàn phí giải, hoàn booking).
  /// - RELEASE: tiền tạm giữ giải ngân cho chủ kèo → khoản chi.
  /// - PAYOUT: PRIZE_* là thưởng giải (cộng); còn lại là trả tiền (booking, góp tiền, chủ kèo bị trừ lại).
  /// - WITHDRAW*: rút tiền về ngân hàng.
  /// - Loại khác (vd. Admin cộng / trừ tay): theo dấu [balanceChange] của BE (âm → khoản chi), không có thì coi là tiền vào.
  static TransactionType typeFromApi(String type, [String status = '', num? balanceChange]) {
    final t = type.toUpperCase();
    if (t.startsWith('WITHDRAW')) return TransactionType.withdrawal;
    return switch (t) {
      'DEPOSIT' => TransactionType.deposit,
      'FREEZE' => TransactionType.hold,
      'RELEASE' => TransactionType.holdRelease,
      'PAYOUT' => status.toUpperCase().startsWith('PRIZE') ? TransactionType.prize : TransactionType.walletPayment,
      'REFUND' => TransactionType.refund,
      _ => balanceChange != null && balanceChange < 0 ? TransactionType.walletPayment : TransactionType.refund,
    };
  }

  /// BE trả trạng thái dạng chuỗi tự do:
  /// - PENDING_PAYMENT (lệnh nạp chờ chuyển khoản) / PENDING (lệnh rút chờ duyệt) → chờ.
  /// - CANCELLED → đã hủy; EXPIRED → lệnh nạp quá hạn chưa nhận tiền; FAILED / REJECTED → không thành công;
  ///   NO_REFUND_* → hủy muộn, không được hoàn.
  /// - Còn lại (SUCCESS, COMPLETED, LFG_*, PRIZE_*, REFUNDED*, WALKIN_*...) → thành công.
  static TransactionStatus statusFromApi(String value) {
    final s = value.toUpperCase();
    if (s.startsWith('NO_REFUND')) return TransactionStatus.notRefunded;
    if (s.startsWith('PENDING')) return TransactionStatus.pending;
    return switch (s) {
      'CANCELLED' || 'CANCELED' => TransactionStatus.cancelled,
      'EXPIRED' => TransactionStatus.expired,
      'FAILED' || 'REJECTED' => TransactionStatus.failed,
      _ => TransactionStatus.success,
    };
  }

  /// Tiền BE là decimal(18,2) nhưng luôn là VNĐ nguyên.
  static int _money(Object? value) => value is num ? value.round() : num.tryParse('$value')?.round() ?? 0;

  Future<Map<String, dynamic>> _wallet() => _walletRequest ??=
      _call(() => _api.get(walletPath)).then((data) => data as Map<String, dynamic>).whenComplete(() => _walletRequest = null);

  /// Gọi BE; lỗi thành [WalletException] mang câu tiếng Việt của BE.
  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw WalletException(e.message);
    }
  }
}
