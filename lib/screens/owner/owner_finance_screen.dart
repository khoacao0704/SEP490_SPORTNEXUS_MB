import 'package:flutter/material.dart';

import '../../core/strings/owner_finance_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/facility.dart';
import '../../models/owner_finance.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/revenue_bar_chart.dart';
import '../wallet/transaction_history_screen.dart';
import '../wallet/withdraw_screen.dart';
import 'listing_fee_screen.dart';

/// Doanh thu & Ví của Chủ sân: số dư ví (rút tiền, lịch sử), doanh thu theo tháng / cơ sở, phí tạm tính.
class OwnerFinanceScreen extends StatefulWidget {
  const OwnerFinanceScreen({super.key});

  @override
  State<OwnerFinanceScreen> createState() => _OwnerFinanceScreenState();
}

class _OwnerFinanceScreenState extends State<OwnerFinanceScreen> {
  late DateTime _month = _thisMonth();
  String? _facilityId;
  List<Facility> _facilities = [];
  MonthlyRevenue? _revenue;
  List<ListingFeeBill> _bills = [];
  int _balance = 0;
  int _pendingWithdrawal = 0;
  bool _loading = true;
  String? _error;
  int _revision = 0;

  static DateTime _thisMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Chỉ nhận kết quả của lần tải mới nhất (đổi cơ sở / ngày / tháng liên tục).
  int _loadSeq = 0;

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final owner = AppRepositories.owner;
      final wallet = AppRepositories.ownerWallet;
      final facilities = await owner.getMyFacilities();
      final revenue = await owner.getMonthlyRevenue(_month, facilityId: _facilityId);
      final bills = await owner.getListingFees();
      final balance = await wallet.getBalance();
      final pending = await wallet.getPendingWithdrawalAmount();
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _facilities = facilities;
        _revenue = revenue;
        _bills = bills;
        _balance = balance;
        _pendingWithdrawal = pending;
        _loading = false;
        _revision++;
      });
    } catch (_) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _error = OwnerFinanceStrings.loadError;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  Future<void> _withdraw() async {
    if (overdueBill(_bills, DateTime.now()) != null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(OwnerFinanceStrings.withdrawBlockedTitle),
          content: const Text(OwnerFinanceStrings.withdrawBlocked),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(OwnerFinanceStrings.close)),
          ],
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WithdrawScreen(wallet: AppRepositories.ownerWallet)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final revenue = _revenue;
    final isCurrentMonth = _month == _thisMonth();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerFinanceStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: OwnerFinanceStrings.feeTitle,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ListingFeeScreen()));
              _load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListingFeeBanner(revision: _revision, onPaid: _load),
            _walletCard(),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(
                    OwnerFinanceStrings.monthLabel(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                ),
                IconButton(
                  onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (_facilities.length > 1)
              Wrap(
                runSpacing: 4,
                children: [
                  _facilityChip(null, OwnerStrings.allFacilities),
                  for (final f in _facilities) _facilityChip(f.id, f.name),
                ],
              ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.textSecondary))
            else if (revenue != null)
              ..._revenueSection(revenue, isCurrentMonth),
          ],
        ),
      ),
    );
  }

  Widget _facilityChip(String? id, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _facilityId == id,
      selectedColor: AppColors.lightGreen,
      labelStyle: TextStyle(
        color: _facilityId == id ? AppColors.darkGreen : AppColors.textMain,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        setState(() => _facilityId = id);
        _load();
      },
    ),
  );

  Widget _walletCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.primaryGreen, AppColors.darkGreen]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(OwnerFinanceStrings.walletBalance, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          Formatters.vnd(_balance),
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        ),
        if (_pendingWithdrawal > 0)
          Text(
            OwnerFinanceStrings.pendingWithdrawal(_pendingWithdrawal),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _withdraw,
                icon: const Icon(Icons.account_balance, size: 18),
                label: const Text(OwnerFinanceStrings.withdraw),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.darkGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TransactionHistoryScreen(wallet: AppRepositories.ownerWallet)),
                  );
                  _load();
                },
                icon: const Icon(Icons.history, size: 18),
                label: const Text(OwnerFinanceStrings.history),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  List<Widget> _revenueSection(MonthlyRevenue r, bool isCurrentMonth) {
    if (r.items.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text(
            OwnerFinanceStrings.noRevenue,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ];
    }
    return [
      _card(
        children: [
          const Text(OwnerFinanceStrings.totalRevenue, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            Formatters.vnd(r.total),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          Text(
            OwnerFinanceStrings.sessions(r.sessions),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 24),
          _line(OwnerFinanceStrings.viaApp, r.viaApp),
          _line(OwnerFinanceStrings.atCourt, r.atCourt),
          _line(OwnerFinanceStrings.penalties, r.penalties),
          const Divider(height: 24),
          _line(OwnerFinanceStrings.estimatedFee, r.listingFee, bold: true),
          const SizedBox(height: 4),
          const Text(OwnerFinanceStrings.feeNote, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
      const SizedBox(height: 12),
      _card(
        children: [
          const Text(
            OwnerFinanceStrings.dailyChart,
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          RevenueBarChart(daily: r.daily, month: r.month),
        ],
      ),
      if (_facilityId == null && r.byFacility.length > 1) ...[
        const SizedBox(height: 12),
        _card(
          children: [
            const Text(
              OwnerFinanceStrings.byFacility,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            for (final f in r.byFacility) ...[
              Row(
                children: [
                  Expanded(child: Text(f.name, overflow: TextOverflow.ellipsis)),
                  Text(Formatters.vnd(f.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: r.total == 0 ? 0 : f.amount / r.total,
                  minHeight: 6,
                  backgroundColor: AppColors.divider,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ],
    ];
  }

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _line(String label, int amount, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Text(
          Formatters.vnd(amount),
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: AppColors.textMain),
        ),
      ],
    ),
  );
}
