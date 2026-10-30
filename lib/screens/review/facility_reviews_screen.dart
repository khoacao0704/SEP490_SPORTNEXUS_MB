import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/review.dart';
import '../../theme/app_colors.dart';
import '../../widgets/review/facility_review_tile.dart';
import '../../widgets/review/paged_reviews.dart';

/// Mọi đánh giá của một cơ sở, lọc theo số sao, cuộn tới cuối thì tải thêm.
class FacilityReviewsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const FacilityReviewsScreen({super.key, required this.facilityId, required this.facilityName});

  @override
  State<FacilityReviewsScreen> createState() => _FacilityReviewsScreenState();
}

class _FacilityReviewsScreenState extends State<FacilityReviewsScreen> {
  int? _stars;
  FacilityReviewStats? _stats;

  Future<FacilityReviewPage> _fetch(int page) async {
    final result = await AppRepositories.review.getFacilityReviews(widget.facilityId, stars: _stars, page: page);
    if (mounted && page == 1) setState(() => _stats = result.stats);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          widget.facilityName,
          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: PagedReviews(
        key: ValueKey(_stars),
        fetch: _fetch,
        emptyText: _stars == null ? ReviewStrings.noReviews : ReviewStrings.noReviewsForStars,
        header: Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              if (stats != null) FacilityReviewSummary(stats: stats),
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final value in <int?>[null, 5, 4, 3, 2, 1])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(value == null ? ReviewStrings.filterAll : ReviewStrings.starsFilter(value)),
                          selected: _stars == value,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _stars = value),
                          selectedColor: AppColors.primaryGreen,
                          backgroundColor: AppColors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _stars == value ? Colors.white : AppColors.textMain,
                          ),
                          side: BorderSide(color: _stars == value ? AppColors.primaryGreen : AppColors.cardBorder),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        itemBuilder: (review) => FacilityReviewTile(review: review),
      ),
    );
  }
}
