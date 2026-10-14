import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/lfg_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/lfg_match.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../wallet/vietqr_payment_screen.dart';

/// Thông tin kèo hiển thị ở màn thanh toán (dùng chung cho Flash Claim và tạo kèo).
class LfgPaymentSummary {
  final String heading;
  final Sport sport;
  final LfgFormat format;
  final String facilityName;
  final String district;
  final DateTime start;
  final DateTime end;

  const LfgPaymentSummary({
    required this.heading,
    required this.sport,
    required this.format,
    required this.facilityName,
    required this.district,
    required this.start,
    required this.end,
  });
}

enum _Method { wallet, vietQr }

/// Thanh toán cọc LFG trong thời gian giữ chỗ 10 phút.
/// Pop về [LfgMatch] khi thành công; thoát ra hoặc hết giờ thì gọi [onRelease] để nhả chỗ.
class LfgPaymentScreen extends StatefulWidget {
  final LfgPaymentSummary summary;
  final int amount;
  final DateTime expiresAt;

  /// Trừ ví và xác nhận chỗ (repository làm trong một giao dịch).
  final Future<LfgMatch> Function() onConfirm;
  final Future<void> Function() onRelease;

  const LfgPaymentScreen({
    super.key,
    required this.summary,
    required this.amount,
    required this.expiresAt,
    required this.onConfirm,
    required this.onRelease,
  });

  @override
  State<LfgPaymentScreen> createState() => _LfgPaymentScreenState();
}

class _LfgPaymentScreenState extends State<LfgPaymentScreen> {
  Timer? _timer;
  late int _secondsLeft;
  int? _balance;
  _Method _method = _Method.wallet;
  bool _isPaying = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsLeft = _remaining());
      if (_secondsLeft == 0) _onExpired();
    });
    _loadBalance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_done) widget.onRelease();
    super.dispose();
  }

  int _remaining() {
    final s = widget.expiresAt.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await AppRepositories.wallet.getBalance();
      if (mounted) setState(() => _balance = balance);
    } catch (_) {
      // Không có số dư thì vẫn cho chọn VietQR.
    }
  }

  Future<void> _onExpired() async {
    _timer?.cancel();
    if (_isPaying) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.timer_off_outlined, color: Colors.red, size: 40),
        title: const Text(LfgStrings.holdExpiredTitle),
        content: const Text(LfgStrings.holdExpiredMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(LfgStrings.understood)),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  bool get _walletEnough => _balance != null && _balance! >= widget.amount;

  Future<void> _pay() async {
    if (_method == _Method.wallet && !_walletEnough) {
      _showError(LfgStrings.insufficient);
      return;
    }
    setState(() => _isPaying = true);
    try {
      if (_method == _Method.vietQr) {
        // Chuyển khoản đúng số tiền cọc vào ví rồi trừ ví (BE xác nhận chuyển khoản).
        final order = await AppRepositories.wallet.createTopUp(widget.amount);
        if (!mounted) return;
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => VietQrPaymentScreen(order: order)),
        );
        if (paid != true) {
          if (mounted) setState(() => _isPaying = false);
          _loadBalance();
          return;
        }
      }
      final match = await widget.onConfirm();
      _done = true;
      if (mounted) Navigator.pop(context, match);
    } on LfgException catch (e) {
      _fail(e.message);
    } on WalletException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(LfgStrings.loadError);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _isPaying = false);
    _loadBalance();
    _showError(message);
    if (_secondsLeft == 0) _onExpired();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final urgent = _secondsLeft < 120;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          LfgStrings.paymentTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: urgent ? const Color(0xFFFFEBEE) : AppColors.tagOrangeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: urgent ? Colors.red : AppColors.tagOrangeText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LfgStrings.holdBanner('$minutes:$seconds'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: urgent ? Colors.red : AppColors.tagOrangeText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.heading,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.lightGreen,
                      child: Icon(sportIcon(s.sport), color: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.sport.label} • ${s.format.label}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                          ),
                          Text(
                            '${s.facilityName} • ${s.district}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            Formatters.slotLabel(s.start, s.end),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            LfgStrings.paymentMethod,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          _methodTile(
            _Method.wallet,
            Icons.account_balance_wallet_outlined,
            LfgStrings.payWallet,
            _balance == null ? '...' : LfgStrings.balance(_balance!),
            warning: _balance != null && !_walletEnough,
          ),
          const SizedBox(height: 8),
          _methodTile(_Method.vietQr, Icons.qr_code_2, LfgStrings.payVietQr, LfgStrings.payVietQrHint),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      LfgStrings.amountToPay,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Formatters.vnd(widget.amount),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isPaying || _secondsLeft == 0 ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isPaying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(LfgStrings.confirmPay, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
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
        onTap: _isPaying ? null : () => setState(() => _method = method),
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
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: warning ? Colors.red : AppColors.textSecondary),
                    ),
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
