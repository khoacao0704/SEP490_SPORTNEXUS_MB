import 'tournament_listing.dart';

String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}

/// Một người / đội tham gia trong màn quản lý của BTC (GET /tournaments/{id}/participants).
class OrganizerParticipant {
  final String participantId;
  final String name;
  final String username;
  final String? teamName;
  final List<String> members;
  final String paymentStatus;
  final bool isCheckedIn;
  final String? avatarUrl;

  const OrganizerParticipant({
    required this.participantId,
    required this.name,
    this.username = '',
    this.teamName,
    this.members = const [],
    this.paymentStatus = '',
    this.isCheckedIn = false,
    this.avatarUrl,
  });

  /// Tên hiển thị (đội thì tên đội).
  String get displayName => teamName ?? name;

  bool get isPaid => paymentStatus.toUpperCase() == 'PAID';

  String get paymentLabel => switch (paymentStatus.toUpperCase()) {
    'PAID' => 'Đã đóng lệ phí',
    'PENDING' || 'UNPAID' => 'Chưa đóng lệ phí',
    'REFUNDED' => 'Đã hoàn lệ phí',
    '' => '',
    _ => paymentStatus,
  };

  factory OrganizerParticipant.fromApi(Map<String, dynamic> j) {
    final team = j['team'] is Map ? j['team'] as Map : const {};
    return OrganizerParticipant(
      participantId: _str(j['participantId'] ?? j['id']) ?? '',
      name: _str(j['fullName'] ?? j['userName'] ?? j['name'] ?? j['playerName']) ?? _str(j['username']) ?? '—',
      username: _str(j['username']) ?? '',
      teamName: _str(j['teamName'] ?? team['name']),
      members: [
        for (final m in (j['teamMembers'] as List? ?? const []).whereType<Map>())
          if (_str(m['fullName'] ?? m['name']) != null) _str(m['fullName'] ?? m['name'])!,
      ],
      paymentStatus: _str(j['paymentStatus']) ?? (j['isPaid'] == true ? 'PAID' : ''),
      isCheckedIn: j['isCheckedIn'] == true || _str(j['checkedInAt']) != null,
      avatarUrl: _str(j['avatarUrl']),
    );
  }
}

/// Lời mời BTC đã gửi (giải nội bộ).
class OrganizerInvitation {
  final String id;
  final String inviteeName;
  final String? teamName;
  final TournamentInvitationStatus status;

  const OrganizerInvitation({required this.id, required this.inviteeName, this.teamName, required this.status});

  String get displayName => teamName == null ? inviteeName : '$teamName ($inviteeName)';

  factory OrganizerInvitation.fromApi(Map<String, dynamic> j) {
    final key = '${j['status'] ?? ''}'.toUpperCase();
    return OrganizerInvitation(
      id: _str(j['id'] ?? j['invitationId']) ?? '',
      inviteeName: _str(j['inviteeName'] ?? j['fullName'] ?? j['phone']) ?? '—',
      teamName: _str(j['teamName']),
      status:
          TournamentInvitationStatus.values.where((s) => s.apiValue == key).firstOrNull ??
          TournamentInvitationStatus.pending,
    );
  }
}

/// Đội tìm được để mời (GET /teams).
class TeamOption {
  final String id;
  final String name;
  final String captainName;
  final int totalMembers;

  const TeamOption({required this.id, required this.name, this.captainName = '', this.totalMembers = 0});

  factory TeamOption.fromApi(Map<String, dynamic> j) => TeamOption(
    id: _str(j['id']) ?? '',
    name: _str(j['name']) ?? '—',
    captainName: _str(j['captainName']) ?? '',
    totalMembers: (j['totalMembers'] as num?)?.toInt() ?? 0,
  );
}

/// Vai trò nhân sự giải.
enum StaffRole {
  referee('REFEREE', 'Trọng tài'),
  scorer('SCORER', 'Ghi điểm'),
  other('OTHER', 'Khác');

  const StaffRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Trọng tài / ghi điểm phải có tài khoản (để điểm danh, nhập tỉ số).
  bool get needsAccount => this != other;

  static StaffRole fromApi(Object? v) {
    final key = '${v ?? ''}'.toUpperCase();
    return values.where((r) => r.apiValue == key).firstOrNull ?? other;
  }
}

/// Một nhân sự của giải.
class TournamentStaffMember {
  final String id;
  final String fullName;
  final String phone;
  final StaffRole role;
  final String? accountId;
  final String note;

  const TournamentStaffMember({
    required this.id,
    required this.fullName,
    this.phone = '',
    this.role = StaffRole.referee,
    this.accountId,
    this.note = '',
  });

  factory TournamentStaffMember.fromApi(Map<String, dynamic> j) => TournamentStaffMember(
    id: _str(j['id'] ?? j['staffId']) ?? '',
    fullName: _str(j['fullName']) ?? '—',
    phone: _str(j['phone']) ?? '',
    role: StaffRole.fromApi(j['role']),
    accountId: _str(j['accountId']),
    note: _str(j['note']) ?? '',
  );
}

/// Thêm / sửa nhân sự (body ghi đè toàn bộ như Web).
class StaffDraft {
  final String fullName;
  final String phone;
  final StaffRole role;
  final String? accountId;
  final String note;

  const StaffDraft({required this.fullName, required this.phone, required this.role, this.accountId, this.note = ''});

  Map<String, dynamic> toJson() => {
    'fullName': fullName.trim(),
    'phone': phone.trim(),
    'role': role.apiValue,
    'accountId': accountId,
    'note': note.trim().isEmpty ? null : note.trim(),
  };
}

/// Tài khoản tìm theo số điện thoại.
class AccountMatch {
  final String id;
  final String fullName;

  const AccountMatch({required this.id, required this.fullName});
}
