import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_community_repository.dart';
import 'package:test1/data/api/api_facility_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_community_repository.dart';
import 'package:test1/data/repositories/community_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/community_post.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/user_role.dart';

class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  void ok(String method, String path, Object? data) =>
      routes['$method $path'] = (200, {'statusCode': 200, 'message': 'OK', 'data': data});

  void fail(String method, String path, int code, String message) =>
      routes['$method $path'] = (code, {'statusCode': code, 'message': message, 'data': null});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) return ResponseBody.fromString('', 404);
    final (status, body) = route;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _post(String id, {String author = 'u-x', Map<String, dynamic> extra = const {}}) => {
      'id': id,
      'authorId': author,
      'authorName': 'Người $author',
      'content': 'Nội dung $id',
      'mediaUrls': ['https://img/$id.jpg'],
      'sportName': 'Cầu lông',
      'createdAt': '2026-11-26T10:00:00Z',
      'likeCount': 3,
      'commentCount': 2,
      'isLikedByMe': false,
      'status': 'ACTIVE',
      ...extra,
    };

void main() {
  group('ApiCommunityRepository', () {
    late _FakeServer server;
    late ApiCommunityRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SessionStore.save(
        const AppUser(id: 'u-me', fullName: 'Khoa', email: 'k@x.com', phone: '0900000000', role: UserRole.player, fairPlayScore: 90),
        rememberMe: true,
      );
      server = _FakeServer();
      final tokens = MemoryTokenStore();
      await tokens.write('t');
      final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
      final api = ApiClient(tokens: tokens, dio: dio);
      repo = ApiCommunityRepository(api: api, facility: ApiFacilityRepository(api: api));
      server.ok('GET', ApiFacilityRepository.sportsPath, [
        {'id': 'cat-bad', 'name': 'Cầu lông'},
      ]);
    });

    test('bảng tin: gửi SortBy + môn + từ khóa + trang; đọc bài, kèo đính kèm, bài của mình', () async {
      server.ok('GET', ApiCommunityRepository.postsPath, {
        'items': [
          _post('p1', extra: {
            'sharedLfg': {'id': 'c1', 'sportName': 'Cầu lông', 'facilityName': 'Sân A', 'startTime': '2026-11-28T11:00:00Z',
              'remainingSlots': 2, 'totalSlots': 3, 'pricePerPerson': 50000.0, 'hostTeamName': 'Đội A'},
          }),
          _post('p2', author: 'u-me', extra: {'isEdited': true, 'isLikedByMe': true}),
        ],
        'totalPages': 3,
      });
      final page = await repo.getPosts(const PostQuery(sort: PostSort.hot, sport: Sport.badminton, keyword: ' vợt '), page: 2);
      final req = server.requests.last;
      expect(req.queryParameters, {'SortBy': 'hot', 'SportCategoryId': 'cat-bad', 'Keyword': 'vợt', 'Page': 2, 'PageSize': 10});
      expect(page.hasMore, isTrue);
      final p1 = page.items.first;
      expect(p1.sport, Sport.badminton);
      expect(p1.mediaUrls, ['https://img/p1.jpg']);
      expect(p1.isMine, isFalse);
      expect(p1.sharedLfg!.isTeamMatch, isTrue);
      expect(p1.sharedLfg!.pricePerPerson, 50000);
      expect(page.items.last.isMine, isTrue);
      expect(page.items.last.isEdited, isTrue);
      expect(page.items.last.isLikedByMe, isTrue);
    });

    test('bài của tôi gửi includeRemoved; bài của một người; trạng thái HIDDEN có lý do', () async {
      server.ok('GET', ApiCommunityRepository.myPostsPath, [
        _post('p3', author: 'u-me', extra: {'status': 'HIDDEN', 'hiddenReason': 'Spam'}),
      ]);
      server.ok('GET', ApiCommunityRepository.userPostsPath('u-x'), {'items': [_post('p4')]});
      final mine = await repo.getPosts(const PostQuery(mine: true));
      expect(server.requests.last.queryParameters, {'page': 1, 'pageSize': 10, 'includeRemoved': true});
      expect(mine.items.single.status, PostStatus.hidden);
      expect(mine.items.single.hiddenReason, 'Spam');
      expect(mine.hasMore, isFalse);
      final theirs = await repo.getPosts(const PostQuery(authorId: 'u-x'));
      expect(theirs.items.single.id, 'p4');
    });

    test('đăng bài (kèm kèo) / sửa / xóa / like / bỏ like / lịch sử sửa gọi đúng API', () async {
      server.ok('POST', ApiCommunityRepository.postsPath, _post('p5', author: 'u-me'));
      server.ok('PUT', ApiCommunityRepository.postPath('p5'), _post('p5', author: 'u-me', extra: {'content': 'Mới'}));
      server.ok('DELETE', ApiCommunityRepository.postPath('p5'), null);
      server.ok('POST', ApiCommunityRepository.likePath('p5'), {'likeCount': 4});
      server.ok('DELETE', ApiCommunityRepository.likePath('p5'), {'likeCount': 3});
      server.ok('GET', ApiCommunityRepository.editsPath('p5'), [
        {'editedAt': '2026-11-26T11:00:00Z', 'oldContent': 'Cũ'},
      ]);

      await repo.createPost(content: '  Kèo còn suất  ', sport: Sport.badminton, lfgCardId: 'c1', mediaUrls: ['u1']);
      final updated = await repo.updatePost('p5', ' Mới ');
      await repo.deletePost('p5');
      expect(await repo.setLiked('p5', true), 4);
      expect(await repo.setLiked('p5', false), 3);
      final edits = await repo.getPostEdits('p5');

      final writes = server.requests.where((r) => r.path.startsWith('/api/v1/community')).toList();
      expect(writes[0].data, {
        'content': 'Kèo còn suất',
        'mediaUrls': ['u1'],
        'sportCategoryId': 'cat-bad',
        'lfgCardId': 'c1',
        'tournamentId': null,
      });
      expect(writes[1].data, {'content': 'Mới'});
      expect(updated.content, 'Mới');
      expect(writes.map((r) => r.method).toList(), ['POST', 'PUT', 'DELETE', 'POST', 'DELETE', 'GET']);
      expect(edits.single.oldContent, 'Cũ');
    });

    test('lỗi BE giữ nguyên câu', () async {
      server.fail('POST', ApiCommunityRepository.postsPath, 400, 'Nội dung vi phạm tiêu chuẩn cộng đồng.');
      await expectLater(
        repo.createPost(content: 'x'),
        throwsA(isA<CommunityException>().having((e) => e.message, 'message', 'Nội dung vi phạm tiêu chuẩn cộng đồng.')),
      );
    });

    test('bình luận: đọc lồng replies + phần tử phẳng có parentCommentId; gửi / trả lời / sửa / xóa / lịch sử', () async {
      server.ok('GET', ApiCommunityRepository.commentsPath('p1'), {
        'items': [
          {'id': 'c1', 'userId': 'u-x', 'userName': 'An', 'content': 'Chào @Khoa', 'createdAt': '2026-11-26T10:00:00Z',
            'replies': [
              {'id': 'c2', 'userId': 'u-me', 'userName': 'Khoa', 'content': 'Hi', 'createdAt': '2026-11-26T10:05:00Z',
                'parentCommentId': 'c1', 'updatedAt': '2026-11-26T10:06:00Z'},
            ]},
          {'id': 'c3', 'userId': 'u-y', 'userName': 'Bình', 'content': 'Phẳng', 'createdAt': '2026-11-26T10:07:00Z',
            'parentCommentId': 'c1'},
        ],
      });
      server.ok('POST', ApiCommunityRepository.commentsPath('p1'), {'id': 'c4', 'userId': 'u-me', 'content': 'Mới',
        'createdAt': '2026-11-26T11:00:00Z'});
      server.ok('PUT', ApiCommunityRepository.commentPath('c4'), {'id': 'c4', 'userId': 'u-me', 'content': 'Sửa',
        'createdAt': '2026-11-26T11:00:00Z'});
      server.ok('DELETE', ApiCommunityRepository.commentPath('c4'), null);
      server.ok('GET', ApiCommunityRepository.commentEditsPath('c4'), [
        {'editedAt': '2026-11-26T11:01:00Z', 'oldContent': 'Mới'},
      ]);

      final list = await repo.getComments('p1');
      expect(server.requests.last.queryParameters, {'page': 1, 'pageSize': 100});
      expect(list.single.id, 'c1');
      expect(list.single.replies.map((r) => r.id), ['c2', 'c3']);
      expect(list.single.replies.first.isMine, isTrue);
      expect(list.single.replies.first.isEdited, isTrue);

      await repo.addComment('p1', ' Mới ', parentId: 'c1');
      final edited = await repo.updateComment('c4', ' Sửa ');
      await repo.deleteComment('c4');
      final edits = await repo.getCommentEdits('c4');
      final writes = server.requests.where((r) => r.method != 'GET').toList();
      expect(writes[0].data, {'content': 'Mới', 'parentCommentId': 'c1'});
      expect(writes[1].data, {'content': 'Sửa'});
      expect(edited.isEdited, isTrue);
      expect(writes[2].method, 'DELETE');
      expect(edits.single.oldContent, 'Mới');
    });
  });

  group('MockCommunityRepository', () {
    late MockCommunityRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = MockCommunityRepository(latency: Duration.zero);
      await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
    });

    test('đăng → lên đầu bảng tin + bài của tôi; like; sửa có lịch sử; xóa: bảng tin ẩn, bài của tôi còn nhãn Đã xóa', () async {
      final created = await repo.createPost(content: 'Bài mới của tôi', sport: Sport.tennis);
      expect((await repo.getPosts(const PostQuery())).items.first.id, created.id);
      expect((await repo.getPosts(const PostQuery(mine: true))).items.single.isMine, isTrue);

      expect(await repo.setLiked(created.id, true), 1);
      expect((await repo.getPosts(const PostQuery())).items.first.isLikedByMe, isTrue);

      await repo.updatePost(created.id, 'Đã sửa');
      expect((await repo.getPostEdits(created.id)).single.oldContent, 'Bài mới của tôi');

      await repo.deletePost(created.id);
      expect((await repo.getPosts(const PostQuery())).items.any((p) => p.id == created.id), isFalse);
      expect((await repo.getPosts(const PostQuery(mine: true))).items.single.status, PostStatus.deleted);
    });

    test('lọc môn, từ khóa, người đăng; Nổi bật xếp theo like + 2 × bình luận; không sửa bài người khác', () async {
      final football = await repo.getPosts(const PostQuery(sport: Sport.football));
      expect(football.items.every((p) => p.sport == Sport.football), isTrue);
      expect((await repo.getPosts(const PostQuery(keyword: 'vợt'))).items.single.authorName, 'Lan Anh');
      expect((await repo.getPosts(const PostQuery(authorId: 'u-minhtuan'))).items.length, 2);
      final hot = (await repo.getPosts(const PostQuery(sort: PostSort.hot))).items;
      for (var i = 1; i < hot.length; i++) {
        expect(hot[i - 1].hotScore >= hot[i].hotScore, isTrue);
      }
      await expectLater(repo.updatePost('post-seed-1', 'x'), throwsA(isA<CommunityException>()));
    });
    test('bình luận: gửi, trả lời, đếm vào bài; sửa trong 15 phút có lịch sử; quá 15 phút thì chặn; xóa gốc xóa luôn trả lời', () async {
      var clock = DateTime(2026, 11, 27, 10);
      final r = MockCommunityRepository(latency: Duration.zero, now: () => clock);
      final c = await r.addComment('post-seed-1', 'Mình tham gia @Minh Tuấn');
      await r.addComment('post-seed-1', 'Ok bạn', parentId: c.id);
      final list = await r.getComments('post-seed-1');
      expect(list.single.replies.single.content, 'Ok bạn');
      final seed = (await r.getPosts(const PostQuery(authorId: 'u-minhtuan'))).items.firstWhere((p) => p.id == 'post-seed-1');
      expect(seed.commentCount, 2);

      await r.updateComment(c.id, 'Đã sửa');
      expect((await r.getCommentEdits(c.id)).single.oldContent, 'Mình tham gia @Minh Tuấn');
      clock = clock.add(const Duration(minutes: 16));
      await expectLater(r.updateComment(c.id, 'Muộn'), throwsA(isA<CommunityException>()));

      await r.deleteComment(c.id);
      expect(await r.getComments('post-seed-1'), isEmpty);
    });
  });
}
