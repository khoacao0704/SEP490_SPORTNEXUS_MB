import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../models/facility.dart';
import '../../theme/app_colors.dart';

/// Nút chọn cơ sở trên AppBar Chủ sân. [selectedId] `null` = tất cả cơ sở.
class FacilitySelector extends StatelessWidget {
  final List<Facility> facilities;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const FacilitySelector({super.key, required this.facilities, required this.selectedId, required this.onChanged});

  String get _label => facilities.where((f) => f.id == selectedId).firstOrNull?.name ?? OwnerStrings.allFacilities;

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                OwnerStrings.chooseFacility,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
            ),
            _option(sheetContext, '', OwnerStrings.allFacilities, null, selectedId == null),
            for (final f in facilities) _option(sheetContext, f.id, f.name, f.address, selectedId == f.id),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    onChanged(picked.isEmpty ? null : picked);
  }

  Widget _option(BuildContext context, String id, String title, String? subtitle, bool selected) {
    return ListTile(
      leading: Icon(
        id.isEmpty ? Icons.apps : Icons.storefront_outlined,
        color: selected ? AppColors.primaryGreen : AppColors.textSecondary,
      ),
      title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      subtitle: subtitle == null ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selected ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
      onTap: () => Navigator.pop(context, id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: facilities.length > 1 ? () => _pick(context) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (facilities.length > 1) const Icon(Icons.arrow_drop_down, color: AppColors.textMain),
        ],
      ),
    );
  }
}
