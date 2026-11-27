import '../../models/community_post.dart';
import '../../models/sport.dart';
import '../repositories/community_repository.dart';
import '../session_store.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// [CommunityRepository] gọi Backend thật (cùng API trang Cộng đồng của Web):
/// - GET /community/posts?SortBy&SportCategoryId&Keyword&Page&PageSize; GET /community/my-posts?includeRemoved=true;
///   GET /community/users/{id}/posts → {items, totalPages?} hoặc mảng.
/// - POST /community/posts {content, mediaUrls, sportCategoryId, lfgCardId, tournamentId};
///   PUT /community/posts/{id} {content}; DELETE /community/posts/{id}.
/// - POST|DELETE /community/posts/{id}/like; GET /community/posts/{id}/edits → [{editedAt, oldContent}].
/// - Ảnh: POST /community/posts/images (field `file`) → {url}.
class ApiCommunityRepository implements CommunityRepository {
  static const String postsPath = '/api/v1/community/posts';
  static const String myPostsPath = '/api/v1/community/my-posts';
  static String userPostsPath(String userId) => '/api/v1/community/users/$userId/posts';
  static String postPath(String id) => '$postsPath/$id';
  static String likePath(String id) => '$postsPath/$id/like';
  static String editsPath(String id) => '$postsPath/$id/edits';
  static const String imagesPath = '$postsPath/images';

  final ApiClient _api;
  final ApiFacilityRepository _facility;

  ApiCommunityRepository({required this._api, required this._facility});

  @override
  Future<PostPage> getPosts(PostQuery query, {int page = 1}) async {
    final paging = {'page': page, 'pageSize': CommunityRepository.pageSize};
    final Object? data;
    if (query.authorId != null) {
      data = await _call(() => _api.get(userPostsPath(query.authorId!), query: paging));
    } else if (query.mine) {
      data = await _call(() => _api.get(myPostsPath, query: {...paging, 'includeRemoved': true}));
    } else {
      final sport = query.sport;
      final categoryId = sport == null ? null : await _facility.categoryIdOf(sport);
      if (sport != null && categoryId == null) return const PostPage(items: [], hasMore: false);
      final keyword = query.keyword.trim();
      data = await _call(
        () => _api.get(
          postsPath,
          query: {
            'SortBy': query.sort.apiValue,
            'SportCategoryId': ?categoryId,
            if (keyword.isNotEmpty) 'Keyword': keyword,
            'Page': page,
            'PageSize': CommunityRepository.pageSize,
          },
        ),
      );
    }
    final myId = (await SessionStore.readUser())?.id ?? '';
    final items = [for (final m in _list(data)) postFromApi(m, myId: myId, mine: query.mine)];
    final totalPages = data is Map ? (data['totalPages'] as num?)?.toInt() : null;
    return PostPage(
      items: items,
      hasMore: totalPages != null ? page < totalPages : items.length >= CommunityRepository.pageSize,
    );
  }

  @override
  Future<CommunityPost> createPost({
    required String content,
    List<String> mediaUrls = const [],
    Sport? sport,
    String? lfgCardId,
  }) async {
    final categoryId = sport == null ? null : await _facility.categoryIdOf(sport);
    final data = await _call(
      () => _api.post(
        postsPath,
        body: {
          'content': content.trim(),
          'mediaUrls': mediaUrls,
          'sportCategoryId': categoryId,
          'lfgCardId': lfgCardId,
          'tournamentId': null,
        },
      ),
    );
    final myId = (await SessionStore.readUser())?.id ?? '';
    return data is Map
        ? postFromApi(Map<String, dynamic>.from(data), myId: myId, mine: true)
        : CommunityPost(id: '', authorId: myId, authorName: '', content: content.trim(), createdAt: DateTime.now());
  }

  @override
  Future<CommunityPost> updatePost(String postId, String content) async {
    final data = await _call(() => _api.put(postPath(postId), body: {'content': content.trim()}));
    final myId = (await SessionStore.readUser())?.id ?? '';
    if (data is Map) return postFromApi(Map<String, dynamic>.from(data), myId: myId, mine: true);
    final fresh = await _call(() => _api.get(postPath(postId)));
    return postFromApi(Map<String, dynamic>.from(fresh as Map), myId: myId, mine: true);
  }

