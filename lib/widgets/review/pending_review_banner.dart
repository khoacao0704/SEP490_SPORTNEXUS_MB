import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../data/app_repositories.dart';
import '../../screens/review/pending_reviews_screen.dart';
import '../../theme/app_colors.dart';

/// Banner "Bạn có N buổi chơi chờ đánh giá"; tự ẩn khi không có buổi nào.
class PendingReviewBanner extends StatefulWidget {
  const PendingReviewBanner({super.key});

  @override
  State<PendingReviewBanner> createState() => _PendingReviewBannerState();
}

class _PendingReviewBannerState extends State<PendingReviewBanner> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pending = await AppRepositories.review.getPendingReviews();
      if (mounted) setState(() => _count = pending.length);
    } catch (_) {
      // Banner chỉ là lời nhắc: lỗi thì ẩn đi.
    }
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingReviewsScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    return Material(
      color: AppColors.tagOrangeBg,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: AppColors.tagOrangeText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ReviewStrings.bannerMessage(_count),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.tagOrangeText),
                ),
              ),
              const Text(
                ReviewStrings.bannerAction,
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
              ),
              const Icon(Icons.chevron_right, color: AppColors.tagOrangeText),
            ],
          ),
        ),
      ),
    );
  }
}
