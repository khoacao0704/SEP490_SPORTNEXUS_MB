import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/split_payment_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/split_payment.dart';
import '../../theme/app_colors.dart';
import '../wallet/vietqr_payment_screen.dart';

String splitStatusLabel(SplitStatus status) {
  switch (status) {
    case SplitStatus.pending:
      return SplitPaymentStrings.statusPending;
    case SplitStatus.completed:
      return SplitPaymentStrings.statusCompleted;
    case SplitStatus.expired:
      return SplitPaymentStrings.statusExpired;
  }
}

({Color bg, Color fg}) splitStatusColors(SplitStatus status) {
  switch (status) {
    case SplitStatus.pending:
      return (bg: AppColors.tagOrangeBg, fg: AppColors.tagOrangeText);
    case SplitStatus.completed:
      return (bg: AppColors.tagGreenBg, fg: AppColors.tagGreenText);
    case SplitStatus.expired:
      return (bg: const Color(0xFFFFEBEE), fg: const Color(0xFFC62828));
  }
}

enum _Method { wallet, vietQr }

/// Chi tiết một lượt chia tiền. Người đặt thấy link/mã để gửi nhóm; người nhận link trả phần của mình.
class SplitPaymentScreen extends StatefulWidget {
  final String splitId;
  final SplitPayment? initial;

  /// Chu kỳ tải lại để thấy người khác vừa trả; test có thể tắt.
  final Duration? refreshInterval;

  const SplitPaymentScreen({
    super.key,
    required this.splitId,
    this.initial,
    this.refreshInterval = const Duration(seconds: 5),
  });

  @override
  State<SplitPaymentScreen> createState() => _SplitPaymentScreenState();
}

