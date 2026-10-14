import 'package:flutter/material.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_card_scaffold.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import 'otp_verification_screen.dart';

/// Pop về email đã đăng ký khi xác thực OTP thành công.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      showAuthError(context, AuthStrings.agreeTermsRequired);
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    try {
      await AppRepositories.auth.register(RegisterRequest(
        fullName: _fullNameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      ));
      if (!mounted) return;
      setState(() => _isLoading = false);
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(email: email, purpose: OtpPurpose.register),
        ),
      );
      // Trả email về màn Login để điền sẵn.
      if (verified == true && mounted) Navigator.pop(context, email);
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCardScaffold(
      title: AuthStrings.registerTitle,
      subtitle: AuthStrings.registerSubtitle,
      icon: Icons.person_add_alt_1,
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              AuthTextField(
                label: AuthStrings.fullNameLabel,
                hint: AuthStrings.fullNameHint,
                controller: _fullNameController,
                validator: Validators.required,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: AuthStrings.emailLabel,
                hint: AuthStrings.emailHint,
                controller: _emailController,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: AuthStrings.phoneLabel,
                hint: AuthStrings.phoneHint,
                controller: _phoneController,
                validator: Validators.phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: AuthStrings.passwordLabel,
                hint: AuthStrings.passwordHint,
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
                onFieldSubmitted: (_) => _handleRegister(),
              ),
              const SizedBox(height: 12),
              _buildTermsCheckbox(),
              const SizedBox(height: 20),
              AuthPrimaryButton(
                label: AuthStrings.registerButton,
                isLoading: _isLoading,
                onPressed: _handleRegister,
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
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _agreedToTerms,
            activeColor: AppColors.authPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: const Text.rich(
              TextSpan(
                text: AuthStrings.agreeTermsPrefix,
                style: TextStyle(fontSize: 13, color: AppColors.authBody),
                children: [
                  TextSpan(
                    text: AuthStrings.termsOfService,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.authPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
