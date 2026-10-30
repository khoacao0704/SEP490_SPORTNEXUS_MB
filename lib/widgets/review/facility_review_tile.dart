import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/review.dart';
import '../../theme/app_colors.dart';

/// Sao chỉ để xem (không chấm được).
class StarDisplay extends StatelessWidget {
  final int stars;
  final double size;

  const StarDisplay({super.key, required this.stars, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < stars ? Colors.amber : AppColors.cardBorder,
        ),
      ),
    );
  }
}

/// Một đánh giá cơ sở: người viết, sao, nhận xét, phản hồi của chủ sân.
/// [showFacility]: hiện tên cơ sở và trạng thái bị ẩn (danh sách đánh giá của chính mình).
class FacilityReviewTile extends StatelessWidget {
  final FacilityReviewItem review;
  final bool showFacility;

  const FacilityReviewTile({super.key, required this.review, this.showFacility = false});

  static String _date(DateTime d) => '${Formatters.dayMonth(d)}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.lightGreen,
            backgroundImage: r.userAvatarUrl == null ? null : NetworkImage(r.userAvatarUrl!),
            child: r.userAvatarUrl != null
                ? null
                : Text(
                    r.userName.isEmpty ? '?' : r.userName.characters.first.toUpperCase(),
                    style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showFacility && r.facilityName != null)
                  Text(
                    r.facilityName!,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                  )
                else
                  Text(r.userName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    StarDisplay(stars: r.stars),
                    const SizedBox(width: 6),
                    Text(_date(r.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                if (showFacility && r.isHidden) ...[
                  const SizedBox(height: 4),
                  Text(
                    r.hiddenReason == null
                        ? ReviewStrings.hiddenByAdmin
                        : '${ReviewStrings.hiddenByAdmin} • ${ReviewStrings.hiddenReason(r.hiddenReason!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ],
                if (r.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r.comment, style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.4)),
                ],
                if (r.ownerReply != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.repliedAt == null
                              ? ReviewStrings.ownerReply
                              : '${ReviewStrings.ownerReply} • ${_date(r.repliedAt!)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(r.ownerReply!, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Điểm trung bình + số đánh giá + thanh phân bố theo từng mức sao.
class FacilityReviewSummary extends StatelessWidget {
  final FacilityReviewStats stats;

  const FacilityReviewSummary({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.distribution.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Row(
      children: [
        Column(
          children: [
            Text(
              stats.average.toStringAsFixed(1),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            StarDisplay(stars: stats.average.round()),
            const SizedBox(height: 2),
            Text(ReviewStrings.reviewCount(stats.total), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              for (var s = 5; s >= 1; s--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    children: [
                      SizedBox(width: 12, child: Text('$s', style: const TextStyle(fontSize: 11))),
                      const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxCount == 0 ? 0 : (stats.distribution[s] ?? 0) / maxCount,
                            minHeight: 6,
                            backgroundColor: AppColors.divider,
                            valueColor: const AlwaysStoppedAnimation(Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${stats.distribution[s] ?? 0}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
