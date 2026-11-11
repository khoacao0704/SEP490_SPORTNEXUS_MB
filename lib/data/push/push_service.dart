import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../models/app_notification.dart';
import '../api/api_client.dart';
import '../api/api_notification_repository.dart';
import 'push_platform.dart';

/// Thông báo đẩy (FCM) cho người chơi.
///
/// - [start]: gọi một lần trong `main()`; chưa gọi (test, giả lập) thì mọi hàm khác không làm gì.
/// - [register]: sau khi người chơi vào màn chính; gửi token lên `POST /api/v1/notifications/devices`.
/// - [unregister]: khi đăng xuất (sau khi đã gửi [registeredToken] kèm `POST /api/auth/logout`).
/// - Bấm thông báo: phát qua [opens]; thông báo mở app từ trạng thái tắt nằm ở [takePendingOpen].
class PushService {
  static const String devicesPath = '/api/v1/notifications/devices';

  final ApiClient? _api;
  final PushPlatform? _platform;

  PushService({required ApiClient this._api, required PushPlatform this._platform});

  /// Không gửi push (chạy giả lập).
  PushService.disabled() : _api = null, _platform = null;

  Future<void>? _starting;
  String? _token;
  AppNotification? _pending;
  StreamSubscription<String>? _refreshSub;
  final List<StreamSubscription<PushMessage>> _subs = [];
  final StreamController<AppNotification> _opens = StreamController<AppNotification>.broadcast();

  /// Token đã đăng ký với BE (gửi kèm khi đăng xuất). `null` nếu chưa đăng ký.
  String? get registeredToken => _token;

  /// Người dùng bấm một thông báo đẩy khi app đang chạy.
  Stream<AppNotification> get opens => _opens.stream;

  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    final platform = _platform;
    if (platform == null) return;
    try {
      await platform.init(onLocalTap: _handleOpen);
      _subs
        ..add(platform.onForegroundMessage.listen(_handleForeground))
        ..add(platform.onMessageOpenedApp.listen(_handleOpen));
      final initial = await platform.getInitialMessage();
      if (initial != null) _pending = notificationOf(initial);
    } catch (e) {
      debugPrint('PushService.start: $e');
    }
  }

  /// Thông báo đã mở app từ trạng thái tắt (chỉ trả một lần).
  AppNotification? takePendingOpen() {
    final n = _pending;
    _pending = null;
    return n;
  }

  /// Xin quyền, lấy token và gửi lên BE. Lỗi bỏ qua: không ảnh hưởng việc dùng app.
  Future<void> register() async {
    final platform = _platform;
    final starting = _starting;
    if (platform == null || starting == null) return;
    await starting;
    try {
      await platform.requestPermission(); // từ chối vẫn gửi token: bật lại trong Cài đặt là nhận được ngay
      final token = await platform.getToken();
      if (token == null || token.isEmpty) return;
      await _send(token);
      _refreshSub ??= platform.onTokenRefresh.listen((t) => unawaited(_send(t).catchError((_) {})));
    } catch (e) {
      debugPrint('PushService.register: $e');
    }
  }

  Future<void> _send(String token) async {
    if (token == _token) return;
    await _api!.post(devicesPath, body: {'token': token, 'platform': 'ANDROID'});
    _token = token;
  }

  /// Ngừng nhận push trên máy này (gọi khi đăng xuất). BE tự xoá token khi FCM báo token đã bị huỷ.
  Future<void> unregister() async {
    final platform = _platform;
    _pending = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (platform == null || _token == null) return;
    _token = null;
    try {
      await platform.deleteToken().timeout(const Duration(seconds: 5)); // mất mạng: không giữ chân việc đăng xuất
    } catch (e) {
      debugPrint('PushService.unregister: $e');
    }
  }

  void _handleForeground(PushMessage message) {
    if (_token == null) return; // đã đăng xuất / chưa phải người chơi
    final title = message.title ?? '';
    final body = message.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    unawaited(_platform!.showLocal(message).catchError((Object e) => debugPrint('PushService.showLocal: $e')));
  }

  void _handleOpen(PushMessage message) {
    final n = notificationOf(message);
    if (n != null) _opens.add(n);
  }

  /// Đổi phần `data` của BE sang [AppNotification]; `null` nếu thiếu `notificationId`.
  static AppNotification? notificationOf(PushMessage message) {
    String? value(String key) {
      final v = message.data[key];
      return v == null || v.isEmpty ? null : v;
    }

    return ApiNotificationRepository.notificationFromApi({
      'id': value('notificationId'),
      'type': value('type'),
      'referenceType': value('referenceType'),
      'referenceId': value('referenceId'),
      'title': message.title,
      'body': message.body,
      'isRead': false,
    });
  }

  @visibleForTesting
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _refreshSub?.cancel();
    await _opens.close();
  }
}
