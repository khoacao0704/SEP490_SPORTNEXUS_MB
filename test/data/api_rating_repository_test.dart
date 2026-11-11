import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_error_codes.dart';
import 'package:test1/data/api/api_rating_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/rating_repository.dart';
import 'package:test1/models/player_survey.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/sport_rating.dart';

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

Map<String, dynamic> _ok(Object? data, {int status = 200}) => {'statusCode': status, 'message': 'OK', 'data': data};

void main() {
  late _FakeServer server;
  late ApiRatingRepository repo;
  const ids = {Sport.badminton: 'cat-cl', Sport.football: 'cat-bd'};

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiRatingRepository(
      api: ApiClient(tokens: tokens, dio: dio),
      categoryIdOf: (s) async => ids[s],
      sportOf: (id) async => ids.entries.where((e) => e.value == id).firstOrNull?.key,
    );
  });

  test('Elo của tôi: dòng cá nhân + đội, rank là hạng mức chữ; rỗng khi chưa có', () async {
    server.routes['GET ${ApiRatingRepository.myRatingsPath}'] = (
      200,
      _ok([
        {
          'ratingType': 'PERSONAL',
          'ownerType': 'USER',
          'ownerId': 'me',
          'ownerName': 'Khoa',
          'sportCategoryId': 'cat-cl',
          'sportName': 'Cầu lông',
          'rating': 1240.0,
          'rank': 'Bạc',
          'ratedMatches': 3,
          'isProvisional': true,
        },
        {
          'ratingType': 'TEAM',
          'ownerType': 'TEAM',
          'ownerId': 'team-1',
          'ownerName': 'FC Q7',
          'sportCategoryId': 'cat-bd',
          'rating': 1180,
          'rank': 'Bạc',
          'ratedMatches': 0,
        },
      ]),
    );
    final ratings = await repo.getMyRatings();
    expect(ratings.map((r) => r.type), [RatingType.personal, RatingType.team]);
    expect(ratings.first.sport, Sport.badminton);
    expect(ratings.first.rating, 1240);
    expect(ratings.first.rankLabel, 'Bạc');
    expect(ratings.first.isProvisional, isTrue);
    expect(ratings.last.sport, Sport.football); // không có sportName → tra theo categoryId
    expect(ratings.last.ownerId, 'team-1');

    server.routes['GET ${ApiRatingRepository.myRatingsPath}'] = (200, _ok([]));
    expect(await repo.getMyRatings(), isEmpty);
  });

  test('bảng xếp hạng: gửi categoryId + ratingType + trang; vị trí tự tính theo trang', () async {
    server.routes['GET ${ApiRatingRepository.leaderboardPath}'] = (
      200,
      _ok({
        'page': 2,
        'pageSize': 20,
        'totalItems': 41,
        'items': [
          {'ownerId': 't1', 'ownerName': 'Đội A', 'rating': 1500, 'rank': 'Bạch kim', 'ratedMatches': 9},
        ],
      }),
    );
    final page = await repo.getLeaderboard(Sport.football, type: RatingType.team, page: 2);
    expect(server.requests.last.queryParameters, {
      'sportCategoryId': 'cat-bd',
      'ratingType': 'TEAM',
      'page': 2,
      'pageSize': ApiRatingRepository.pageSize,
    });
    expect(page.items.single.type, RatingType.team);
    expect(page.items.single.sport, Sport.football);
    expect(page.positionOf(0), 21);
    expect(page.hasMore, isTrue);
  });

  test('đề khảo sát: câu chọn + câu thang điểm, kết quả cũ, lý do bị chặn', () async {
    server.routes['GET ${ApiRatingRepository.questionsPath('cat-cl')}'] = (
      200,
      _ok({
        'sportCategoryId': 'cat-cl',
        'sportName': 'Cầu lông',
        'questions': [
          {
            'code': 'YEARS',
            'question': 'Bạn chơi bao lâu?',
            'type': 'SINGLE_CHOICE',
            'options': [
              {'value': 'LT_1', 'label': 'Dưới 1 năm'},
            ],
          },
          {'code': 'TECH_1', 'question': 'Đập cầu', 'type': 'SCALE_1_5', 'options': []},
        ],
        'current': {
          'id': 'a1',
          'sportCategoryId': 'cat-cl',
          'score': 50,
          'computedRating': 1300,
          'assignedRating': 1300,
          'skillLevel': 'INTERMEDIATE',
          'evidenceStatus': 'NONE',
          'flags': [],
        },
        'blockedReason': 'Mỗi môn chỉ làm lại khảo sát sau 90 ngày (từ 01/02/2027).',
      }),
    );
    final form = await repo.getAssessmentForm(Sport.badminton);
    expect(form.questions.map((q) => q.code), ['YEARS', 'TECH_1']);
    expect(form.questions.last.isScale, isTrue);
    expect(form.questions.last.choices.map((c) => c.value), ['1', '2', '3', '4', '5']);
    expect(form.current!.assignedRating, 1300);
    expect(form.current!.skillLevel, SkillLevel.intermediate);
    expect(form.isBlocked, isTrue);
  });

  test('nộp bài: answers / techniques / evidenceUrls; Elo bị giữ 1400 khi bằng chứng chờ duyệt', () async {
    server.routes['POST ${ApiRatingRepository.submitPath('cat-cl')}'] = (
      201,
      _ok({
        'id': 'a2',
        'sportCategoryId': 'cat-cl',
        'score': 90,
        'computedRating': 1540,
        'assignedRating': 1400,
        'skillLevel': 'PROFESSIONAL',
        'flags': ['SELF_LEVEL mâu thuẫn với TOURNAMENT_LEVEL'],
        'evidenceUrls': ['https://a.vn/1.jpg'],
        'evidenceStatus': 'PENDING',
      }, status: 201),
    );
    final result = await repo.submitAssessment(
      Sport.badminton,
      answers: {'YEARS': 'GT_5'},
      techniques: {'TECH_1': 5},
      evidenceUrls: [' https://a.vn/1.jpg ', ''],
    );
    expect(server.requests.last.data, {
      'answers': {'YEARS': 'GT_5'},
      'techniques': {'TECH_1': 5},
      'evidenceUrls': ['https://a.vn/1.jpg'],
    });
    expect(result.isCapped, isTrue);
    expect(result.evidenceStatus, EvidenceStatus.pending);
    expect(result.flags, hasLength(1));
  });

  test('ảnh bằng chứng: POST uploads/images?purpose=general, trường "file", lấy data.url; quá 5MB chặn trên máy', () async {
    final dir = await Directory.systemTemp.createTemp('evidence');
    // Windows có thể còn giữ file khi stream multipart chưa đọc hết: dọn được thì dọn.
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // bỏ qua
      }
    });
    final small = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, ...List.filled(997, 1)]);
    server.routes['POST ${ApiRatingRepository.uploadPath}'] = (
      201,
      _ok({'url': 'https://res.cloudinary.com/x/a.jpg', 'publicId': 'x'}, status: 201),
    );
    expect(await repo.uploadEvidence(small.path), 'https://res.cloudinary.com/x/a.jpg');
    final request = server.requests.last;
    expect(request.queryParameters, {'purpose': 'general'});
    expect((request.data as FormData).files.single.key, 'file');

    final big = File('${dir.path}/b.jpg')..writeAsBytesSync(List.filled(ApiRatingRepository.maxImageBytes + 1, 1));
    final count = server.requests.length;
    await expectLater(repo.uploadEvidence(big.path), throwsA(isA<RatingException>()));
    expect(server.requests.length, count);
  });

  test('nộp bài không có câu thang điểm vẫn gửi techniques rỗng', () async {
    server.routes['POST ${ApiRatingRepository.submitPath('cat-cl')}'] = (201, _ok({'id': 'a3', 'score': 0}, status: 201));
    await repo.submitAssessment(Sport.badminton, answers: {'YEARS': 'LT_1'}, techniques: const {});
    expect(server.requests.last.data, {
      'answers': {'YEARS': 'LT_1'},
      'techniques': <String, int>{},
    });
  });

  test('ràng buộc: chưa dự giải thì kết quả = NONE, số giải = ZERO; đã dự giải thì bỏ NONE', () {
    const questions = [
      AssessmentQuestion(
        code: 'TOURNAMENT_LEVEL',
        question: '',
        type: AssessmentQuestionType.singleChoice,
        options: [AssessmentOption('NONE', 'Chưa'), AssessmentOption('CITY', 'Thành phố')],
      ),
      AssessmentQuestion(
        code: 'BEST_RESULT',
        question: '',
        type: AssessmentQuestionType.singleChoice,
        options: [AssessmentOption('NONE', 'Không có'), AssessmentOption('WINNER', 'Vô địch')],
      ),
      AssessmentQuestion(
        code: 'RECENT_TOURNAMENTS',
        question: '',
        type: AssessmentQuestionType.singleChoice,
        options: [AssessmentOption('ZERO', '0'), AssessmentOption('ONE_TWO', '1-2')],
      ),
    ];
    var answers = AssessmentRules.answer({'BEST_RESULT': 'WINNER'}, questions, 'TOURNAMENT_LEVEL', 'NONE');
    expect(answers, {'TOURNAMENT_LEVEL': 'NONE', 'BEST_RESULT': 'NONE', 'RECENT_TOURNAMENTS': 'ZERO'});
    expect(AssessmentRules.disabledOptions(questions[1], answers), {'WINNER'});
    expect(AssessmentRules.disabledOptions(questions[2], answers), {'ONE_TWO'});

    answers = AssessmentRules.answer(answers, questions, 'TOURNAMENT_LEVEL', 'CITY');
    expect(answers.containsKey('BEST_RESULT'), isFalse);
    expect(AssessmentRules.disabledOptions(questions[1], answers), {'NONE'});
    expect(AssessmentRules.disabledOptions(questions[2], answers), isEmpty);
    expect(AssessmentRules.disabledOptions(questions[0], answers), isEmpty);
  });

  test('nhận xét trình độ: gửi revieweeId + contextId + verdict; 409 bỏ qua, 403 báo lỗi', () async {
    server.routes['POST ${ApiRatingRepository.feedbackPath}'] = (201, _ok(null, status: 201));
    await repo.sendSkillFeedback(revieweeId: 'u2', contextId: 'lfg-1', verdict: SkillVerdict.higher);
    expect(server.requests.last.data, {'revieweeId': 'u2', 'contextId': 'lfg-1', 'verdict': 'HIGHER'});

    server.routes['POST ${ApiRatingRepository.feedbackPath}'] = (
      409,
      {'statusCode': 409, 'message': 'Bạn đã đánh giá trình độ người này trong trận này rồi.', 'data': null},
    );
    await repo.sendSkillFeedback(revieweeId: 'u2', contextId: 'lfg-1', verdict: SkillVerdict.higher);

    server.routes['POST ${ApiRatingRepository.feedbackPath}'] = (
      403,
      {'statusCode': 403, 'message': 'Điểm Fair Play của bạn dưới 50.', 'data': null},
    );
    await expectLater(
      repo.sendSkillFeedback(revieweeId: 'u3', contextId: 'lfg-1', verdict: SkillVerdict.lower),
      throwsA(isA<RatingException>().having((e) => e.message, 'message', 'Điểm Fair Play của bạn dưới 50.')),
    );
  });

  test('lỗi BE giữ mã: chưa khảo sát người chơi → ONBOARDING_REQUIRED', () async {
    server.routes['POST ${ApiRatingRepository.submitPath('cat-cl')}'] = (
      403,
      {'statusCode': 403, 'message': 'Hãy hoàn thành khảo sát', 'errorCode': ApiErrorCodes.onboardingRequired, 'data': null},
    );
    await expectLater(
      repo.submitAssessment(Sport.badminton, answers: const {}, techniques: const {}),
      throwsA(isA<RatingException>().having((e) => e.isOnboardingRequired, 'onboarding', isTrue)),
    );
    await expectLater(repo.getAssessmentForm(Sport.tennis), throwsA(isA<RatingException>()));
  });
}
