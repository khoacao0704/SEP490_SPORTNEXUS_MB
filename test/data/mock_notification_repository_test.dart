import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_notification_repository.dart';
import 'package:test1/data/repositories/notification_repository.dart';
import 'package:test1/models/app_notification.dart';

void main() {
  late DateTime clock;
  late MockNotificationRepository repo;

  Future<void> loginAs(String identifier) =>
      MockAuthRepository(latency: Duration.zero).login(identifier, 'Player@123');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 14, 20, 0);
    repo = MockNotificationRepository(latency: Duration.zero, now: () => clock);
    await loginAs('player@sportnexus.vn');
  });

  test('mới nhất trước, có 3 thông báo chưa đọc', () async {
    final items = await repo.getNotifications();
    expect(items, isNotEmpty);
    for (var i = 1; i < items.length; i++) {
      expect(items[i - 1].createdAt.isBefore(items[i].createdAt), isFalse);
    }
    expect(await repo.getUnreadCount(), 3);
  });

  test('đánh dấu đã đọc một thông báo và tất cả', () async {
    final first = (await repo.getNotifications()).firstWhere((n) => !n.isRead);
    await repo.markAsRead(first.id);
    expect(await repo.getUnreadCount(), 2);
    expect((await repo.getNotifications()).firstWhere((n) => n.id == first.id).isRead, isTrue);

    await repo.markAllAsRead();
    expect(await repo.getUnreadCount(), 0);
  });

  test('trạng thái đã đọc tính riêng từng tài khoản; tài khoản không có dữ liệu mẫu thì trống', () async {
    await repo.markAllAsRead();
    await loginAs('restricted@sportnexus.vn');
    expect(await repo.getUnreadCount(), 2);
    expect((await repo.getNotifications()).any((n) => n.type == NotificationType.lfgRestriction), isTrue);

    await MockAuthRepository(latency: Duration.zero).logout();
    expect(await repo.getNotifications(), isEmpty);
  });

  test('giả lập thông báo mới: lên đầu danh sách, chưa đọc, báo thay đổi', () async {
    var changes = 0;
    final sub = repo.changes.listen((_) => changes++);
    clock = clock.add(const Duration(minutes: 5));

    final added = await repo.simulateIncoming();
    final items = await repo.getNotifications();
    expect(items.first.id, added.id);
    expect(items.first.isRead, isFalse);
    expect(await repo.getUnreadCount(), 4);

    await Future<void>.delayed(Duration.zero);
    expect(changes, 1);
    await sub.cancel();
  });

  test('loại thông báo lạ từ BE thì bỏ qua thay vì lỗi', () {
    final json = {
      'id': 'x',
      'type': 'SomethingNew',
      'title': 't',
      'body': 'b',
      'createdAt': clock.toIso8601String(),
    };
    expect(AppNotification.fromJson(json), isNull);
    expect(AppNotification.fromJson({...json, 'type': 'LfgFull'})?.type, NotificationType.lfgFull);
  });

  test('thời gian tương đối', () {
    final now = DateTime(2026, 10, 14, 20, 0);
    expect(Formatters.timeAgo(now.subtract(const Duration(seconds: 20)), now), 'Vừa xong');
    expect(Formatters.timeAgo(now.subtract(const Duration(minutes: 5)), now), '5 phút trước');
    expect(Formatters.timeAgo(now.subtract(const Duration(hours: 3)), now), '3 giờ trước');
    expect(Formatters.timeAgo(DateTime(2026, 10, 13, 18, 30), now), 'Thứ 3, 13/10 • 18:30');
  });

  test('trang theo nhóm / chưa đọc, số chưa đọc theo nhóm, đọc hết một nhóm', () async {
    final lfg = await repo.getPage(group: NotificationGroup.lfg);
    expect(lfg.items, isNotEmpty);
    expect(lfg.items.every((n) => n.group == NotificationGroup.lfg), isTrue);
    expect(lfg.hasMore, isFalse);

    final unread = await repo.getUnread();
    expect(unread.total, 3);
    expect(unread.byGroup.values.fold<int>(0, (a, b) => a + b), 3);

    await repo.markAllAsRead(group: NotificationGroup.lfg);
    expect((await repo.getUnread()).byGroup.containsKey(NotificationGroup.lfg), isFalse);
    expect(await repo.getUnreadCount(), 3 - (unread.byGroup[NotificationGroup.lfg] ?? 0));
    expect((await repo.getPage(unreadOnly: true)).items.every((n) => !n.isRead), isTrue);
  });

  test('xoá một thông báo và xoá mọi thông báo đã đọc', () async {
    final all = await repo.getNotifications();
    await repo.delete(all.first.id);
    expect((await repo.getNotifications()).any((n) => n.id == all.first.id), isFalse);

    final readCount = all.skip(1).where((n) => n.isRead).length;
    expect(await repo.deleteRead(), readCount);
    final left = await repo.getNotifications();
    expect(left.every((n) => !n.isRead), isTrue);
    expect(left, hasLength(all.length - 1 - readCount));
  });

  test('cài đặt: lưu nhóm tắt theo tài khoản, chặn tắt nhóm bắt buộc', () async {
    expect(await repo.getDisabledGroups(), isEmpty);
    await repo.setDisabledGroups({NotificationGroup.lfg, NotificationGroup.team});
    expect(await repo.getDisabledGroups(), {NotificationGroup.lfg, NotificationGroup.team});

    expect(() => repo.setDisabledGroups({NotificationGroup.wallet}), throwsA(isA<NotificationException>()));

    await loginAs('restricted@sportnexus.vn');
    expect(await repo.getDisabledGroups(), isEmpty);
  });
}
