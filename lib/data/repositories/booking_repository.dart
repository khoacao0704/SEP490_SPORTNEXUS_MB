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
  Future<Booking> cancelBooking(String bookingId);
}
