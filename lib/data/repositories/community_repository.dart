import '../../models/community_post.dart';
import '../../models/sport.dart';
import '../api/api_error_codes.dart';

/// Lỗi Bảng tin cộng đồng; [message] sẵn sàng để hiển thị (câu của BE khi gọi API thật).
class CommunityException implements Exception, CodedError {
  @override
  final String message;

  @override
  final String? code;

  @override
  final Map<String, dynamic>? detail;

  const CommunityException(this.message, {this.code, this.detail});

  CommunityException.fromApi(CodedError e) : this(e.message, code: e.code, detail: e.detail);

  @override
  String toString() => 'CommunityException: $message';
}

/// Bảng tin cộng đồng (như trang Cộng đồng của Web).
abstract class CommunityRepository {
  static const int pageSize = 10;
  static const int maxContent = 5000;
  static const int maxImages = 10;

  /// [page] bắt đầu từ 1. Theo [PostQuery]: bảng tin / bài của tôi / bài của một người.
  Future<PostPage> getPosts(PostQuery query, {int page = 1});

  Future<CommunityPost> createPost({
    required String content,
    List<String> mediaUrls = const [],
    Sport? sport,
    String? lfgCardId,
  });

  /// Như Web: chỉ sửa nội dung.
  Future<CommunityPost> updatePost(String postId, String content);

  Future<void> deletePost(String postId);

  /// Like / bỏ like; trả số like mới nếu BE trả về.
  Future<int?> setLiked(String postId, bool liked);

  Future<List<PostEdit>> getPostEdits(String postId);

  // ---------- Bình luận ----------

  /// Bình luận của bài (mỗi bình luận gốc kèm trả lời), cũ trước.
  Future<List<PostComment>> getComments(String postId);

  /// [parentId]: trả lời một bình luận.
  Future<PostComment> addComment(String postId, String content, {String? parentId});

  /// Chỉ trong [PostComment.editWindow] kể từ lúc đăng (BE kiểm lại).
  Future<PostComment> updateComment(String commentId, String content);

  Future<void> deleteComment(String commentId);

  Future<List<PostEdit>> getCommentEdits(String commentId);

  /// Tải ảnh bài viết, trả link.
  Future<String> uploadImage(String filePath);
}
