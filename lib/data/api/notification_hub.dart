import 'dart:async';

import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../core/config/api_config.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Kênh realtime của thông báo: BE đẩy thông báo mới và số chưa đọc xuống app.
abstract class NotificationRealtime {
  /// Mở kết nối. Lỗi mạng không ném ra ngoài: kênh tự thử lại cho tới khi [stop].
  Future<void> start({
    required void Function(Map<String, dynamic> json) onNotification,
    required void Function(int unread) onUnreadCount,
  });

  Future<void> stop();
}

/// SignalR `/hubs/notifications`. Token gửi qua `?access_token=` (thư viện tự gắn).
///
/// Event của server: `notificationReceived` (một thông báo, cùng dạng item của
/// GET /notifications) và `unreadCountChanged` (số nguyên). Vừa kết nối, server gửi ngay số chưa đọc.
class SignalRNotificationRealtime implements NotificationRealtime {
  static const String hubPath = '/hubs/notifications';
  static const Duration retryDelay = Duration(seconds: 30);

  final TokenStore _tokens;
  final ApiClient _api;

  HubConnection? _connection;
  Timer? _retry;
  bool _wanted = false;
  bool _connecting = false;
  void Function(Map<String, dynamic>)? _onNotification;
  void Function(int)? _onUnreadCount;

  SignalRNotificationRealtime({required this._tokens, required this._api});

  @override
  Future<void> start({
    required void Function(Map<String, dynamic> json) onNotification,
    required void Function(int unread) onUnreadCount,
  }) async {
    _onNotification = onNotification;
    _onUnreadCount = onUnreadCount;
    _wanted = true;
    await _connect(refreshed: false);
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _retry?.cancel();
    _retry = null;
    final connection = _connection;
    _connection = null;
    try {
      await connection?.stop();
    } catch (_) {
      // Đang đóng thì bỏ qua lỗi.
    }
  }

  Future<void> _connect({required bool refreshed}) async {
    if (!_wanted || _connection != null || _connecting) return;
    _connecting = true;
    try {
      await _open(refreshed: refreshed);
    } catch (_) {
      // Lỗi ngoài dự kiến (vd. đọc token): không để lọt ra ngoài, chờ thử lại.
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  Future<void> _open({required bool refreshed}) async {
    // Kiểm tra lại sau mỗi bước chờ: có thể đã [stop] trong lúc đó.
    if (await _tokens.read() == null || !_wanted) return;

    final connection = HubConnectionBuilder()
        .withUrl(
          '${ApiConfig.baseUrl}$hubPath',
          options: HttpConnectionOptions(accessTokenFactory: () async => await _tokens.read() ?? ''),
        )
        .withAutomaticReconnect()
        .build();
    connection.on('notificationReceived', (args) {
      final json = args?.firstOrNull;
      if (json is Map) _onNotification?.call(Map<String, dynamic>.from(json));
    });
    connection.on('unreadCountChanged', (args) {
      final count = args?.firstOrNull;
      if (count is num) _onUnreadCount?.call(count.toInt());
    });
    // Tự kết nối lại của thư viện bỏ cuộc sau vài lần: chờ rồi mở kết nối mới.
    connection.onclose(({error}) {
      if (_connection == connection) _connection = null;
      _scheduleRetry();
    });

    _connection = connection;
    try {
      await connection.start();
      if (!_wanted && _connection == connection) {
        // Đã dừng trong lúc đang kết nối.
        _connection = null;
        await connection.stop();
      }
    } catch (e) {
      if (_connection == connection) _connection = null;
      // Chỉ làm mới token khi BE từ chối token (401), mỗi lượt một lần; lỗi mạng thì chờ thử lại.
      if (!refreshed && _wanted && e is HttpError && e.statusCode == 401 && await _tryRefresh()) {
        await _open(refreshed: true);
        return;
      }
      _scheduleRetry();
    }
  }

  Future<bool> _tryRefresh() async {
    try {
      return await _api.refreshSession();
    } catch (_) {
      return false;
    }
  }

  void _scheduleRetry() {
    if (!_wanted) return;
    _retry?.cancel();
    _retry = Timer(retryDelay, () => _connect(refreshed: false));
  }
}
