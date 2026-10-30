import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/review.dart';
import '../../screens/review/facility_reviews_screen.dart';
import '../../screens/review/write_facility_review_screen.dart';
import '../../theme/app_colors.dart';
import 'facility_review_tile.dart';

/// Phần "Đánh giá" ở chi tiết cơ sở: tổng hợp, vài đánh giá mới nhất, nút xem tất cả và viết đánh giá
/// (chỉ hiện khi BE cho phép: đã từng check-in và chưa đánh giá cơ sở này).
class FacilityReviewsSection extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  /// Số đánh giá hiện sẵn ở chi tiết cơ sở.
  static const int previewCount = 3;

  const FacilityReviewsSection({super.key, required this.facilityId, required this.facilityName});

  @override
  State<FacilityReviewsSection> createState() => _FacilityReviewsSectionState();
}

class _FacilityReviewsSectionState extends State<FacilityReviewsSection> {
  FacilityReviewPage? _page;
  ReviewEligibility? _eligibility;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await AppRepositories.review.getFacilityReviews(widget.facilityId);
      if (mounted) setState(() => _page = page);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    try {
      final eligibility = await AppRepositories.review.getEligibility(widget.facilityId);
      if (mounted) setState(() => _eligibility = eligibility);
    } catch (_) {
      // Không biết được phép hay không thì ẩn nút viết đánh giá.
    }
  }

  Future<void> _write() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WriteFacilityReviewScreen(facilityId: widget.facilityId, facilityName: widget.facilityName),
      ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ReviewStrings.submitted), backgroundColor: AppColors.primaryGreen),
      );
      _load();
    }
  }

  void _seeAll() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FacilityReviewsScreen(facilityId: widget.facilityId, facilityName: widget.facilityName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final eligibility = _eligibility;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  ReviewStrings.facilityReviews,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
              ),
              if (page != null && page.stats.total > 0)
                TextButton(onPressed: _seeAll, child: const Text(ReviewStrings.seeAll)),
            ],
          ),
          if (_failed)
            const Text(ReviewStrings.loadError, style: TextStyle(color: AppColors.textSecondary))
          else if (page == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2)),
            )
          else if (page.items.isEmpty)
            const Text(ReviewStrings.noReviews, style: TextStyle(color: AppColors.textSecondary))
          else ...[
            FacilityReviewSummary(stats: page.stats),
            const SizedBox(height: 4),
            for (final review in page.items.take(FacilityReviewsSection.previewCount)) ...[
              const Divider(height: 1, color: AppColors.divider),
              FacilityReviewTile(review: review),
            ],
          ],
          if (eligibility != null && eligibility.canReview) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _write,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text(ReviewStrings.writeReview),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else if (eligibility != null && eligibility.alreadyReviewed) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: AppColors.primaryGreen),
                SizedBox(width: 6),
                Text(ReviewStrings.facilityAlreadyReviewed, style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
