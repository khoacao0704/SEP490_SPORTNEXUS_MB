/// Chuỗi hiển thị cho Elo, bảng xếp hạng và khảo sát trình độ.
class RatingStrings {
  RatingStrings._();

  // Elo của tôi
  static const String myEloTitle = 'Elo & Xếp Hạng';
  static const String profileMenu = 'Elo & xếp hạng';
  static const String loadError = 'Không tải được Elo. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
  static const String personal = 'Elo cá nhân';
  static const String teams = 'Elo của đội';
  static const String noRating =
      'Bạn chưa có Elo. Làm khảo sát trình độ của môn bạn chơi để có Elo – cần có Elo mới tạo đội, '
      'vào đội và đăng ký giải được.';
  static const String noTeamRating = 'Đội của bạn chưa có Elo (đội trưởng cần khai môn cho đội).';
  static String ratedMatches(int n) => '$n trận tính Elo';
  static const String provisional = 'Tạm tính';
  static const String provisionalNote = 'Elo tạm tính thay đổi nhanh hơn trong 10 trận đầu.';
  static const String takeAssessment = 'Làm khảo sát trình độ';
  static const String retakeAssessment = 'Xem / làm lại khảo sát';
  static const String leaderboard = 'Bảng xếp hạng';
  static const String sportsWithoutRating = 'Môn chưa có Elo';
  static String sportUnavailable(String sport) => 'Môn $sport chưa có trên hệ thống.';
  static const String eloExplain =
      'Elo khởi đầu từ khảo sát trình độ, sau đó chỉ thay đổi theo kết quả các trận giải '
      '(thắng đối thủ mạnh hơn được cộng nhiều hơn).';

  // Bảng xếp hạng
  static const String leaderboardTitle = 'Bảng Xếp Hạng';
  static const String emptyLeaderboard = 'Chưa có ai trên bảng xếp hạng môn này.';
  static const String loadMore = 'Đang tải thêm…';
  static String eloValue(int rating) => '$rating Elo';
  static const String you = '(bạn)';

  // Khảo sát trình độ
  static String assessmentTitle(String sport) => 'Khảo Sát Trình Độ • $sport';
  static const String assessmentIntro =
      'Trả lời trung thực để có Elo khởi đầu chính xác. Câu trả lời mâu thuẫn sẽ bị đánh dấu; '
      'khai sai trình độ có thể bị khoá khảo sát môn này.';
  static const String scaleHint = 'Tự chấm: 1 = yếu, 5 = rất tốt';
  static const String evidenceTitle = 'Bằng chứng thành tích (không bắt buộc)';
  static const String evidenceHint =
      'Elo tối đa 1400 nếu chưa có bằng chứng. Tải ảnh hoặc dán link bài viết về thành tích (tối đa 5) '
      'để Admin duyệt cho Elo cao hơn.';
  static const String evidenceLabel = 'Link bằng chứng';
  static const String addEvidence = 'Thêm link';
  static const String addPhoto = 'Tải ảnh lên';
  static const String uploading = 'Đang tải ảnh…';
  static const String uploadFailed = 'Tải ảnh lên thất bại, vui lòng thử lại sau.';
  static const String imageTooLarge = 'Ảnh không được vượt quá 5MB.';
  static const String pickPhotoError = 'Không mở được thư viện ảnh. Hãy kiểm tra quyền truy cập của ứng dụng.';
  static String evidenceLimit(int max) => 'Tối đa $max bằng chứng';
  static const String invalidUrl = 'Link phải bắt đầu bằng http:// hoặc https://';
  static const int maxEvidence = 5;
  static const int maxUrlLength = 500;
  static const String submit = 'NỘP BÀI';
  static String unanswered(int n) => 'Còn $n câu chưa trả lời';
  static const String blockedTitle = 'Chưa làm khảo sát được';
  static const String lastResult = 'Kết quả gần nhất';
  static const String mockPendingBlocked = 'Bằng chứng thành tích đang chờ Admin duyệt.';

  // Kết quả
  static const String resultTitle = 'Kết quả khảo sát';
  static String score(int s) => 'Điểm: $s/100';
  static String assigned(int elo) => 'Elo khởi đầu: $elo';
  static String computed(int elo) => 'Elo tính được: $elo (giữ ở 1400 tới khi bằng chứng được duyệt)';
  static String level(String label) => 'Trình độ: $label';
  static const String flagsTitle = 'Câu trả lời cần xem lại';
  static String reviewNote(String note) => 'Ghi chú của Admin: $note';
  static const String done = 'Xong';

  // Thiếu Elo khi tạo đội / vào đội / đăng ký giải
  static const String ratingRequiredTitle = 'Cần có Elo môn này';
  static const String ratingRequiredMine =
      'Bạn chưa có Elo môn này. Làm khảo sát trình độ (khoảng 2 phút) rồi thử lại.';
  static String ratingRequiredOthers(int n) =>
      'Còn $n thành viên chưa có Elo môn này. Nhắc họ làm khảo sát trình độ trong mục Hồ sơ → Elo & xếp hạng.';
  static const String later = 'Để sau';
  static const String ok = 'Đã hiểu';
}
