import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_drawer.dart';
import '../../core/constants/fair_play_rules.dart';
import '../../core/strings/profile_strings.dart';
import '../../core/strings/review_strings.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/session_store.dart';
import '../../models/app_user.dart';
import '../../widgets/profile/user_avatar.dart';
import '../booking/split_payments_screen.dart';
import '../fair_play/fair_play_screen.dart';
import '../review/pending_reviews_screen.dart';
import '../wallet/transaction_history_screen.dart';
import '../wallet/withdraw_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'top_up_wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _balance = 0;
  int _pendingWithdrawal = 0;
  int _frozenBalance = 0;
  AppUser? _user;
  int _pendingReviews = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    // Hiện ngay hồ sơ đã lưu trong máy, rồi tải bản mới nhất từ máy chủ.
    final cached = await SessionStore.readUser();
    if (mounted && cached != null) setState(() => _user = cached);
    try {
      final fresh = await AppRepositories.auth.getProfile();
      if (mounted) setState(() => _user = fresh);
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(ProfileStrings.loadError)));
      }
    }

    try {
      final wallet = await Future.wait([
        AppRepositories.wallet.getBalance(),
        AppRepositories.wallet.getFrozenBalance(),
        AppRepositories.wallet.getPendingWithdrawalAmount(),
      ]);
      if (mounted) {
        setState(() {
          _balance = wallet[0];
          _frozenBalance = wallet[1];
          _pendingWithdrawal = wallet[2];
        });
      }
    } on WalletException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(WalletStrings.loadError)));
      }
    }

    final pendingReviews = await AppRepositories.review.getPendingReviews();
    if (!mounted) return;
    setState(() => _pendingReviews = pendingReviews.length);
  }

  /// Mở màn nạp / rút; BE chưa hỗ trợ thì báo đang phát triển. Quay lại thì tải lại số dư.
  Future<void> _openWalletAction(bool supported, Widget screen) async {
    if (!supported) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(WalletStrings.featureInDevelopment)));
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadProfileData();
  }

  @override
  Widget build(BuildContext context) {
    // Tài khoản Google / Facebook chưa có mật khẩu: "Đặt mật khẩu" thay cho "Đổi mật khẩu".
    final hasPassword = _user?.hasPassword ?? true;
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
        title: const Text(ProfileStrings.title, style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
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
              icon: Icons.call_split,
              title: SplitPaymentStrings.listTitle,
              screen: const SplitPaymentsScreen(),
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
            _menuTile(
              icon: Icons.lock_outline,
              title: hasPassword ? ProfileStrings.changePassword : ProfileStrings.setPassword,
              screen: ChangePasswordScreen(hasPassword: hasPassword),
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
    final user = _user;
    if (user == null) {
      return const SizedBox(height: 72, child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
    }
    final fairPlay = user.fairPlayScore;
    return Row(
      children: [
        UserAvatar(user: user),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              if (user.username.isNotEmpty)
                Text('@${user.username}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _openAndReload(const FairPlayScreen()),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: FairPlayRules.canJoinLfg(fairPlay) ? Colors.amber : Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      ReviewStrings.scoreLabel(fairPlay),
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: ProfileStrings.editProfile,
          icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreen),
          onPressed: () => _openAndReload(EditProfileScreen(user: user)),
        ),
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
          if (_frozenBalance > 0)
            Text(
              WalletStrings.frozenBalance(Formatters.vnd(_frozenBalance)),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _openWalletAction(AppRepositories.wallet.supportsTopUp, const TopUpWalletScreen()),
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
                  onPressed: () =>
                      _openWalletAction(AppRepositories.wallet.supportsWithdrawal, const WithdrawScreen()),
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
