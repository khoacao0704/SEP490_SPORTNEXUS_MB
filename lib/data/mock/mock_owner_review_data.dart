import '../../models/facility_review.dart';

/// Đánh giá mẫu cho hai cơ sở đã duyệt của Chủ sân demo.
class MockOwnerReviewData {
  MockOwnerReviewData._();

  static List<FacilityReview> seed(DateTime now) {
    DateTime ago(int hours) => now.subtract(Duration(hours: hours));
    const tt = ('f-hcm-thientrieu', 'Sân Cầu Lông Thiên Triều');
    const hl = ('f-hcm-hoalu', 'Sân Bóng Hoa Lư');

    FacilityReview r(String id, (String, String) f, String user, int stars, String comment, int hoursAgo,
            {String? reply, int? repliedHoursAgo, ReviewReport? report, bool hidden = false, String? hiddenReason}) =>
        FacilityReview(
          id: id,
          facilityId: f.$1,
          facilityName: f.$2,
          userName: user,
          rating: stars,
          comment: comment,
          createdAt: ago(hoursAgo),
          ownerReply: reply,
          repliedAt: repliedHoursAgo == null ? null : ago(repliedHoursAgo),
          report: report,
          isHidden: hidden,
          hiddenReason: hiddenReason,
        );

    return [
      r('rv-01', tt, 'Nguyễn Minh Anh', 2, 'Đèn sân 3 bị chớp, mong sân sửa sớm.', 3),
      r('rv-02', hl, 'Trần Quốc Bảo', 5, 'Cỏ mới, đèn sáng, nhân viên nhiệt tình.', 20),
      r('rv-03', tt, 'Lê Thu Hà', 4, 'Sân đẹp nhưng bãi xe hơi chật vào giờ cao điểm.', 30,
          reply: 'Cảm ơn bạn! Sân đã thuê thêm bãi xe bên cạnh từ tuần này.', repliedHoursAgo: 26),
      r('rv-04', hl, 'Phạm Đức Long', 1, 'Sân như cái chợ, chủ sân lừa đảo!!! Đừng ai đặt.', 50,
          report: ReviewReport(
            reason: ReportReason.falseInfo,
            note: 'Khách này không có lượt check-in nào tại sân trong tuần.',
            createdAt: ago(45),
          )),
      r('rv-05', tt, 'Võ Hoàng Nam', 5, '', 72),
      r('rv-06', hl, 'Đặng Mai Linh', 3, 'Rổ hơi lỏng, còn lại ổn.', 96),
      r('rv-07', tt, 'Bùi Gia Huy', 5, 'Thảm êm, giá hợp lý. Sẽ quay lại.', 120,
          reply: 'Cảm ơn bạn đã ủng hộ sân!', repliedHoursAgo: 118),
      r('rv-08', hl, 'Khách 09xx', 1, 'Mua sân giá rẻ inbox 09xx...', 200,
          report: ReviewReport(reason: ReportReason.spam, createdAt: ago(190), status: ReportStatus.hidden),
          hidden: true,
          hiddenReason: 'Spam quảng cáo'),
      r('rv-09', tt, 'Hồ Thanh Tâm', 4, 'Ổn, nhưng nước uống hơi đắt.', 260,
          report: ReviewReport(reason: ReportReason.falseInfo, createdAt: ago(250), status: ReportStatus.kept)),
    ];
  }
}
