/// Đội của người chơi (dùng cho giải đôi / đội cố định). Đội không gắn với môn nào.
class Team {
  static const int maxMembers = 20;

  final String id;
  final String name;
  final String description;
  final String? logoUrl;

  /// Đội trưởng (người tạo đội hoặc người được chuyển quyền).
  final String captainId;
  final String captainName;
  final DateTime? createdAt;

  /// Bị Admin khoá: không đăng ký giải, không đổi logo được.
  final bool isLocked;
  final String? lockedReason;
  final List<TeamMember> members;

  const Team({
    required this.id,
    required this.name,
    this.description = '',
    this.logoUrl,
    required this.captainId,
    this.captainName = '',
    this.createdAt,
    this.isLocked = false,
    this.lockedReason,
    this.members = const [],
  });

  int get memberCount => members.length;

  bool isCaptain(String? userId) => userId != null && userId == captainId;
}

class TeamMember {
  final String accountId;
  final String fullName;

  /// Chỉ thấy khi mình ở trong đội.
  final String? phone;
  final String? avatarUrl;
  final DateTime? joinedAt;

  const TeamMember({required this.accountId, required this.fullName, this.phone, this.avatarUrl, this.joinedAt});
}

enum InvitationStatus {
  pending('PENDING', 'Đang chờ'),
  accepted('ACCEPTED', 'Đã nhận lời'),
  declined('DECLINED', 'Đã từ chối'),
  cancelled('CANCELLED', 'Đã thu hồi'),
  expired('EXPIRED', 'Hết hạn');

  const InvitationStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static InvitationStatus fromApi(String? value) =>
      values.where((s) => s.apiValue == value?.toUpperCase()).firstOrNull ?? InvitationStatus.pending;
}

/// Lời mời vào đội (hết hạn sau 7 ngày).
class TeamInvitation {
  final String id;
  final String teamId;
  final String teamName;
  final String? teamLogoUrl;
  final String inviteeId;
  final String inviteeName;
  final String? inviteeAvatarUrl;
  final String invitedByName;
  final String message;
  final InvitationStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const TeamInvitation({
    required this.id,
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl,
    this.inviteeId = '',
    this.inviteeName = '',
    this.inviteeAvatarUrl,
    this.invitedByName = '',
    this.message = '',
    required this.status,
    this.createdAt,
    this.expiresAt,
  });
}
