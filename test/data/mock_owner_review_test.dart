import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_review_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_notification_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/app_notification.dart';
import 'package:test1/models/facility_review.dart';

void main() {
  final now = DateTime(2026, 10, 15, 15, 0);
  late MockOwnerRepository repo;

  Future<void> loginAs(String email, String password) async {
    SharedPreferences.setMockInitialValues({});
    await MockAuthRepository(latency: Duration.zero).login(email, password);
  }

  setUp(() async {
    await loginAs('owner@sportnexus.vn', 'Owner@123');
    repo = MockOwnerRepository(latency: Duration.zero, now: () => now);
  });

  Matcher throwsOwner(String message) =>
      throwsA(isA<OwnerException>().having((e) => e.message, 'message', message));

  test('đánh giá ẩn danh, mới nhất trước, lọc theo cơ sở', () async {
    final all = await repo.getFacilityReviews();
    expect(all, hasLength(9));
    expect(all.first.id, 'rv-01');
    final hoaLu = await repo.getFacilityReviews(facilityId: 'f-hcm-hoalu');
    expect(hoaLu.every((r) => r.facilityId == 'f-hcm-hoalu'), isTrue);
    expect(hoaLu, hasLength(4));
  });

  test('điểm trung bình không tính đánh giá Admin đã ẩn', () async {
    final summary = ReviewSummary(await repo.getFacilityReviews());
    expect(summary.count, 8); // rv-08 bị ẩn
    expect(summary.average, closeTo(29 / 8, 0.001));
    expect(summary.distribution, [1, 1, 1, 2, 3]);
    expect(summary.unreplied, 6);
  });

  test('trả lời công khai: bắt buộc nội dung, sửa được, không trả lời đánh giá đã ẩn', () async {
    await expectLater(repo.replyToReview('rv-01', '   '), throwsOwner(OwnerReviewStrings.replyEmpty));

    final replied = await repo.replyToReview('rv-01', 'Cảm ơn bạn, sân đã thay đèn mới.');
    expect(replied.reply!.text, 'Cảm ơn bạn, sân đã thay đèn mới.');
    final edited = await repo.replyToReview('rv-01', 'Đã thay đèn sân 3 ngày 16/10.');
    expect(edited.reply!.text, 'Đã thay đèn sân 3 ngày 16/10.');

    await expectLater(repo.replyToReview('rv-08', 'abc'), throwsOwner(OwnerReviewStrings.cannotReplyHidden));
  });

  test('báo cáo đánh giá: một lần, chờ Admin xem xét', () async {
    final reported = await repo.reportReview('rv-01', ReportReason.offensive, note: ' chửi bậy ');
    expect(reported.report!.status, ReportStatus.pending);
    expect(reported.report!.note, 'chửi bậy');
    expect(reported.canReport, isFalse);
    expect(reported.isHidden, isFalse); // chưa ẩn cho tới khi Admin quyết

    await expectLater(repo.reportReview('rv-01', ReportReason.spam), throwsOwner(OwnerReviewStrings.alreadyReported));
    await expectLater(repo.reportReview('rv-04', ReportReason.spam), throwsOwner(OwnerReviewStrings.alreadyReported));
  });

  test('người chơi không xem được đánh giá của chủ sân', () async {
    await loginAs('player@sportnexus.vn', 'Player@123');
    expect(await repo.getFacilityReviews(), isEmpty);
    await expectLater(repo.replyToReview('rv-01', 'x'), throwsOwner(OwnerReviewStrings.notFound));
  });

  test('thông báo của Chủ sân chỉ thuộc các nhóm Chủ sân', () async {
    final notifications = MockNotificationRepository(latency: Duration.zero, now: () => now);
    final items = await notifications.getNotifications();
    expect(items, isNotEmpty);
    expect(items.every((n) => n.type.category.forOwner), isTrue);
    expect(items.map((n) => n.type.category).toSet(), NotificationCategory.ownerCategories.toSet());
    expect(await notifications.getUnreadCount(), 4);

    final incoming = await notifications.simulateIncoming();
    expect(incoming.type.category.forOwner, isTrue);
  });
}
