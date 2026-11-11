import '../../models/sport.dart';
import '../../models/team.dart';
import '../api/api_error_codes.dart';

/// Lỗi quản lý đội; [message] sẵn sàng để hiển thị.
class TeamException implements Exception, CodedError {
  @override
  final String message;

  /// Mã lỗi của BE (xem [ApiErrorCodes]); lỗi của mock không có.
  @override
  final String? code;

  @override
  final Map<String, dynamic>? detail;

  const TeamException(this.message, {this.code, this.detail});

  /// Giữ nguyên câu và mã lỗi của BE.
  TeamException.fromApi(CodedError e) : this(e.message, code: e.code, detail: e.detail);

  @override
  String toString() => 'TeamException: $message';
}

/// Đội của người chơi. Thêm người vào đội luôn qua lời mời (người được mời phải nhận lời).
abstract class TeamRepository {
  /// Đội mình là đội trưởng hoặc thành viên.
  Future<List<Team>> getMyTeams();

  Future<Team> getTeam(String teamId);

  /// Tạo đội của môn [sport] và gửi lời mời tới các SĐT (SĐT không có tài khoản bị bỏ qua).
  /// Người tạo phải có Elo môn đó, không thì lỗi RATING_REQUIRED.
  Future<Team> createTeam({
    required String name,
    required Sport sport,
    String description = '',
    List<String> invitePhones = const [],
  });

  /// Sửa tên / giới thiệu; [sport] chỉ gửi khi đội chưa khai môn (đội cũ).
  Future<Team> updateTeam(String teamId, {required String name, String description = '', Sport? sport});

  Future<Team> uploadLogo(String teamId, String filePath);

  /// Mời một người bằng SĐT (phải có tài khoản).
  Future<void> invite(String teamId, String phone, {String message = ''});

  /// Lời mời đội đã gửi (đội trưởng xem / thu hồi).
  Future<List<TeamInvitation>> getTeamInvitations(String teamId);

  Future<void> revokeInvitation(String invitationId);

  /// Lời mời gửi tới mình đang chờ trả lời.
  Future<List<TeamInvitation>> getMyInvitations();

  Future<void> acceptInvitation(String invitationId);

  Future<void> declineInvitation(String invitationId);

  Future<void> removeMember(String teamId, String accountId);

  Future<void> transferCaptain(String teamId, String accountId);

  /// Thành viên rời đội (đội trưởng phải chuyển quyền trước).
  Future<void> leave(String teamId);

  /// Giải tán đội (chỉ đội trưởng).
  Future<void> disband(String teamId);
}
