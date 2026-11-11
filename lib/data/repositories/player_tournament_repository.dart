import '../../models/tournament_listing.dart';

export 'tournament_repository.dart' show TournamentException;

/// Giải đấu phía người chơi: tìm giải, xem bảng con / người tham gia / sơ đồ, đăng ký và rút.
/// Lỗi nghiệp vụ ném [TournamentException].
abstract class PlayerTournamentRepository {
  static const int pageSize = 10;

  Future<TournamentPage> search(TournamentSearchQuery query, {int page = 1});

  /// Giải mẹ kèm các bảng con.
  Future<TournamentDetails> getDetails(String tournamentId);

  /// Người đã đăng ký mọi bảng con của giải (người đã rút không có).
  Future<List<TournamentParticipant>> getParticipants(String tournamentId);

  /// Các trận của một bảng con; chưa bốc thăm thì rỗng.
  Future<List<BracketMatch>> getBracket(String divisionId);

  Future<List<TournamentRegistrationItem>> getMyRegistrations();

  /// Lịch thi đấu của tôi (cá nhân và đội), sớm nhất trước.
  Future<List<MyTournamentMatch>> getMyMatches();

  /// Đăng ký một bảng con; lệ phí chuyển sang tạm giữ trong ví người gọi.
  /// [teamId] chỉ dùng cho bảng đội / đôi cố định.
  Future<void> join(String divisionId, {String? teamId});

  /// Rút đăng ký (cả đội với bảng đội). Trước hạn đăng ký hoàn 100%, sau hạn không hoàn.
  Future<void> withdraw(String divisionId);

  Future<TournamentTicket> getTicket(String divisionId);

  /// Người thi đấu của một trận (cả hai bên, trừ mình) để nhận xét trình độ; đấu đội thì là từng thành viên.
  Future<List<MatchPlayer>> getMatchPlayers(String matchId);

  /// Bảng xếp hạng vòng bảng của một bảng con; giải không có vòng bảng thì rỗng.
  Future<List<StandingGroup>> getStandings(String divisionId);

  /// Lời mời tham gia giải nội bộ gửi cho mình (hoặc đội mình làm đội trưởng); [pendingOnly] chỉ lời mời đang chờ.
  Future<List<TournamentInvitation>> getMyInvitations({bool pendingOnly = true});

  /// Nhận lời = đăng ký thật (trừ lệ phí từ ví người nhận lời); từ chối thì thôi.
  Future<void> respondInvitation(String invitationId, {required bool accept});
}
