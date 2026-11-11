import '../../core/strings/survey_strings.dart';
import '../../models/player_survey.dart';
import '../../models/sport.dart';
import '../repositories/player_profile_repository.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// Khảo sát người chơi qua BE: GET / PUT /api/auth/me/onboarding (chỉ Player).
///
/// - GET luôn 200; chưa làm thì `isCompleted` = false, có thể còn môn / lịch rảnh đã lưu dở.
/// - Môn gửi theo `sportCategoryId` (ghép với môn của app theo tên); môn BE có mà app không có thì bỏ qua.
/// - Enum BE nhận không phân biệt hoa thường; lịch rảnh "HH:mm" giờ Việt Nam, dayOfWeek 0 = Chủ nhật.
/// - `preferredFormats`: môn vợt SINGLES / DOUBLES, môn đồng đội là số người mỗi đội; GET có thể trả mảng hoặc chuỗi
///   cách nhau dấu phẩy.
class ApiPlayerProfileRepository implements PlayerProfileRepository {
  static const String onboardingPath = '/api/auth/me/onboarding';

  final ApiClient _api;
  final Future<String?> Function(Sport sport) _categoryIdOf;
  final Future<Sport?> Function(String categoryId) _sportOf;

  ApiPlayerProfileRepository({required this._api, required this._categoryIdOf, required this._sportOf});

  @override
  Future<PlayerSurvey> getSurvey() async {
    final data = await _call(() => _api.get(onboardingPath));
    return _fromApi(data is Map ? Map<String, dynamic>.from(data) : const {});
  }

  @override
  Future<PlayerSurvey> saveSurvey(PlayerSurvey survey) async {
    final sports = <Map<String, dynamic>>[];
    for (final s in survey.sports) {
      final id = await _categoryIdOf(s.sport);
      if (id == null) throw PlayerProfileException(SurveyStrings.sportUnavailable(s.sport.label));
      sports.add({
        'sportCategoryId': id,
        'skillLevel': s.level.apiValue,
        if (s.formats.isNotEmpty) 'preferredFormats': s.formats,
      });
    }
    final data = await _call(
      () => _api.put(
        onboardingPath,
        body: {
          'gender': ?survey.gender?.apiValue,
          'sports': sports,
          'availability': [
            for (final w in survey.availability)
              {'dayOfWeek': w.dayOfWeek, 'startTime': w.start.hhmm, 'endTime': w.end.hhmm},
          ],
          if (survey.hasLocation) ...{'latitude': survey.latitude, 'longitude': survey.longitude},
          'radiusKm': survey.radiusKm,
          'maxPricePerHour': ?survey.maxPricePerHour,
          'goal': ?survey.goal?.apiValue,
          'frequency': ?survey.frequency?.apiValue,
        },
      ),
    );
    if (data is Map && data['sports'] is List) {
      final saved = await _fromApi(Map<String, dynamic>.from(data));
      return saved.isCompleted ? saved : saved.copyWith(isCompleted: true);
    }
    return survey.copyWith(isCompleted: true);
  }

  Future<PlayerSurvey> _fromApi(Map<String, dynamic> m) async {
    final sports = <SurveySport>[];
    for (final raw in _maps(m['sports'])) {
      final id = raw['sportCategoryId']?.toString();
      final sport =
          ApiFacilityRepository.sportFromName(raw['sportName']?.toString()) ?? (id == null ? null : await _sportOf(id));
      if (sport == null || sports.any((s) => s.sport == sport)) continue;
      sports.add(
        SurveySport(
          sport: sport,
          level: SkillLevel.fromApi(raw['skillLevel']) ?? SkillLevel.beginner,
          formats: _formats(raw['preferredFormats']),
        ),
      );
    }
    final availability = <AvailabilityWindow>[];
    for (final raw in _maps(m['availability'])) {
      final day = (raw['dayOfWeek'] as num?)?.toInt();
      final start = DayTime.parse(raw['startTime']);
      final end = DayTime.parse(raw['endTime']);
      if (day == null || day < 0 || day > 6 || start == null || end == null) continue;
      availability.add(AvailabilityWindow(dayOfWeek: day, start: start, end: end));
    }
    availability.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final radius = (m['radiusKm'] as num?)?.round();
    final maxPrice = (m['maxPricePerHour'] as num?)?.round();
    return PlayerSurvey(
      isCompleted: m['isCompleted'] == true,
      gender: Gender.fromApi(m['gender']),
      sports: sports,
      availability: availability,
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      radiusKm: radius == null
          ? PlayerSurvey.defaultRadiusKm
          : radius.clamp(PlayerSurvey.minRadiusKm, PlayerSurvey.maxRadiusKm),
      maxPricePerHour: maxPrice == null || maxPrice <= 0 ? null : maxPrice,
      goal: PlayGoal.fromApi(m['goal']),
      frequency: PlayFrequency.fromApi(m['frequency']),
    );
  }

  static List<String> _formats(Object? v) {
    final list = v is List ? v.map((e) => e.toString()) : (v?.toString() ?? '').split(',');
    return list.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toSet().toList();
  }

  static List<Map<String, dynamic>> _maps(Object? v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw PlayerProfileException.fromApi(e);
    }
  }
}
