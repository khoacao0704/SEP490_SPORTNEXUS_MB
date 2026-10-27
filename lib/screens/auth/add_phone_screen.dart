import 'package:flutter/material.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/session_store.dart';
import '../../widgets/auth/auth_card_scaffold.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';
import 'role_router.dart';

/// Tài khoản Google / Facebook chưa có SĐT: bắt buộc thêm SĐT đã xác thực trước khi vào màn chính.
/// Không thêm thì chỉ có thể đăng xuất.
class AddPhoneScreen extends StatefulWidget {
  const AddPhoneScreen({super.key});

  @override
  State<AddPhoneScreen> createState() => _AddPhoneScreenState();
}

class _AddPhoneScreenState extends State<AddPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final phone = _phoneController.text.trim();
    try {
      final devOtp = await AppRepositories.auth.requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phone: phone, purpose: OtpPurpose.addPhone, devOtp: devOtp),
        ),
      );
      if (verified != true || !mounted) return;
      final user = await SessionStore.readUser();
      if (user != null && mounted) goToHome(context, user);
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AppRepositories.auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthCardScaffold(
      title: AuthStrings.addPhoneTitle,
      subtitle: AuthStrings.addPhoneSubtitle,
      icon: Icons.phone_iphone,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              label: AuthStrings.phoneLabel,
              hint: AuthStrings.phoneHint,
              controller: _phoneController,
              validator: Validators.phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              onFieldSubmitted: (_) => _handleSendOtp(),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: AuthStrings.sendOtpButton,
              isLoading: _isLoading,
              onPressed: _handleSendOtp,
            ),
            const SizedBox(height: 20),
            AuthFooterLink(
              prompt: AuthStrings.otherAccount,
              action: AuthStrings.logout,
              onTap: _isLoading ? null : _logout,
            ),
          ],
        ),
      ),
    );
  }
}
