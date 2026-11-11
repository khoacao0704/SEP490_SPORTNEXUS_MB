import 'package:flutter/material.dart';

import '../../data/api/api_error_codes.dart';
import '../../data/onboarding_gate.dart';
import '../../screens/profile/player_survey_screen.dart';

/// BE báo người chơi chưa làm khảo sát (ONBOARDING_REQUIRED): báo câu của BE rồi mở màn khảo sát.
/// Trả `true` khi đã xử lý lỗi này (nơi gọi không cần báo lỗi nữa), `false` với lỗi khác.
Future<bool> handleOnboardingRequired(BuildContext context, Object error) async {
  if (error is! CodedError || !error.isOnboardingRequired) return false;
  await OnboardingGate.clear();
  if (!context.mounted) return true;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.message)));
  await Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerSurveyScreen()));
  return true;
}
