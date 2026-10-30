/// Chuỗi hiển thị cho quản lý đội.
class TeamStrings {
  TeamStrings._();

  static const String myTeams = 'Đội của tôi';
  static const String invitationsTitle = 'Lời mời vào đội';
  static const String noTeams = 'Bạn chưa ở đội nào';
  static const String noTeamsHint = 'Tạo đội để đăng ký các giải đôi / đội. Thành viên được mời phải nhận lời mới vào đội.';
  static const String createTeam = 'Tạo đội';
  static const String editTeam = 'Sửa thông tin đội';
  static const String teamName = 'Tên đội';
  static const String teamDescription = 'Giới thiệu (không bắt buộc)';
  static const String invitePhonesLabel = 'Mời thành viên bằng SĐT (không bắt buộc)';
  static const String invitePhonesHint = 'Mỗi số một dòng hoặc cách nhau bởi dấu phẩy';
  static const String inviteNote = 'Chỉ mời được người đã có tài khoản SportNexus. Lời mời hết hạn sau 7 ngày.';
  static const String save = 'LƯU';
  static const String create = 'TẠO ĐỘI';
  static String memberCount(int n) => '$n thành viên';
  static const String captain = 'Đội trưởng';
  static const String you = '(bạn)';
  static const String locked = 'Đội bị khoá';
  static String lockedReason(String reason) => 'Đội bị khoá: $reason';
  static const String members = 'Thành viên';
  static const String pendingInvitations = 'Lời mời đang chờ';
  static String invitedBy(String name) => 'Mời bởi $name';
  static String expiresOn(String date) => 'Hết hạn $date';
  static const String accept = 'Nhận lời';
  static const String decline = 'Từ chối';
  static const String revoke = 'Thu hồi';
  static const String accepted = 'Đã vào đội';
  static const String declined = 'Đã từ chối lời mời';
  static const String revoked = 'Đã thu hồi lời mời';

  // Mời
  static const String invite = 'Mời thành viên';
  static const String invitePhone = 'Số điện thoại';
  static const String inviteMessage = 'Lời nhắn (không bắt buộc)';
  static const String send = 'Gửi lời mời';
  static const String invited = 'Đã gửi lời mời';

  // Thao tác
  static const String changeLogo = 'Đổi logo';
  static const String logoUpdated = 'Đã cập nhật logo';
  static const String makeCaptain = 'Chuyển đội trưởng';
  static const String remove = 'Xoá khỏi đội';
  static const String leave = 'Rời đội';
  static const String disband = 'Giải tán đội';
  static const String cancel = 'Hủy';
  static const String confirm = 'Xác nhận';
  static String confirmMakeCaptain(String name) => 'Chuyển quyền đội trưởng cho $name? Bạn sẽ trở thành thành viên.';
  static String confirmRemove(String name) => 'Xoá $name khỏi đội?';
  static const String confirmLeave = 'Rời khỏi đội này?';
  static const String confirmDisband = 'Giải tán đội? Lời mời đang chờ sẽ bị hủy, lịch sử giải đấu vẫn được giữ.';
  static const String captainTransferred = 'Đã chuyển quyền đội trưởng';
  static const String memberRemoved = 'Đã xoá thành viên';
  static const String left = 'Đã rời đội';
  static const String disbanded = 'Đã giải tán đội';
  static const String captainLeaveHint = 'Đội trưởng muốn rời đội phải chuyển quyền cho thành viên khác hoặc giải tán đội.';
  static const String saved = 'Đã lưu';

  // Lỗi (bản giả lập; BE trả message riêng)
  static const String loadError = 'Không tải được dữ liệu. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
  static const String nameRequired = 'Vui lòng nhập tên đội.';
  static String phoneNotFound(String phone) => 'Không tìm thấy tài khoản với số điện thoại $phone';
  static const String alreadyMember = 'Người này đã ở trong đội.';
  static const String teamFull = 'Đội đã đủ 20 thành viên.';
  static const String notFound = 'Không tìm thấy đội.';
  static const String notMember = 'Người này không phải thành viên của đội.';
  static const String captainOnly = 'Chỉ đội trưởng mới làm được việc này.';
  static const String captainCannotLeave = 'Đội trưởng không thể rời đội. Hãy chuyển quyền đội trưởng trước.';
  static const String inTournament = 'Đội đang đăng ký giải chưa kết thúc. Hãy rút đăng ký giải trước.';
  static const String invitationNotFound = 'Lời mời không còn hiệu lực.';
}
