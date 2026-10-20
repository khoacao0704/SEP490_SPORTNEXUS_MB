import '../../models/booking.dart';
import '../../models/time_slot.dart';

/// Lỗi nghiệp vụ đặt sân; [message] sẵn sàng để hiển thị.
class BookingException implements Exception {
  final String message;

  const BookingException(this.message);

  @override
  String toString() => 'BookingException: $message';
}

abstract class BookingRepository {
  /// false: chỉ trả 100% (BE chưa có cọc 1/4) — chọn cọc thì UI báo "đang phát triển".
  bool get supportsDeposit;

  /// false: chưa chia tiền nhóm được — chọn chia tiền thì UI báo "đang phát triển".
  bool get supportsSplitPayment;

  /// Mã QR vé đổi theo chu kỳ này thì UI tải lại mã định kỳ; `null` = mã cố định.
  Duration? get ticketRefreshInterval;

  /// Thanh toán 100% hoặc cọc 1/4 (từng khung) từ ví cho các khung giờ đang giữ.
  /// Mỗi khung giờ thành một lượt đặt riêng (vé QR và hủy riêng), sắp theo giờ bắt đầu.
  /// (Chia tiền nhóm đi qua SplitPaymentRepository, đủ tiền thì BE tự tạo các lượt đặt.)
  Future<List<Booking>> createBooking({
    required SlotHold hold,
    required BookingPaymentType paymentType,
    required String facilityName,
    required String sportLabel,
    required String location,
    required String schedule,
  });

  /// Lần đặt sân người dùng đã đặt hoặc góp tiền: sắp diễn ra trước (gần nhất trước), đã qua sau.
  Future<List<Booking>> getMyBookings();

  /// Người đặt hủy: trước 24 giờ hoàn 100%, trong 24 giờ mất 1/4 tiền sân.
  /// Chia tiền nhóm: phần mất trừ vào phần của người đặt trước, những người góp được hoàn phần còn lại.
  /// [reasonCode] lấy từ [getCancelReasons]; lý do tự nhập đi trong [reason]. Trả về lượt đặt đã hủy
  /// với [Booking.refunded] là số tiền thực được hoàn.
  Future<Booking> cancelBooking(String bookingId, {int? reasonCode, String? reason});

  /// Các lý do hủy chọn sẵn (có một mục "Khác" cho tự nhập).
  Future<List<CancelReason>> getCancelReasons();

  /// Chuỗi vẽ mã QR vé của người dùng hiện tại cho lượt đặt [booking].
  Future<String> getTicketCode(Booking booking);

  // ---------- Chia tiền bằng cách mời bạn (theo tài khoản) ----------

  /// true: chia tiền theo luồng mời bạn bên dưới (thay cho chia mã/link của [SplitPaymentRepository]).
  bool get supportsSplitInvite;

  /// Tìm tài khoản theo số điện thoại để mời góp tiền.
  Future<PlayerLookup> findPlayerByPhone(String phone);

  /// Đặt sân chia tiền: người đặt trả phần của mình ngay, mỗi ca một đơn chờ [inviteeIds] góp
  /// (30 phút, không quá giờ bắt đầu; hết hạn chưa đủ thì tự hủy và hoàn tiền).
  Future<List<Booking>> createSplitBooking({
    required SlotHold hold,
    required List<String> inviteeIds,
    required String facilityName,
    required String sportLabel,
    required String location,
  });

  /// Chi tiết một đơn (kèm danh sách người góp).
  Future<Booking> getBooking(String bookingId);

  /// Người được mời góp phần của mình từ ví.
  Future<Booking> joinSplit(String bookingId);

  /// Người đặt mời thêm bạn (chỉ khi chưa ai góp; phần tiền được chia lại).
  Future<Booking> inviteMore(String bookingId, List<String> inviteeIds);

  /// Người đặt trả nốt phần của những người chưa góp; họ bị bỏ khỏi đơn.
  Future<Booking> payRemaining(String bookingId);
}
