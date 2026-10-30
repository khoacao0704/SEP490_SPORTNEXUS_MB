import 'dart:async';

import '../../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import 'api_client.dart';
import 'notification_hub.dart';

/// Thông báo qua BE: hộp thư, đọc / xoá, cài đặt theo nhóm và realtime (SignalR).
///
/// Kênh realtime chỉ mở khi có người nghe [changes] hoặc [incoming] (chuông, màn thông báo)
/// và đóng khi không còn ai nghe.
class ApiNotificationRepository implements NotificationRepository {
  static const String listPath = '/api/v1/notifications';
  static const String unreadPath = '/api/v1/notifications/unread-count';
  static const String readAllPath = '/api/v1/notifications/read-all';
  static const String settingsPath = '/api/v1/notifications/settings';
  static String itemPath(String id) => '/api/v1/notifications/$id';
  static String readPath(String id) => '/api/v1/notifications/$id/read';

  final ApiClient _api;
  final NotificationRealtime? _realtime;

  late final StreamController<void> _changes = StreamController<void>.broadcast(
    onListen: _listenersChanged,
    onCancel: _listenersChanged,
  );
  late final StreamController<AppNotification> _incoming = StreamController<AppNotification>.broadcast(
    onListen: _listenersChanged,
    onCancel: _listenersChanged,
  );
  bool _live = false;

  ApiNotificationRepository({required this._api, this._realtime});

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<AppNotification> get incoming => _incoming.stream;

  @override
  Future<NotificationPage> getPage({NotificationGroup? group, bool unreadOnly = false, int page = 1}) async {
    const size = NotificationRepository.pageSize;
    final data = await _call(
      () => _api.get(
        listPath,
        query: {
          if (group != null) 'type': group.apiValue,
          if (unreadOnly) 'unreadOnly': true,
          'page': page,
          'pageSize': size,
        },
      ),
    );
    final map = data is Map ? data : const {};
    final items = (map['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => notificationFromApi(Map<String, dynamic>.from(e)))
        .whereType<AppNotification>()
        .toList();
    final totalPages = (map['totalPages'] as num?)?.toInt();
    return NotificationPage(items: items, hasMore: totalPages != null ? page < totalPages : items.length >= size);
  }

  @override
  Future<List<AppNotification>> getNotifications() async => (await getPage()).items;

  @override
  Future<int> getUnreadCount() async => (await getUnread()).total;

  @override
  Future<UnreadNotifications> getUnread() async {
    final data = await _call(() => _api.get(unreadPath));
    if (data is num) return UnreadNotifications(total: data.toInt());
    final map = data is Map ? data : const {};
    final byType = map['byType'] is Map ? map['byType'] as Map : const {};
    final byGroup = <NotificationGroup, int>{};
    byType.forEach((key, value) {
      if (value is! num || value <= 0) return;
      final group = NotificationGroup.fromApi(key.toString());
      byGroup[group] = (byGroup[group] ?? 0) + value.toInt();
    });
    return UnreadNotifications(total: (map['total'] as num?)?.toInt() ?? 0, byGroup: byGroup);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _call(() => _api.put(readPath(notificationId)));
    _changes.add(null);
  }

  @override
  Future<void> markAllAsRead({NotificationGroup? group}) async {
    await _call(() => _api.put(readAllPath, query: {if (group != null) 'type': group.apiValue}));
    _changes.add(null);
  }

  @override
  Future<void> delete(String notificationId) async {
    await _call(() => _api.delete(itemPath(notificationId)));
    _changes.add(null);
  }

  @override
  Future<int> deleteRead() async {
    final data = await _call(() => _api.delete(listPath));
    _changes.add(null);
    return data is Map ? (data['deleted'] as num?)?.toInt() ?? 0 : 0;
  }

  @override
  Future<Set<NotificationGroup>> getDisabledGroups() async =>
      disabledGroupsFromApi(await _call(() => _api.get(settingsPath)));

  @override
  Future<void> setDisabledGroups(Set<NotificationGroup> disabled) async {
    await _call(
      () => _api.put(
        settingsPath,
        body: {'disabledTypes': disabled.where((g) => !g.mandatory).map((g) => g.apiValue).toList()},
      ),
    );
  }

  // ---------------- Realtime ----------------

  void _listenersChanged() {
    final wanted = _changes.hasListener || _incoming.hasListener;
    final realtime = _realtime;
    if (realtime == null || wanted == _live) return;
    _live = wanted;
    if (wanted) {
      unawaited(
        realtime.start(
          onNotification: (json) {
            final n = notificationFromApi(json);
            if (n != null) _incoming.add(n);
            _changes.add(null);
          },
          onUnreadCount: (_) => _changes.add(null),
        ),
      );
    } else {
      unawaited(realtime.stop());
    }
  }

  // ---------------- Chuyển đổi ----------------

  /// `null` khi thiếu id (bỏ qua bản ghi hỏng).
  static AppNotification? notificationFromApi(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final group = NotificationGroup.fromApi(json['type']?.toString());
    final reference = NotificationReference.fromApi(json['referenceType']?.toString());
    final referenceId = json['referenceId']?.toString();
    return AppNotification(
      id: id,
      type: NotificationType.forApi(group, reference),
      group: group,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      isRead: json['isRead'] == true,
      referenceType: referenceId == null ? null : reference,
      referenceId: referenceId,
    );
  }

  /// GET /settings trả đủ 9 nhóm kèm trạng thái. Đọc được cả dạng `{disabledTypes: [...]}`.
  static Set<NotificationGroup> disabledGroupsFromApi(Object? data) {
    if (data is Map && data['disabledTypes'] is List) {
      return {for (final v in data['disabledTypes'] as List) NotificationGroup.fromApi(v.toString())}
        ..removeWhere((g) => g.mandatory);
    }
    final list = data is List
        ? data
        : data is Map
        ? (data['items'] ?? data['settings'] ?? data['types']) as List? ?? const []
        : const [];
    final disabled = <NotificationGroup>{};
    for (final item in list.whereType<Map>()) {
      final type = (item['type'] ?? item['code'])?.toString();
      final enabled = item['enabled'] ?? item['isEnabled'];
      final off = enabled is bool ? !enabled : (item['disabled'] ?? item['isDisabled']) == true;
      if (type == null || !off) continue;
      final group = NotificationGroup.fromApi(type);
      if (!group.mandatory) disabled.add(group);
    }
    return disabled;
  }

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw NotificationException(e.message);
    }
  }
}
