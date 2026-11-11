import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Tiêu đề một mục trên màn hình: icon + tiêu đề (chiếm phần còn lại, cắt 1 dòng) + nút "Tất cả >".
/// Nút xem thêm luôn nằm gọn bên phải, không bị tiêu đề dài đẩy ra ngoài.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = AppColors.primaryGreen,
    this.onSeeAll,
    this.seeAllLabel = 'Tất cả',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seeAllLabel,
                    style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.primaryGreen, size: 18),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
