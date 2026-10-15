import 'package:flutter/material.dart';

import '../../core/strings/owner_facility_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/photo_picker.dart';
import 'facility_form_screen.dart';
import 'listing_fee_screen.dart';
import 'owner_facility_detail_screen.dart';

/// Tab "Cơ sở": tất cả cơ sở của Chủ sân kèm trạng thái duyệt, nút đăng cơ sở mới.
class OwnerFacilitiesScreen extends StatefulWidget {
  /// Gọi khi có thay đổi để khung chính tải lại danh sách cơ sở đã duyệt.
  final VoidCallback onChanged;

  const OwnerFacilitiesScreen({super.key, required this.onChanged});

  @override
  State<OwnerFacilitiesScreen> createState() => _OwnerFacilitiesScreenState();
}

class _OwnerFacilitiesScreenState extends State<OwnerFacilitiesScreen> {
  List<OwnerFacility> _facilities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AppRepositories.owner.getOwnerFacilities();
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

  Future<void> _create() async {
    final created = await Navigator.push<OwnerFacility>(
      context,
      MaterialPageRoute(builder: (_) => const FacilityFormScreen()),
    );
    if (created != null) {
      widget.onChanged();
      _load();
    }
  }

  Future<void> _open(OwnerFacility f) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OwnerFacilityDetailScreen(facility: f)),
    );
    if (changed == true) {
      widget.onChanged();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text(
          OwnerFacilityStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-facility',
        onPressed: _create,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text(OwnerFacilityStrings.addFacility),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const ListingFeeBanner(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else if (_facilities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(Icons.storefront_outlined, size: 48, color: AppColors.cardBorder),
                          SizedBox(height: 12),
                          Text(OwnerFacilityStrings.empty, style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                            OwnerFacilityStrings.emptyHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final f in _facilities) _FacilityTile(facility: f, onTap: () => _open(f)),
                ],
              ),
      ),
    );
  }
}

class _FacilityTile extends StatelessWidget {
  final OwnerFacility facility;
  final VoidCallback onTap;

  const _FacilityTile({required this.facility, required this.onTap});

  List<({String label, Color fg, Color bg})> _badges(DateTime now) {
    final f = facility;
    final pending = (fg: AppColors.tagOrangeText, bg: AppColors.tagOrangeBg);
    final bad = (fg: Colors.red.shade700, bg: Colors.red.shade50);
    return [
      switch (f.status) {
        ApprovalStatus.approved => (
          label: OwnerFacilityStrings.statusApproved,
          fg: AppColors.tagGreenText,
          bg: AppColors.tagGreenBg,
        ),
        ApprovalStatus.pending => (label: OwnerFacilityStrings.statusPending, fg: pending.fg, bg: pending.bg),
        ApprovalStatus.rejected => (label: OwnerFacilityStrings.statusRejected, fg: bad.fg, bg: bad.bg),
      },
      if (f.hasPendingChange) (label: OwnerFacilityStrings.statusChangePending, fg: pending.fg, bg: pending.bg),
      if (f.isApproved && f.closures.any((c) => c.isWholeFacility && c.isActiveOn(now)))
        (label: OwnerFacilityStrings.statusClosedToday, fg: bad.fg, bg: bad.bg),
      if (f.isApproved && f.courts.any((c) => c.needsPricing))
        (label: OwnerFacilityStrings.needsPricing, fg: pending.fg, bg: pending.bg),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final f = facility;
    final totalCourts = f.activeCourts.fold(0, (sum, c) => sum + c.courtCount);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (f.operations.images.isNotEmpty)
              OwnerImage(f.operations.images.first, width: 96, height: 112)
            else
              Container(width: 96, height: 112, color: AppColors.lightGreen),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.profile.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.profile.fullAddress,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      OwnerFacilityStrings.courtsSummary(f.activeCourts.length, totalCourts),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final b in _badges(DateTime.now()))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: b.bg, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              b.label,
                              style: TextStyle(fontSize: 11, color: b.fg, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
