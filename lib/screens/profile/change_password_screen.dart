import 'package:flutter/material.dart';

import '../../core/strings/auth_strings.dart';
import '../../core/strings/profile_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/profile/profile_actions.dart';

/// Đổi mật khẩu khi đang đăng nhập. BE thu hồi mọi phiên nên đổi xong phải đăng nhập lại.
/// [hasPassword] = false (tài khoản Google / Facebook): đặt mật khẩu lần đầu, không hỏi mật khẩu cũ, ở lại phiên.
class ChangePasswordScreen extends StatefulWidget {
  final bool hasPassword;

  const ChangePasswordScreen({super.key, this.hasPassword = true});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateNew(String? value) {
    final error = Validators.password(value);
    if (error != null) return error;
    if (value == _oldController.text) return ProfileStrings.samePassword;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (widget.hasPassword) {
        await AppRepositories.auth.changePassword(
          oldPassword: _oldController.text,
          newPassword: _newController.text,
          confirmPassword: _confirmController.text,
        );
      } else {
        await AppRepositories.auth.setPassword(
          newPassword: _newController.text,
          confirmPassword: _confirmController.text,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showProfileError(context, e.message);
      return;
    }
    if (!mounted) return;
    if (widget.hasPassword) {
      goToLogin(context, ProfileStrings.passwordChanged);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(ProfileStrings.passwordSet)));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword = widget.hasPassword;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          hasPassword ? ProfileStrings.changePasswordTitle : ProfileStrings.setPasswordTitle,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.darkGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasPassword ? ProfileStrings.changePasswordNote : ProfileStrings.setPasswordNote,
                        style: const TextStyle(fontSize: 12, color: AppColors.darkGreen, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (hasPassword) ...[
                AuthTextField(
                  label: ProfileStrings.oldPasswordLabel,
                  hint: AuthStrings.passwordHint,
                  controller: _oldController,
                  validator: Validators.required,
                  isPassword: true,
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 16),
              ],
              AuthTextField(
                label: ProfileStrings.newPasswordLabel,
                hint: AuthStrings.newPasswordHint,
                controller: _newController,
                validator: _validateNew,
                isPassword: true,
                helperText: AuthStrings.passwordRule,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: ProfileStrings.confirmPasswordLabel,
                hint: AuthStrings.confirmPasswordHint,
                controller: _confirmController,
                validator: Validators.confirmPassword(() => _newController.text),
                isPassword: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: hasPassword ? ProfileStrings.changePasswordButton : ProfileStrings.setPasswordButton,
                isLoading: _isLoading,
                trailingIcon: null,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