  @override
  Future<void> deletePost(String postId) => _call(() => _api.delete(postPath(postId)));

  @override
  Future<int?> setLiked(String postId, bool liked) async {
    final data = await _call(() => liked ? _api.post(likePath(postId)) : _api.delete(likePath(postId)));
    return data is Map ? (data['likeCount'] as num?)?.toInt() : null;
  }

  @override
  Future<List<PostEdit>> getPostEdits(String postId) async {
    final data = await _call(() => _api.get(editsPath(postId)));
    return [
      for (final m in _list(data))
        if (DateTime.tryParse('${m['editedAt']}') case final at?)
          PostEdit(editedAt: at.toLocal(), oldContent: '${m['oldContent'] ?? ''}'),
    ];
  }

  // ---------------- Bình luận ----------------

  static String commentsPath(String postId) => '$postsPath/$postId/comments';
  static String commentPath(String id) => '/api/v1/community/comments/$id';
  static String commentEditsPath(String id) => '${commentPath(id)}/edits';

  /// GET /posts/{id}/comments?page=1&pageSize=100 (như Web). BE trả bình luận gốc kèm `replies`; phần tử phẳng có
  /// `parentCommentId` thì app tự xếp vào bình luận cha.
  @override
  Future<List<PostComment>> getComments(String postId) async {
    final data = await _call(() => _api.get(commentsPath(postId), query: const {'page': 1, 'pageSize': 100}));
    final myId = (await SessionStore.readUser())?.id ?? '';
    final all = [for (final m in _list(data)) commentFromApi(m, myId: myId)];
    final roots = <PostComment>[];
    final byId = {for (final c in all) c.id: c};
    for (final c in all) {
      final parent = c.parentId == null ? null : byId[c.parentId];
      if (parent == null) roots.add(c);
    }
    final result = [
      for (final r in roots)
        r.copyWith(
          replies: [...r.replies, ...all.where((c) => c.parentId == r.id && !r.replies.any((x) => x.id == c.id))]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        ),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  @override
  Future<PostComment> addComment(String postId, String content, {String? parentId}) async {
    final data = await _call(
      () => _api.post(commentsPath(postId), body: {'content': content.trim(), 'parentCommentId': parentId}),
    );
    final myId = (await SessionStore.readUser())?.id ?? '';
    return data is Map
        ? commentFromApi(Map<String, dynamic>.from(data), myId: myId)
        : PostComment(
            id: '',
            userId: myId,
            userName: '',
            content: content.trim(),
            createdAt: DateTime.now(),
            isMine: true,
            parentId: parentId,
          );
  }

  @override
  Future<PostComment> updateComment(String commentId, String content) async {
    final data = await _call(() => _api.put(commentPath(commentId), body: {'content': content.trim()}));
    final myId = (await SessionStore.readUser())?.id ?? '';
    return data is Map
        ? commentFromApi(Map<String, dynamic>.from(data), myId: myId).copyWith(isEdited: true)
        : PostComment(
            id: commentId,
            userId: myId,
            userName: '',
            content: content.trim(),
            createdAt: DateTime.now(),
            isMine: true,
            isEdited: true,
          );
  }

  @override
  Future<void> deleteComment(String commentId) => _call(() => _api.delete(commentPath(commentId)));

  @override
  Future<List<PostEdit>> getCommentEdits(String commentId) async {
    final data = await _call(() => _api.get(commentEditsPath(commentId)));
    return [
      for (final m in _list(data))
        if (DateTime.tryParse('${m['editedAt']}') case final at?)
          PostEdit(editedAt: at.toLocal(), oldContent: '${m['oldContent'] ?? ''}'),
    ];
  }

  static PostComment commentFromApi(Map<String, dynamic> j, {required String myId}) {
    String? str(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    DateTime? time(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
    final userId = str(j['userId'] ?? j['authorId']) ?? '';
    final createdAt = time(j['createdAt']) ?? DateTime.now();
    final updatedAt = time(j['editedAt'] ?? j['updatedAt']);
    final replies = j['replies'];
    return PostComment(
      id: str(j['id']) ?? '',
      userId: userId,
      userName: str(j['userName'] ?? j['authorName']) ?? 'Người chơi',
      userAvatarUrl: str(j['userAvatarUrl'] ?? j['authorAvatar']),
      content: '${j['content'] ?? ''}',
      createdAt: createdAt,
      isEdited: j['isEdited'] == true || (updatedAt != null && updatedAt.difference(createdAt).inSeconds > 1),
      isMine: j['isMine'] == true || (myId.isNotEmpty && userId == myId),
      canEdit: j['canEdit'] != false,
      parentId: str(j['parentCommentId'] ?? j['parentId']),
      replies: replies is List
          ? [
              for (final r in replies)
                if (r is Map) commentFromApi(Map<String, dynamic>.from(r), myId: myId),
            ]
          : const [],
    );
  }

  @override
  Future<String> uploadImage(String filePath) async {
    final data = await _call(() => _api.upload(imagesPath, filePath: filePath));
    final url = data is String ? data : (data is Map ? data['url'] ?? data['imageUrl'] : null);
    if (url == null || '$url'.isEmpty) throw const CommunityException('Không tải được ảnh.');
    return '$url';
  }

  // ---------------- Chuyển đổi dữ liệu BE ----------------

  static CommunityPost postFromApi(Map<String, dynamic> j, {required String myId, bool mine = false}) {
    String? str(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    int n(Object? v) => (v as num?)?.round() ?? 0;
    DateTime? time(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
    final authorId = str(j['authorId']) ?? '';
    final sportName = str(j['sportName']);
    final media = j['mediaUrls'];
    final lfg = j['sharedLfg'];
    final tour = j['sharedTournament'];
    final createdAt = time(j['createdAt']) ?? DateTime.now();
    final updatedAt = time(j['updatedAt']);
    return CommunityPost(
      id: str(j['id']) ?? '',
      authorId: authorId,
      authorName: str(j['authorName']) ?? '',
      authorAvatarUrl: str(j['authorAvatarUrl'] ?? j['authorAvatar']),
      content: '${j['content'] ?? ''}',
      mediaUrls: media is List
          ? [
              for (final u in media)
                if (str(u) != null) str(u)!,
            ]
          : const [],
      sport: ApiFacilityRepository.sportFromName(sportName),
      sportName: sportName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isEdited: j['isEdited'] == true,
      likeCount: n(j['likeCount']),
      commentCount: n(j['commentCount']),
      isLikedByMe: j['isLikedByMe'] == true,
      isMine: mine || j['isMine'] == true || (myId.isNotEmpty && authorId == myId),
      status: PostStatus.fromApi(j['status']),
      hiddenReason: str(j['hiddenReason']),
      sharedLfg: lfg is Map
          ? SharedLfg(
              id: str(lfg['id'] ?? lfg['cardId']) ?? '',
              sportName: str(lfg['sportName']) ?? '',
              facilityName: str(lfg['facilityName']) ?? '',
              start: time(lfg['startTime']),
              remainingSlots: n(lfg['remainingSlots']),
              totalSlots: n(lfg['totalSlots']),
              pricePerPerson: n(lfg['pricePerPerson']),
              hostTeamName: str(lfg['hostTeamName']),
              challengerTeamName: str(lfg['challengerTeamName']),
            )
          : null,
      sharedTournament: tour is Map
          ? SharedTournament(
              name: str(tour['name']) ?? '',
              facilityName: str(tour['facilityName']) ?? '',
              entryFee: n(tour['entryFee']),
            )
          : null,
    );
  }

  static List<Map<String, dynamic>> _list(Object? data) {
    final list = data is Map ? data['items'] : data;
    return list is List
        ? [
            for (final e in list)
              if (e is Map) Map<String, dynamic>.from(e),
          ]
        : const [];
  }

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw CommunityException.fromApi(e);
    }
  }
}
