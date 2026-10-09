import 'package:flutter/material.dart';
import 'screens/main/main_navigation_screen.dart';

void main() {
  runApp(const SportNexusApp());
}

class SportNexusApp extends StatelessWidget {
  const SportNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportNexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF139C4F)),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}
