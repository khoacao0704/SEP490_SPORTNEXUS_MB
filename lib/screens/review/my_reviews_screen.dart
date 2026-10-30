import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../data/app_repositories.dart';
import '../../theme/app_colors.dart';
import '../../widgets/review/facility_review_tile.dart';
import '../../widgets/review/paged_reviews.dart';

/// Đánh giá cơ sở mình đã viết, kể cả đánh giá bị Admin ẩn (chỉ mình thấy).
class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          ReviewStrings.myReviews,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: PagedReviews(
        fetch: (page) => AppRepositories.review.getMyReviews(page: page),
        emptyText: ReviewStrings.noMyReviews,
        itemBuilder: (review) => FacilityReviewTile(review: review, showFacility: true),
      ),
    );
  }
}