class _SplitPaymentScreenState extends State<SplitPaymentScreen> {
  SplitPayment? _split;
  String? _myId;
  String? _error;
  int? _balance;
  _Method _method = _Method.wallet;
  bool _isBusy = false;
  Timer? _ticker;
  Timer? _refresher;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _split = widget.initial;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final wasPending = _split?.status(_now) == SplitStatus.pending;
      setState(() => _now = DateTime.now());
      if (wasPending && _split?.status(_now) != SplitStatus.pending) _load();
    });
    final interval = widget.refreshInterval;
    if (interval != null) _refresher = Timer.periodic(interval, (_) => _load());
    _load();
    _loadBalance();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _refresher?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final split = await AppRepositories.split.getById(widget.splitId);
      final user = await AppRepositories.auth.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _split = split;
        _myId = user?.id;
        _error = null;
      });
    } on SplitPaymentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = SplitPaymentStrings.loadError);
    }
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await AppRepositories.paymentWallet.getBalance();
      if (mounted) setState(() => _balance = balance);
    } catch (_) {
      // Không có số dư thì vẫn cho chọn VietQR.
    }
  }

  Future<void> _pay() async {
    final split = _split!;
    final amount = split.nextUnpaid?.amount ?? 0;
    if (_method == _Method.wallet && (_balance == null || _balance! < amount)) {
      _snack(SplitPaymentStrings.insufficient, error: true);
      return;
    }
    setState(() => _isBusy = true);
    try {
      if (_method == _Method.vietQr) {
        // Chuyển khoản đúng số tiền vào ví rồi trừ ví (BE xác nhận chuyển khoản).
        final order = await AppRepositories.paymentWallet.createTopUp(amount);
        if (!mounted) return;
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => VietQrPaymentScreen(order: order, wallet: AppRepositories.paymentWallet)),
        );
        if (paid != true) return;
      }
      final updated = await AppRepositories.split.payShare(split.code);
      if (!mounted) return;
      setState(() => _split = updated);
      _snack(SplitPaymentStrings.paidMessage);
    } on SplitPaymentException catch (e) {
      _snack(e.message, error: true);
    } on WalletException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack(SplitPaymentStrings.loadError, error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
      _loadBalance();
    }
  }

  Future<void> _simulateFriend() async {
    setState(() => _isBusy = true);
    try {
      final updated = await (AppRepositories.split as SandboxSplitSimulator).simulateFriendPaid(_split!.id);
      if (mounted) setState(() => _split = updated);
    } on SplitPaymentException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _split!.shareLink));
    _snack(SplitPaymentStrings.copied);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : AppColors.primaryGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final split = _split;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          SplitPaymentStrings.detailTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: split == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                        TextButton(onPressed: _load, child: const Text(SplitPaymentStrings.retry)),
                      ],
                    ),
            )
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _load,
              child: _buildBody(split),
            ),
      bottomNavigationBar: split == null ? null : _buildPayBar(split),
    );
  }

  bool _isBooker(SplitPayment s) => s.bookerId == _myId;

  bool _canPay(SplitPayment s) =>
      _myId != null && !_isBooker(s) && !s.hasPaid(_myId!) && s.status(_now) == SplitStatus.pending;

  Widget _buildBody(SplitPayment s) {
    final status = s.status(_now);
    final colors = splitStatusColors(status);
    final left = s.expiresAt.difference(_now);
    final seconds = left.isNegative ? 0 : left.inSeconds;
    final countdown = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final isSandbox = AppRepositories.split is SandboxSplitSimulator;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (status == SplitStatus.pending) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: seconds < 300 ? const Color(0xFFFFEBEE) : AppColors.tagOrangeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: seconds < 300 ? Colors.red : AppColors.tagOrangeText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    SplitPaymentStrings.countdown(countdown),
                    style: TextStyle(fontWeight: FontWeight.bold, color: seconds < 300 ? Colors.red : AppColors.tagOrangeText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SplitPaymentStrings.bookedBy(_isBooker(s) ? '${s.bookerName} ${SplitPaymentStrings.you}' : s.bookerName),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(s.facilityName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            Text('${s.sportLabel} • ${s.location}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              s.schedule,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(12)),
              child: Text(splitStatusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.fg)),
            ),
          ],
        )),
        const SizedBox(height: 12),
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    SplitPaymentStrings.progress(s.paidCount, s.parts),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                  ),
                ),
                Text(
                  '${SplitPaymentStrings.total} ${Formatters.vnd(s.totalAmount)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.paidCount / s.parts,
                minHeight: 6,
                color: AppColors.primaryGreen,
                backgroundColor: AppColors.divider,
              ),
            ),
            const SizedBox(height: 8),
            for (final share in s.shares)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  share.isPaid ? Icons.check_circle : Icons.schedule,
                  color: share.isPaid ? AppColors.primaryGreen : AppColors.textSecondary,
                ),
                title: Text(
                  share.isPaid
                      ? '${share.payerName}${share.payerId == _myId ? ' ${SplitPaymentStrings.you}' : ''}'
                      : SplitPaymentStrings.waiting,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: share.isPaid ? AppColors.textMain : AppColors.textSecondary,
                  ),
                ),
                subtitle: Text(SplitPaymentStrings.shareRow(share.index)),
                trailing: Text(
                  Formatters.vnd(share.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: share.isPaid ? AppColors.primaryGreen : AppColors.textMain,
                  ),
                ),
              ),
          ],
        )),
        if (_isBooker(s) && status == SplitStatus.pending) ...[
          const SizedBox(height: 12),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                SplitPaymentStrings.shareLinkTitle,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  s.code,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: SelectableText(s.shareLink, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text(SplitPaymentStrings.copyLink),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(SplitPaymentStrings.shareLinkNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (isSandbox) ...[
                const Divider(height: 20),
                TextButton.icon(
                  onPressed: _isBusy ? null : _simulateFriend,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text(SplitPaymentStrings.simulateFriend),
                ),
              ],
            ],
          )),
        ],
        if (_myId != null && !_isBooker(s) && s.hasPaid(_myId!) && status == SplitStatus.pending) ...[
          const SizedBox(height: 12),
          const Text(SplitPaymentStrings.paid, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
        if (_canPay(s)) ...[
          const SizedBox(height: 16),
          const Text(
            SplitPaymentStrings.paymentMethod,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          _methodTile(
            _Method.wallet,
            Icons.account_balance_wallet_outlined,
            SplitPaymentStrings.payWallet,
            _balance == null ? '...' : SplitPaymentStrings.balance(_balance!),
            warning: _balance != null && _balance! < (s.nextUnpaid?.amount ?? 0),
          ),
          const SizedBox(height: 8),
          _methodTile(_Method.vietQr, Icons.qr_code_2, SplitPaymentStrings.payVietQr, SplitPaymentStrings.payVietQrHint),
        ],
        if (status == SplitStatus.completed) ...[
          const SizedBox(height: 12),
          _card(Column(
            children: [
              const Text(
                SplitPaymentStrings.completedNote,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMain),
              ),
            ],
          )),
        ],
        if (status == SplitStatus.expired) ...[
          const SizedBox(height: 12),
          const Text(
            SplitPaymentStrings.expiredNote,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget? _buildPayBar(SplitPayment s) {
    if (!_canPay(s)) return null;
    final amount = s.nextUnpaid?.amount ?? 0;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.divider))),
        child: Row(
          children: [
            Expanded(
              child: Text(
                SplitPaymentStrings.yourShare(amount),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
              ),
            ),
            ElevatedButton(
              onPressed: _isBusy ? null : _pay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isBusy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text(SplitPaymentStrings.payShare, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );

  Widget _methodTile(_Method method, IconData icon, String title, String subtitle, {bool warning = false}) {
    final selected = _method == method;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isBusy ? null : () => setState(() => _method = method),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primaryGreen : AppColors.cardBorder, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: warning ? Colors.red : AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
