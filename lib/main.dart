import 'package:flutter/material.dart';
import 'core/strings/api_strings.dart';
import 'data/app_repositories.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  AppRepositories.api.onUnauthorized = _onSessionExpired;
  runApp(const SportNexusApp());
}

bool _handlingExpiry = false;

/// Phiên hết hạn (BE trả 401 và refresh token cũng không dùng được nữa): đăng xuất và về màn đăng nhập.
Future<void> _onSessionExpired() async {
  if (_handlingExpiry) return; // nhiều request cùng bị 401 một lúc
  _handlingExpiry = true;
  try {
    await AppRepositories.auth.logout(revoke: false); // phiên đã bị thu hồi trên BE
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    appMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text(ApiStrings.sessionExpired)));
  } finally {
    _handlingExpiry = false;
  }
}

class SportNexusApp extends StatelessWidget {
  const SportNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportNexus',
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF139C4F)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
