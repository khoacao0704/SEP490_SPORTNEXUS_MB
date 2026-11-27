import 'package:flutter/material.dart';
import '../../widgets/owner/owner_shell.dart';

import '../../core/strings/owner_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_booking_list.dart';
import '../../widgets/owner/schedule_grid_view.dart';
import 'owner_booking_detail_screen.dart';

/// Tab Lịch đặt: "Lưới lịch" (lịch đặt sân theo ngày × sân, nhận khách vãng lai) và
/// "Danh sách đơn" (trang Đơn đặt sân của Web) của cơ sở đang chọn.
class OwnerScheduleScreen extends StatefulWidget {
  final String? facilityId;
  final int revision;
  final Widget facilitySelector;
  final VoidCallback onChanged;

  const OwnerScheduleScreen({
    super.key,
    required this.facilityId,
    required this.revision,
    required this.facilitySelector,
    required this.onChanged,
  });

  @override
  State<OwnerScheduleScreen> createState() => _OwnerScheduleScreenState();
}

class _OwnerScheduleScreenState extends State<OwnerScheduleScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openBooking(String bookingId) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerBookingDetailScreen(
          bookingId: bookingId,
          onOpenSchedule: () => _tabs.animateTo(0),
        ),
      ),
    );
    if (changed == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final facilityId = widget.facilityId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leading: const OwnerMenuButton(),
        title: widget.facilitySelector,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          tabs: const [Tab(text: OwnerStrings.viewGrid), Tab(text: OwnerStrings.viewList)],
        ),
      ),
      body: facilityId == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(OwnerStrings.noFacilityHint, textAlign: TextAlign.center),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                ScheduleGridView(
                  facilityId: facilityId,
                  revision: widget.revision,
                  onOpenBooking: _openBooking,
                  onChanged: widget.onChanged,
                ),
                OwnerBookingList(
                  facilityId: facilityId,
                  revision: widget.revision,
                  onOpen: _openBooking,
                  onChanged: widget.onChanged,
                ),
              ],
            ),
    );
  }
}
