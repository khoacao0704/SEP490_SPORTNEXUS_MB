import '../../models/match_scoring.dart';
import '../../models/organized_tournament.dart';
import '../../models/owner_court.dart';
import '../../models/tournament_listing.dart';
import '../../models/tournament_management.dart';

/// Tổ chức giải (giải 1 tầng, luồng 26/11): người chơi làm Ban tổ chức, sau này chủ sân dùng chung.
/// Lỗi nghiệp vụ ném TournamentException với câu của BE.
abstract class HostTournamentRepository {
  /// Giải tôi tổ chức. [facilityScope] = giải người khác tổ chức tại cơ sở của tôi (chủ sân).
  Future<List<OrganizedTournament>> getMine({bool facilityScope = false});

  Future<OrganizedTournament> getDetail(String tournamentId);

  /// Gửi giải; mọi giải chờ Admin duyệt. Trả về trạng thái duyệt BE báo.
  Future<ApprovalStatus> create(NewTournament draft);

  /// Sửa tên / ngày / ảnh / giới thiệu; lệ phí chỉ khi còn mở và chưa ai đăng ký.
  Future<void> updateInfo(String tournamentId, TournamentInfoUpdate update);

  /// BTC hủy (tới 24 giờ trước hạn đăng ký); hoàn lệ phí cho người đã đăng ký.
  Future<void> cancel(String tournamentId, String reason);

  /// Xóa vĩnh viễn (đã hủy hoặc chưa ai đăng ký).
  Future<void> delete(String tournamentId);

  /// Tải file PDF gửi Admin duyệt, trả về link.
  Future<String> uploadDocument(String filePath);

  /// Tải ảnh bìa giải, trả về link.
  Future<String> uploadImage(String filePath);

  /// Cơ sở đã duyệt để chọn nơi tổ chức.
  Future<List<FacilityOption>> getFacilities();

  /// Bộ môn (có id để gửi BE).
  Future<List<SportCategory>> getSports();

  // ---------------- Quản lý (đợt 3) ----------------

  Future<List<OrganizerParticipant>> getParticipants(String tournamentId);

  /// Xóa khỏi giải (chỉ khi giải còn mở đăng ký).
  Future<void> removeParticipant(String tournamentId, String participantId);

  /// BTC điểm danh tay; người chưa đóng lệ phí thì BE chặn.
  Future<void> checkIn(String tournamentId, String participantId);

  /// Lời mời đã gửi (giải nội bộ).
  Future<List<OrganizerInvitation>> getInvitations(String tournamentId);

  /// Mời VĐV theo số điện thoại (giải cá nhân) hoặc mời đội theo [teamId] (giải đội, đội trưởng nhận).
  Future<void> invite(String tournamentId, {String? phone, String? teamId});

  Future<void> cancelInvitation(String invitationId);

  /// Tìm đội theo tên đội / tên đội trưởng, cùng môn, bỏ đội bị khóa.
  Future<List<TeamOption>> searchTeams(String keyword, {String? categoryId});

  /// Quá hạn mà thiếu người: [proceed] = vẫn thi đấu (CONTINUE), false = hủy giải (CANCEL, hoàn 100%).
  Future<void> decideRegistration(String tournamentId, {required bool proceed, String reason = ''});

  Future<List<TournamentStaffMember>> getStaff(String tournamentId);
  Future<void> addStaff(String tournamentId, StaffDraft draft);
  Future<void> updateStaff(String tournamentId, String staffId, StaffDraft draft);
  Future<void> removeStaff(String tournamentId, String staffId);

  /// Tìm tài khoản theo số điện thoại (gắn trọng tài / người ghi điểm). null = không có.
  Future<AccountMatch?> lookupAccount(String phone);

  /// Giải Đôi bốc thăm: BTC bốc thăm ghép cặp.
  Future<void> randomPairing(String tournamentId);

  /// Chốt danh sách & sinh sơ đồ theo thể thức đã chốt; giải chuyển sang Đang thi đấu.
  Future<void> generateBracket(String tournamentId, BracketFormat? format);

  /// Các trận của sơ đồ (mảng phẳng, theo thứ tự).
  Future<List<BracketMatch>> getBracket(String tournamentId);

  // ---------------- Thi đấu (đợt 4) ----------------

  /// Chi tiết trận (có id hai bên).
  Future<MatchDetail> getMatch(String matchId);

  /// Nhập / sửa tỉ số; body từ TournamentRules.buildScorePayload.
  Future<void> updateScore(String matchId, Map<String, dynamic> payload);

  /// Sân đang giữ + trận đã xếp sân của giải.
  Future<CourtSchedule> getCourtSchedule(String tournamentId);

  /// Tự xếp các trận vào ca đã giữ + đề xuất trọng tài.
  Future<void> autoSchedule(String tournamentId);

  /// Ca xếp được trong ngày: ca đã giữ cho giải này hoặc ca còn trống, chưa qua.
  Future<List<AssignableSlot>> getAssignableSlots(String facilityId, String tournamentId, DateTime date);

  /// Xếp trận vào một ca sân.
  Future<void> assignCourt(String matchId, String courtSlotId);

  /// Phân trọng tài cho trận (rỗng = bỏ).
  Future<void> assignOfficials(String matchId, List<String> staffIds);

  /// Khiếu nại kết quả các trận của giải; [openOnly] = chỉ đang mở.
  Future<List<MatchComplaintItem>> getMatchComplaints(String tournamentId, {bool openOnly = true});

  /// Giữ kết quả (REJECT) hoặc chấp nhận (ACCEPT); [note] bắt buộc, gửi người khiếu nại.
  Future<void> decideComplaint(String complaintId, {required bool accept, required String note});

  /// Sửa tỉ số và đóng khiếu nại trong một bước (UPDATE_SCORE).
  Future<void> resolveComplaintWithScore(String complaintId, Map<String, dynamic> score, String note);

  // ---------------- Trọng tài & chủ sân (đợt 5) ----------------

  /// Trận tôi là trọng tài / người nhập điểm (giải đã sinh sơ đồ, chưa kết thúc).
  Future<List<StaffMatch>> getMyStaffMatches();

  /// Chủ sân giữ ca cho giải: ca đã có khách thì bỏ qua và trả về trong conflicts.
  Future<CourtBlockResult> blockCourts(String tournamentId, CourtBlockRequest request);

  /// Chủ sân trả ca đang giữ cho giải.
  Future<CourtBlockResult> releaseCourts(String tournamentId, CourtBlockRequest request);
}
