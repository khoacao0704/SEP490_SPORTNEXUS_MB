import '../utils/formatters.dart';

/// Chuỗi hiển thị cho Bảng tin cộng đồng (theo trang Cộng đồng của Web).
class CommunityStrings {
  CommunityStrings._();

  static const String menu = 'Cộng đồng';
  static const String title = 'Cộng đồng';
  static const String tabFeed = 'Bảng tin';
  static const String tabMine = 'Bài viết của tôi';
  static const String sortNewest = 'Mới nhất';
  static const String sortHot = 'Nổi bật';
  static const String allSports = 'Tất cả môn';
  static const String searchHint = 'Tìm kiếm Bảng tin cộng đồng';
  static const String emptyFeed = 'Chưa có bài viết nào phù hợp.';
  static const String emptyMine = 'Bạn chưa có bài viết nào.';
  static String authorPosts(String name) => 'Bài viết của $name';
  static const String backToFeed = 'Về Bảng tin';
  static const String loadError = 'Không tải được bài viết.';
  static const String retry = 'Thử lại';

  // Đăng bài
  static const String newPost = 'Đăng bài';
  static const String composeTitle = 'Bài viết mới';
  static const String composeHint = 'Chia sẻ trận đấu, tìm bạn chơi, hỏi kinh nghiệm…';
  static const String sportOptional = 'Môn (không bắt buộc)';
  static const String noSport = 'Không chọn môn';
  static String imagesLabel(int n, int max) => 'Ảnh ($n/$max)';
  static const String addImage = 'Thêm ảnh';
  static const String uploading = 'Đang tải…';
  static const String removeImage = 'Bỏ ảnh';
  static const String post = 'Đăng';
  static const String posting = 'Đang đăng…';
  static const String posted = 'Đã đăng bài.';
  static const String contentRequired = 'Vui lòng nhập nội dung bài viết.';
  static const String postError = 'Không đăng được bài viết.';
  static const String uploadError = 'Không tải được ảnh.';

  // Thẻ bài viết
  static String timeAgo(DateTime t, DateTime now) {
    final d = now.difference(t);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inHours < 1) return '${d.inMinutes} phút trước';
    if (d.inDays < 1) return '${d.inHours} giờ trước';
    if (d.inDays < 7) return '${d.inDays} ngày trước';
    return Formatters.date(t);
  }

  static const String edited = 'đã sửa';
  static const String editHistory = 'lịch sử sửa';
  static const String deletedBadge = 'Đã xóa';
  static const String hiddenBadge = 'Bị Admin ẩn';
  static String hiddenReason(String reason) => 'Lý do ẩn: $reason';
  static const String edit = 'Sửa';
  static const String delete = 'Xóa';
  static const String save = 'Lưu';
  static const String cancel = 'Hủy';
  static const String deleteConfirm = 'Xóa bài viết này?';
  static const String saved = 'Đã sửa bài viết.';
  static const String saveError = 'Không sửa được bài viết.';
  static const String deleted = 'Đã xóa bài viết.';
  static const String deleteError = 'Không xóa được bài viết.';
  static const String actionError = 'Không thực hiện được.';
  static String comments(int n) => '$n bình luận';
  static String lfgTitle(String sport) => 'Kèo LFG · $sport';
  static String teamTitle(String host, String? challenger, String sport) =>
      '$host vs ${challenger ?? 'Đang tìm đối thủ'} · $sport';
  static String lfgDetail(String facility, String when, int left, int total, int price) =>
      '$facility · $when · còn $left/$total suất · ${Formatters.vnd(price)}/người';
  static String tournamentTitle(String name) => 'Giải đấu · $name';
  static String tournamentDetail(String facility, int fee) => '$facility · Lệ phí ${Formatters.vnd(fee)}';

  // Lịch sử sửa
  static const String historyTitle = 'Lịch sử sửa';
  static const String historyEmpty = 'Chưa chỉnh sửa lần nào.';
  static String historyItem(String at) => 'Trước lần sửa lúc $at';

  // Đăng kèo lên Bảng tin
  static const String shareLfg = 'Đăng lên Bảng tin';
  static const String shareLfgTitle = 'Đăng kèo này lên Bảng tin cộng đồng?';
  static String shareLfgContent(String sport, int left, String place, String when) =>
      'Kèo $sport còn $left suất${place.isEmpty ? '' : ' tại $place'}${when.isEmpty ? '' : ', $when'}. '
      'Ai rảnh vào nhận suất chơi cùng nhé!';
  static const String shared = 'Đã đăng kèo lên Bảng tin cộng đồng.';
  static const String viewFeed = 'Xem bảng tin';
  static const String shareError = 'Không đăng được kèo lên bảng tin.';

  // Bình luận
  static const String commentsTitle = 'Bình luận';
  static const String noComments = 'Chưa có bình luận nào. Hãy là người đầu tiên!';
  static const String commentHint = 'Viết bình luận… (gõ @ để tag người chơi)';
  static String replyHint(String name) => 'Trả lời $name…';
  static const String send = 'Gửi';
  static const String reply = 'Trả lời';
  static const String cancelReply = 'Hủy trả lời';
  static const String commentRequired = 'Nội dung bình luận không được để trống';
  static const String commentError = 'Không gửi được bình luận.';
  static const String commentDeleteConfirm = 'Xóa bình luận này?';
  static const String commentDeleted = 'Đã xóa bình luận.';
  static const String commentSaved = 'Đã sửa bình luận.';
  static const String editWindowPassed =
      'Đã quá thời hạn 15 phút kể từ lúc đăng bình luận. Không thể chỉnh sửa bình luận này nữa.';
  static const String commentNotFound = 'Bình luận không còn.';
  static const String report = 'Báo cáo';
  static const String reportPostTitle = 'Báo cáo bài viết';
  static const String reportCommentTitle = 'Báo cáo bình luận';

  // Lỗi bản giả lập
  static const String loginRequired = 'Vui lòng đăng nhập.';
  static const String notFound = 'Bài viết không còn.';
  static const String notOwner = 'Bạn chỉ sửa / xóa được bài của mình.';
}
