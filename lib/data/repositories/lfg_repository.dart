import '../../models/facility.dart';
import '../../models/lfg_match.dart';
import '../../models/time_slot.dart';

/// Lỗi nghiệp vụ LFG; [message] sẵn sàng để hiển thị.
class LfgException implements Exception {
  final String message;

  const LfgException(this.message);

  @override
  String toString() => 'LfgException: $message';
}

abstract class LfgRepository {
  /// Kèo còn nhận người theo bộ lọc, giờ bắt đầu sớm nhất trước.
  Future<List<LfgFeedItem>> getFeed(LfgFeedQuery query);

  Future<LfgMatch> getMatch(String matchId);

  /// Kèo người dùng đang/đã tham gia (kể cả đã hủy): sắp diễn ra trước, đã qua sau.
  Future<List<LfgMatch>> getMyMatches();

  /// Flash Claim: giữ 1 chỗ trong 10 phút để thanh toán cọc. Ai bấm trước được trước.
  /// Ném [LfgException] nếu hết chỗ, đã qua T−48h, đã ở trong kèo, hoặc Fair Play dưới 30.
  Future<LfgClaim> claimSlot(String matchId);

  /// Trừ cọc từ ví và đưa người dùng vào kèo (cùng một giao dịch phía BE).
  Future<LfgMatch> confirmClaim(String claimId);

  Future<void> releaseClaim(String claimId);

  /// Tạo kèo từ khung giờ đã giữ chỗ: trừ cọc của host từ ví, đăng kèo lên bảng tin.
  /// Khung giờ phải bắt đầu sau 48 giờ và trong vòng 5 ngày.
  Future<LfgMatch> createMatch({
    required SlotHold hold,
    required Facility facility,
    required LfgFormat format,
    String note = '',
  });

  /// Người tham gia (không phải host) rời kèo: mất cọc. Trước T−48h chỗ mở lại cho người khác.
  /// Trả về số tiền cọc bị mất.
  Future<int> leaveMatch(String matchId);

  /// Host hủy kèo: host mất cọc, những người khác được hoàn 100%.
  Future<void> cancelMatch(String matchId);
}

/// Chỉ bản giả lập cài đặt: dùng cho nút "Giả lập có người vào kèo" khi demo.
abstract class SandboxLfgSimulator {
  Future<LfgMatch> simulatePlayerJoined(String matchId);
}
