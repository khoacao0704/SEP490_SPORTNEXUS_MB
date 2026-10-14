import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Khung chung cho các màn hình xác thực: ảnh nền sân, thẻ trắng ở giữa, logo, tiêu đề.
class AuthCardScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;
  final bool showBackButton;

  const AuthCardScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon = Icons.flash_on,
    this.showBackButton = false,
  });

  static const String _backgroundUrl =
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?auto=format&fit=crop&q=80&w=1000';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.authPrimary,
          image: DecorationImage(
            image: NetworkImage(_backgroundUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.authPrimary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.authTitle,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 13, color: AppColors.authSubtle, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
              if (showBackButton)
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
