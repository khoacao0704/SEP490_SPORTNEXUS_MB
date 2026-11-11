import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_error_codes.dart';
import 'package:test1/data/api/api_player_profile_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/player_profile_repository.dart';
import 'package:test1/models/player_survey.dart';
import 'package:test1/models/sport.dart';

class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) return ResponseBody.fromString('', 404);
    final (status, body) = route;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ok(Object? data) => {'statusCode': 200, 'message': 'OK', 'data': data};

void main() {
  late _FakeServer server;
  late ApiPlayerProfileRepository repo;
  const ids = {Sport.badminton: 'cat-cl', Sport.football: 'cat-bd'};

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiPlayerProfileRepository(
      api: ApiClient(tokens: tokens, dio: dio),
      categoryIdOf: (s) async => ids[s],
      sportOf: (id) async => ids.entries.where((e) => e.value == id).firstOrNull?.key,
    );
  });

  test('chưa khảo sát: isCompleted false, các mục rỗng', () async {
    server.routes['GET ${ApiPlayerProfileRepository.onboardingPath}'] = (
      200,
      {
        'statusCode': 200,
        'message': 'Bạn chưa hoàn thành khảo sát người chơi',
        'data': {'isCompleted': false, 'sports': [], 'availability': [], 'radiusKm': null},
      },
    );
    final survey = await repo.getSurvey();
    expect(survey.isCompleted, isFalse);
    expect(survey.sports, isEmpty);
    expect(survey.radiusKm, PlayerSurvey.defaultRadiusKm);
  });

  test('đọc khảo sát: môn theo id hoặc tên, nội dung dạng chuỗi phẩy, lịch rảnh sắp T2 → CN, bỏ môn lạ', () async {
    server.routes['GET ${ApiPlayerProfileRepository.onboardingPath}'] = (
      200,
      _ok({
        'isCompleted': true,
        'gender': 'female',
        'sports': [
          {'sportCategoryId': 'cat-cl', 'skillLevel': 'ADVANCED', 'preferredFormats': 'singles, DOUBLES'},
          {'sportCategoryId': 'x', 'sportName': 'Bóng đá', 'skillLevel': 'beginner', 'preferredFormats': ['7']},
          {'sportCategoryId': 'cat-la', 'sportName': 'Bóng bàn', 'skillLevel': 'BEGINNER'},
        ],
        'availability': [
          {'dayOfWeek': 0, 'startTime': '08:00:00', 'endTime': '10:00:00'},
          {'dayOfWeek': 1, 'startTime': '18:30', 'endTime': '21:00'},
        ],
        'latitude': 10.77,
        'longitude': 106.7,
        'radiusKm': 15,
        'maxPricePerHour': 300000,
        'goal': 'COMPETITION',
        'frequency': 'WEEKLY_3_PLUS',
      }),
    );
    final s = await repo.getSurvey();
    expect(s.isCompleted, isTrue);
    expect(s.gender, Gender.female);
    expect(s.sports.map((x) => x.sport), [Sport.badminton, Sport.football]);
    expect(s.sports.first.level, SkillLevel.advanced);
    expect(s.sports.first.formats, ['SINGLES', 'DOUBLES']);
    expect(s.sports.last.formats, ['7']);
    expect(s.availability.map((w) => w.label), ['T2 18:30–21:00', 'CN 08:00–10:00']);
    expect(s.hasLocation, isTrue);
    expect(s.radiusKm, 15);
    expect(s.maxPricePerHour, 300000);
    expect(s.goal, PlayGoal.competition);
    expect(s.frequency, PlayFrequency.weekly3Plus);
  });

  test('lưu khảo sát: gửi categoryId, enum BE, giờ HH:mm; không có vị trí / giá / giới tính thì bỏ field', () async {
    server.routes['PUT ${ApiPlayerProfileRepository.onboardingPath}'] = (200, _ok(null));
    final saved = await repo.saveSurvey(
      PlayerSurvey(
        sports: const [SurveySport(sport: Sport.football, level: SkillLevel.intermediate, formats: ['5'])],
        availability: [AvailabilityWindow(dayOfWeek: 6, start: DayTime.hm(7, 0), end: DayTime.hm(9, 30))],
        radiusKm: 5,
        goal: PlayGoal.exchange,
        frequency: PlayFrequency.weekly12,
      ),
    );
    expect(server.requests.last.data, {
      'sports': [
        {
          'sportCategoryId': 'cat-bd',
          'skillLevel': 'INTERMEDIATE',
          'preferredFormats': ['5'],
        },
      ],
      'availability': [
        {'dayOfWeek': 6, 'startTime': '07:00', 'endTime': '09:30'},
      ],
      'radiusKm': 5,
      'goal': 'EXCHANGE',
      'frequency': 'WEEKLY_1_2',
    });
    expect(saved.isCompleted, isTrue);
  });

  test('môn chưa có trên BE thì báo lỗi, không gửi; lỗi BE giữ mã lỗi', () async {
    await expectLater(
      repo.saveSurvey(const PlayerSurvey(sports: [SurveySport(sport: Sport.tennis, level: SkillLevel.beginner)])),
      throwsA(isA<PlayerProfileException>()),
    );
    expect(server.requests, isEmpty);

    server.routes['GET ${ApiPlayerProfileRepository.onboardingPath}'] = (
      403,
      {'statusCode': 403, 'message': 'Chỉ người chơi', 'errorCode': 'X', 'data': null},
    );
    await expectLater(
      repo.getSurvey(),
      throwsA(isA<PlayerProfileException>().having((e) => e.code, 'code', 'X')),
    );
    expect(ApiErrorCodes.onboardingRequired, 'ONBOARDING_REQUIRED');
  });
}
