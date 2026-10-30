/// Chuỗi hiển thị cho đánh giá sau trận, đánh giá cơ sở và Fair Play.
class ReviewStrings {
  ReviewStrings._();

  // Danh sách chờ đánh giá
  static const String pendingTitle = 'Chờ Đánh Giá';
  static String pendingCount(int n) => 'Chờ đánh giá ($n)';
  static String bannerMessage(int n) => 'Bạn có $n trận chờ chấm người chơi';
  static const String bannerAction = 'Đánh giá';
  static const String noPending = 'Không có trận nào chờ đánh giá';
  static const String noPendingHint = 'Sau mỗi trận, bạn có 24 giờ kể từ giờ kết thúc để chấm người chơi cùng trận.';
  static String timeLeft(String t) => 'Còn $t để đánh giá';
  static String hoursMinutes(int h, int m) => h > 0 ? '$h giờ $m phút' : '$m phút';
  static const String lfgMatch = 'Trận ghép LFG';
  static const String booking = 'Đặt sân';
  static String playerCount(int n) => '$n người chơi chờ chấm';

  // Màn đánh giá trận
  static const String reviewTitle = 'Đánh Giá Buổi Chơi';
  static const String facilitySection = 'Đánh giá sân';
  static const String playersSection = 'Đánh giá người chơi cùng';
  static const String anonymousNote = 'Đánh giá được ẩn danh. Người chơi chỉ thấy điểm tổng, không biết ai đã chấm.';
  static const String facilityPublicNote = 'Đánh giá sân hiển thị công khai kèm tên của bạn.';
  static const String facilityAlreadyReviewed = 'Bạn đã đánh giá sân này.';
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

  // Đánh giá cơ sở
  static const String facilityReviews = 'Đánh giá';
  static String reviewCount(int n) => '$n đánh giá';
  static const String seeAll = 'Xem tất cả';
  static const String writeReview = 'Viết đánh giá';
  static const String writeReviewTitle = 'Đánh Giá Sân';
  static const String noReviews = 'Chưa có đánh giá nào';
  static const String noReviewsForStars = 'Không có đánh giá nào ở mức sao này';
  static const String ownerReply = 'Phản hồi của chủ sân';
  static const String filterAll = 'Tất cả';
  static String starsFilter(int n) => '$n sao';
  static const String chooseStars = 'Chạm vào sao để chấm điểm';
  static const String facilityCommentHint = 'Chia sẻ trải nghiệm của bạn về sân (không bắt buộc)';
  static const String myReviews = 'Đánh giá của tôi';
  static const String noMyReviews = 'Bạn chưa đánh giá sân nào';
  static const String hiddenByAdmin = 'Đã bị Admin ẩn';
  static String hiddenReason(String reason) => 'Lý do: $reason';
  static const String loadMore = 'Xem thêm';

  // Fair Play
  static const String fairPlay = 'Fair Play';
  static const String fairPlayTitle = 'Điểm Fair Play';
  static String scoreLabel(int score) => 'Fair Play: $score';
  static const String eligible = 'Đủ điều kiện ghép LFG';
  static String restricted(int min) => 'Tạm khóa ghép LFG (cần tối thiểu $min điểm)';
  static const String banned = 'Đang bị cấm ghép LFG';
  static String banUntil(String date) => 'Đến hết $date';
  static const String banForever = 'Không thời hạn';
  static String banReason(String reason) => 'Lý do: $reason';
  static String recovering(int cap) => 'Điểm tự hồi +1 mỗi ngày (tối đa đến $cap).';
  static String ratingSummary(int count, double average) =>
      'Được chấm $count lượt • trung bình ${average.toStringAsFixed(1)} sao';
  static const String howItWorks = 'Cách tính điểm';
  static List<String> rules(int minScore, int cap) => [
    'Mỗi tài khoản bắt đầu với 100 điểm (tối đa 100).',
    'Vắng mặt, check-in trễ quá 15 phút, hủy muộn hoặc chủ kèo hủy kèo: −10 điểm.',
    'Sau mỗi trận, người chơi cùng trận chấm sao cho nhau (ẩn danh) trong 24 giờ sau giờ kết thúc. '
        'Hết hạn chấm, điểm được tính theo số sao trung bình bạn nhận:',
    'Dưới $minScore điểm: không thể tạo kèo hoặc Flash Claim LFG. Đặt sân thường vẫn bình thường.',
    'Điểm thấp tự hồi +1 mỗi ngày tới $cap điểm. Trên $cap chỉ tăng nhờ được đánh giá tốt.',
  ];

  /// Bảng điểm theo sao trung bình, hiện ngay dưới dòng thứ 3 của [rules].
  static const int reviewTableAfterRule = 2;
  static const List<(String, String)> reviewTable = [
    ('Dưới 1.5 sao', '−5'),
    ('1.5 – dưới 2.5 sao', '−2'),
    ('2.5 – 4 sao', '0'),
    ('Trên 4 – dưới 4.5 sao', '+3'),
    ('Từ 4.5 sao', '+5'),
  ];
  static const String history = 'Lịch sử thay đổi';
  static const String noHistory = 'Chưa có thay đổi nào';

  // Chặn LFG
  static const String blockedTitle = 'Chưa thể ghép LFG';
  static String blockedMessage(int score, int min) =>
      'Điểm Fair Play của bạn là $score, cần tối thiểu $min điểm để tạo kèo hoặc tham gia kèo LFG.\n\n'
      'Điểm sẽ tự hồi phục dần theo thời gian. Bạn vẫn có thể đặt sân thường.';
  static String bannedMessage(String? reason, String until) =>
      'Tài khoản đang bị cấm tạo kèo và tham gia kèo LFG ($until).'
      '${reason == null ? '' : '\nLý do: $reason'}\n\nBạn vẫn có thể đặt sân thường.';
  static const String viewFairPlay = 'Xem Fair Play';
  static const String close = 'Đóng';

  // Lỗi
  static const String expired = 'Đã hết hạn đánh giá trận này (24 giờ sau giờ kết thúc).';
  static const String alreadySubmitted = 'Bạn đã đánh giá rồi.';
  static const String nothingRated = 'Vui lòng chấm sao cho sân hoặc ít nhất một người chơi.';
  static const String invalidStars = 'Số sao phải từ 1 đến 5.';
  static const String sessionNotFound = 'Không tìm thấy trận đấu.';
  static const String notEligible = 'Bạn cần check-in tại sân ít nhất một lần để đánh giá.';
  static const String loadError = 'Không tải được dữ liệu. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
