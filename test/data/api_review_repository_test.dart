import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_review_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/review_repository.dart';
import 'package:test1/models/review.dart';
import 'package:test1/models/sport.dart';

/// Giả lập server: trả JSON theo "METHOD path" (hoặc theo hàm), ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  (int, Object?) Function(RequestOptions options)? handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final route = handler?.call(options) ?? routes['${options.method} ${options.path}'];
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

Map<String, dynamic> _err(int status, String message) => {'statusCode': status, 'message': message, 'data': null};

void main() {
  late _FakeServer server;
  late ApiReviewRepository repo;

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiReviewRepository(api: ApiClient(tokens: tokens, dio: dio));
  });

  test('trận chờ chấm: đọc loại / môn / hạn / người chơi, hạn gần nhất trước, bỏ trận không còn ai', () async {
    server.routes['GET ${ApiReviewRepository.pendingPath}'] = (
      200,
      _ok([
        {
          'contextId': 'lfg-1',
          'contextType': 'LFG',
          'facilityId': 'f-1',
          'facilityName': 'Sân A',
          'courtName': 'Sân 2',
          'sportName': 'Cầu lông',
          'startTime': '2026-10-30T10:00:00Z',
          'endTime': '2026-10-30T11:00:00Z',
          'ratingDeadline': '2026-10-31T11:00:00Z',
          'players': [
            {'userId': 'u-1', 'fullName': 'An', 'avatarUrl': 'https://img/a.png'},
            {'userId': 'u-2', 'fullName': 'Bình', 'avatarUrl': null},
          ],
        },
        {
          'contextId': 'bk-1',
          'contextType': 'BOOKING',
          'facilityId': 'f-2',
          'facilityName': 'Sân B',
          'sportName': 'Môn lạ',
          'startTime': '2026-10-30T06:00:00Z',
          'endTime': '2026-10-30T07:00:00Z',
          'ratingDeadline': '2026-10-31T07:00:00Z',
          'players': [
            {'userId': 'u-3', 'fullName': 'Chi'},
          ],
        },
        {'contextId': 'bk-2', 'contextType': 'BOOKING', 'players': <Object>[]},
      ]),
    );

    final pending = await repo.getPendingReviews();

    expect(pending.map((p) => p.sessionId), ['bk-1', 'lfg-1']);
    final lfg = pending[1];
    expect(lfg.type, SessionType.lfg);
    expect(lfg.sport, Sport.badminton);
    expect(lfg.courtName, 'Sân 2');
    expect(lfg.deadline, DateTime.utc(2026, 10, 31, 11).toLocal());
    expect(lfg.players.first.avatarUrl, 'https://img/a.png');
    expect(lfg.players.last.avatarUrl, isNull);
    final booking = pending[0];
    expect(booking.type, SessionType.booking);
    expect(booking.sport, isNull);
    expect(booking.sportLabel, 'Môn lạ');
  });

  test('chấm người chơi: gửi từng người, thẻ ghép vào nhận xét, người đã chấm (409) bỏ qua', () async {
    server.handler = (o) {
      final body = o.data as Map<String, dynamic>;
      return body['revieweeId'] == 'u-2' ? (409, _err(409, 'Bạn đã chấm người này')) : (200, _ok(null));
    };

    await repo.ratePlayers('lfg-1', const [
      PlayerReviewInput(playerId: 'u-1', stars: 5, tags: {ReviewTag.onTime}, comment: 'Hay'),
      PlayerReviewInput(playerId: 'u-2', stars: 3),
      PlayerReviewInput(playerId: 'u-3', stars: 4),
    ]);

    final bodies = server.requests.map((r) => r.data as Map<String, dynamic>).toList();
    expect(server.requests.every((r) => r.path == ApiReviewRepository.ratePath), isTrue);
    expect(bodies, hasLength(3));
    expect(bodies[0], {'revieweeId': 'u-1', 'contextId': 'lfg-1', 'score': 5, 'comment': 'Đúng giờ. Hay'});
    expect(bodies[2].containsKey('comment'), isFalse);
  });

  test('chấm người chơi: lỗi khác thì dừng và báo message của BE', () async {
    server.routes['POST ${ApiReviewRepository.ratePath}'] = (400, _err(400, 'Đã hết hạn chấm điểm'));

    expect(
      () => repo.ratePlayers('lfg-1', const [PlayerReviewInput(playerId: 'u-1', stars: 5)]),
      throwsA(isA<ReviewException>().having((e) => e.message, 'message', 'Đã hết hạn chấm điểm')),
    );
  });

  test('đánh giá cơ sở: lọc sao, phân trang, tổng hợp, phản hồi chủ sân', () async {
    server.routes['GET ${ApiReviewRepository.facilityReviewsPath('f-1')}'] = (
      200,
      _ok({
        'page': 1,
        'pageSize': 10,
        'totalItems': 12,
        'totalPages': 2,
        'averageRating': 4.2,
        'totalReviews': 30,
        'ratingDistribution': {'1': 1, '2': 2, '3': 3, '4': 10, '5': 14},
        'items': [
          {
            'id': 'r-1',
            'userId': 'u-1',
            'userFullName': 'An',
            'userAvatarUrl': '',
            'rating': 4,
            'comment': 'Tốt',
            'createdAt': '2026-10-29T03:00:00Z',
            'ownerReply': 'Cảm ơn',
            'repliedAt': '2026-10-29T05:00:00Z',
          },
        ],
      }),
    );

    final page = await repo.getFacilityReviews('f-1', stars: 4);

    final query = server.requests.single.queryParameters;
    expect(query['rating'], 4);
    expect(query['pageSize'], ReviewRepository.reviewPageSize);
    expect(page.hasMore, isTrue);
    expect(page.stats.average, 4.2);
    expect(page.stats.total, 30);
    expect(page.stats.distribution[5], 14);
    final r = page.items.single;
    expect(r.userName, 'An');
    expect(r.userAvatarUrl, isNull);
    expect(r.ownerReply, 'Cảm ơn');
    expect(r.repliedAt, DateTime.utc(2026, 10, 29, 5).toLocal());
  });

  test('điều kiện đánh giá và gửi đánh giá cơ sở', () async {
    server.routes['GET ${ApiReviewRepository.eligibilityPath('f-1')}'] = (
      200,
      _ok({'canReview': false, 'reason': 'Bạn đã đánh giá sân này', 'existingReviewId': 'r-9'}),
    );
    server.routes['POST ${ApiReviewRepository.createReviewPath}'] = (
      201,
      _ok({'id': 'r-10', 'userId': 'me', 'userFullName': 'Tôi', 'rating': 5, 'createdAt': '2026-10-30T03:00:00Z'}, status: 201),
    );

    final eligibility = await repo.getEligibility('f-1');
    expect(eligibility.canReview, isFalse);
    expect(eligibility.alreadyReviewed, isTrue);
    expect(eligibility.reason, 'Bạn đã đánh giá sân này');

    final created = await repo.submitFacilityReview('f-2', const FacilityReviewInput(stars: 5, comment: '  '));
    expect(created.id, 'r-10');
    expect(server.requests.last.data, {'facilityId': 'f-2', 'rating': 5});
  });

  test('đánh giá của tôi: tên / ảnh cơ sở, trạng thái bị ẩn', () async {
    server.routes['GET ${ApiReviewRepository.myReviewsPath}'] = (
      200,
      _ok({
        'page': 1,
        'pageSize': 10,
        'totalItems': 1,
        'items': [
          {
            'id': 'r-1',
            'userId': 'me',
            'userFullName': 'Tôi',
            'rating': 1,
            'createdAt': '2026-10-29T03:00:00Z',
            'facilityId': 'f-1',
            'facilityName': 'Sân A',
            'facilityThumbnailUrl': 'https://img/f.png',
            'isHidden': true,
            'hiddenReason': 'Ngôn từ không phù hợp',
          },
        ],
      }),
    );

    final page = await repo.getMyReviews();

    expect(page.hasMore, isFalse);
    final r = page.items.single;
    expect(r.facilityName, 'Sân A');
    expect(r.facilityThumbnailUrl, 'https://img/f.png');
    expect(r.isHidden, isTrue);
    expect(r.hiddenReason, 'Ngôn từ không phù hợp');
  });

  test('Fair Play: điểm, mức tối thiểu của BE, cấm, lịch sử theo nguồn, còn trang sau', () async {
    server.routes['GET ${ApiReviewRepository.fairPlayPath}'] = (
      200,
      _ok({
        'fairPlayScore': 72.0,
        'minClaimScore': 35,
        'recoveryCap': 40,
        'isLfgBlocked': true,
        'claimBanReason': 'Gian lận',
        'claimBannedUntil': null,
        'ratingCount': 8,
        'averageRating': 4.4,
        'history': {
          'page': 1,
          'pageSize': 20,
          'totalItems': 25,
          'items': [
            {
              'id': 'h-1',
              'delta': -10,
              'scoreAfter': 72,
              'source': 'LATE',
              'reason': 'Check-in trễ',
              'referenceId': 'lfg-1',
              'createdAt': '2026-10-28T03:00:00Z',
            },
            {'id': 'h-2', 'delta': 3, 'scoreAfter': 82, 'source': 'RATING', 'reason': '', 'createdAt': '2026-10-27T03:00:00Z'},
          ],
        },
      }),
    );

    final fp = await repo.getFairPlay();

    expect(server.requests.single.queryParameters['pageSize'], ReviewRepository.fairPlayPageSize);
    expect(fp.score, 72);
    expect(fp.minScoreForLfg, 35);
    expect(fp.canJoinLfg, isFalse);
    expect(fp.isBanned, isTrue);
    expect(fp.banReason, 'Gian lận');
    expect(fp.bannedUntil, isNull);
    expect(fp.ratingCount, 8);
    expect(fp.averageRating, 4.4);
    expect(fp.history.map((e) => e.type), [FairPlayEventType.late, FairPlayEventType.review]);
    expect(fp.history.first.scoreAfter, 72);
    expect(fp.hasMoreHistory, isTrue);
  });

  test('Fair Play: điểm thấp bị chặn nhưng không phải bị cấm; chưa được chấm thì không có trung bình', () async {
    server.routes['GET ${ApiReviewRepository.fairPlayPath}'] = (
      200,
      _ok({'fairPlayScore': 20, 'minClaimScore': 30, 'isLfgBlocked': true, 'ratingCount': 0, 'averageRating': 0, 'history': []}),
    );

    final fp = await repo.getFairPlay();

    expect(fp.canJoinLfg, isFalse);
    expect(fp.isBanned, isFalse);
    expect(fp.averageRating, isNull);
    expect(fp.history, isEmpty);
    expect(fp.hasMoreHistory, isFalse);
  });
}
