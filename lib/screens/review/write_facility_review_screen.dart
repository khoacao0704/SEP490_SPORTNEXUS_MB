import 'package:flutter/material.dart';
import '../../core/strings/review_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/review_repository.dart';
import '../../models/review.dart';
import '../../theme/app_colors.dart';
import '../../widgets/review/star_rating.dart';

/// Viết đánh giá cho một cơ sở (một lần, không sửa). Pop về `true` khi gửi thành công.
class WriteFacilityReviewScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const WriteFacilityReviewScreen({super.key, required this.facilityId, required this.facilityName});

  @override
  State<WriteFacilityReviewScreen> createState() => _WriteFacilityReviewScreenState();
}

class _WriteFacilityReviewScreenState extends State<WriteFacilityReviewScreen> {
  final TextEditingController _comment = TextEditingController();
  int _stars = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ReviewStrings.confirmTitle),
        content: const Text('${ReviewStrings.confirmMessage}\n${ReviewStrings.facilityPublicNote}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(ReviewStrings.back)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text(ReviewStrings.send),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await AppRepositories.review.submitFacilityReview(
        widget.facilityId,
        FacilityReviewInput(stars: _stars, comment: _comment.text.trim()),
      );
      if (mounted) Navigator.pop(context, true);
    } on ReviewException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          ReviewStrings.writeReviewTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.facilityName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const SizedBox(height: 12),
                StarRating(value: _stars, onChanged: (v) => setState(() => _stars = v)),
                if (_stars == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(ReviewStrings.chooseStars, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _comment,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: ReviewStrings.facilityCommentHint,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const Text(
                  ReviewStrings.facilityPublicNote,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _stars > 0 && !_isSubmitting ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.authPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.cardBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                  : const Text(ReviewStrings.submit, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
