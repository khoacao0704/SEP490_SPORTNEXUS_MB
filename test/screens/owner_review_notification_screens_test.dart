import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_review_strings.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_notification_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/app_notification.dart';
import 'package:test1/models/facility_review.dart';
import 'package:test1/screens/notification/notifications_screen.dart';
import 'package:test1/screens/owner/owner_account_screen.dart';
import 'package:test1/screens/owner/owner_notifications.dart';
import 'package:test1/screens/owner/owner_reviews_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    AppRepositories.owner = MockOwnerRepository(latency: Duration.zero);
    AppRepositories.notification = MockNotificationRepository(latency: Duration.zero);
    await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 5000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('đánh giá: điểm trung bình, lọc chưa trả lời, ẩn danh', (tester) async {
    await pump(tester, const OwnerReviewsScreen());
    expect(find.text('3.6'), findsOneWidget);
    expect(find.text(OwnerReviewStrings.reviewCount(8)), findsOneWidget);
    expect(find.text(OwnerReviewStrings.anonymous), findsNWidgets(9));
    expect(find.text(OwnerReviewStrings.reportHidden), findsOneWidget);
    expect(find.text(OwnerReviewStrings.reportPending), findsOneWidget);

    await tester.tap(find.textContaining(OwnerReviewStrings.filterUnreplied));
    await tester.pumpAndSettle();
    expect(find.text(OwnerReviewStrings.anonymous), findsNWidgets(6));
    expect(find.text(OwnerReviewStrings.yourReply), findsNothing);
  });

  testWidgets('trả lời đánh giá 2 sao', (tester) async {
    await pump(tester, const OwnerReviewsScreen());
    await tester.tap(find.widgetWithText(TextButton, OwnerReviewStrings.reply).first);
    await tester.pumpAndSettle();
    expect(find.text(OwnerReviewStrings.replyTitle), findsOneWidget);
    expect(find.text('"Đèn sân 3 bị chớp, mong sân sửa sớm."'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Cảm ơn bạn, sân đã thay đèn mới.');
    await tester.tap(find.text(OwnerReviewStrings.send));
    await tester.pumpAndSettle();

    expect(find.text('Cảm ơn bạn, sân đã thay đèn mới.'), findsOneWidget);
    expect(find.text(OwnerReviewStrings.replySaved), findsOneWidget);
    final reviews = await AppRepositories.owner.getFacilityReviews();
    expect(reviews.firstWhere((r) => r.id == 'rv-01').reply, isNotNull);
  });

  testWidgets('báo cáo đánh giá vi phạm', (tester) async {
    await pump(tester, const OwnerReviewsScreen());
    await tester.tap(find.widgetWithText(TextButton, OwnerReviewStrings.report).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReportReason.spam.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerReviewStrings.sendReport));
    await tester.pumpAndSettle();

    expect(find.text(OwnerReviewStrings.reportSent), findsOneWidget);
    expect(find.text(OwnerReviewStrings.reportPending), findsNWidgets(2));
    final rv = (await AppRepositories.owner.getFacilityReviews()).firstWhere((r) => r.id == 'rv-01');
    expect(rv.report!.reason, ReportReason.spam);
  });

  testWidgets('thông báo Chủ sân: chỉ nhóm của Chủ sân, bấm mở đúng màn', (tester) async {
    OwnerTab? selected;
    await pump(tester, ownerNotificationsScreen(onSelectTab: (t) => selected = t));

    for (final c in NotificationCategory.ownerCategories) {
      expect(find.text(c.label, skipOffstage: false), findsOneWidget);
    }
    expect(find.text(NotificationCategory.booking.label), findsNothing);
    expect(find.text('Có lượt đặt sân mới'), findsOneWidget);

    await tester.tap(find.text('Đánh giá mới 2 sao'));
    await tester.pumpAndSettle();
    expect(find.text(OwnerReviewStrings.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Có lượt đặt sân mới'));
    await tester.pumpAndSettle();
    expect(selected, OwnerTab.schedule);
  });

  testWidgets('màn thông báo người chơi không hiện nhóm của Chủ sân', (tester) async {
    await pump(tester, const NotificationsScreen());
    expect(find.widgetWithText(ChoiceChip, NotificationCategory.ownerFacility.label), findsNothing);
    expect(find.widgetWithText(ChoiceChip, NotificationCategory.booking.label), findsOneWidget);
  });

  testWidgets('tab Tài khoản mở Đánh giá và Thông báo', (tester) async {
    final owner = (await AppRepositories.auth.getCurrentUser())!;
    await pump(tester, OwnerAccountScreen(user: owner, onSelectTab: (_) {}));
    await tester.tap(find.text(OwnerStrings.menuReviews));
    await tester.pumpAndSettle();
    expect(find.text(OwnerReviewStrings.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(OwnerStrings.menuNotifications));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, NotificationCategory.ownerMoney.label), findsOneWidget);
  });
}
