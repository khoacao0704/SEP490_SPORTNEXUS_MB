import 'package:flutter/material.dart';

import '../../core/constants/wallet_rules.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/bank_account.dart';
import '../../models/identity_verification.dart';
import '../../theme/app_colors.dart';
import '../profile/identity_verification_screen.dart';
import 'add_bank_account_screen.dart';

/// Pop về `true` khi đã gửi lệnh rút.
class WithdrawScreen extends StatefulWidget {
  /// Ví dùng cho màn này; bỏ trống = ví người chơi. Chủ sân truyền ví của Chủ sân.
  final WalletRepository? wallet;

  /// Mức tối thiểu, phí, có cần eKYC không. Mặc định: luật Chủ sân; người chơi truyền [WithdrawalPolicy.player].
  final WithdrawalPolicy policy;

  const WithdrawScreen({super.key, this.wallet, this.policy = WithdrawalPolicy.owner});

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

  /// Hồ sơ eKYC (chỉ tải khi [WithdrawalPolicy.requiresIdentity]); `null` = chưa gửi.
  IdentityVerification? _identity;

  WithdrawalPolicy get _policy => widget.policy;

  /// Điều kiện rút của BE; `null` (bản giả lập / lỗi tải) thì dùng [_policy].
  WithdrawalConfig? _config;

  int get _minAmount => _config?.minAmount ?? _policy.minAmount;
  int get _fee => _config?.fee ?? _policy.fee;

  /// BE chặn rút vì lý do khác eKYC / chưa có tài khoản nhận (hai lý do này có ô riêng trên màn).
  String? get _blockedReason {
    final c = _config;
    if (c == null || c.canWithdraw) return null;
    if (c.blockedCode == WithdrawalConfig.kycRequired || c.blockedCode == WithdrawalConfig.noBankAccount) return null;
    return c.blockedReason;
  }

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
      final identity = _policy.requiresIdentity ? await AppRepositories.identity.getMyVerification() : null;
      WithdrawalConfig? config;
      try {
        config = await _wallet.getWithdrawalConfig();
      } catch (_) {
        config = null; // vẫn cho xem màn; BE kiểm lại khi gửi lệnh
      }
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _config = config;
        _balance = balance;
        _accounts = accounts;
        _selectedAccount ??= accounts.isEmpty ? null : accounts.first;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Câu lỗi của BE (vd. tài khoản chưa được phép đổi Điểm ra tiền); lỗi khác thì báo chung.
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
    if (amount < _minAmount) {
      return WalletStrings.belowMinWithdrawal(Formatters.vnd(_minAmount));
    }
    // Phí trừ vào số rút (BE 27/11): ví chỉ bị trừ đúng số rút.
    if (amount <= _fee) return WalletStrings.invalidAmount;
    if (amount > _balance) return WalletStrings.insufficientBalance;
    return null;
  }

  /// Chưa eKYC (hoặc bị từ chối) → mở màn chụp CCCD; đang chờ duyệt → báo. `true` = được đổi.
  Future<bool> _ensureIdentity() async {
    if (!_policy.requiresIdentity) return true;
    final identity = _identity;
    if (identity?.isApproved ?? false) return true;
    if (identity?.status == IdentityStatus.pending) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(WalletStrings.identityPending)));
      return false;
    }
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()));
    if (mounted) _load();
    return false;
  }

  Future<void> _addAccount() async {
    final account = await Navigator.push<BankAccount>(
      context,
      MaterialPageRoute(builder: (_) => AddBankAccountScreen(wallet: widget.wallet)),
    );
    if (account == null || !mounted) return;
    _load(); // BE có thể đã hết chặn "chưa có tài khoản nhận"
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
    if (!await _ensureIdentity() || !mounted) return;
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
                if (_blockedReason != null) ...[
                  _buildBlockedBanner(_blockedReason!),
                  const SizedBox(height: 16),
                ],
                if (_policy.requiresIdentity && !(_identity?.isApproved ?? false)) ...[
                  _buildIdentityBanner(),
                  const SizedBox(height: 16),
                ],
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
                    onPressed: _isSubmitting || _selectedAccount == null || _blockedReason != null ? null : _submit,
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

  Widget _buildBlockedBanner(String reason) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.block, color: Colors.red.shade700),
            const SizedBox(width: 10),
            Expanded(child: Text(reason, style: TextStyle(fontSize: 13, color: Colors.red.shade700))),
          ],
        ),
      );

  Widget _buildIdentityBanner() {
    final pending = _identity?.status == IdentityStatus.pending;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pending ? AppColors.tagOrangeBg : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(pending ? Icons.hourglass_top : Icons.badge_outlined,
              color: pending ? AppColors.tagOrangeText : Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending ? WalletStrings.identityPending : WalletStrings.identityRequired,
                  style: TextStyle(fontSize: 13, color: pending ? AppColors.tagOrangeText : Colors.red.shade700),
                ),
                if (!pending)
                  TextButton(
                    onPressed: _ensureIdentity,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    child: const Text(WalletStrings.verifyNow),
                  ),
              ],
            ),
          ),
        ],
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
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                Formatters.vnd(_balance),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
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
    final fee = _fee == 0 ? WalletStrings.free : Formatters.vnd(_fee);
    // Người chơi: ghi đúng chữ thẻ 41, số tiền chuyển khoản thật nên dùng "đ".
    final note = _policy.requiresIdentity
        ? WalletStrings.playerWithdrawalNote(Formatters.bankVnd(_minAmount), Formatters.bankVnd(_fee))
        : WalletStrings.minWithdrawalNote(Formatters.vnd(_minAmount), fee);
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
              suffixText: 'Điểm',
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
                onPressed: () => _setAmount(_balance),
                backgroundColor: AppColors.lightGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(note, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (_fee > 0 && _amount > _fee) ...[
            const SizedBox(height: 4),
            Text(
              WalletStrings.withdrawReceive(Formatters.bankVnd(_amount - _fee), Formatters.bankVnd(_fee)),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
          ],
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
