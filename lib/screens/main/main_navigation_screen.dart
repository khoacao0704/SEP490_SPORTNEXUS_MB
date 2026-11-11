import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/app_repositories.dart';
import '../../models/app_notification.dart';
import '../../theme/app_colors.dart';
import '../notification/notification_opener.dart';
import '../home_screen.dart'; // Tab 0: Home
import '../lfg/lfg_screen.dart'; // Tab 1: LFG
import '../ai_chat/ai_chat_screen.dart'; // Tab 2: AI Chat
import '../booking/my_bookings_screen.dart'; // Tab 3: Bookings & QR
import '../profile/profile_screen.dart'; // Tab 4: Profile

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  /// Tăng mỗi lần mở tab "Lịch Đặt & QR" để màn đó tải lại (IndexedStack giữ nguyên màn đã dựng).
  int _bookingsVisit = 0;

  List<Widget> get _pages => [
        const HomeScreen(),
        const LfgScreen(),
        const AiChatScreen(),
        MyBookingsScreen(key: ValueKey(_bookingsVisit)),
        const ProfileScreen(),
      ];

  StreamSubscription<AppNotification>? _pushOpens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Thông báo đẩy chỉ cho người chơi: đăng ký token khi vào màn chính (đã qua khảo sát / thêm SĐT).
    final push = AppRepositories.push;
    unawaited(push.register());
    _pushOpens = push.opens.listen(_openPush);
    final pending = push.takePendingOpen(); // bấm thông báo khi app đang tắt
    if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openPush(pending));
  }

  @override
  void dispose() {
    _pushOpens?.cancel();
    super.dispose();
  }

  void _openPush(AppNotification n) {
    if (!mounted) return;
    unawaited(AppRepositories.notification.markAsRead(n.id).catchError((_) {}));
    unawaited(openPlayerNotification(Navigator.of(context), n));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              if (index == 3 && _currentIndex != 3) _bookingsVisit++;
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Ghép trận',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'AI Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Lịch đặt',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}
