import '../../core/strings/wallet_strings.dart';
import '../../models/bank_account.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/wallet_repository.dart';
import 'api_client.dart';

/// [WalletRepository] gọi Backend thật (ví của tài khoản đang đăng nhập).
///
/// - Đã nối: số dư (GET /api/v1/wallet) và lịch sử giao dịch (GET /api/v1/wallet/transactions).
/// - BE chưa có: nạp tiền VietQR, tài khoản ngân hàng, rút tiền, chi tiết một giao dịch, thanh toán bằng ví
///   → báo "đang phát triển". Các luồng đặt sân / LFG / giải đấu chưa nối vẫn trừ tiền qua ví giả lập
///   ([AppRepositories.paymentWallet]).
class ApiWalletRepository implements WalletRepository {
  static const String walletPath = '/api/v1/wallet';
  static const String transactionsPath = '/api/v1/wallet/transactions';

  /// pageSize tối đa BE cho phép.
  static const int pageSize = 100;

  /// Giới hạn số trang tải về cho một lần xem lịch sử.
  static const int maxPages = 10;

  final ApiClient _api;

  /// Lượt tải ví đang chạy: số dư và tiền tạm giữ gọi cùng lúc thì dùng chung một request.
  Future<Map<String, dynamic>>? _walletRequest;

  ApiWalletRepository({required this._api});

  @override
  bool get supportsTopUp => false;

  @override
  bool get supportsWithdrawal => false;

  @override
  Future<int> getBalance() async => _money((await _wallet())['availableBalance']);

  @override
  Future<int> getFrozenBalance() async => _money((await _wallet())['frozenBalance']);

  /// BE chưa có luồng rút tiền.
  @override
  Future<int> getPendingWithdrawalAmount() async => 0;

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

  /// BE chưa có API chi tiết theo id: tìm trong lịch sử.
  @override
  Future<WalletTransaction> getTransaction(String transactionId) async {
    final txs = await getTransactions();
    for (final tx in txs) {
      if (tx.id == transactionId) return tx;
    }
    throw const WalletException(WalletStrings.transactionNotFound);
  }

  // ---------------- Chưa có trên BE ----------------

  Never _notSupported() => throw const WalletException(WalletStrings.featureInDevelopment);

  @override
  Future<WalletTransaction> pay({
    required int amount,
    required TransactionType type,
    required String description,
    String? reference,
  }) async =>
      _notSupported();

  @override
  Future<TopUpOrder> createTopUp(int amount) async => _notSupported();

  @override
  Future<void> cancelTopUp(String transactionId) async => _notSupported();

  @override
  Future<List<BankAccount>> getBankAccounts() async => _notSupported();

  @override
  Future<BankAccount> addBankAccount({
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async =>
      _notSupported();

  @override
  Future<void> removeBankAccount(String accountId) async => _notSupported();

  @override
  Future<WalletTransaction> requestWithdrawal({required int amount, required BankAccount account}) async =>
      _notSupported();

  // ---------------- Chuyển đổi dữ liệu BE ----------------

  /// Một dòng của GET /api/v1/wallet/transactions → [WalletTransaction].
  static WalletTransaction transactionFromApi(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? '';
    return WalletTransaction(
      id: json['id'].toString(),
      type: typeFromApi(json['type'] as String? ?? '', status),
      amount: _money(json['amount']).abs(),
      status: statusFromApi(status),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      description: json['description'] as String? ?? '',
      reference: json['referenceId']?.toString(),
    );
  }

  /// amount của BE không mang dấu; chiều tiền theo type (PAYOUT còn xét status):
  /// - DEPOSIT: cộng (nạp tiền, nhận tiền kèo LFG / tiền bạn góp booking).
  /// - FREEZE: chuyển từ số dư khả dụng sang tạm giữ (vào kèo LFG, đóng phí giải) → trừ khỏi số dư khả dụng.
  /// - REFUND: cộng (hoàn kèo, hoàn phí giải, hoàn booking).
  /// - RELEASE: tiền tạm giữ giải ngân cho chủ kèo → khoản chi.
  /// - PAYOUT: PRIZE_* là thưởng giải (cộng); còn lại là trả tiền (booking, góp tiền, chủ kèo bị trừ lại).
  static TransactionType typeFromApi(String type, [String status = '']) => switch (type.toUpperCase()) {
        'DEPOSIT' => TransactionType.deposit,
        'FREEZE' => TransactionType.hold,
        'RELEASE' => TransactionType.holdRelease,
        'PAYOUT' => status.toUpperCase().startsWith('PRIZE') ? TransactionType.prize : TransactionType.walletPayment,
        _ => TransactionType.refund,
      };

  /// BE trả trạng thái dạng chuỗi tự do và chỉ ghi giao dịch đã xảy ra (SUCCESS, LFG_*, PRIZE_*, REFUNDED*,
  /// WALKIN_*...) → thành công; riêng NO_REFUND_* là hủy muộn, không được hoàn (số tiền 0).
  static TransactionStatus statusFromApi(String value) =>
      value.toUpperCase().startsWith('NO_REFUND') ? TransactionStatus.notRefunded : TransactionStatus.success;

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
