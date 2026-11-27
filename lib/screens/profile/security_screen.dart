import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings/profile_strings.dart';
import '../../core/strings/security_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile/delete_account.dart';
import '../../widgets/profile/profile_actions.dart';
import 'change_password_screen.dart';

/// Bảo mật (như mục Bảo mật trong Hồ sơ của Web): đổi / đặt mật khẩu, xác thực email bằng OTP,
/// đăng xuất khỏi tất cả thiết bị. BE không cho biết email đã xác thực chưa nên luôn cho gửi mã (như Web).
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  AppUser? _user;
  final _otp = TextEditingController();
  bool _otpSent = false;
  String? _devOtp;
  bool _sending = false;
  bool _verifying = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _otp.addListener(() => setState(() {}));
    _loadUser();
  }

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AppRepositories.auth.getCurrentUser();
    if (mounted) setState(() => _user = user);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : AppColors.primaryGreen,
      ));
  }

  Future<void> _sendOtp() async {
    setState(() => _sending = true);
    try {
      final dev = await AppRepositories.auth.sendEmailOtp();
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _devOtp = dev;
      });
      _snack(SecurityStrings.otpSent);
    } on AuthException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack(SecurityStrings.sendError, error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return _snack(SecurityStrings.otpInvalid, error: true);
    setState(() => _verifying = true);
    try {
      await AppRepositories.auth.verifyEmail(code);
      if (!mounted) return;
      setState(() {
        _otpSent = false;
        _devOtp = null;
        _otp.clear();
      });
      _snack(SecurityStrings.verified);
    } on AuthException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack(SecurityStrings.verifyError, error: true);
    }
    if (mounted) setState(() => _verifying = false);
  }

  Future<void> _logoutAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(SecurityStrings.logoutAll),
        content: const Text(SecurityStrings.logoutAllConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(SecurityStrings.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(SecurityStrings.logoutAll),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await AppRepositories.auth.logoutAllDevices();
      if (mounted) goToLogin(context, SecurityStrings.loggedOutAll);
      return;
    } on AuthException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack(SecurityStrings.logoutAllError, error: true);
    }
    if (mounted) setState(() => _loggingOut = false);
  }

  Future<void> _openPassword(bool hasPassword) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen(hasPassword: hasPassword)));
    _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final hasPassword = user?.hasPassword ?? true;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(SecurityStrings.title, style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            icon: Icons.lock_outline,
            title: SecurityStrings.passwordSection,
            children: [
              Text(hasPassword ? SecurityStrings.passwordHint : SecurityStrings.setPasswordHint, style: _hint),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _openPassword(hasPassword),
                child: Text(hasPassword ? ProfileStrings.changePassword : ProfileStrings.setPassword),
              ),
            ],
          ),
          _card(
            icon: Icons.mark_email_read_outlined,
            title: SecurityStrings.emailSection,
            children: _buildEmail(user),
          ),
          _card(
            icon: Icons.devices_outlined,
            title: SecurityStrings.devicesSection,
            children: [
              const Text(SecurityStrings.devicesHint, style: _hint),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loggingOut ? null : _logoutAll,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(SecurityStrings.logoutAll),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              ),
            ],
          ),
          _card(
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.red,
            title: SecurityStrings.dangerSection,
            children: [
              const Text(SecurityStrings.dangerHint, style: _hint),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: user == null || _loggingOut ? null : () => startDeleteAccount(context, hasPassword: hasPassword),
                icon: const Icon(Icons.person_remove_outlined, size: 18),
                label: const Text(ProfileStrings.deleteAccount),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEmail(AppUser? user) {
    if (user == null) return const [LinearProgressIndicator(color: AppColors.primaryGreen)];
    if (user.email.isEmpty) return const [Text(SecurityStrings.noEmail, style: _hint)];
    return [
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: SecurityStrings.emailLabel, style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: user.email),
        ]),
        style: const TextStyle(fontSize: 13),
      ),
      const SizedBox(height: 6),
      if (!_otpSent) ...[
        const Text(SecurityStrings.emailIntro, style: _hint),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _sending ? null : _sendOtp,
          icon: const Icon(Icons.send, size: 18),
          label: Text(_sending ? SecurityStrings.sending : SecurityStrings.sendOtp),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
        ),
      ] else ...[
        const Text(SecurityStrings.otpLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        if (_devOtp != null)
          Text(SecurityStrings.devOtp(_devOtp!), style: const TextStyle(fontSize: 12, color: AppColors.tagOrangeText)),
        const SizedBox(height: 6),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '123456',
            isDense: true,
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _verifying || _otp.text.trim().length != 6 ? null : _verify,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
              child: Text(_verifying ? SecurityStrings.verifying : SecurityStrings.verify),
            ),
            TextButton(
              onPressed: _sending ? null : _sendOtp,
              child: Text(_sending ? SecurityStrings.sending : SecurityStrings.resend),
            ),
          ],
        ),
      ],
    ];
  }

  static const TextStyle _hint = TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4);

  static Widget _card({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color iconColor = AppColors.primaryGreen,
  }) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
}
