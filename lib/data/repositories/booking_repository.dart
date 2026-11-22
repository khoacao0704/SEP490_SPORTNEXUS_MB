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
  /// false: chưa chia Điểm nhóm được — chọn chia Điểm thì UI báo "đang phát triển".
  bool get supportsSplitPayment;

  /// Mã QR vé đổi theo chu kỳ này thì UI tải lại mã định kỳ; `null` = mã cố định.
  Duration? get ticketRefreshInterval;

  /// Thanh toán 100% từ ví cho các khung giờ đang giữ (đặt sân thường không có cọc).
  /// Mỗi khung giờ thành một lượt đặt riêng (vé QR và hủy riêng), sắp theo giờ bắt đầu.
  /// (Chia Điểm nhóm đi qua SplitPaymentRepository, đủ Điểm thì BE tự tạo các lượt đặt.)
  ///
  /// [recurring]: đặt gói cố định hằng tuần — [hold] phải gồm đủ khung giờ của mọi buổi (ít nhất 4 tuần liên tiếp,
  /// cùng sân con, cùng giờ); các lượt đặt trả về có chung [Booking.recurringGroupId] và giá đã giảm.
  /// [discountPercent]: % giảm của cơ sở để bản giả lập tính giá (BE thật tự tính, không dùng tham số này).
  Future<List<Booking>> createBooking({
    required SlotHold hold,
    required BookingPaymentType paymentType,
    required String facilityName,
    required String sportLabel,
    required String location,
    required String schedule,
    bool recurring = false,
    int discountPercent = 0,
  });

  /// Lần đặt sân người dùng đã đặt hoặc góp Điểm: sắp diễn ra trước (gần nhất trước), đã qua sau.
  Future<List<Booking>> getMyBookings();

  /// Người đặt hủy: trước 24 giờ hoàn 100% (chia Điểm nhóm: mỗi người được hoàn phần đã góp),
  /// trong 24 giờ không hoàn cho ai.
  /// Buổi thuộc gói cố định: hủy CẢ gói (các buổi chưa hủy), chỉ khi còn ít nhất 48 giờ trước buổi đầu còn lại,
  /// hoàn 100%; quá mốc thì báo lỗi. Trả về buổi [bookingId] đã hủy.
  /// [reasonCode] lấy từ [getCancelReasons]; lý do tự nhập đi trong [reason]. Trả về lượt đặt đã hủy
  /// với [Booking.refunded] là số tiền thực được hoàn.
  Future<Booking> cancelBooking(String bookingId, {int? reasonCode, String? reason});

  /// Các lý do hủy chọn sẵn (có một mục "Khác" cho tự nhập).
  Future<List<CancelReason>> getCancelReasons();

  /// Chuỗi vẽ mã QR vé của người dùng hiện tại cho lượt đặt [booking].
  Future<String> getTicketCode(Booking booking);

  // ---------- Chia Điểm bằng cách mời bạn (theo tài khoản) ----------

  /// true: chia Điểm theo luồng mời bạn bên dưới (thay cho chia mã/link của [SplitPaymentRepository]).
  bool get supportsSplitInvite;

  /// Tìm tài khoản theo số điện thoại để mời góp Điểm.
  Future<PlayerLookup> findPlayerByPhone(String phone);

  /// Đặt sân chia Điểm: người đặt trả phần của mình ngay, mỗi ca một đơn chờ [inviteeIds] góp
  /// (30 phút, không quá giờ bắt đầu; hết hạn chưa đủ thì tự hủy và hoàn Điểm).
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

  /// Người đặt mời thêm bạn (chỉ khi chưa ai góp; phần Điểm được chia lại).
  Future<Booking> inviteMore(String bookingId, List<String> inviteeIds);

  /// Người đặt trả nốt phần của những người chưa góp; họ bị bỏ khỏi đơn.
  Future<Booking> payRemaining(String bookingId);
}
