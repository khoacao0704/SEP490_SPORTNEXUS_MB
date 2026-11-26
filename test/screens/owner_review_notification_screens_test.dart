import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_review_strings.dart';
import 'package:test1/core/strings/owner_slot_strings.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_notification_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/models/app_notification.dart';
import 'package:test1/models/facility_review.dart';
import 'package:test1/models/owner_complaint.dart';
import 'package:test1/screens/notification/notifications_screen.dart';
import 'package:test1/screens/owner/owner_account_screen.dart';
import 'package:test1/screens/owner/owner_complaints_screen.dart';
import 'package:test1/screens/owner/owner_notifications.dart';
import 'package:test1/screens/owner/owner_reviews_screen.dart';

import '../helpers/layout_check.dart';

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

  testWidgets('đánh giá như Web: thống kê, phân bố sao, tên khách, lọc chưa phản hồi', (tester) async {
    await pump(tester, const OwnerReviewsScreen());
    expect(find.text(OwnerReviewStrings.statAverage), findsOneWidget);
    expect(find.text('3.6 / 5'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text(OwnerReviewStrings.distributionTitle), findsOneWidget);
    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
    expect(find.text(OwnerReviewStrings.reportPending), findsOneWidget);
    expect(find.text(OwnerReviewStrings.noComment), findsOneWidget);
    await tester.scrollUntilVisible(find.text(OwnerReviewStrings.hidden), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Spam quảng cáo'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DropdownButtonFormField<bool?>, OwnerReviewStrings.allReplied));
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerReviewStrings.unreplied).last);
    await tester.pumpAndSettle();
    expect(find.text(OwnerReviewStrings.yourReply), findsNothing);
    expect(find.text('Lê Thu Hà'), findsNothing);
  });

  testWidgets('gửi phản hồi, sửa rồi xóa phản hồi', (tester) async {
    await pump(tester, const OwnerReviewsScreen());
    await tester.enterText(find.byType(TextField).first, 'Cảm ơn bạn, sân đã thay đèn mới.');
    await tester.tap(find.text(OwnerReviewStrings.sendReply).first);
    await tester.pumpAndSettle();
    expect(find.text(OwnerReviewStrings.replySent), findsOneWidget);
    expect(find.text('Cảm ơn bạn, sân đã thay đèn mới.'), findsOneWidget);

    await tester.tap(find.text(OwnerReviewStrings.edit).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cảm ơn bạn, sân đã thay đèn mới.'), 'Đã thay đèn.');
    await tester.tap(find.text(OwnerReviewStrings.saveReply));
    await tester.pumpAndSettle();
    expect(find.text('Đã thay đèn.'), findsOneWidget);

    await tester.tap(find.text(OwnerReviewStrings.delete).first);
    await tester.pumpAndSettle();
    expect(find.text(OwnerReviewStrings.deleteConfirm), findsOneWidget);
    await tester.tap(find.text(OwnerSlotStrings.confirm));
    await tester.pumpAndSettle();
    final first = (await AppRepositories.owner.getFacilityReviews()).items.first;
    expect(first.hasReply, isFalse);
  });

  testWidgets('báo cáo đánh giá vi phạm (giữ của mobile)', (tester) async {
    await pump(tester, const OwnerReviewsScreen());
    await tester.tap(find.text(OwnerReviewStrings.report).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReportReason.spam.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerReviewStrings.sendReport));
    await tester.pumpAndSettle();

    expect(find.text(OwnerReviewStrings.reportSent), findsOneWidget);
    expect(find.text(OwnerReviewStrings.reportPending), findsNWidgets(2));
    final rv = (await AppRepositories.owner.getFacilityReviews()).items.firstWhere((r) => r.id == 'rv-01');
    expect(rv.report!.reason, ReportReason.spam);
  });

  testWidgets('khiếu nại: tab có số đếm, mở xử lý, gửi giải trình', (tester) async {
    await pump(tester, const OwnerComplaintsScreen());
    expect(find.text('${ComplaintTab.pending.label} (2)'), findsOneWidget);
    expect(find.text(OwnerComplaintStrings.handle), findsNWidgets(2));

    await tester.tap(find.text('${ComplaintTab.pending.label} (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Lê Thu Hà'), findsNothing);

    await tester.tap(find.text(OwnerComplaintStrings.handle).first);
    await tester.pumpAndSettle();
    expect(find.text(OwnerComplaintStrings.detailTitle('Nguyễn Minh Anh')), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    await tester.tap(find.text(OwnerComplaintStrings.submitRespond));
    await tester.pumpAndSettle();
    expect(find.text(OwnerComplaintStrings.responseEmpty), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, OwnerComplaintStrings.fieldRespond), 'Đã thay bóng đèn sân 3.');
    await tester.tap(find.text(OwnerComplaintStrings.submitRespond));
    await tester.pumpAndSettle();
    expect(find.text(OwnerComplaintStrings.title), findsOneWidget);
    expect((await AppRepositories.owner.getComplaint('cp-01')).status, ComplaintStatus.ownerResponded);
    expect(find.text('${ComplaintTab.pending.label} (1)'), findsOneWidget);
  });

  testWidgets('khiếu nại: đồng ý hoàn tiền có hỏi xác nhận, khóa ca', (tester) async {
    await pump(tester, const OwnerComplaintDetailScreen(complaintId: 'cp-02'));
    await tester.tap(find.text(OwnerComplaintStrings.modeRefund));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, OwnerComplaintStrings.fieldRefund), 'Xin lỗi bạn.');
    await tester.enterText(find.widgetWithText(TextField, OwnerComplaintStrings.refundPercent), '40');
    await tester.tap(find.text(OwnerComplaintStrings.lockSlot));
    await tester.tap(find.text(OwnerComplaintStrings.submitRefund));
    await tester.pumpAndSettle();
    expect(find.text(OwnerComplaintStrings.refundConfirm(40)), findsOneWidget);
    await tester.tap(find.text(OwnerSlotStrings.confirm));
    await tester.pumpAndSettle();
    final c = await AppRepositories.owner.getComplaint('cp-02');
    expect(c.status, ComplaintStatus.resolvedRefunded);
    expect(c.appliedRefundPercentage, 40);
  });

  testWidgets('khiếu nại đã xử lý: chỉ xem, có kết luận Admin, không có form', (tester) async {
    await pump(tester, const OwnerComplaintDetailScreen(complaintId: 'cp-04'));
    expect(find.text(OwnerComplaintStrings.yourResponse), findsOneWidget);
    expect(find.textContaining('Chủ sân đã hoàn tiền'), findsOneWidget);
    expect(find.text(OwnerComplaintStrings.submitRespond), findsNothing);
  });

  Future<void> scrollAll(WidgetTester t) async {
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -500), warnIfMissed: false);
      await t.pump();
    }
  }

  testWidgets('bố cục Đánh giá và Khiếu nại: nhiều cỡ máy + chữ phóng to không tràn', (tester) async {
    final problems = [
      ...await collectLayoutProblems(tester, 'Đánh giá', () => const OwnerReviewsScreen(), interact: scrollAll),
      ...await collectLayoutProblems(tester, 'Khiếu nại', () => const OwnerComplaintsScreen(), interact: scrollAll),
      ...await collectLayoutProblems(tester, 'Xử lý khiếu nại', () => const OwnerComplaintDetailScreen(complaintId: 'cp-01'),
          interact: (t) async {
        await t.ensureVisible(find.text(OwnerComplaintStrings.modeRefund));
        await t.pump();
        await t.tap(find.text(OwnerComplaintStrings.modeRefund));
        await t.pump();
        await scrollAll(t);
      }),
      ...await collectLayoutProblems(tester, 'Khiếu nại đã xử lý', () => const OwnerComplaintDetailScreen(complaintId: 'cp-04'), interact: scrollAll),
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
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
    // Màn người chơi lọc theo nhóm của BE (Đặt sân / Kèo LFG / Ví), không có nhóm nào của Chủ sân.
    expect(find.widgetWithText(ChoiceChip, NotificationCategory.ownerFacility.label), findsNothing);
    expect(find.widgetWithText(ChoiceChip, NotificationCategory.ownerMoney.label), findsNothing);
    expect(find.widgetWithText(ChoiceChip, NotificationGroup.booking.label), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, NotificationGroup.lfg.label), findsOneWidget);
  });

  testWidgets('tab Tài khoản mở Đánh giá, Khiếu nại và Thông báo', (tester) async {
    final owner = (await AppRepositories.auth.getCurrentUser())!;
    await pump(tester, OwnerAccountScreen(user: owner, onSelectTab: (_) {}));
    await tester.tap(find.text(OwnerStrings.menuReviews));
    await tester.pumpAndSettle();
    expect(find.text(OwnerReviewStrings.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(OwnerStrings.menuComplaints));
    await tester.pumpAndSettle();
    expect(find.text(OwnerComplaintStrings.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(OwnerStrings.menuNotifications));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, NotificationCategory.ownerMoney.label), findsOneWidget);
  });
}
