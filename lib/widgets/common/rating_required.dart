import 'package:flutter/material.dart';

import '../../core/strings/rating_strings.dart';
import '../../data/api/api_error_codes.dart';
import '../../data/app_repositories.dart';
import '../../data/session_store.dart';
import '../../models/sport.dart';
import '../../screens/rating/skill_assessment_screen.dart';

/// BE báo thiếu Elo môn (RATING_REQUIRED) khi tạo đội / nhận lời mời vào đội / đăng ký giải.
/// Mình thiếu: mời làm khảo sát trình độ môn đó. Thành viên khác thiếu: báo số người cần làm.
/// Trả `true` khi đã xử lý lỗi này, `false` với lỗi khác.
Future<bool> handleRatingRequired(BuildContext context, Object error) async {
  if (error is! CodedError || !error.isRatingRequired) return false;
  final me = await SessionStore.readUser();
  final missing = error.missingUserIds;
  final mine = missing.isEmpty || (me != null && missing.contains(me.id));
  final others = missing.where((id) => id != me?.id).length;
  final categoryId = error.sportCategoryId;
  final Sport? sport = categoryId == null ? null : await AppRepositories.sportOfCategory(categoryId);
  if (!context.mounted) return true;

  final takeTest = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(RatingStrings.ratingRequiredTitle),
      content: Text(
        [
          if (mine) RatingStrings.ratingRequiredMine,
          if (others > 0) RatingStrings.ratingRequiredOthers(others),
        ].join('\n\n'),
      ),
      actions: [
        if (mine && sport != null) ...[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(RatingStrings.later)),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(RatingStrings.takeAssessment),
          ),
        ] else
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(RatingStrings.ok)),
      ],
    ),
  );
  if (takeTest == true && sport != null && context.mounted) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SkillAssessmentScreen(sport: sport)));
  }
  return true;
}
