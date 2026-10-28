import 'package:flutter/material.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/wallet_transaction.dart';
import '../../theme/app_colors.dart';
import '../../widgets/wallet/transaction_tile.dart';

enum _Filter { all, moneyIn, moneyOut, pending }

class TransactionHistoryScreen extends StatefulWidget {
  /// Ví dùng cho màn này; bỏ trống = ví người chơi. Chủ sân truyền ví của Chủ sân.
  final WalletRepository? wallet;

  const TransactionHistoryScreen({super.key, this.wallet});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  WalletRepository get _wallet => widget.wallet ?? AppRepositories.wallet;

  List<WalletTransaction> _transactions = [];
  bool _isLoading = true;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final txs = await _wallet.getTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = txs;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = WalletStrings.loadError;
      });
    }
  }

  Future<void> _cancelWithdrawal(WalletTransaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(WalletStrings.cancelWithdrawal),
        content: const Text(WalletStrings.cancelWithdrawalConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(WalletStrings.keep)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(WalletStrings.cancelWithdrawal, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _wallet.cancelWithdrawal(tx);
      messenger.showSnackBar(const SnackBar(content: Text(WalletStrings.withdrawalCancelled)));
    } on WalletException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
    if (mounted) _load();
  }

  List<WalletTransaction> get _filtered {
    switch (_filter) {
      case _Filter.all:
        return _transactions;
      case _Filter.moneyIn:
        return _transactions.where((t) => t.type.isCredit).toList();
      case _Filter.moneyOut:
        return _transactions.where((t) => !t.type.isCredit).toList();
      case _Filter.pending:
        return _transactions.where((t) => t.status == TransactionStatus.pending).toList();
    }
  }

  static String _dayHeader(DateTime date, DateTime now) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return WalletStrings.today;
    if (diff == 1) return WalletStrings.yesterday;
    return '${Formatters.weekdayDayMonth(date)}/${date.year}';
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
          WalletStrings.historyTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    const labels = {
      _Filter.all: WalletStrings.filterAll,
      _Filter.moneyIn: WalletStrings.filterIn,
      _Filter.moneyOut: WalletStrings.filterOut,
      _Filter.pending: WalletStrings.filterPending,
    };
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: labels.entries.map((e) {
            final selected = _filter == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = e.key),
                selectedColor: AppColors.primaryGreen,
                backgroundColor: AppColors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textMain,
                ),
                side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text(WalletStrings.retry)),
          ],
        ),
      );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.cardBorder),
            SizedBox(height: 12),
            Text(
              WalletStrings.noTransactions,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Danh sách phẳng: tiêu đề ngày xen giữa các giao dịch.
    final now = DateTime.now();
    final rows = <Object>[];
    String? lastHeader;
    for (final tx in items) {
      final header = _dayHeader(tx.createdAt, now);
      if (header != lastHeader) {
        rows.add(header);
        lastHeader = header;
      }
      rows.add(tx);
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                row,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            );
          }
          final tx = row as WalletTransaction;
          return Material(
            color: AppColors.white,
            child: TransactionTile(
              transaction: tx,
              onTap: () => showTransactionDetailSheet(
                context,
                tx,
                // Chỉ ví Người chơi; ví Chủ sân giữ nguyên như cũ.
                onCancelWithdrawal: widget.wallet == null && _wallet.supportsWithdrawal ? () => _cancelWithdrawal(tx) : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
