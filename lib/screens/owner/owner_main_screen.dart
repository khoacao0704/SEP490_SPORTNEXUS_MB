import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/app_user.dart';
import '../../models/facility.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notification/notification_bell.dart';
import '../../widgets/owner/facility_selector.dart';
import 'owner_account_screen.dart';
import 'owner_facilities_screen.dart';
import 'owner_notifications.dart';
import 'owner_overview_screen.dart';
import 'owner_scan_screen.dart';
import 'owner_schedule_screen.dart';

/// Khung chính của Chủ sân: Tổng quan · Lịch đặt · Quét QR · Cơ sở · Tài khoản.
/// Nút "Quét QR" mở màn camera riêng (không giữ camera chạy nền trong tab).
class OwnerMainScreen extends StatefulWidget {
  final AppUser user;

  const OwnerMainScreen({super.key, required this.user});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  static final int _scanIndex = OwnerTab.scan.index;

  int _currentIndex = 0;
  List<Facility> _facilities = [];
  bool _loading = true;
  String? _error;

  /// Cơ sở đang chọn; `null` = tất cả.
  String? _facilityId;

  /// Tăng sau mỗi lần check-in / check-out để các tab tải lại.
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AppRepositories.owner.getMyFacilities();
      if (mounted) {
        setState(() {
          _facilities = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = OwnerStrings.loadError;
        });
      }
    }
  }

  void _bump() => setState(() => _revision++);

  /// Tải lại cơ sở đã duyệt (cho bộ chọn) sau khi sửa ở tab Cơ sở, không hiện màn chờ.
  Future<void> _refreshFacilities() async {
    try {
      final list = await AppRepositories.owner.getMyFacilities();
      if (!mounted) return;
      setState(() {
        _facilities = list;
        // Cơ sở đang chọn không còn trong danh sách thì quay về "Tất cả cơ sở".
        if (!list.any((f) => f.id == _facilityId)) _facilityId = null;
      });
    } catch (_) {}
  }

  void _selectTab(OwnerTab tab) => setState(() => _currentIndex = tab.index);

  Future<void> _onTap(int index) async {
    if (index == _scanIndex) {
      final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const OwnerScanScreen()));
      if (changed == true) _bump();
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                    TextButton(onPressed: _loadFacilities, child: const Text(OwnerStrings.retry)),
                  ],
                ),
        ),
      );
    }

    final selector = FacilitySelector(
      facilities: _facilities,
      selectedId: _facilityId,
      onChanged: (id) => setState(() => _facilityId = id),
    );

    final pages = [
      OwnerOverviewScreen(
        ownerName: widget.user.fullName,
        facilityId: _facilityId,
        revision: _revision,
        facilitySelector: selector,
        onChanged: _bump,
        onOpenSchedule: () => _selectTab(OwnerTab.schedule),
        notificationBell: NotificationBell(screenBuilder: (_) => ownerNotificationsScreen(onSelectTab: _selectTab)),
      ),
      OwnerScheduleScreen(facilityId: _facilityId, revision: _revision, facilitySelector: selector, onChanged: _bump),
      const SizedBox.shrink(), // Quét QR mở màn riêng
      OwnerFacilitiesScreen(onChanged: _refreshFacilities),
      OwnerAccountScreen(user: widget.user, onSelectTab: _selectTab),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: OwnerStrings.navOverview,
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: OwnerStrings.navSchedule,
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
              label: OwnerStrings.navScan,
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: OwnerStrings.navFacilities,
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: OwnerStrings.navAccount,
            ),
          ],
        ),
      ),
    );
  }
}
