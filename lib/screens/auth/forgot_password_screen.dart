import 'package:flutter/material.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/auth/auth_card_scaffold.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import 'otp_verification_screen.dart';

/// Pop về email của tài khoản khi đặt lại mật khẩu thành công.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    try {
      await AppRepositories.auth.requestPasswordReset(email);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(email: email, purpose: OtpPurpose.resetPassword),
        ),
      );
      if (done == true && mounted) Navigator.pop(context, email);
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCardScaffold(
      title: AuthStrings.forgotTitle,
      subtitle: AuthStrings.forgotSubtitle,
      icon: Icons.lock_reset,
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              label: AuthStrings.emailLabel,
              hint: AuthStrings.emailHint,
              controller: _emailController,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
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
              prompt: AuthStrings.haveAccount,
              action: AuthStrings.loginNow,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
