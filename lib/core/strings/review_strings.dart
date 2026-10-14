/// Chuỗi hiển thị cho đánh giá sau trận và Fair Play.
class ReviewStrings {
  ReviewStrings._();

  // Danh sách chờ đánh giá
  static const String pendingTitle = 'Chờ Đánh Giá';
  static String pendingCount(int n) => 'Chờ đánh giá ($n)';
  static String bannerMessage(int n) => 'Bạn có $n buổi chơi chờ đánh giá';
  static const String bannerAction = 'Đánh giá';
  static const String noPending = 'Không có buổi chơi nào chờ đánh giá';
  static const String noPendingHint = 'Sau khi chủ sân check-out, bạn có 24 giờ để đánh giá.';
  static String timeLeft(String t) => 'Còn $t để đánh giá';
  static String hoursMinutes(int h, int m) => h > 0 ? '$h giờ $m phút' : '$m phút';
  static const String lfgMatch = 'Trận ghép LFG';
  static const String booking = 'Đặt sân';
  static String playerCount(int n) => '$n người chơi cùng';

  // Màn đánh giá
  static const String reviewTitle = 'Đánh Giá Buổi Chơi';
  static const String facilitySection = 'Đánh giá sân';
  static const String playersSection = 'Đánh giá người chơi cùng';
  static const String anonymousNote = 'Đánh giá được ẩn danh. Người chơi chỉ thấy điểm tổng, không biết ai đã chấm.';
  static const String commentHint = 'Nhận xét thêm (không bắt buộc)';
  static const String host = 'Chủ kèo';
  static const String skipped = 'Chưa chấm (sẽ bỏ qua)';
  static const String submit = 'GỬI ĐÁNH GIÁ';
  static const String confirmTitle = 'Gửi đánh giá?';
  static const String confirmMessage = 'Đánh giá đã gửi sẽ không thể sửa.';
  static String confirmSkipped(int n) => '$n người chơi chưa được chấm sẽ bị bỏ qua.';
  static const String send = 'Gửi';
  static const String back = 'Quay lại';
  static const String submitted = 'Cảm ơn bạn đã đánh giá!';
  static const List<String> starLabels = ['Rất tệ', 'Tệ', 'Bình thường', 'Tốt', 'Rất tốt'];

  // Fair Play
  static const String fairPlay = 'Fair Play';
  static const String fairPlayTitle = 'Điểm Fair Play';
  static String scoreLabel(int score) => 'Fair Play: $score';
  static const String eligible = 'Đủ điều kiện ghép LFG';
  static String restricted(int min) => 'Tạm khóa ghép LFG (cần tối thiểu $min điểm)';
  static String recovering(int cap) => 'Điểm đang tự hồi phục dần theo thời gian (tối đa đến $cap).';
  static const String howItWorks = 'Cách tính điểm';
  static const List<String> rules = [
    'Mỗi tài khoản bắt đầu với 100 điểm (tối đa 100).',
    'Vắng mặt không check-in hoặc đến trễ quá 15 phút: −10 điểm.',
    'Sau mỗi trận LFG, người chơi cùng trận chấm sao cho nhau. Theo số sao trung bình bạn nhận được:',
    'Team vs Team: người đại diện ghép kèo nhận cộng/trừ thay cả đội.',
    'Hủy kèo đã đủ người khi tất cả cùng đồng ý (trước giờ chơi 24 giờ) thì không bị trừ điểm.',
    'Dưới 30 điểm: không thể tạo kèo hoặc Flash Claim LFG. Đặt sân thường vẫn bình thường.',
    'Dưới 30 điểm sẽ tự hồi phục dần theo thời gian tới 40 điểm. Trên 40 chỉ tăng nhờ được đánh giá tốt.',
  ];

  /// Bảng điểm theo sao trung bình, hiện ngay dưới dòng thứ 3 của [rules].
  static const int reviewTableAfterRule = 2;
  static const List<(String, String)> reviewTable = [
    ('Dưới 2.5 sao', '−5'),
    ('2.5 – dưới 4 sao', '0'),
    ('4 – 4.5 sao', '+3'),
    ('Trên 4.5 sao', '+5'),
  ];
  static const String history = 'Lịch sử thay đổi';
  static const String noHistory = 'Chưa có thay đổi nào';

  // Chặn LFG
  static const String blockedTitle = 'Chưa thể ghép LFG';
  static String blockedMessage(int score, int min) =>
      'Điểm Fair Play của bạn là $score, cần tối thiểu $min điểm để tạo kèo hoặc tham gia kèo LFG.\n\n'
      'Điểm sẽ tự hồi phục dần theo thời gian. Bạn vẫn có thể đặt sân thường.';
  static const String viewFairPlay = 'Xem Fair Play';
  static const String close = 'Đóng';

  // Lỗi
  static const String expired = 'Đã hết hạn đánh giá buổi chơi này (24 giờ sau check-out).';
  static const String alreadySubmitted = 'Bạn đã đánh giá buổi chơi này rồi.';
  static const String nothingRated = 'Vui lòng chấm sao cho sân hoặc ít nhất một người chơi.';
  static const String invalidStars = 'Số sao phải từ 1 đến 5.';
  static const String sessionNotFound = 'Không tìm thấy buổi chơi.';
  static const String loadError = 'Không tải được dữ liệu. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
