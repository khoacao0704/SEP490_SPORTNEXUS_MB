import 'package:flutter/material.dart';
import '../../core/strings/lfg_strings.dart';
import '../../theme/app_colors.dart';

/// Công tắc "Chế độ duyệt người tham gia" ở màn tạo / sửa kèo (mặc định tắt như Web).
class LfgApprovalSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const LfgApprovalSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Material (không phải Container có màu nền) để hiệu ứng chạm của ListTile hiện đúng.
    return Material(
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primaryGreen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 18, color: AppColors.tagOrangeText),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                LfgStrings.approvalTitle,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value ? LfgStrings.approvalOn : LfgStrings.approvalOff,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ),
    );
  }
}

/// Nhãn "Cần duyệt người" trên thẻ / chi tiết kèo.
class LfgApprovalChip extends StatelessWidget {
  const LfgApprovalChip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.tagOrangeBg, borderRadius: BorderRadius.circular(10)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 12, color: AppColors.tagOrangeText),
            SizedBox(width: 3),
            Flexible(
              child: Text(
                LfgStrings.needsApproval,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.tagOrangeText),
              ),
            ),
          ],
        ),
      );
}
