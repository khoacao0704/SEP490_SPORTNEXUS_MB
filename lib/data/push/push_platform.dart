import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/strings/notification_strings.dart';

/// Một tin đẩy: tiêu đề, nội dung và phần `data` của BE
/// (`notificationId`, `type`, `referenceType`, `referenceId`; tất cả là chuỗi, không có thì là "").
class PushMessage {
  final String? title;
  final String? body;
  final Map<String, String> data;

  const PushMessage({this.title, this.body, this.data = const {}});
}

/// Lớp mỏng trên Firebase Messaging + thông báo cục bộ, để [PushService] test được bằng bản giả.
abstract class PushPlatform {
  /// Gọi một lần lúc mở app. [onLocalTap]: người dùng bấm thông báo app tự hiện (lúc đang mở app).
  Future<void> init({required void Function(PushMessage message) onLocalTap});

  /// `true` nếu được phép hiện thông báo.
  Future<bool> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// Huỷ token trên máy (người đăng nhập sau nhận token mới).
  Future<void> deleteToken();

  /// Tin tới khi app đang mở (Android không tự hiện).
  Stream<PushMessage> get onForegroundMessage;

  /// Bấm thông báo hệ thống khi app đang chạy nền.
  Stream<PushMessage> get onMessageOpenedApp;

  /// Thông báo đã mở app từ trạng thái tắt hẳn (nếu có).
  Future<PushMessage?> getInitialMessage();

  /// Hiện thông báo trên thanh trạng thái (dùng khi app đang mở).
  Future<void> showLocal(PushMessage message);
}

/// Bản thật: Firebase Cloud Messaging (Android).
class FcmPushPlatform implements PushPlatform {
  /// Phải trùng `default_notification_channel_id` trong AndroidManifest.xml.
  static const String channelId = 'sportnexus_default';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    channelId,
    NotificationStrings.pushChannelName,
    channelDescription: NotificationStrings.pushChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
  );

  @override
  Future<void> init({required void Function(PushMessage message) onLocalTap}) async {
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) {
        final message = _decode(response.payload);
        if (message != null) onLocalTap(message);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            NotificationStrings.pushChannelName,
            description: NotificationStrings.pushChannelDescription,
            importance: Importance.high,
          ),
        );
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // BE gửi bằng FCM HTTP v1 `messages:send` theo registration token. API mới register()/onRegistered
  // trả Firebase Installation ID (cho direct-send), BE không dùng được, nên vẫn dùng getToken / onTokenRefresh / deleteToken.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _fcm.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _fcm.deleteToken();

  @override
  Stream<PushMessage> get onForegroundMessage => FirebaseMessaging.onMessage.map(_fromRemote);

  @override
  Stream<PushMessage> get onMessageOpenedApp => FirebaseMessaging.onMessageOpenedApp.map(_fromRemote);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final remote = await _fcm.getInitialMessage();
    if (remote != null) return _fromRemote(remote);
    // Bấm thông báo app tự hiện, sau đó app bị tắt hẳn.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) return _decode(launch!.notificationResponse?.payload);
    return null;
  }

  @override
  Future<void> showLocal(PushMessage message) => _local.show(
        id: (message.data['notificationId'] ?? '${DateTime.now().millisecondsSinceEpoch}').hashCode & 0x7fffffff,
        title: message.title,
        body: message.body,
        notificationDetails: const NotificationDetails(android: _androidDetails),
        payload: jsonEncode({'title': message.title, 'body': message.body, 'data': message.data}),
      );

  static PushMessage _fromRemote(RemoteMessage remote) => PushMessage(
        title: remote.notification?.title,
        body: remote.notification?.body,
        data: {for (final e in remote.data.entries) e.key: e.value?.toString() ?? ''},
      );

  static PushMessage? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>? ?? const {};
      return PushMessage(
        title: json['title'] as String?,
        body: json['body'] as String?,
        data: {for (final e in data.entries) e.key: e.value?.toString() ?? ''},
      );
    } catch (_) {
      return null;
    }
  }
}
