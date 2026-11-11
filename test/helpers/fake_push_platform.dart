import 'dart:async';

import 'package:test1/data/push/push_platform.dart';

/// Firebase Messaging giả: không gọi Firebase, ghi lại những gì app làm.
class FakePushPlatform implements PushPlatform {
  String? token = 'fcm-token-1';
  bool permissionGranted = true;
  PushMessage? initialMessage;
  Object? getTokenError;

  int initCalls = 0;
  int permissionRequests = 0;
  int deleteTokenCalls = 0;
  final List<PushMessage> shownLocal = [];

  void Function(PushMessage message)? _onLocalTap;
  final StreamController<String> refresh = StreamController<String>.broadcast();
  final StreamController<PushMessage> foreground = StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> openedApp = StreamController<PushMessage>.broadcast();

  /// Giả lập người dùng bấm thông báo app tự hiện.
  void tapLocal(PushMessage message) => _onLocalTap?.call(message);

  @override
  Future<void> init({required void Function(PushMessage message) onLocalTap}) async {
    initCalls++;
    _onLocalTap = onLocalTap;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async {
    if (getTokenError != null) throw getTokenError!;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    token = null;
  }

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => openedApp.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => initialMessage;

  @override
  Future<void> showLocal(PushMessage message) async => shownLocal.add(message);
}
