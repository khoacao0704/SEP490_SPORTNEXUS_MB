import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_review_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_notification_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/app_notification.dart';
import 'package:test1/models/facility_review.dart';
import 'package:test1/models/owner_complaint.dart';

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

  group('Đánh giá', () {
    test('mới nhất trước, lọc theo cơ sở / số sao / phản hồi, phân trang', () async {
      final all = await repo.getFacilityReviews();
      expect(all.total, 9);
      expect(all.items.first.id, 'rv-01');
      expect(all.items.first.userName, 'Nguyễn Minh Anh');
      expect((await repo.getFacilityReviews(facilityId: 'f-hcm-hoalu')).total, 4);
      expect((await repo.getFacilityReviews(rating: 5)).items.map((r) => r.id), ['rv-02', 'rv-05', 'rv-07']);
      expect((await repo.getFacilityReviews(replied: true)).items.map((r) => r.id), ['rv-03', 'rv-07']);
      final p2 = await repo.getFacilityReviews(page: 2, pageSize: 4);
      expect(p2.totalPages, 3);
      expect(p2.items.first.id, 'rv-05');
    });

    test('thống kê không tính đánh giá Admin đã ẩn', () async {
      final s = await repo.getReviewStats();
      expect(s.totalReviews, 8);
      expect(s.averageRating, closeTo(29 / 8, 0.001));
      expect([for (var i = 1; i <= 5; i++) s.countOf(i)], [1, 1, 1, 2, 3]);
      expect(s.unrepliedCount, 6);
      expect(s.replyPercent, 25);
      expect(s.newLast30Days, 8);
    });

    test('phản hồi: gửi (POST) một lần, sửa (PUT), xóa', () async {
      await expectLater(repo.replyToReview('rv-01', '   '), throwsOwner(OwnerReviewStrings.replyEmpty));
      await expectLater(repo.replyToReview('rv-01', 'x', edit: true), throwsOwner(OwnerReviewStrings.noReplyYet));

      await repo.replyToReview('rv-01', 'Cảm ơn bạn, sân đã thay đèn mới.');
      await expectLater(repo.replyToReview('rv-01', 'lần 2'), throwsOwner(OwnerReviewStrings.alreadyReplied));
      await repo.replyToReview('rv-01', 'Đã thay đèn sân 3 ngày 16/10.', edit: true);
      var r = (await repo.getFacilityReviews()).items.first;
      expect(r.ownerReply, 'Đã thay đèn sân 3 ngày 16/10.');
      expect(r.repliedAt, now);

      await repo.deleteReviewReply('rv-01');
      r = (await repo.getFacilityReviews()).items.first;
      expect(r.hasReply, isFalse);
      expect(r.comment, isNotEmpty, reason: 'đánh giá của khách vẫn giữ');
    });

    test('báo cáo đánh giá (mobile): một lần, chờ Admin xem xét', () async {
      final reported = await repo.reportReview('rv-01', ReportReason.offensive, note: ' chửi bậy ');
      expect(reported.report!.status, ReportStatus.pending);
      expect(reported.report!.note, 'chửi bậy');
      expect(reported.canReport, isFalse);
      expect(reported.isHidden, isFalse);

      await expectLater(repo.reportReview('rv-01', ReportReason.spam), throwsOwner(OwnerReviewStrings.alreadyReported));
      await expectLater(repo.reportReview('rv-08', ReportReason.spam), throwsOwner(OwnerReviewStrings.alreadyReported));
    });

    test('người chơi không xem được đánh giá của chủ sân', () async {
      await loginAs('player@sportnexus.vn', 'Player@123');
      expect((await repo.getFacilityReviews()).items, isEmpty);
      await expectLater(repo.replyToReview('rv-01', 'x'), throwsOwner(OwnerReviewStrings.notFound));
    });
  });

  group('Khiếu nại', () {
    test('đếm theo trạng thái, lọc tab / cơ sở / từ khóa', () async {
      final all = await repo.getComplaints();
      expect(all.total, 5);
      expect(all.items.first.id, 'cp-01');
      expect(all.counts.pending, 2);
      expect(all.counts.responded, 1);
      expect(all.counts.refunded, 1);
      expect(all.counts.noRefund, 1);
      expect((await repo.getComplaints(status: ComplaintStatus.pending)).items.map((c) => c.id), ['cp-01', 'cp-02']);
      expect((await repo.getComplaints(facilityId: 'f-hcm-hoalu')).total, 2);
      expect((await repo.getComplaints(keyword: 'lê thu')).items.single.id, 'cp-03');
    });

    test('gửi giải trình: bắt buộc nội dung, chuyển Đã giải trình, vẫn hoàn tiền được', () async {
      await expectLater(repo.respondComplaint('cp-01', response: ' '), throwsOwner(OwnerComplaintStrings.responseEmpty));
      await repo.respondComplaint('cp-01', response: 'Đã thay bóng đèn.', evidenceUrls: const ['/tmp/a.jpg']);
      final c = await repo.getComplaint('cp-01');
      expect(c.status, ComplaintStatus.ownerResponded);
      expect(c.ownerEvidenceUrls, ['/tmp/a.jpg']);
      expect(c.status.canAct, isTrue);
    });

    test('đồng ý hoàn tiền: tỉ lệ 1-100%, xong thì không xử lý lại', () async {
      await expectLater(
        repo.acceptComplaintRefund('cp-02', response: 'ok', refundPercent: 0),
        throwsOwner(OwnerComplaintStrings.percentError),
      );
      await repo.acceptComplaintRefund('cp-02', response: 'Xin lỗi bạn', refundPercent: 40, lockSlot: true);
      final c = await repo.getComplaint('cp-02');
      expect(c.status, ComplaintStatus.resolvedRefunded);
      expect(c.refundedAmount, 180000);
      expect(c.appliedRefundPercentage, 40);
      await expectLater(repo.respondComplaint('cp-02', response: 'x'), throwsOwner(OwnerComplaintStrings.cannotAct));
      await expectLater(repo.respondComplaint('cp-05', response: 'x'), throwsOwner(OwnerComplaintStrings.cannotAct));
    });
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
