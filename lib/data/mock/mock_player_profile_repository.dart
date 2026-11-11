import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/player_survey.dart';
import '../../models/sport.dart';
import '../repositories/player_profile_repository.dart';
import 'mock_auth_repository.dart';

/// Bản giả lập khảo sát người chơi, lưu theo tài khoản trong SharedPreferences.
/// Hai người chơi demo đã làm khảo sát sẵn; tài khoản mới đăng ký thì chưa.
class MockPlayerProfileRepository implements PlayerProfileRepository {
  static const String keyPrefix = 'mock_player_survey_';
  static const Set<String> completedDemoIds = {'u-player-001', MockAuthRepository.restrictedPlayerId};

  @override
  Future<PlayerSurvey> getSurvey() async {
    final id = await _myId();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$keyPrefix$id');
    if (raw != null) return _decode(jsonDecode(raw) as Map<String, dynamic>);
    if (completedDemoIds.contains(id)) return _demo;
    return const PlayerSurvey();
  }

  @override
  Future<PlayerSurvey> saveSurvey(PlayerSurvey survey) async {
    final id = await _myId();
    final saved = survey.copyWith(isCompleted: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$keyPrefix$id', jsonEncode(_encode(saved)));
    return saved;
  }

  static final PlayerSurvey _demo = PlayerSurvey(
    isCompleted: true,
    gender: Gender.male,
    sports: const [SurveySport(sport: Sport.badminton, level: SkillLevel.intermediate, formats: ['DOUBLES'])],
    availability: [
      for (final d in const [2, 4])
        AvailabilityWindow(dayOfWeek: d, start: DayTime.hm(18, 0), end: DayTime.hm(21, 0)),
    ],
    goal: PlayGoal.exchange,
    frequency: PlayFrequency.weekly12,
  );

  Future<String> _myId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) return 'guest';
    return (jsonDecode(raw) as Map<String, dynamic>)['id'] as String? ?? 'guest';
  }

  static Map<String, dynamic> _encode(PlayerSurvey s) => {
    'isCompleted': s.isCompleted,
    'gender': s.gender?.apiValue,
    'sports': [
      for (final x in s.sports) {'sport': x.sport.apiValue, 'level': x.level.apiValue, 'formats': x.formats},
    ],
    'availability': [
      for (final w in s.availability) {'day': w.dayOfWeek, 'start': w.start.minutes, 'end': w.end.minutes},
    ],
    'lat': s.latitude,
    'lng': s.longitude,
    'radius': s.radiusKm,
    'maxPrice': s.maxPricePerHour,
    'goal': s.goal?.apiValue,
    'frequency': s.frequency?.apiValue,
  };

  static PlayerSurvey _decode(Map<String, dynamic> m) => PlayerSurvey(
    isCompleted: m['isCompleted'] == true,
    gender: Gender.fromApi(m['gender']),
    sports: [
      for (final x in (m['sports'] as List? ?? const []).cast<Map<String, dynamic>>())
        SurveySport(
          sport: Sport.fromApi(x['sport'] as String),
          level: SkillLevel.fromApi(x['level']) ?? SkillLevel.beginner,
          formats: (x['formats'] as List? ?? const []).cast<String>(),
        ),
    ],
    availability: [
      for (final w in (m['availability'] as List? ?? const []).cast<Map<String, dynamic>>())
        AvailabilityWindow(dayOfWeek: w['day'] as int, start: DayTime(w['start'] as int), end: DayTime(w['end'] as int)),
    ],
    latitude: (m['lat'] as num?)?.toDouble(),
    longitude: (m['lng'] as num?)?.toDouble(),
    radiusKm: m['radius'] as int? ?? PlayerSurvey.defaultRadiusKm,
    maxPricePerHour: m['maxPrice'] as int?,
    goal: PlayGoal.fromApi(m['goal']),
    frequency: PlayFrequency.fromApi(m['frequency']),
  );
}
