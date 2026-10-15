import '../../models/tournament.dart';

/// Chủ sân tổ chức giải trên app: tạo / sửa / hủy, bốc thăm, xếp lịch, nhập kết quả.
/// Lỗi nghiệp vụ ném TournamentException (cùng loại lỗi với phía người chơi).
abstract class OrganizerTournamentRepository {
  /// Giải do Chủ sân đang đăng nhập tổ chức: chưa kết thúc trước (gần nhất trước), đã kết thúc / hủy sau.
  Future<List<Tournament>> getOrganizedTournaments();

  /// Tạo giải tại cơ sở đã duyệt, mở đăng ký ngay (không cần Admin duyệt).
  /// Tự tạm đóng loại sân thi đấu trong các ngày thi đấu; ngày đó đã có lượt đặt thì không tạo được.
  Future<Tournament> createTournament(TournamentDraft draft);

  /// Chưa ai đăng ký: sửa được hết. Đã có đơn: chỉ sửa mô tả, điều lệ, giải thưởng.
  Future<Tournament> updateTournament(String tournamentId, TournamentDraft draft);

  /// Hủy giải (chưa kết thúc): hoàn 100% lệ phí cho mọi đơn, mở lại sân.
  Future<Tournament> cancelTournament(String tournamentId);

  /// Bốc thăm ngẫu nhiên sau hạn đăng ký, cần ít nhất 4 đơn. Thiếu đơn thì có trận miễn thi đấu.
  Future<Tournament> drawBracket(String tournamentId);

  /// Xếp giờ / sân cho một trận.
  Future<Tournament> scheduleMatch(String tournamentId, String matchId, {required DateTime at, required String court});

  /// Nhập tỉ số và người thắng; người thắng tự vào vòng sau.
  /// Nhập xong trận chung kết: giải kết thúc, lệ phí giải ngân về ví Chủ sân.
  Future<Tournament> recordResult(String tournamentId, String matchId, {required String winnerId, required String score});
}
