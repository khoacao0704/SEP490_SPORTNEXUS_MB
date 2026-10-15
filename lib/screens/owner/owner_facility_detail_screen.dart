import 'package:flutter/material.dart';

import '../../core/strings/owner_facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../../widgets/owner/closure_sheet.dart';
import '../../widgets/owner/photo_picker.dart';
import 'court_pricing_screen.dart';
import 'facility_form_screen.dart';
import 'operations_edit_screen.dart';

/// Quản lý một cơ sở. Chưa duyệt: chỉ xem (bị từ chối thì sửa & nộp lại).
/// Đã duyệt: yêu cầu đổi tên/địa chỉ/giấy phép, sửa vận hành, cài giá & khung giờ, tạm đóng.
/// Pop trả về `true` nếu đã có thay đổi.
class OwnerFacilityDetailScreen extends StatefulWidget {
  final OwnerFacility facility;

  const OwnerFacilityDetailScreen({super.key, required this.facility});

  @override
  State<OwnerFacilityDetailScreen> createState() => _OwnerFacilityDetailScreenState();
}

class _OwnerFacilityDetailScreenState extends State<OwnerFacilityDetailScreen> {
  late OwnerFacility _f = widget.facility;
  bool _changed = false;

  void _apply(OwnerFacility? updated) {
    if (updated == null || !mounted) return;
    setState(() {
      _f = updated;
      _changed = true;
    });
  }

