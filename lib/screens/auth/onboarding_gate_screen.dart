import 'package:flutter/material.dart';

import '../../core/strings/survey_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/onboarding_gate.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../profile/player_survey_screen.dart';
import 'login_screen.dart';
import 'role_router.dart';

/// Màn chờ sau đăng nhập của người chơi: chưa làm khảo sát thì bắt buộc làm, xong mới vào màn chính.
class OnboardingGateScreen extends StatefulWidget {
  final AppUser user;

  const OnboardingGateScreen({super.key, required this.user});

  @override
  State<OnboardingGateScreen> createState() => _OnboardingGateScreenState();
}

class _OnboardingGateScreenState extends State<OnboardingGateScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final needs = await OnboardingGate.needsSurvey(widget.user);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => needs
            ? PlayerSurveyScreen(mandatory: true, onCompleted: _goHome, onLogout: _logout)
            : homeScreenFor(widget.user),
      ),
    );
  }

  // Gọi bằng context của màn khảo sát (màn chờ này đã bị thay thế).
  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => homeScreenFor(widget.user)), (_) => false);
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await AppRepositories.auth.logout();
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 12),
            Text(SurveyStrings.loading, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
