import '../../models/owner_complaint.dart';

/// Khiếu nại mẫu của khách tại hai cơ sở đã duyệt của Chủ sân demo. Kèm id cơ sở để lọc.
class MockOwnerComplaintData {
  MockOwnerComplaintData._();

  static List<(String, OwnerComplaint)> seed(DateTime now) {
    DateTime ago(int hours) => now.subtract(Duration(hours: hours));
    const tt = ('f-hcm-thientrieu', 'Sân Cầu Lông Thiên Triều');
    const hl = ('f-hcm-hoalu', 'Sân Bóng Hoa Lư');

    (String, OwnerComplaint) c(
      String id,
      (String, String) f,
      String court,
      ComplaintStatus status,
      String name,
      String reason,
      String description,
      int hoursAgo, {
      int amount = 160000,
      int? requested,
      String? response,
      String? adminNote,
      int? refundedPct,
    }) =>
        (
          f.$1,
          OwnerComplaint(
            id: id,
            status: status,
            reporterName: name,
            reporterPhone: '09091234${id.substring(id.length - 2)}',
            facilityName: f.$2,
            courtName: court,
            reason: reason,
            description: description,
            evidenceImageUrls: const ['https://picsum.photos/seed/snx-report/400/300'],
            requestedRefundPercentage: requested,
            bookingStartTime: ago(hoursAgo + 6),
            bookingTotalAmount: amount,
            bookingStatus: 'COMPLETED',
            createdAt: ago(hoursAgo),
            ownerResponse: response,
            ownerRespondedAt: response == null ? null : ago(hoursAgo - 2),
            adminNote: adminNote,
            resolvedByAdminName: adminNote == null ? null : 'Quản trị viên',
            resolvedAt: adminNote == null ? null : ago(hoursAgo - 10),
            refundedAmount: refundedPct == null ? null : amount * refundedPct ~/ 100,
            appliedRefundPercentage: refundedPct,
          ),
        );

    return [
      c('cp-01', tt, 'Sân 3', ComplaintStatus.pending, 'Nguyễn Minh Anh', 'Cơ sở vật chất hư hỏng',
          'Đèn sân 3 chớp liên tục, chơi được 30 phút thì phải dừng.', 4,
          requested: 50),
      c('cp-02', hl, 'Sân 7 người A', ComplaintStatus.pending, 'Trần Quốc Bảo', 'Sân không đúng mô tả',
          'Mặt cỏ bị rách nhiều chỗ, không giống ảnh.', 28,
          amount: 450000, requested: 100),
      c('cp-03', tt, 'Sân 1', ComplaintStatus.ownerResponded, 'Lê Thu Hà', 'Bị hủy sát giờ',
          'Đến nơi thì sân đang có người khác chơi.', 60,
          requested: 100, response: 'Do nhân viên nhập nhầm ca, sân đã liên hệ xin lỗi khách.'),
      c('cp-04', hl, 'Sân 5 người B', ComplaintStatus.resolvedRefunded, 'Phạm Đức Long', 'Cơ sở vật chất hư hỏng',
          'Lưới khung thành bị thủng.', 130,
          amount: 300000, response: 'Đồng ý hoàn tiền, sân đã thay lưới.', adminNote: 'Chủ sân đã hoàn tiền', refundedPct: 50),
      c('cp-05', tt, 'Sân 2', ComplaintStatus.resolvedNoRefund, 'Võ Hoàng Nam', 'Thái độ nhân viên',
          'Nhân viên nói chuyện khó chịu.', 220,
          response: 'Camera cho thấy nhân viên chỉ nhắc khách giữ trật tự.', adminNote: 'Không đủ căn cứ hoàn tiền'),
    ];
  }
}