  Future<T?> _push<T>(Widget screen) => Navigator.push<T>(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _removeClosure(FacilityClosure c) async {
    try {
      _apply(await AppRepositories.owner.removeClosure(_f.id, c.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.closureRemoved)));
      }
    } on OwnerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _unlock(CourtConfig c) async {
    try {
      _apply(await AppRepositories.owner.unlockCourt(_f.id, c.sport, c.courtType));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.unlocked)));
      }
    } on OwnerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: Text(
            f.profile.name,
            style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._banners(f),
            _profileSection(f),
            _operationsSection(f),
            _courtsSection(f),
            if (f.isApproved) _closuresSection(f),
          ],
        ),
        bottomNavigationBar: f.status == ApprovalStatus.rejected
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ElevatedButton.icon(
                    onPressed: () async => _apply(
                      await _push<OwnerFacility>(FacilityFormScreen(mode: FacilityFormMode.resubmit, facility: f)),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text(OwnerFacilityStrings.resubmit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  List<Widget> _banners(OwnerFacility f) {
    final change = f.change;
    return [
      if (f.status == ApprovalStatus.pending) _banner(OwnerFacilityStrings.pendingBanner, warning: false),
      if (f.status == ApprovalStatus.rejected) _banner(OwnerFacilityStrings.rejectedBanner(f.rejectReason ?? '')),
      if (change?.status == ApprovalStatus.pending) _banner(OwnerFacilityStrings.changePendingBanner, warning: false),
      if (change?.status == ApprovalStatus.rejected)
        _banner(OwnerFacilityStrings.changeRejectedBanner(change?.rejectReason ?? '')),
    ];
  }

  Widget _banner(String text, {bool warning = true}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: warning ? Colors.red.shade50 : AppColors.tagOrangeBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning ? Icons.error_outline : Icons.hourglass_top,
          size: 18,
          color: warning ? Colors.red.shade700 : AppColors.tagOrangeText,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: warning ? Colors.red.shade700 : AppColors.tagOrangeText),
          ),
        ),
      ],
    ),
  );

  Widget _section({required String title, String? hint, Widget? action, required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
              ),
            ),
            ?action,
          ],
        ),
        if (hint != null) Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _actionButton(String label, VoidCallback? onPressed, {IconData icon = Icons.edit_outlined}) => TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen, visualDensity: VisualDensity.compact),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: AppColors.textMain)),
        ),
      ],
    ),
  );

  Widget _profileSection(OwnerFacility f) => _section(
    title: OwnerFacilityStrings.sectionProfile,
    hint: f.isApproved ? OwnerFacilityStrings.sectionProfileHint : null,
    action: f.isApproved
        ? _actionButton(
            OwnerFacilityStrings.requestChange,
            f.hasPendingChange
                ? null
                : () async => _apply(
                    await _push<OwnerFacility>(FacilityFormScreen(mode: FacilityFormMode.change, facility: f)),
                  ),
          )
        : null,
    children: [
      _row(OwnerFacilityStrings.name, f.profile.name),
      _row(OwnerFacilityStrings.address, f.profile.fullAddress),
      _row(OwnerFacilityStrings.licenseNumber, f.profile.licenseNumber),
      const SizedBox(height: 6),
      SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final img in f.profile.licenseImages)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: OwnerImage(img, width: 64, height: 64)),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _operationsSection(OwnerFacility f) {
    final o = f.operations;
    return _section(
      title: OwnerFacilityStrings.sectionOperations,
      action: f.isApproved
          ? _actionButton(
              OwnerFacilityStrings.edit,
              () async => _apply(await _push<OwnerFacility>(OperationsEditScreen(facility: f))),
            )
          : null,
      children: [
        _row(OwnerFacilityStrings.phone, o.phone),
        _row(
          OwnerFacilityStrings.openTime,
          OwnerFacilityStrings.openHours(formatMinutes(o.openMinutes), formatMinutes(o.closeMinutes)),
        ),
        if (o.amenities.isNotEmpty) _row(OwnerFacilityStrings.amenities, o.amenities.join(' • ')),
        if (o.images.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final img in o.images)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: OwnerImage(img, width: 96, height: 64),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _courtsSection(OwnerFacility f) => _section(
    title: OwnerFacilityStrings.sectionCourts,
    hint: f.isApproved ? null : OwnerFacilityStrings.lockedUntilApproved,
    action: f.isApproved
        ? _actionButton(
            OwnerFacilityStrings.addCourtType,
            () async => _apply(await _push<OwnerFacility>(CourtPricingScreen(facility: f))),
            icon: Icons.add,
          )
        : null,
    children: [
      for (final c in f.courts)
        InkWell(
          onTap: f.isApproved && !c.isLocked
              ? () async => _apply(await _push<OwnerFacility>(CourtPricingScreen(facility: f, court: c)))
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  sportIcon(c.sport),
                  size: 20,
                  color: c.isLocked ? AppColors.textSecondary : AppColors.primaryGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        OwnerFacilityStrings.courtLine(c.label, c.courtCount),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: c.isLocked ? AppColors.textSecondary : AppColors.textMain,
                          decoration: c.isLocked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        _pricingSummary(c),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.needsPricing && f.isApproved ? AppColors.tagOrangeText : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (c.isLocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: AppColors.textSecondary),
                        SizedBox(width: 2),
                        Text(
                          OwnerFacilityStrings.locked,
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _unlock(c),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(OwnerFacilityStrings.unlock),
                  ),
                ] else if (f.isApproved)
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
    ],
  );

  String _pricingSummary(CourtConfig c) {
    final p = c.pricing;
    if (p == null) return OwnerFacilityStrings.noPricing;
    final prices = [p.weekdayPrice, p.weekdayPeakPrice, p.weekendPrice, p.weekendPeakPrice];
    final low = prices.reduce((a, b) => a < b ? a : b);
    final high = prices.reduce((a, b) => a > b ? a : b);
    return '${OwnerFacilityStrings.slotLength(p.slotMinutes)} • ${OwnerFacilityStrings.priceRange(low, high)}';
  }

  Widget _closuresSection(OwnerFacility f) {
    final active = f.activeClosures(DateTime.now());
    return _section(
      title: OwnerFacilityStrings.sectionClosures,
      action: _actionButton(OwnerFacilityStrings.addClosure, () async {
        final updated = await showClosureSheet(context, f);
        _apply(updated);
        if (updated != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.closureAdded)));
        }
      }, icon: Icons.block),
      children: [
        if (active.isEmpty)
          const Text(OwnerFacilityStrings.noClosures, style: TextStyle(color: AppColors.textSecondary))
        else
          for (final c in active)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 18, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.isWholeFacility ? OwnerFacilityStrings.wholeFacility : f.courtFor(c.sport!, c.courtType!)?.label ?? ''}'
                          ' • ${OwnerFacilityStrings.closureRange(Formatters.dayMonth(c.from), Formatters.dayMonth(c.to))}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(c.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _removeClosure(c),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                    child: const Text(OwnerFacilityStrings.reopen),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
