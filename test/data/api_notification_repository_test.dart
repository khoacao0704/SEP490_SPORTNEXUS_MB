import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_notification_repository.dart';
import 'package:test1/data/api/notification_hub.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/notification_repository.dart';
import 'package:test1/models/app_notification.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
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

class _FakeRealtime implements NotificationRealtime {
  int starts = 0;
  int stops = 0;
  void Function(Map<String, dynamic>)? onNotification;
  void Function(int)? onUnreadCount;

  @override
  Future<void> start({
    required void Function(Map<String, dynamic> json) onNotification,
    required void Function(int unread) onUnreadCount,
  }) async {
    starts++;
    this.onNotification = onNotification;
    this.onUnreadCount = onUnreadCount;
  }

  @override
  Future<void> stop() async => stops++;
}

Map<String, dynamic> _ok(Object? data) => {'statusCode': 200, 'message': 'OK', 'data': data};

Map<String, dynamic> _item(
  String id, {
  String type = 'BOOKING',
  String? referenceType = 'BOOKING',
  String? referenceId = 'bk-1',
  bool isRead = false,
}) => {
  'id': id,
  'title': 'Tiêu đề $id',
  'body': 'Nội dung $id',
  'type': type,
  'referenceType': referenceType,
  'referenceId': referenceId,
  'isRead': isRead,
  'readAt': null,
  'createdAt': '2026-10-30T03:00:00Z',
};

