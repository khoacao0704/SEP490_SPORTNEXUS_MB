import 'package:flutter/material.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/auth_repository.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_card_scaffold.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'role_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _isLoading = false;
  /// Nút mạng xã hội đang đăng nhập ('google' / 'facebook'), `null` khi không có.
  String? _socialLoading;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_socialLoading != null || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await _signIn(() => AppRepositories.auth.login(
          _usernameController.text.trim(),
          _passwordController.text,
          rememberMe: _rememberMe,
        ));
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleSocialLogin(String provider, Future<AppUser?> Function() request) async {
    if (_isLoading || _socialLoading != null) return;

    setState(() => _socialLoading = provider);
    await _signIn(request);
    if (mounted) setState(() => _socialLoading = null);
  }

  /// [request] trả `null` khi người dùng tự hủy đăng nhập Google / Facebook.
  Future<void> _signIn(Future<AppUser?> Function() request) async {
    try {
      // Role do BE trả về quyết định màn hình chính.
      final user = await request();
      if (user == null) return;
      if (!isRoleAllowedOnMobile(user.role)) {
        await AppRepositories.auth.logout(revoke: false); // không thu hồi phiên Web của Admin
        if (mounted) showAuthError(context, AuthStrings.roleNotAllowed);
        return;
      }
      if (!mounted) return;
      goToHome(context, user);
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    }
  }

  /// Register / ForgotPassword pop về tên đăng nhập khi hoàn tất (rỗng = không điền sẵn).
  Future<void> _openAuthFlow(Widget screen, String successMessage) async {
    final username = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => screen));
    if (username == null || !mounted) return;
    if (username.isNotEmpty) _usernameController.text = username;
    _passwordController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage), backgroundColor: AppColors.primaryGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthCardScaffold(
      title: AuthStrings.loginTitle,
      subtitle: AuthStrings.loginSubtitle,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              AuthTextField(
                label: AuthStrings.identifierLabel,
                hint: AuthStrings.identifierHint,
                controller: _usernameController,
                validator: Validators.required,
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: AuthStrings.passwordLabel,
                hint: AuthStrings.passwordHint,
                controller: _passwordController,
                validator: Validators.required,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: 12),

              // Remember Me & Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: AppColors.authPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (value) => setState(() => _rememberMe = value ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        AuthStrings.rememberMe,
                        style: TextStyle(fontSize: 13, color: AppColors.authBody),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _openAuthFlow(const ForgotPasswordScreen(), AuthStrings.resetSuccess),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      AuthStrings.forgotPasswordLink,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.authPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              AuthPrimaryButton(
                label: AuthStrings.loginButton,
                isLoading: _isLoading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: 24),

              // Divider: HOẶC ĐĂNG NHẬP BẰNG
              const Row(
                children: [
                  Expanded(child: Divider(color: AppColors.authDivider)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      AuthStrings.orLoginWith,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.authHint,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.authDivider)),
                ],
              ),
              const SizedBox(height: 20),

              // Social Buttons (Google & Facebook)
              Row(
                children: [
                  Expanded(
                    child: _buildSocialButton(
                      icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
                      label: 'Google',
                      provider: 'google',
                      onPressed: () => _handleSocialLogin(
                        'google',
                        () => AppRepositories.auth.loginWithGoogle(rememberMe: _rememberMe),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSocialButton(
                      icon: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 20),
                      label: 'Facebook',
                      provider: 'facebook',
                      onPressed: () => _handleSocialLogin(
                        'facebook',
                        () => AppRepositories.auth.loginWithFacebook(rememberMe: _rememberMe),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              AuthFooterLink(
                prompt: AuthStrings.noAccount,
                action: AuthStrings.registerNow,
                onTap: () => _openAuthFlow(
                  const RegisterScreen(),
                  AppRepositories.auth.supportsOtp ? AuthStrings.registerSuccess : AuthStrings.registerDone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required String provider,
    required VoidCallback onPressed,
  }) {
    final loading = _socialLoading == provider;
    return OutlinedButton.icon(
      onPressed: _socialLoading == null ? onPressed : null,
      icon: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : icon,
      label: Text(label, style: const TextStyle(color: AppColors.authLabel, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: const BorderSide(color: AppColors.authBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
