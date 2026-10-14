import '../../models/tournament.dart';

/// Lỗi nghiệp vụ giải đấu; [message] sẵn sàng để hiển thị.
class TournamentException implements Exception {
  final String message;

  const TournamentException(this.message);

  @override
  String toString() => 'TournamentException: $message';
}

/// Giải đấu do chủ sân / Admin tạo trên Web; app chỉ xem, đăng ký và theo dõi.
abstract class TournamentRepository {
  /// Giải theo bộ lọc: đang mở đăng ký trước, rồi sắp diễn ra / đang diễn ra, đã kết thúc sau cùng.
  Future<List<Tournament>> getTournaments(TournamentQuery query);

  Future<Tournament> getTournament(String tournamentId);

  /// Giải người dùng đã đăng ký (là đội trưởng hoặc thành viên), kể cả đã kết thúc / bị hủy.
  Future<List<Tournament>> getMyTournaments();

  /// Tra cứu người chơi theo email hoặc số điện thoại để thêm vào đội.
  /// Ném [TournamentException] nếu không có tài khoản người chơi tương ứng.
  Future<TournamentMember> findPlayer(String emailOrPhone);

  /// Đăng ký và trừ lệ phí từ ví (cùng một giao dịch phía BE). Người gọi là đội trưởng.
  /// Ném [TournamentException] nếu hết suất, quá hạn, sai số thành viên, có thành viên đã đăng ký, hoặc ví không đủ.
  Future<Tournament> register(TournamentRegistration registration);

  /// Đội trưởng rút khỏi giải. Trước hạn đăng ký: hoàn 100% lệ phí, suất mở lại.
  /// Sau hạn (tới trước khai mạc): không hoàn, đội vẫn trong sơ đồ và bị xử thua.
  /// Trả về số tiền được hoàn.
  Future<int> withdraw(String tournamentId);
}

/// Chỉ bản giả lập cài đặt: dùng cho nút "Giả lập BTC hủy giải" khi demo.
abstract class SandboxTournamentSimulator {
  Future<Tournament> simulateOrganizerCancelled(String tournamentId);
}
