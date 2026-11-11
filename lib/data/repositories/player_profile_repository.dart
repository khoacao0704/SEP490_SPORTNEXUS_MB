import '../../models/player_survey.dart';
import '../api/api_error_codes.dart';

/// Lỗi khảo sát / hồ sơ thể thao; [message] sẵn sàng để hiển thị.
class PlayerProfileException implements Exception, CodedError {
  @override
  final String message;

  @override
  final String? code;

  @override
  final Map<String, dynamic>? detail;

  const PlayerProfileException(this.message, {this.code, this.detail});

  PlayerProfileException.fromApi(CodedError e) : this(e.message, code: e.code, detail: e.detail);

  @override
  String toString() => 'PlayerProfileException: $message';
}

/// Khảo sát người chơi (hồ sơ thể thao). Người chơi chưa hoàn thành thì phải làm trước khi vào app.
abstract class PlayerProfileRepository {
  /// Khảo sát hiện có; chưa làm thì [PlayerSurvey.isCompleted] = false (có thể còn phần đã lưu dở).
  Future<PlayerSurvey> getSurvey();

  /// Lưu (hoàn thành) khảo sát; trả bản đã lưu.
  Future<PlayerSurvey> saveSurvey(PlayerSurvey survey);
}
