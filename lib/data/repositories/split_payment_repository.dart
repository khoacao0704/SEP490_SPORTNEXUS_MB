import '../../models/split_payment.dart';
import '../../models/time_slot.dart';

/// Lỗi nghiệp vụ chia tiền; [message] sẵn sàng để hiển thị.
class SplitPaymentException implements Exception {
  final String message;

  const SplitPaymentException(this.message);

  @override
  String toString() => 'SplitPaymentException: $message';
}

/// Chia tiền khi đặt sân thường (không áp dụng cho LFG).
abstract class SplitPaymentRepository {
  /// Người đặt chọn chia [parts] phần (2 hoặc 4) và trả phần của mình từ ví ngay.
  /// Khung giờ đang giữ ([hold]) được giữ tiếp 30 phút để nhóm trả nốt.
  Future<SplitPayment> create({
    required SlotHold hold,
    required int parts,
    required String facilityName,
    required String sportLabel,
    required String location,
    required String schedule,
  });

  Future<SplitPayment> getById(String id);

  /// Tra lượt chia theo mã trong link. Ném [SplitPaymentException] nếu không có.
  Future<SplitPayment> findByCode(String code);

  /// Các lượt chia người dùng đã tạo hoặc đã trả, mới nhất trước.
  Future<List<SplitPayment>> getMine();

  /// Người dùng hiện tại (phải có tài khoản, không xét Fair Play) trả một phần còn trống từ ví.
  /// Phần cuối cùng được trả thì đặt sân thành công.
  Future<SplitPayment> payShare(String code);
}

/// Chỉ bản giả lập cài đặt: dùng cho nút "Giả lập bạn bè trả" khi demo.
abstract class SandboxSplitSimulator {
  Future<SplitPayment> simulateFriendPaid(String id);
}
