import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/wallet_rules.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/bank_account.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/wallet_repository.dart';

/// Bản giả lập [WalletRepository], lưu trong SharedPreferences.
///
/// - Giữ key `wallet_balance` cũ để số dư hiện có của người dùng không bị mất.
/// - Lần đầu chạy: tạo 1 giao dịch "Số dư ban đầu" bằng đúng số dư hiện tại để lịch sử khớp với số dư.
/// - Lệnh nạp chỉ cộng tiền khi gọi [simulateTopUpReceived] (thay cho webhook ngân hàng của BE).
/// - Ví dùng chung cho mọi tài khoản trên cùng máy (giới hạn của bản giả lập); ví Chủ sân tách riêng
///   bằng [keyPrefix] để tiền demo của hai phía không lẫn vào nhau.
class MockWalletRepository implements WalletRepository, SandboxPaymentSimulator {
  static const String keyBalance = 'wallet_balance';
  static const String keyTransactions = 'wallet_transactions';
  static const String keyBankAccounts = 'wallet_bank_accounts';
  static const int defaultBalance = 500000;

  /// Tài khoản nhận tiền giả lập; ghi rõ Sandbox để không ai nhầm là tài khoản thật.
  static const String sandboxBankName = 'Ngân hàng thử nghiệm (Sandbox)';
  static const String sandboxAccountNumber = '0000 0000 0000';
  static const String sandboxAccountName = 'SPORTNEXUS SANDBOX';

  final Duration latency;
  final DateTime Function() _now;
  final Random _random;
  int _counter = 0;

  /// Tiền tố key lưu trữ ('owner_' cho ví Chủ sân).
  final String keyPrefix;

  /// Số dư lúc chạy lần đầu.
  final int initialBalance;

  MockWalletRepository({
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? now,
    Random? random,
    this.keyPrefix = '',
    this.initialBalance = defaultBalance,
  })  : _now = now ?? DateTime.now,
        _random = random ?? Random();

  String get _keyBalance => '$keyPrefix$keyBalance';
  String get _keyTransactions => '$keyPrefix$keyTransactions';
  String get _keyBankAccounts => '$keyPrefix$keyBankAccounts';

  @override
  bool get supportsTopUp => true;

  @override
  bool get supportsWithdrawal => true;

  @override
  bool get singleBankAccount => false;

  // ---------------- Số dư & lịch sử ----------------

