import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/wallet_transaction.dart';
import '../../theme/app_colors.dart';

String transactionStatusLabel(WalletTransaction tx) {
  switch (tx.status) {
    case TransactionStatus.pending:
      return tx.type == TransactionType.topUp || tx.type == TransactionType.deposit
          ? WalletStrings.statusPendingTopUp
          : WalletStrings.statusPendingWithdrawal;
    case TransactionStatus.success:
      return WalletStrings.statusSuccess;
    case TransactionStatus.failed:
      return WalletStrings.statusFailed;
    case TransactionStatus.expired:
      return WalletStrings.statusExpired;
    case TransactionStatus.cancelled:
      return WalletStrings.statusCancelled;
    case TransactionStatus.notRefunded:
      return WalletStrings.statusNotRefunded;
  }
}

Color transactionStatusColor(TransactionStatus status) {
  switch (status) {
    case TransactionStatus.pending:
      return AppColors.tagOrangeText;
    case TransactionStatus.success:
      return AppColors.primaryGreen;
    case TransactionStatus.failed:
      return Colors.red;
    case TransactionStatus.expired:
    case TransactionStatus.cancelled:
    case TransactionStatus.notRefunded:
      return AppColors.textSecondary;
  }
}

IconData transactionIcon(TransactionType type) {
  switch (type) {
    case TransactionType.topUp:
      return Icons.add_card;
    case TransactionType.withdrawal:
      return Icons.account_balance;
    case TransactionType.bookingPayment:
      return Icons.sports_tennis;
    case TransactionType.lfgDeposit:
    case TransactionType.flashClaim:
      return Icons.groups;
    case TransactionType.tournamentFee:
      return Icons.emoji_events_outlined;
    case TransactionType.refund:
      return Icons.replay;
    case TransactionType.deposit:
      return Icons.add_card;
    case TransactionType.hold:
      return Icons.lock_clock_outlined;
    case TransactionType.holdRelease:
      return Icons.lock_open_outlined;
    case TransactionType.walletPayment:
      return Icons.shopping_bag_outlined;
    case TransactionType.prize:
      return Icons.emoji_events_outlined;
    case TransactionType.escrowRelease:
      return Icons.payments_outlined;
    case TransactionType.penaltyIncome:
      return Icons.gavel_outlined;
    case TransactionType.listingFee:
      return Icons.receipt_long_outlined;
  }
}

/// Số tiền có dấu; giao dịch không làm đổi số dư khả dụng (hết hạn, đã hủy, giải ngân tiền
/// đã tạm giữ — đã trừ lúc tạm giữ) thì không có dấu.
String _amountText(WalletTransaction tx) {
  final affectsBalance = (tx.status == TransactionStatus.success && tx.type != TransactionType.holdRelease) ||
      (tx.status == TransactionStatus.pending && tx.type == TransactionType.withdrawal);
  if (!affectsBalance) return Formatters.vnd(tx.amount);
  return '${tx.type.isCredit ? '+' : '-'}${Formatters.vnd(tx.amount)}';
}

class TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final inactive = tx.status == TransactionStatus.expired ||
        tx.status == TransactionStatus.cancelled ||
        tx.status == TransactionStatus.failed ||
        tx.status == TransactionStatus.notRefunded;
    final amountColor = inactive
        ? AppColors.textSecondary
        : tx.type.isCredit
            ? AppColors.primaryGreen
            : AppColors.textMain;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: tx.type.isCredit ? AppColors.lightGreen : AppColors.background,
        child: Icon(
          transactionIcon(tx.type),
          size: 20,
          color: tx.type.isCredit ? AppColors.primaryGreen : AppColors.textSecondary,
        ),
      ),
      title: Text(
        tx.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
      ),
      subtitle: Text(
        '${Formatters.time(tx.createdAt)} • ${tx.type.label}',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _amountText(tx),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: amountColor,
              decoration: inactive ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            transactionStatusLabel(tx),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: transactionStatusColor(tx.status)),
          ),
        ],
      ),
    );
  }
}

/// [onCancelWithdrawal]: có thì lệnh rút đang chờ hiện nút "Hủy yêu cầu rút" (đóng bảng rồi gọi).
void showTransactionDetailSheet(BuildContext context, WalletTransaction tx, {VoidCallback? onCancelWithdrawal}) {
  Widget row(String label, String value, {Color? valueColor, bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textMain),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(WalletStrings.copied)));
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy, size: 16, color: AppColors.primaryGreen),
              ),
            ),
        ],
      ),
    );
  }

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              WalletStrings.transactionDetail,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 12),
            Text(
              _amountText(tx),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: tx.type.isCredit ? AppColors.primaryGreen : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              transactionStatusLabel(tx),
              style: TextStyle(fontWeight: FontWeight.bold, color: transactionStatusColor(tx.status)),
            ),
            const Divider(height: 24),
            row(WalletStrings.type, tx.type.label),
            row(WalletStrings.content, tx.description),
            if (tx.reference != null) row(WalletStrings.reference, tx.reference!, copyable: true),
            if (tx.note != null) row(WalletStrings.note, tx.note!),
            row(WalletStrings.time, '${Formatters.time(tx.createdAt)} • ${Formatters.weekdayDayMonth(tx.createdAt)}/${tx.createdAt.year}'),
            row(WalletStrings.transactionId, tx.id, copyable: true),
            if (onCancelWithdrawal != null && tx.isPendingWithdrawal) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onCancelWithdrawal();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text(WalletStrings.cancelWithdrawal),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
