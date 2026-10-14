import 'package:flutter/material.dart';
import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../theme/app_colors.dart';

/// Chọn loại sân (sân 5/7/11, nửa sân 3x3 / sân 5x5). Mỗi loại có số sân và giá riêng.
class CourtTypeSelector extends StatelessWidget {
  /// Các loại sân có ở cơ sở (để hiện số sân và giá từ).
  final List<SportOffering> offerings;
  final CourtType selected;
  final ValueChanged<CourtType> onSelected;

  const CourtTypeSelector({super.key, required this.offerings, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in offerings)
          CourtTypeChip(
            type: o.courtType,
            subtitle: '${FacilityStrings.courtCount(o.courtCount)} • ${FacilityStrings.priceFrom(Formatters.vnd(o.priceFrom))}',
            selected: o.courtType == selected,
            onTap: () => onSelected(o.courtType),
          ),
      ],
    );
  }
}

class CourtTypeChip extends StatelessWidget {
  final CourtType type;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const CourtTypeChip({super.key, required this.type, required this.selected, required this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryGreen : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${type.label} (${type.matchup})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textMain,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
