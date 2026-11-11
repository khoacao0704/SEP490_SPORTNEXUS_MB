/// Mã lỗi máy đọc (`errorCode`) BE trả kèm câu lỗi. Phần lớn lỗi không có mã (chỉ có message).
abstract final class ApiErrorCodes {
  /// 403: người chơi chưa làm khảo sát (tạo / vào kèo, đăng ký giải, khảo sát trình độ…).
  static const String onboardingRequired = 'ONBOARDING_REQUIRED';

  /// 403: có người chưa có Elo môn này. errorDetail = {sportCategoryId, missingUserIds[]}.
  static const String ratingRequired = 'RATING_REQUIRED';

  /// 400: đội chưa khai môn. errorDetail = {teamId}.
  static const String teamSportRequired = 'TEAM_SPORT_REQUIRED';
}

/// Lỗi nghiệp vụ có thể mang mã lỗi của BE ([code], [detail]); lỗi của mock không có mã.
abstract interface class CodedError {
  String get message;
  String? get code;
  Map<String, dynamic>? get detail;
}

extension CodedErrorX on CodedError {
  bool get isOnboardingRequired => code == ApiErrorCodes.onboardingRequired;
  bool get isRatingRequired => code == ApiErrorCodes.ratingRequired;
  bool get isTeamSportRequired => code == ApiErrorCodes.teamSportRequired;

  /// Môn còn thiếu Elo ([ApiErrorCodes.ratingRequired]).
  String? get sportCategoryId => _string(detail?['sportCategoryId']);

  /// Người chưa có Elo môn đó ([ApiErrorCodes.ratingRequired]).
  List<String> get missingUserIds =>
      (detail?['missingUserIds'] as List? ?? const []).map((e) => e.toString()).toList(growable: false);

  /// Đội chưa khai môn ([ApiErrorCodes.teamSportRequired]).
  String? get teamId => _string(detail?['teamId']);

  static String? _string(Object? v) {
    final s = v?.toString();
    return s == null || s.isEmpty ? null : s;
  }
}
