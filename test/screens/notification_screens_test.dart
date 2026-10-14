import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/notification_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_notification_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/screens/fair_play/fair_play_screen.dart';
import 'package:test1/screens/notification/notifications_screen.dart';
import 'package:test1/widgets/notification/notification_bell.dart';

void main() {
  late MockNotificationRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = MockNotificationRepository(latency: Duration.zero);
    AppRepositories.notification = repo;
    AppRepositories.review = MockReviewRepository(latency: Duration.zero);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('chuông hiện số chưa đọc và tự cập nhật khi có thông báo mới', (tester) async {
    await pump(tester, Scaffold(appBar: AppBar(actions: const [NotificationBell()])));
    expect(find.text('3'), findsOneWidget);

    await tester.runAsync(repo.simulateIncoming);
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('lọc chưa đọc, đọc tất cả', (tester) async {
    await pump(tester, const NotificationsScreen());
    expect(find.text(NotificationStrings.today), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(3));

    await tester.tap(find.text('${NotificationStrings.filterUnread} (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Rút tiền thành công'), findsNothing);
    expect(find.text('Sắp tới giờ chơi'), findsOneWidget);

    await tester.tap(find.byTooltip(NotificationStrings.markAllRead));
    await tester.pumpAndSettle();
    expect(find.text(NotificationStrings.emptyUnread), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
  });

  testWidgets('lọc theo nhóm Ví', (tester) async {
    await pump(tester, const NotificationsScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ví'));
    await tester.pumpAndSettle();
    expect(find.text('Nạp tiền thành công'), findsOneWidget);
    expect(find.text('Sắp tới giờ chơi'), findsNothing);
  });

  testWidgets('bấm thông báo Fair Play: đánh dấu đã đọc và mở màn Fair Play', (tester) async {
    await pump(tester, const NotificationsScreen());
    await tester.tap(find.text('Fair Play +3'));
    await tester.pumpAndSettle();
    expect(find.byType(FairPlayScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('bấm thông báo chưa đọc thì giảm số chưa đọc', (tester) async {
    await pump(tester, const NotificationsScreen());
    await tester.tap(find.text('Đánh giá buổi chơi'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(2));
  });
}
