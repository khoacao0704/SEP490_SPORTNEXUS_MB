import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../theme/app_colors.dart';

/// Chọn 1–5 sao; [value] = 0 nghĩa là chưa chấm.
class StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRating({super.key, required this.value, required this.onChanged, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final star = i + 1;
          return Semantics(
            button: true,
            selected: star <= value,
            label: '$star sao',
            child: InkResponse(
              onTap: () => onChanged(star),
              radius: size * 0.7,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: star <= value ? Colors.amber : AppColors.cardBorder,
                ),
              ),
            ),
          );
        }),
        if (value > 0) ...[
          const SizedBox(width: 8),
          Text(
            ReviewStrings.starLabels[value - 1],
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
