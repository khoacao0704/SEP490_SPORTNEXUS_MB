import '../../models/facility_review.dart';
import '../../models/sport.dart';

/// Đánh giá mẫu cho hai cơ sở đã duyệt của Chủ sân demo.
class MockOwnerReviewData {
  MockOwnerReviewData._();

  static List<FacilityReview> seed(DateTime now) {
    DateTime ago(int hours) => now.subtract(Duration(hours: hours));
    const tt = ('f-hcm-thientrieu', 'Sân Cầu Lông Thiên Triều');
    const hl = ('f-hcm-hoalu', 'Sân Bóng Hoa Lư');

    FacilityReview r(String id, (String, String) f, Sport sport, int stars, String comment, int hoursAgo,
            {ReviewReply? reply, ReviewReport? report}) =>
        FacilityReview(
          id: id,
          facilityId: f.$1,
          facilityName: f.$2,
          sport: sport,
          stars: stars,
          comment: comment,
          createdAt: ago(hoursAgo),
          reply: reply,
          report: report,
        );

    return [
      r('rv-01', tt, Sport.badminton, 2, 'Đèn sân 3 bị chớp, mong sân sửa sớm.', 3),
      r('rv-02', hl, Sport.football, 5, 'Cỏ mới, đèn sáng, nhân viên nhiệt tình.', 20),
      r('rv-03', tt, Sport.pickleball, 4, 'Sân đẹp nhưng bãi xe hơi chật vào giờ cao điểm.', 30,
          reply: ReviewReply(text: 'Cảm ơn bạn! Sân đã thuê thêm bãi xe bên cạnh từ tuần này.', updatedAt: ago(26))),
      r('rv-04', hl, Sport.football, 1, 'Sân như cái chợ, chủ sân lừa đảo!!! Đừng ai đặt.', 50,
          report: ReviewReport(
            reason: ReportReason.falseInfo,
            note: 'Khách này không có lượt check-in nào tại sân trong tuần.',
            createdAt: ago(45),
          )),
      r('rv-05', tt, Sport.badminton, 5, '', 72),
      r('rv-06', hl, Sport.basketball, 3, 'Rổ hơi lỏng, còn lại ổn.', 96),
      r('rv-07', tt, Sport.badminton, 5, 'Thảm êm, giá hợp lý. Sẽ quay lại.', 120,
          reply: ReviewReply(text: 'Cảm ơn bạn đã ủng hộ sân!', updatedAt: ago(118))),
      r('rv-08', hl, Sport.football, 1, 'Mua sân giá rẻ inbox 09xx...', 200,
          report: ReviewReport(reason: ReportReason.spam, createdAt: ago(190), status: ReportStatus.hidden)),
      r('rv-09', tt, Sport.badminton, 4, 'Ổn, nhưng nước uống hơi đắt.', 260,
          report: ReviewReport(reason: ReportReason.falseInfo, createdAt: ago(250), status: ReportStatus.kept)),
    ];
  }
}
