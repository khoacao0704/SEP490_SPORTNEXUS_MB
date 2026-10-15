import 'package:flutter/material.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_card_scaffold.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import 'otp_verification_screen.dart';

/// Pop về tên đăng nhập khi đăng ký xong (BE chưa có OTP) hoặc khi xác thực OTP thành công (bản giả lập).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreedToTerms = false;
  UserRole _role = UserRole.player;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
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
    final username = _usernameController.text.trim();
    try {
      await AppRepositories.auth.register(RegisterRequest(
        username: username,
        fullName: _fullNameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        role: _role,
      ));
      if (!mounted) return;
      // BE chưa có OTP: tài khoản dùng được ngay, về màn Login với tên đăng nhập điền sẵn.
      if (!AppRepositories.auth.supportsOtp) {
        Navigator.pop(context, username);
        return;
      }
      setState(() => _isLoading = false);
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(email: email, purpose: OtpPurpose.register),
        ),
      );
      if (verified == true && mounted) Navigator.pop(context, username);
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
              _buildRoleSelector(),
              const SizedBox(height: 16),
              AuthTextField(
                label: AuthStrings.usernameLabel,
                hint: AuthStrings.usernameHint,
                controller: _usernameController,
                validator: Validators.username,
                keyboardType: TextInputType.text,
                helperText: AuthStrings.usernameRule,
                autofillHints: const [AutofillHints.newUsername],
              ),
              const SizedBox(height: 16),
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

  Widget _buildRoleSelector() {
    Widget option(UserRole role, String label, IconData icon) {
      final selected = _role == role;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _role = role),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.lightGreen : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.authPrimary : AppColors.authBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? AppColors.authPrimary : AppColors.authSubtle),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selected ? AppColors.authPrimary : AppColors.authBody,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AuthStrings.roleLabel,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.authLabel),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            option(UserRole.player, AuthStrings.rolePlayer, Icons.sports_tennis),
            const SizedBox(width: 12),
            option(UserRole.courtOwner, AuthStrings.roleOwner, Icons.storefront),
          ],
        ),
      ],
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