void main() {
  late _FakeServer server;
  late _FakeRealtime realtime;
  late ApiNotificationRepository repo;

  setUp(() async {
    server = _FakeServer();
    realtime = _FakeRealtime();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiNotificationRepository(api: ApiClient(tokens: tokens, dio: dio), realtime: realtime);
  });

  test('trang thông báo: gửi nhóm / chưa đọc / trang, đọc nhóm, đối tượng liên quan, còn trang sau', () async {
    server.routes['GET ${ApiNotificationRepository.listPath}'] = (
      200,
      _ok({
        'page': 1,
        'pageSize': 20,
        'totalItems': 25,
        'totalPages': 2,
        'items': [
          _item('n1', type: 'LFG', referenceType: 'LFG_CARD', referenceId: 'lfg-9'),
          _item('n2', type: 'REVIEW', referenceType: null, referenceId: null, isRead: true),
          _item('n3', type: 'TEAM_MODERATION', referenceType: 'TEAM', referenceId: 'team-1'),
          {'title': 'thiếu id'},
        ],
      }),
    );

    final page = await repo.getPage(group: NotificationGroup.lfg, unreadOnly: true);

    final query = server.requests.single.queryParameters;
    expect(query['type'], 'LFG');
    expect(query['unreadOnly'], true);
    expect(query['page'], 1);
    expect(query['pageSize'], NotificationRepository.pageSize);
    expect(page.hasMore, isTrue);
    expect(page.items.map((n) => n.id), ['n1', 'n2', 'n3']);

    final lfg = page.items[0];
    expect(lfg.group, NotificationGroup.lfg);
    expect(lfg.referenceType, NotificationReference.lfgCard);
    expect(lfg.referenceId, 'lfg-9');
    expect(lfg.isRead, isFalse);
    expect(lfg.createdAt, DateTime.utc(2026, 10, 30, 3).toLocal());

    // Fair Play sau trận: REVIEW không có đối tượng → mở màn Fair Play.
    final fairPlay = page.items[1];
    expect(fairPlay.referenceType, isNull);
    expect(fairPlay.type.target, NotificationTarget.fairPlay);
    expect(fairPlay.isRead, isTrue);

    // Giá trị nhóm lạ: coi là SYSTEM như BE.
    expect(page.items[2].group, NotificationGroup.system);
  });

  test('trang cuối: hết trang sau; bỏ lọc thì không gửi type / unreadOnly', () async {
    server.routes['GET ${ApiNotificationRepository.listPath}'] = (
      200,
      _ok({'page': 2, 'pageSize': 20, 'totalItems': 21, 'totalPages': 2, 'items': [_item('n21')]}),
    );

    final page = await repo.getPage(page: 2);

    final query = server.requests.single.queryParameters;
    expect(query.containsKey('type'), isFalse);
    expect(query.containsKey('unreadOnly'), isFalse);
    expect(query['page'], 2);
    expect(page.hasMore, isFalse);
  });

  test('số chưa đọc: tổng và theo nhóm', () async {
    server.routes['GET ${ApiNotificationRepository.unreadPath}'] = (
      200,
      _ok({
        'total': 5,
        'byType': {'LFG': 3, 'BOOKING': 2},
      }),
    );

    final unread = await repo.getUnread();

    expect(unread.total, 5);
    expect(unread.byGroup, {NotificationGroup.lfg: 3, NotificationGroup.booking: 2});
    expect(await repo.getUnreadCount(), 5);
  });

  test('đọc một / đọc hết theo nhóm / xoá / xoá đã đọc; mỗi thao tác báo chuông tải lại', () async {
    server.routes['PUT ${ApiNotificationRepository.readPath('n1')}'] = (200, _ok(null));
    server.routes['PUT ${ApiNotificationRepository.readAllPath}'] = (200, _ok({'updated': 3}));
    server.routes['DELETE ${ApiNotificationRepository.itemPath('n1')}'] = (200, _ok(null));
    server.routes['DELETE ${ApiNotificationRepository.listPath}'] = (200, _ok({'deleted': 4}));
    var changes = 0;
    final sub = repo.changes.listen((_) => changes++);

    await repo.markAsRead('n1');
    await repo.markAllAsRead(group: NotificationGroup.wallet);
    await repo.markAllAsRead();
    await repo.delete('n1');
    final deleted = await repo.deleteRead();
    await Future<void>.delayed(Duration.zero);

    expect(deleted, 4);
    final readAll = server.requests.where((r) => r.path == ApiNotificationRepository.readAllPath).toList();
    expect(readAll[0].queryParameters['type'], 'WALLET');
    expect(readAll[1].queryParameters.containsKey('type'), isFalse);
    expect(changes, 5);
    await sub.cancel();
  });

  test('lỗi BE thành NotificationException kèm message', () async {
    server.routes['PUT ${ApiNotificationRepository.settingsPath}'] = (
      400,
      {'statusCode': 400, 'message': 'Không thể tắt nhóm thông báo bắt buộc', 'data': null},
    );

    expect(
      () => repo.setDisabledGroups({NotificationGroup.lfg}),
      throwsA(isA<NotificationException>().having((e) => e.message, 'message', 'Không thể tắt nhóm thông báo bắt buộc')),
    );
  });

  test('cài đặt: đọc danh sách 9 nhóm, gửi lên chỉ nhóm không bắt buộc', () async {
    server.routes['GET ${ApiNotificationRepository.settingsPath}'] = (
      200,
      _ok([
        {'type': 'BOOKING', 'enabled': true, 'isMandatory': true},
        {'type': 'LFG', 'enabled': false, 'isMandatory': false},
        {'type': 'TEAM', 'enabled': true, 'isMandatory': false},
        {'type': 'COMMUNITY', 'enabled': false, 'isMandatory': false},
      ]),
    );
    server.routes['PUT ${ApiNotificationRepository.settingsPath}'] = (200, _ok(null));

    expect(await repo.getDisabledGroups(), {NotificationGroup.lfg, NotificationGroup.community});

    await repo.setDisabledGroups({NotificationGroup.team, NotificationGroup.booking});
    final body = server.requests.last.data as Map<String, dynamic>;
    expect(body['disabledTypes'], ['TEAM']);
  });

  test('cài đặt dạng khác: {disabledTypes} hoặc cờ isEnabled', () {
    expect(
      ApiNotificationRepository.disabledGroupsFromApi({
        'disabledTypes': ['TOURNAMENT', 'WALLET'],
      }),
      {NotificationGroup.tournament},
    );
    expect(
      ApiNotificationRepository.disabledGroupsFromApi({
        'items': [
          {'type': 'REVIEW', 'isEnabled': false},
          {'type': 'LFG', 'isEnabled': true},
        ],
      }),
      {NotificationGroup.review},
    );
  });

  test('realtime chỉ mở khi có người nghe; thông báo mới đẩy vào incoming và changes', () async {
    expect(realtime.starts, 0);
    final received = <AppNotification>[];
    var changes = 0;
    final a = repo.incoming.listen(received.add);
    final b = repo.changes.listen((_) => changes++);
    expect(realtime.starts, 1);

    realtime.onNotification!(_item('live-1', type: 'WALLET', referenceType: 'WALLET', referenceId: 'w-1'));
    realtime.onUnreadCount!(7);
    await Future<void>.delayed(Duration.zero);

    expect(received.single.id, 'live-1');
    expect(received.single.group, NotificationGroup.wallet);
    expect(changes, 2);

    await a.cancel();
    expect(realtime.stops, 0);
    await b.cancel();
    expect(realtime.stops, 1);
  });
}
