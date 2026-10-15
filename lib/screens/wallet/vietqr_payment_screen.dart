import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/bank_account.dart';
import '../../models/wallet_transaction.dart';
import '../../theme/app_colors.dart';

/// Màn chờ chuyển khoản VietQR cho một lệnh nạp.
/// Pop về `true` khi BE xác nhận đã nhận tiền, `false` khi hết hạn / bị hủy.
class VietQrPaymentScreen extends StatefulWidget {
  final TopUpOrder order;

  /// Chu kỳ hỏi lại trạng thái; test có thể rút ngắn.
  final Duration pollInterval;

  /// Ví tạo lệnh nạp; bỏ trống = ví người chơi.
  final WalletRepository? wallet;

  const VietQrPaymentScreen({
    super.key,
    required this.order,
    this.pollInterval = const Duration(seconds: 3),
    this.wallet,
  });

  @override
  State<VietQrPaymentScreen> createState() => _VietQrPaymentScreenState();
}

class _VietQrPaymentScreenState extends State<VietQrPaymentScreen> {
  WalletRepository get _wallet => widget.wallet ?? AppRepositories.wallet;

  Timer? _countdownTimer;
  Timer? _pollTimer;
  late int _secondsLeft;
  bool _isSimulating = false;
  bool _finished = false;

  TopUpOrder get _order => widget.order;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _remainingSeconds();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsLeft = _remainingSeconds());
      if (_secondsLeft == 0) _checkStatus();
    });
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _checkStatus());
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  int _remainingSeconds() {
    final s = _order.expiresAt.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
  }

  Future<void> _checkStatus() async {
    if (_finished) return;
    WalletTransaction tx;
    try {
      tx = await _wallet.getTransaction(_order.transactionId);
    } catch (_) {
      return; // lỗi mạng tạm thời: lần hỏi sau thử lại
    }
    if (!mounted || _finished) return;

    switch (tx.status) {
      case TransactionStatus.pending:
        return;
      case TransactionStatus.success:
        _finish();
        await _showResultDialog(success: true);
        if (mounted) Navigator.pop(context, true);
      case TransactionStatus.expired:
      case TransactionStatus.failed:
      case TransactionStatus.cancelled:
        _finish();
        await _showResultDialog(success: false);
        if (mounted) Navigator.pop(context, false);
    }
  }

  void _finish() {
    _finished = true;
    _stopTimers();
  }

  Future<void> _simulatePaid() async {
    final simulator = _wallet;
    if (simulator is! SandboxPaymentSimulator) return;
    setState(() => _isSimulating = true);
    try {
      await (simulator as SandboxPaymentSimulator).simulateTopUpReceived(_order.transactionId);
    } on WalletException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isSimulating = false);
    await _checkStatus();
  }

  Future<void> _confirmCancel() async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(WalletStrings.cancelTopUp),
        content: const Text(WalletStrings.cancelTopUpConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(WalletStrings.keepWaiting)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(WalletStrings.cancelTopUp, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (cancel != true || !mounted) return;
    _finish();
    await _wallet.cancelTopUp(_order.transactionId);
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _showResultDialog({required bool success}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: success ? AppColors.lightGreen : AppColors.tagOrangeBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check : Icons.timer_off_outlined,
                color: success ? AppColors.primaryGreen : AppColors.tagOrangeText,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success ? WalletStrings.topUpSuccessTitle : WalletStrings.topUpExpiredTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              success
                  ? WalletStrings.topUpSuccessMessage(Formatters.vnd(_order.amount))
                  : WalletStrings.topUpExpiredMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  success ? WalletStrings.done : WalletStrings.understood,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(WalletStrings.copied), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final mmss = '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';
    final isSandbox = _wallet is SandboxPaymentSimulator;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmCancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMain),
            onPressed: _confirmCancel,
          ),
          title: const Text(
            WalletStrings.vietQrTitle,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.tagOrangeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: AppColors.tagOrangeText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        WalletStrings.expiresIn(mmss),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildQrCard(),
              const SizedBox(height: 16),
              _buildTransferInfo(),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(WalletStrings.waitingForPayment, style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isSandbox) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isSimulating ? null : _simulatePaid,
                    icon: _isSimulating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.science_outlined, color: AppColors.primaryGreen),
                    label: const Text(
                      WalletStrings.simulatePaid,
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  WalletStrings.sandboxNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: _confirmCancel,
                child: const Text(WalletStrings.cancelTopUp, style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Text(
            WalletStrings.scanToPay,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          QrImageView(
            data: _order.qrData,
            size: 200,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.authPrimary),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.authPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.vnd(_order.amount),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferInfo() {
    /// [copyValue]: giá trị dán vào app ngân hàng (null = không có nút sao chép).
    Widget row(String label, String value, {String? copyValue, bool highlight = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: highlight ? AppColors.tagOrangeText : AppColors.textMain,
                ),
              ),
            ),
            if (copyValue != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 18, color: AppColors.primaryGreen),
                onPressed: () => _copy(copyValue),
              )
            else
              const SizedBox(width: 40),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            WalletStrings.orTransferManually,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 4),
          row(WalletStrings.bank, _order.receiverBankName),
          row(
            WalletStrings.accountNumber,
            _order.receiverAccountNumber,
            copyValue: _order.receiverAccountNumber.replaceAll(' ', ''),
          ),
          row(WalletStrings.accountName, _order.receiverAccountName),
          row(WalletStrings.amount, Formatters.vnd(_order.amount), copyValue: '${_order.amount}'),
          row(
            WalletStrings.transferContent,
            _order.transferContent,
            copyValue: _order.transferContent,
            highlight: true,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12, top: 4),
            child: Text(
              WalletStrings.transferContentWarning,
              style: TextStyle(fontSize: 12, color: AppColors.tagOrangeText),
            ),
          ),
        ],
      ),
    );
  }
}
