import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_drawer.dart';
import '../../core/constants/fair_play_rules.dart';
import '../../core/strings/review_strings.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../fair_play/fair_play_screen.dart';
import '../review/pending_reviews_screen.dart';
import '../wallet/transaction_history_screen.dart';
import '../wallet/withdraw_screen.dart';
import 'top_up_wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _balance = 0;
  int _pendingWithdrawal = 0;
  String _userName = 'Khoa Cao';
  int? _fairPlay;
  int _pendingReviews = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final balance = await AppRepositories.wallet.getBalance();
    final pending = await AppRepositories.wallet.getPendingWithdrawalAmount();
    final fairPlay = await AppRepositories.review.getFairPlay();
    final pendingReviews = await AppRepositories.review.getPendingReviews();
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _pendingWithdrawal = pending;
      _fairPlay = fairPlay.score;
      _pendingReviews = pendingReviews.length;
      _userName = prefs.getString('user_name') ?? 'Khoa Cao';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textMain),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          }
        ),
        title: const Text('Hồ Sơ Cá Nhân', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
      ),
      drawer: const MainDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildUserInfo(),
            const SizedBox(height: 24),
            _buildWalletCard(context),
            const SizedBox(height: 12),
            _menuTile(
              icon: Icons.receipt_long_outlined,
              title: WalletStrings.historyLink,
              screen: const TransactionHistoryScreen(),
            ),
            _menuTile(
              icon: Icons.rate_review_outlined,
              title: ReviewStrings.pendingCount(_pendingReviews),
              screen: const PendingReviewsScreen(),
              highlight: _pendingReviews > 0,
            ),
            _menuTile(
              icon: Icons.verified_user_outlined,
              title: ReviewStrings.fairPlayTitle,
              screen: const FairPlayScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAndReload(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadProfileData();
  }

  Widget _menuTile({required IconData icon, required String title, required Widget screen, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          leading: Icon(icon, color: highlight ? AppColors.tagOrangeText : AppColors.primaryGreen),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: highlight ? AppColors.tagOrangeText : null),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: () => _openAndReload(screen),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.primaryGreen,
          child: Text(
            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'K',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _openAndReload(const FairPlayScreen()),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: _fairPlay == null || FairPlayRules.canJoinLfg(_fairPlay!) ? Colors.amber : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _fairPlay == null ? ReviewStrings.fairPlay : ReviewStrings.scoreLabel(_fairPlay!),
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                ],
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.darkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white),
              SizedBox(width: 8),
              Text('SportNexus Escrow Wallet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Số dư khả dụng', style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text(Formatters.vnd(_balance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          if (_pendingWithdrawal > 0)
            Text(
              WalletStrings.pendingWithdrawal(Formatters.vnd(_pendingWithdrawal)),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TopUpWalletScreen()),
                    );
                    _loadProfileData(); // Reload balance after coming back
                  },
                  icon: const Icon(Icons.add, color: AppColors.primaryGreen),
                  label: const Text('Nạp tiền', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                    );
                    _loadProfileData(); // Reload balance after coming back
                  },
                  icon: const Icon(Icons.arrow_upward, color: Colors.white),
                  label: const Text('Rút tiền', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
