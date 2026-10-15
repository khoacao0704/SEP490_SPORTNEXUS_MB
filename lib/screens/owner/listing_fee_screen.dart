import 'package:flutter/material.dart';

import '../../core/constants/owner_rules.dart';
import '../../core/strings/owner_finance_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/owner_finance.dart';
import '../../theme/app_colors.dart';
import '../wallet/vietqr_payment_screen.dart';

/// Hóa đơn quá hạn cũ nhất (nếu có) — đang nợ thì cơ sở bị ẩn và không rút tiền được.
ListingFeeBill? overdueBill(List<ListingFeeBill> bills, DateTime now) {
  final overdue = bills.where((b) => b.status(now) == FeeStatus.overdue).toList();
  return overdue.isEmpty ? null : overdue.last;
}

/// Trả một hóa đơn phí: trừ ví hoặc chuyển khoản VietQR (nạp đúng số tiền vào ví rồi trừ).
/// Trả về `true` nếu đã trả xong.
Future<bool> payListingFee(BuildContext context, ListingFeeBill bill) async {
  final wallet = AppRepositories.ownerWallet;
  int balance;
  try {
    balance = await wallet.getBalance();
  } catch (_) {
    balance = 0;
  }
  if (!context.mounted) return false;

  final method = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              OwnerFinanceStrings.payTitle(bill.month),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.vnd(bill.amount),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 12),
            ListTile(
              enabled: balance >= bill.amount,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text(OwnerFinanceStrings.payByWallet),
              subtitle: Text(
                balance >= bill.amount
                    ? OwnerFinanceStrings.walletBalanceNote(balance)
                    : '${OwnerFinanceStrings.insufficient} • ${OwnerFinanceStrings.walletBalanceNote(balance)}',
              ),
              onTap: () => Navigator.pop(sheetContext, 'wallet'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text(OwnerFinanceStrings.payByVietQr),
              subtitle: const Text(OwnerFinanceStrings.vietQrNote),
              onTap: () => Navigator.pop(sheetContext, 'vietqr'),
            ),
          ],
        ),
      ),
    ),
  );
  if (method == null || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    if (method == 'vietqr') {
      final order = await wallet.createTopUp(bill.amount);
      if (!context.mounted) return false;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VietQrPaymentScreen(order: order, wallet: wallet),
        ),
      );
      if (paid != true) return false;
    }
    await AppRepositories.owner.payListingFee(bill.id);
    messenger.showSnackBar(SnackBar(content: Text(OwnerFinanceStrings.paid(bill.amount))));
    return true;
  } on OwnerException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
  } on WalletException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
  }
  return false;
}

/// Banner nhắc phí: quá hạn (đỏ, cơ sở đang bị ẩn) hoặc sắp tới hạn (cam). Không có phí chưa trả thì ẩn.
class ListingFeeBanner extends StatefulWidget {
  /// Đổi giá trị để banner tải lại.
  final int revision;
  final VoidCallback? onPaid;

  const ListingFeeBanner({super.key, this.revision = 0, this.onPaid});

  @override
  State<ListingFeeBanner> createState() => _ListingFeeBannerState();
}

class _ListingFeeBannerState extends State<ListingFeeBanner> {
  List<ListingFeeBill> _bills = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ListingFeeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    try {
      final bills = await AppRepositories.owner.getListingFees();
      if (mounted) setState(() => _bills = bills);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = overdueBill(_bills, now);
    final due = _bills.where((b) => b.status(now) == FeeStatus.due).firstOrNull;
    final bill = overdue ?? due;
    if (bill == null) return const SizedBox.shrink();
    final isOverdue = overdue != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.shade50 : AppColors.tagOrangeBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isOverdue ? Icons.visibility_off_outlined : Icons.receipt_long_outlined,
                size: 18,
                color: isOverdue ? Colors.red.shade700 : AppColors.tagOrangeText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOverdue
                      ? OwnerFinanceStrings.overdueBanner(bill.month, bill.amount)
                      : OwnerFinanceStrings.dueBanner(bill.month, bill.amount, bill.dueDate),
                  style: TextStyle(fontSize: 13, color: isOverdue ? Colors.red.shade700 : AppColors.tagOrangeText),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                if (await payListingFee(context, bill)) {
                  _load();
                  widget.onPaid?.call();
                }
              },
              style: TextButton.styleFrom(foregroundColor: isOverdue ? Colors.red.shade700 : AppColors.tagOrangeText),
              child: const Text(OwnerFinanceStrings.pay, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phí duy trì: quy định, phí tạm tính tháng này, các tháng đã chốt và nút trả.
class ListingFeeScreen extends StatefulWidget {
  const ListingFeeScreen({super.key});

  @override
  State<ListingFeeScreen> createState() => _ListingFeeScreenState();
}

class _ListingFeeScreenState extends State<ListingFeeScreen> {
  List<ListingFeeBill> _bills = [];
  MonthlyRevenue? _current;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bills = await AppRepositories.owner.getListingFees();
      final current = await AppRepositories.owner.getMonthlyRevenue(DateTime.now());
      if (mounted) {
        setState(() {
          _bills = bills;
          _current = current;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = OwnerFinanceStrings.loadError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = _current;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerFinanceStrings.feeTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: AppColors.textSecondary))
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
                      child: const Text(
                        OwnerFinanceStrings.feeRule,
                        style: TextStyle(fontSize: 13, color: AppColors.darkGreen, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (current != null)
                      _card(
                        children: [
                          Text(
                            OwnerFinanceStrings.currentMonth(current.month),
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.vnd(current.listingFee),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${OwnerFinanceStrings.billRevenue(current.total)} • '
                            '${OwnerFinanceStrings.currentMonthNote(DateTime(current.month.year, current.month.month + 1, ListingFeeRules.dueDay))}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      OwnerFinanceStrings.bills,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 8),
                    if (_bills.isEmpty)
                      const Text(OwnerFinanceStrings.noBills, style: TextStyle(color: AppColors.textSecondary))
                    else
                      for (final b in _bills) _billTile(b, now),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _billTile(ListingFeeBill b, DateTime now) {
    final status = b.status(now);
    final (label, fg, bg) = switch (status) {
      FeeStatus.paid => (OwnerFinanceStrings.statusPaid, AppColors.tagGreenText, AppColors.tagGreenBg),
      FeeStatus.due => (OwnerFinanceStrings.statusDue, AppColors.tagOrangeText, AppColors.tagOrangeBg),
      FeeStatus.overdue => (OwnerFinanceStrings.statusOverdue, Colors.red.shade700, Colors.red.shade50),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status == FeeStatus.overdue ? Colors.red.shade200 : AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      OwnerFinanceStrings.monthLabel(b.month),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.vnd(b.amount),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                Text(
                  '${OwnerFinanceStrings.billRevenue(b.revenue)} • '
                  '${b.paidAt != null ? OwnerFinanceStrings.paidOn(b.paidAt!) : OwnerFinanceStrings.dueOn(b.dueDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (status != FeeStatus.paid)
            ElevatedButton(
              onPressed: () async {
                if (await payListingFee(context, b)) _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: status == FeeStatus.overdue ? Colors.red.shade600 : AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(OwnerFinanceStrings.pay),
            ),
        ],
      ),
    );
  }
}
