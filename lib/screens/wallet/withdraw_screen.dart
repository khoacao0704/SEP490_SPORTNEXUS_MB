import 'package:flutter/material.dart';

import '../../core/constants/wallet_rules.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/bank_account.dart';
import '../../theme/app_colors.dart';
import 'add_bank_account_screen.dart';

/// Pop về `true` khi đã gửi lệnh rút.
class WithdrawScreen extends StatefulWidget {
  /// Ví dùng cho màn này; bỏ trống = ví người chơi. Chủ sân truyền ví của Chủ sân.
  final WalletRepository? wallet;

  const WithdrawScreen({super.key, this.wallet});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  WalletRepository get _wallet => widget.wallet ?? AppRepositories.wallet;

  final _amountController = TextEditingController();
  static const List<int> _quickAmounts = [100000, 200000, 500000];

  int _balance = 0;
  List<BankAccount> _accounts = [];
  BankAccount? _selectedAccount;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  String? _amountError;

  int get _amount => ThousandsInputFormatter.parse(_amountController.text);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final balance = await _wallet.getBalance();
      final accounts = await _wallet.getBankAccounts();
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _accounts = accounts;
        _selectedAccount ??= accounts.isEmpty ? null : accounts.first;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Câu lỗi của BE (vd. tài khoản chưa được phép rút tiền); lỗi khác thì báo chung.
        _loadError = e is WalletException ? e.message : WalletStrings.loadError;
      });
    }
  }

  void _setAmount(int amount) {
    _amountController.text = Formatters.currency(amount);
    setState(() => _amountError = null);
  }

  String? _validateAmount() {
    final amount = _amount;
    if (amount <= 0) return WalletStrings.invalidAmount;
    if (amount < WalletRules.minWithdrawal) {
      return WalletStrings.belowMinWithdrawal(Formatters.vnd(WalletRules.minWithdrawal));
    }
    if (amount + WalletRules.withdrawalFee > _balance) return WalletStrings.insufficientBalance;
    return null;
  }

  Future<void> _addAccount() async {
    final account = await Navigator.push<BankAccount>(
      context,
      MaterialPageRoute(builder: (_) => AddBankAccountScreen(wallet: widget.wallet)),
    );
    if (account == null || !mounted) return;
    setState(() {
      // Chỉ một tài khoản: tài khoản mới thay cho tài khoản cũ.
      _accounts = _wallet.singleBankAccount ? [account] : [..._accounts, account];
      _selectedAccount = account;
    });
  }

  Future<void> _removeAccount(BankAccount account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(WalletStrings.removeAccount),
        content: Text('${WalletStrings.removeAccountConfirm}\n\n${account.bankName} • ${account.maskedNumber}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(WalletStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(WalletStrings.removeAccount, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _wallet.removeBankAccount(account.id);
    if (!mounted) return;
    setState(() {
      _accounts = _accounts.where((a) => a.id != account.id).toList();
      if (_selectedAccount?.id == account.id) _selectedAccount = _accounts.isEmpty ? null : _accounts.first;
    });
  }

  Future<void> _submit() async {
    final error = _validateAmount();
    setState(() => _amountError = error);
    final account = _selectedAccount;
    if (error != null || account == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(WalletStrings.confirmWithdrawTitle),
        content: Text(
          WalletStrings.confirmWithdrawMessage(
            Formatters.vnd(_amount),
            '${account.bankName} ${account.maskedNumber} (${account.accountHolder})',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(WalletStrings.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text(WalletStrings.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final amount = _amount;
      await _wallet.requestWithdrawal(amount: amount, account: account);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.schedule_send, color: AppColors.primaryGreen, size: 40),
          title: const Text(WalletStrings.withdrawSubmittedTitle),
          content: Text(WalletStrings.withdrawSubmittedMessage(Formatters.vnd(amount)), textAlign: TextAlign.center),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text(WalletStrings.understood))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on WalletException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      _load(); // số dư có thể đã đổi
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          WalletStrings.withdrawTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _load, child: const Text(WalletStrings.retry)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBalance(),
                const SizedBox(height: 16),
                _buildAmountCard(),
                const SizedBox(height: 16),
                _buildAccountsCard(),
                const SizedBox(height: 12),
                const Text(
                  WalletStrings.withdrawProcessingNote,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading || _loadError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting || _selectedAccount == null ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.authPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.cardBorder,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                        : const Text(WalletStrings.withdrawButton, style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBalance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primaryGreen, AppColors.darkGreen]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(WalletStrings.availableBalance, style: TextStyle(color: Colors.white70)),
          ),
          Text(
            Formatters.vnd(_balance),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    final fee = WalletRules.withdrawalFee == 0 ? WalletStrings.free : Formatters.vnd(WalletRules.withdrawalFee);
    return _card(
      title: WalletStrings.withdrawAmountLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            onChanged: (_) => setState(() => _amountError = null),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'đ',
              errorText: _amountError,
              errorMaxLines: 2,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._quickAmounts.map(
                (a) => ActionChip(
                  label: Text(Formatters.currency(a)),
                  onPressed: () => _setAmount(a),
                  backgroundColor: AppColors.white,
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
              ActionChip(
                label: const Text(WalletStrings.withdrawAll),
                onPressed: () => _setAmount((_balance - WalletRules.withdrawalFee).clamp(0, _balance)),
                backgroundColor: AppColors.lightGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            WalletStrings.minWithdrawalNote(Formatters.vnd(WalletRules.minWithdrawal), fee),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsCard() {
    final replaceAccount = _wallet.singleBankAccount && _accounts.isNotEmpty;
    return _card(
      title: WalletStrings.receiveAccount,
      child: Column(
        children: [
          if (_accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(WalletStrings.noBankAccount, style: TextStyle(color: AppColors.textSecondary)),
            ),
          ..._accounts.map((a) {
            final selected = a.id == _selectedAccount?.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              // Material trong suốt: thẻ ngoài có nền trắng sẽ che hiệu ứng bấm của ListTile.
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? AppColors.primaryGreen : AppColors.cardBorder,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  tileColor: selected ? AppColors.lightGreen : AppColors.white,
                  onTap: () => setState(() => _selectedAccount = a),
                  leading: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: AppColors.primaryGreen,
                  ),
                  title: Text(
                    '${a.bankName} • ${a.maskedNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(a.accountHolder, style: const TextStyle(fontSize: 12)),
                  trailing: _wallet.singleBankAccount
                      ? null
                      : IconButton(
                          tooltip: WalletStrings.removeAccount,
                          icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                          onPressed: () => _removeAccount(a),
                        ),
                ),
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addAccount,
              icon: Icon(replaceAccount ? Icons.edit_outlined : Icons.add, color: AppColors.primaryGreen),
              label: Text(
                replaceAccount ? WalletStrings.changeBankAccount : WalletStrings.addBankAccount,
                style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryGreen),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
