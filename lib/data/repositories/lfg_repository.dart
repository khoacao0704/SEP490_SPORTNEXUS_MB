import '../../core/constants/lfg_rules.dart';
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

  /// Rời kèo chưa đủ người: hoàn 100% cọc, chỗ mở lại, kèo vẫn ở lại để ghép tiếp.
  /// Host rời thì quyền host chuyển cho người vào sớm nhất; host là người cuối cùng thì kèo bị hủy.
  /// Kèo đã chốt (đủ người) không rời được — dùng [requestCancel]. Trả về số tiền được hoàn.
  Future<int> leaveMatch(String matchId);

  /// Gửi yêu cầu hủy kèo đã chốt (bất kỳ thành viên nào, trước T−24h). Người gửi tính là đã đồng ý.
  Future<LfgMatch> requestCancel(String matchId);

  /// Trả lời yêu cầu hủy. Một người từ chối là bác yêu cầu; tất cả đồng ý thì hủy kèo,
  /// hoàn 100% cho mọi người và không trừ Fair Play.
  Future<LfgMatch> respondCancel(String matchId, {required bool approve});

  // ---------- Khác biệt giữa bản giả lập và BE thật ----------

  /// false: không lọc bảng tin theo tỉnh/quận (UI ẩn chọn khu vực).
  bool get supportsAreaFilter;

  /// true: host rời kèo thì chuyển quyền host ([leaveMatch]); false: host chỉ hủy kèo ([cancelMatch]).
  bool get hostCanLeave;

  /// true: host trả trước cả tiền sân khi tạo kèo, người vào trả phần của mình cho host (BE);
  /// false: host chỉ cọc phần của mình như mọi người.
  bool get hostPaysCourt;

  /// Số tiền host trả khi tạo kèo.
  int createCost(int courtPrice, LfgFormat format) =>
      hostPaysCourt ? courtPrice : LfgRules.depositPerSlot(courtPrice, format.totalSlots);

  /// Host hủy kèo: mọi người được hoàn 100%, tiền sân của host hoàn theo chính sách đặt sân.
  Future<LfgMatch> cancelMatch(String matchId);

  /// Chấp nhận lời mời vào kèo: trả phần của mình từ ví, nhận vé.
  Future<LfgMatch> acceptInvitation(String matchId);

  /// Từ chối lời mời; chỗ mở lại cho người khác.
  Future<void> declineInvitation(String matchId);

  /// Chuỗi vẽ mã QR vé của [userId] trong kèo [match].
  Future<String> getTicketCode(LfgMatch match, String userId);
}

/// Chỉ bản giả lập cài đặt: các nút giả lập hành động của người chơi khác khi demo.
abstract class SandboxLfgSimulator {
  Future<LfgMatch> simulatePlayerJoined(String matchId);

  /// Các thành viên khác (chưa trả lời) cùng đồng ý, hoặc một người từ chối yêu cầu hủy.
  Future<LfgMatch> simulateOthersRespond(String matchId, {required bool approve});
}
