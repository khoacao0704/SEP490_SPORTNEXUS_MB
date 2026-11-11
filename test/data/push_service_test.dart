import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/push/push_platform.dart';
import 'package:test1/data/push/push_service.dart';
import 'package:test1/models/app_notification.dart';

import '../helpers/fake_push_platform.dart';

/// Server giả: mọi request trả [status], ghi lại request đã gửi.
class _FakeServer implements HttpClientAdapter {
  int status = 200;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    await requestStream?.drain<void>();
    return ResponseBody.fromString(
      jsonEncode({'statusCode': status, 'message': status == 200 ? 'OK' : 'Lỗi', 'data': null}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _lfgPush = PushMessage(
  title: 'Có người vào kèo',
  body: 'Minh vừa vào kèo Cầu lông tối nay',
  data: {'notificationId': 'n-1', 'type': 'LFG', 'referenceType': 'LFG_CARD', 'referenceId': 'card-9'},
);

void main() {
  late _FakeServer server;
  late FakePushPlatform platform;
  late PushService push;

  setUp(() async {
    server = _FakeServer();
    platform = FakePushPlatform();
    final tokens = MemoryTokenStore();
    await tokens.write('access', refreshToken: 'refresh');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    push = PushService(api: ApiClient(tokens: tokens, dio: dio), platform: platform);
  });

  tearDown(() => push.dispose());

  group('đăng ký token', () {
    test('chưa start (test, giả lập): không xin quyền, không gọi BE', () async {
      await push.register();
      expect(platform.permissionRequests, 0);
      expect(server.requests, isEmpty);
      expect(push.registeredToken, isNull);
    });

    test('xin quyền rồi gửi {token, platform: ANDROID} lên /notifications/devices', () async {
      await push.start();
      await push.register();
      expect(platform.permissionRequests, 1);
      expect(server.requests.single.method, 'POST');
      expect(server.requests.single.path, PushService.devicesPath);
      expect(server.requests.single.data, {'token': 'fcm-token-1', 'platform': 'ANDROID'});
      expect(push.registeredToken, 'fcm-token-1');
    });

    test('vào lại màn chính: không gửi lại cùng token', () async {
      await push.start();
      await push.register();
      await push.register();
      expect(server.requests, hasLength(1));
    });

    test('Firebase đổi token: gửi token mới', () async {
      await push.start();
      await push.register();
      platform.refresh.add('fcm-token-2');
      await pumpEventQueue();
      expect(server.requests.last.data, {'token': 'fcm-token-2', 'platform': 'ANDROID'});
      expect(push.registeredToken, 'fcm-token-2');
    });

    test('BE lỗi / Firebase lỗi: bỏ qua, không ném lỗi', () async {
      await push.start();
      server.status = 500;
      await push.register();
      expect(push.registeredToken, isNull);

      platform.getTokenError = Exception('no play services');
      await push.register();
      expect(push.registeredToken, isNull);
    });

    test('đăng xuất: huỷ token trên máy; đăng nhập lại gửi token mới', () async {
      await push.start();
      await push.register();
      await push.unregister();
      expect(platform.deleteTokenCalls, 1);
      expect(push.registeredToken, isNull);

      platform.token = 'fcm-token-3';
      await push.register();
      expect(server.requests.last.data, {'token': 'fcm-token-3', 'platform': 'ANDROID'});
    });

    test('chưa đăng ký (vd. Chủ sân) thì đăng xuất không động tới Firebase', () async {
      await push.start();
      await push.unregister();
      expect(platform.deleteTokenCalls, 0);
    });
  });

  group('nhận thông báo', () {
    test('app đang mở: tự hiện thông báo trên thanh trạng thái', () async {
      await push.start();
      await push.register();
      platform.foreground.add(_lfgPush);
      await pumpEventQueue();
      expect(platform.shownLocal.single.title, 'Có người vào kèo');
    });

    test('chưa đăng ký (đã đăng xuất / Chủ sân): không hiện', () async {
      await push.start();
      platform.foreground.add(_lfgPush);
      await pumpEventQueue();
      expect(platform.shownLocal, isEmpty);
    });

    test('bấm thông báo khi app chạy nền hoặc bấm thông báo app tự hiện: phát qua opens', () async {
      await push.start();
      final opened = <AppNotification>[];
      push.opens.listen(opened.add);

      platform.openedApp.add(_lfgPush);
      platform.tapLocal(_lfgPush);
      await pumpEventQueue();

      expect(opened, hasLength(2));
      expect(opened.first.id, 'n-1');
      expect(opened.first.group, NotificationGroup.lfg);
      expect(opened.first.referenceType, NotificationReference.lfgCard);
      expect(opened.first.referenceId, 'card-9');
    });

    test('mở app từ trạng thái tắt: giữ lại cho màn chính, chỉ lấy một lần', () async {
      platform.initialMessage = _lfgPush;
      await push.start();
      expect(push.takePendingOpen()?.referenceId, 'card-9');
      expect(push.takePendingOpen(), isNull);
    });
  });

  group('đọc payload của BE', () {
    test('referenceType / referenceId rỗng: không có đối tượng liên quan', () {
      final n = PushService.notificationOf(const PushMessage(
        title: 'Thông báo hệ thống',
        body: 'Bảo trì tối nay',
        data: {'notificationId': 'n-2', 'type': 'SYSTEM', 'referenceType': '', 'referenceId': ''},
      ));
      expect(n!.group, NotificationGroup.system);
      expect(n.referenceType, isNull);
      expect(n.referenceId, isNull);
      expect(n.title, 'Thông báo hệ thống');
    });

    test('thiếu notificationId: bỏ qua', () {
      expect(PushService.notificationOf(const PushMessage(title: 'x', data: {'type': 'LFG'})), isNull);
    });
  });
}