  @override
  Future<int> getBalance() async {
    await _delay();
    await _transactions(); // đảm bảo đã khởi tạo dữ liệu ban đầu
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBalance) ?? initialBalance;
  }

  /// Bản giả lập trừ thẳng vào số dư, không có phần tạm giữ.
  @override
  Future<int> getFrozenBalance() async => 0;

  @override
  Future<int> getPendingWithdrawalAmount() async {
    final txs = await _transactions();
    return txs
        .where((t) => t.type == TransactionType.withdrawal && t.status == TransactionStatus.pending)
        .fold<int>(0, (sum, t) => sum + t.amount);
  }

  @override
  Future<List<WalletTransaction>> getTransactions() async {
    await _delay();
    final txs = await _transactions();
    return [...txs]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<TransactionStatus> getTopUpStatus(String orderId) async => (await getTransaction(orderId)).status;

  @override
  Future<WalletTransaction> getTransaction(String transactionId) async {
    final txs = await _transactions();
    return txs.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => throw const WalletException(WalletStrings.transactionNotFound),
    );
  }

  @override
  Future<WalletTransaction> pay({
    required int amount,
    required TransactionType type,
    required String description,
    String? reference,
  }) async {
    await _delay();
    if (amount <= 0 || type.isCredit) throw const WalletException(WalletStrings.invalidAmount);
    final balance = await getBalance();
    if (amount > balance) throw const WalletException(WalletStrings.insufficientBalance);

    final tx = _newTransaction(
      type: type,
      amount: amount,
      status: TransactionStatus.success,
      description: description,
      reference: reference,
    );
    await _save(balance: balance - amount, add: tx);
    return tx;
  }

  // ---------------- Nạp tiền ----------------

  @override
  Future<TopUpOrder> createTopUp(int amount) async {
    await _delay();
    if (amount < WalletRules.minTopUp) {
      throw WalletException('${WalletStrings.minTopUpError} ${Formatters.vnd(WalletRules.minTopUp)}');
    }
    if (amount > WalletRules.maxTopUp) {
      throw WalletException('${WalletStrings.maxTopUpError} ${Formatters.vnd(WalletRules.maxTopUp)}');
    }

    final content = 'SPN ${_randomCode(6)}';
    final tx = _newTransaction(
      type: TransactionType.topUp,
      amount: amount,
      status: TransactionStatus.pending,
      description: 'Nạp tiền qua VietQR',
      reference: content,
    );
    await _save(add: tx);

    return TopUpOrder(
      transactionId: tx.id,
      amount: amount,
      transferContent: content,
      receiverBankName: sandboxBankName,
      receiverAccountNumber: sandboxAccountNumber,
      receiverAccountName: sandboxAccountName,
      // Cố ý KHÔNG theo chuẩn VietQR/EMVCo: mã giả không được để app ngân hàng quét ra lệnh chuyển tiền thật.
      qrData: 'SPORTNEXUS-SANDBOX|TOPUP|${tx.id}|$amount|$content',
      expiresAt: tx.createdAt.add(WalletRules.topUpExpiry),
    );
  }

  @override
  Future<void> cancelTopUp(String transactionId) async {
    final tx = await getTransaction(transactionId);
    if (tx.status != TransactionStatus.pending) return;
    await _save(replace: tx.copyWith(status: TransactionStatus.cancelled));
  }

  @override
  Future<void> simulateTopUpReceived(String transactionId) async {
    await _delay();
    final tx = await getTransaction(transactionId);
    if (tx.type != TransactionType.topUp || tx.status != TransactionStatus.pending) {
      throw const WalletException(WalletStrings.topUpNotPending);
    }
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getInt(_keyBalance) ?? initialBalance;
    await _save(balance: balance + tx.amount, replace: tx.copyWith(status: TransactionStatus.success));
  }

  /// Cộng tiền hoàn vào ví. Chỉ các bản giả lập khác gọi (vd. hoàn cọc LFG); bản thật do BE tự cộng.
  Future<WalletTransaction> creditRefund({required int amount, required String description, String? reference}) =>
      credit(type: TransactionType.refund, amount: amount, description: description, reference: reference);

  /// Cộng tiền vào ví (hoàn tiền, giải ngân cho Chủ sân...). Chỉ các bản giả lập khác gọi; bản thật do BE tự cộng.
  Future<WalletTransaction> credit({
    required TransactionType type,
    required int amount,
    required String description,
    String? reference,
  }) async {
    final tx = _newTransaction(
      type: type,
      amount: amount,
      status: TransactionStatus.success,
      description: description,
      reference: reference,
    );
    await _save(balance: await getBalance() + amount, add: tx);
    return tx;
  }

  // ---------------- Rút tiền ----------------

  @override
  Future<List<BankAccount>> getBankAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBankAccounts);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => BankAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<BankAccount> addBankAccount({
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    await _delay();
    final accounts = await getBankAccounts();
    if (accounts.any((a) => a.bankCode == bankCode && a.accountNumber == accountNumber)) {
      throw const WalletException(WalletStrings.accountExists);
    }
    final account = BankAccount(
      id: 'ba-${_now().microsecondsSinceEpoch}-${_counter++}',
      bankCode: bankCode,
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder.trim().toUpperCase(),
    );
    await _saveBankAccounts([...accounts, account]);
    return account;
  }

  @override
  Future<void> removeBankAccount(String accountId) async {
    final accounts = await getBankAccounts();
    await _saveBankAccounts(accounts.where((a) => a.id != accountId).toList());
  }

  @override
  Future<WalletTransaction> requestWithdrawal({required int amount, required BankAccount account}) async {
    await _delay();
    if (amount < WalletRules.minWithdrawal) {
      throw WalletException(WalletStrings.belowMinWithdrawal(Formatters.vnd(WalletRules.minWithdrawal)));
    }
    final total = amount + WalletRules.withdrawalFee;
    final balance = await getBalance();
    if (total > balance) throw const WalletException(WalletStrings.insufficientBalance);

    final tx = _newTransaction(
      type: TransactionType.withdrawal,
      amount: total,
      status: TransactionStatus.pending,
      description: 'Rút tiền về ${account.bankName}',
      reference: '${account.bankCode} ${account.accountNumber} - ${account.accountHolder}',
    );
    await _save(balance: balance - total, add: tx);
    return tx;
  }

  @override
  Future<void> cancelWithdrawal(WalletTransaction withdrawal) async {
    await _delay();
    final tx = await getTransaction(withdrawal.id);
    if (!tx.isPendingWithdrawal) throw const WalletException(WalletStrings.noPendingWithdrawal);
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getInt(_keyBalance) ?? initialBalance;
    await _save(balance: balance + tx.amount, replace: tx.copyWith(status: TransactionStatus.cancelled));
  }

  @override
  Future<void> simulateWithdrawalProcessed(String transactionId, {required bool approved}) async {
    final tx = await getTransaction(transactionId);
    if (tx.type != TransactionType.withdrawal || tx.status != TransactionStatus.pending) return;
    if (approved) {
      await _save(replace: tx.copyWith(status: TransactionStatus.success));
      return;
    }
    // Bị từ chối: hoàn lại tiền vào ví.
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getInt(_keyBalance) ?? initialBalance;
    await _save(balance: balance + tx.amount, replace: tx.copyWith(status: TransactionStatus.failed));
  }

  // ---------------- Lưu trữ ----------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  /// Đọc giao dịch; tự chuyển lệnh nạp quá hạn sang "Hết hạn".
  Future<List<WalletTransaction>> _transactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTransactions);

    if (raw == null) {
      final balance = prefs.getInt(_keyBalance) ?? initialBalance;
      final seed = <WalletTransaction>[
        if (balance > 0)
          WalletTransaction(
            id: 'TX-INIT',
            type: TransactionType.topUp,
            amount: balance,
            status: TransactionStatus.success,
            createdAt: _now().subtract(const Duration(days: 7)),
            description: 'Số dư ban đầu',
          ),
      ];
      await prefs.setInt(_keyBalance, balance);
      await prefs.setString(_keyTransactions, jsonEncode(seed.map((t) => t.toJson()).toList()));
      return seed;
    }

    final now = _now();
    var changed = false;
    final txs = (jsonDecode(raw) as List).map((e) {
      final tx = WalletTransaction.fromJson(e as Map<String, dynamic>);
      final expired = tx.type == TransactionType.topUp &&
          tx.status == TransactionStatus.pending &&
          !tx.createdAt.add(WalletRules.topUpExpiry).isAfter(now);
      if (!expired) return tx;
      changed = true;
      return tx.copyWith(status: TransactionStatus.expired);
    }).toList();

    if (changed) await prefs.setString(_keyTransactions, jsonEncode(txs.map((t) => t.toJson()).toList()));
    return txs;
  }

  Future<void> _save({int? balance, WalletTransaction? add, WalletTransaction? replace}) async {
    final prefs = await SharedPreferences.getInstance();
    final txs = await _transactions();
    if (add != null) txs.add(add);
    if (replace != null) {
      final i = txs.indexWhere((t) => t.id == replace.id);
      if (i >= 0) txs[i] = replace;
    }
    await prefs.setString(_keyTransactions, jsonEncode(txs.map((t) => t.toJson()).toList()));
    if (balance != null) await prefs.setInt(_keyBalance, balance);
  }

  Future<void> _saveBankAccounts(List<BankAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBankAccounts, jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  WalletTransaction _newTransaction({
    required TransactionType type,
    required int amount,
    required TransactionStatus status,
    required String description,
    String? reference,
  }) {
    return WalletTransaction(
      id: 'TX${_now().millisecondsSinceEpoch}${_counter++}',
      type: type,
      amount: amount,
      status: status,
      createdAt: _now(),
      description: description,
      reference: reference,
    );
  }

  /// Mã ngẫu nhiên in hoa, bỏ các ký tự dễ nhầm (0/O, 1/I).
  String _randomCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(length, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}
