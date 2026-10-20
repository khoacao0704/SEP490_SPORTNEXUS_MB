import 'package:flutter/material.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/auth/auth_card_scaffold.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';

/// Pop về `true` khi đặt lại mật khẩu thành công.
class ResetPasswordScreen extends StatefulWidget {
  final String phone;
  final String resetToken;

  const ResetPasswordScreen({super.key, required this.phone, required this.resetToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AppRepositories.auth.resetPassword(widget.phone, widget.resetToken, _passwordController.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCardScaffold(
      title: AuthStrings.resetTitle,
      subtitle: AuthStrings.resetSubtitle,
      icon: Icons.lock_outline,
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              label: AuthStrings.newPasswordLabel,
              hint: AuthStrings.newPasswordHint,
              controller: _passwordController,
              validator: Validators.password,
              isPassword: true,
              helperText: AuthStrings.passwordRule,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: AuthStrings.confirmPasswordLabel,
              hint: AuthStrings.confirmPasswordHint,
              controller: _confirmPasswordController,
              validator: Validators.confirmPassword(() => _passwordController.text),
              isPassword: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleReset(),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: AuthStrings.resetButton,
              isLoading: _isLoading,
              onPressed: _handleReset,
              trailingIcon: null,
            ),
          ],
        ),
      ),
    );
  }
}
