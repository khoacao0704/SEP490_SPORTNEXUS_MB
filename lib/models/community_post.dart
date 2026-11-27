import 'sport.dart';

/// Trạng thái bài viết (BE): ACTIVE, DELETED (người đăng xóa), HIDDEN (Admin ẩn). Chỉ "Bài viết của tôi" có bài
/// khác ACTIVE.
enum PostStatus {
  active('ACTIVE'),
  deleted('DELETED'),
  hidden('HIDDEN');

  const PostStatus(this.apiValue);

  final String apiValue;

  static PostStatus fromApi(Object? v) {
    final key = '${v ?? ''}'.toUpperCase();
    return values.firstWhere((s) => s.apiValue == key, orElse: () => active);
  }
}

/// Kèo LFG đính kèm bài viết (bài "Đăng kèo lên Bảng tin").
class SharedLfg {
  final String id;
  final String sportName;
  final String facilityName;
  final DateTime? start;
  final int remainingSlots;
  final int totalSlots;
  final int pricePerPerson;

  /// Kèo Đội vs Đội: tên 2 đội (đội nhận kèo `null` khi chưa có).
  final String? hostTeamName;
  final String? challengerTeamName;

  const SharedLfg({
    required this.id,
    required this.sportName,
    required this.facilityName,
    required this.remainingSlots,
    required this.totalSlots,
    required this.pricePerPerson,
    this.start,
    this.hostTeamName,
    this.challengerTeamName,
  });

  bool get isTeamMatch => hostTeamName != null;
}

/// Giải đấu đính kèm bài viết (chỉ hiện, mobile chưa làm giải đấu).
class SharedTournament {
  final String name;
  final String facilityName;
  final int entryFee;

  const SharedTournament({required this.name, required this.facilityName, required this.entryFee});
}

/// Một bài viết trên Bảng tin cộng đồng.
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final List<String> mediaUrls;

  /// Môn của app; [sportName] giữ tên BE (môn app chưa có vẫn hiện được).
  final Sport? sport;
  final String? sportName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final bool isMine;
  final PostStatus status;
  final String? hiddenReason;
  final SharedLfg? sharedLfg;
  final SharedTournament? sharedTournament;

  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
    this.mediaUrls = const [],
    this.sport,
    this.sportName,
    this.updatedAt,
    this.isEdited = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
    this.isMine = false,
    this.status = PostStatus.active,
    this.hiddenReason,
    this.sharedLfg,
    this.sharedTournament,
  });

  bool get isRemoved => status != PostStatus.active;

  /// Điểm "Nổi bật" như Web: like + 2 × bình luận.
  int get hotScore => likeCount + commentCount * 2;

  CommunityPost copyWith({
    String? content,
    List<String>? mediaUrls,
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
    bool? isEdited,
    DateTime? updatedAt,
    PostStatus? status,
  }) =>
      CommunityPost(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        content: content ?? this.content,
        mediaUrls: mediaUrls ?? this.mediaUrls,
        sport: sport,
        sportName: sportName,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isEdited: isEdited ?? this.isEdited,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        isMine: isMine,
        status: status ?? this.status,
        hiddenReason: hiddenReason,
        sharedLfg: sharedLfg,
        sharedTournament: sharedTournament,
      );
}

/// Một lần sửa (nội dung trước khi sửa).
class PostEdit {
  final DateTime editedAt;
  final String oldContent;

  const PostEdit({required this.editedAt, required this.oldContent});
}

/// Sắp xếp bảng tin (SortBy của BE).
enum PostSort {
  newest('newest'),
  hot('hot');

  const PostSort(this.apiValue);

  final String apiValue;
}

/// Bộ lọc bảng tin. [authorId] khác `null`: chỉ bài của một người (bấm tên người đăng).
class PostQuery {
  final PostSort sort;
  final Sport? sport;
  final String keyword;
  final String? authorId;

  /// "Bài viết của tôi": gồm cả bài đã xóa / bị ẩn.
  final bool mine;

  const PostQuery({this.sort = PostSort.newest, this.sport, this.keyword = '', this.authorId, this.mine = false});
}

/// Một trang bài viết.
class PostPage {
  final List<CommunityPost> items;
  final bool hasMore;

  const PostPage({required this.items, required this.hasMore});
}

/// Một bình luận (kèm các trả lời, BE trả lồng trong [replies]).
class PostComment {
  /// Như Web: sửa bình luận trong 15 phút kể từ lúc đăng.
  static const Duration editWindow = Duration(minutes: 15);

  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isEdited;
  final bool isMine;

  /// BE có thể trả `canEdit = false` (khi đó không sửa được dù còn trong 15 phút).
  final bool canEdit;
  final String? parentId;
  final List<PostComment> replies;

  const PostComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.userAvatarUrl,
    this.isEdited = false,
    this.isMine = false,
    this.canEdit = true,
    this.parentId,
    this.replies = const [],
  });

  bool editableAt(DateTime now) => isMine && canEdit && now.difference(createdAt) <= editWindow;

  PostComment copyWith({String? content, bool? isEdited, List<PostComment>? replies}) => PostComment(
        id: id,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        content: content ?? this.content,
        createdAt: createdAt,
        isEdited: isEdited ?? this.isEdited,
        isMine: isMine,
        canEdit: canEdit,
        parentId: parentId,
        replies: replies ?? this.replies,
      );
}
