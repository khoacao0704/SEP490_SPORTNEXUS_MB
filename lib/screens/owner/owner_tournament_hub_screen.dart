import 'package:flutter/material.dart';

import '../../core/strings/organizer_strings.dart';
import '../../models/organized_tournament.dart';
import '../../theme/app_colors.dart';
import '../tournament/organized_tournaments_tab.dart';

/// Giải đấu của Chủ sân (mở từ menu trái): "Tôi tổ chức" (tạo giải tại cơ sở đang quản lý, mọi giải chờ Admin duyệt)
/// và "Giải tại sân của tôi" (giải người khác tổ chức tại cơ sở: xem lịch và giữ / trả ca sân).
class OwnerTournamentHubScreen extends StatelessWidget {
  /// Cơ sở đang quản lý (đã duyệt); null khi chưa có cơ sở nào được duyệt.
  final FacilityOption? facility;

  const OwnerTournamentHubScreen({super.key, this.facility});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                OrganizerStrings.ownerTitle,
                style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (facility != null)
                Text(
                  facility!.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
            ],
          ),
          bottom: const TabBar(
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryGreen,
            tabs: [
              Tab(text: OrganizerStrings.ownerMine),
              Tab(text: OrganizerStrings.ownerAtFacility),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OrganizedTournamentsTab(ownerMode: true, ownerFacility: facility),
            OrganizedTournamentsTab(ownerMode: true, ownerFacility: facility, facilityScope: true),
          ],
        ),
      ),
    );
  }
}
