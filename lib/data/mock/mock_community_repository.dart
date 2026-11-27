import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/community_strings.dart';
import '../../models/community_post.dart';
import '../../models/sport.dart';
import '../repositories/community_repository.dart';
import '../repositories/lfg_repository.dart';
import '../session_store.dart';

/// Bản giả lập Bảng tin cộng đồng: vài bài mẫu của người khác + bài người dùng đăng (lưu trong máy).
/// Like, sửa (có lịch sử), xóa (bài còn trong "Bài viết của tôi" với nhãn Đã xóa). Bài "Đăng kèo" đọc kèo từ [lfg].
class MockCommunityRepository implements CommunityRepository {
  static const String keyPosts = 'community_posts_v1';
  static const String keyLikes = 'community_likes_v1';
  static const String keyEdits = 'community_edits_v1';

  final Duration latency;
  final DateTime Function() _now;

  /// Đọc kèo đính kèm lúc đăng (hàm để luôn lấy repository kèo đang dùng).
  final LfgRepository? Function()? lfg;
  int _counter = 0;

  MockCommunityRepository({this.latency = const Duration(milliseconds: 300), DateTime Function()? now, this.lfg})
    : _now = now ?? DateTime.now;

  @override
  Future<PostPage> getPosts(PostQuery query, {int page = 1}) async {
    await _delay();
    final myId = (await SessionStore.readUser())?.id ?? '';
    final likes = await _likes();
    final counts = await _commentCounts();
    var all = [for (final p in await _all()) _view(p, myId, likes, counts)];
    if (query.mine) {
      all = all.where((p) => p.authorId == myId).toList();
    } else {
      all = all.where((p) => !p.isRemoved).toList();
      if (query.authorId != null) all = all.where((p) => p.authorId == query.authorId).toList();
      if (query.sport != null) all = all.where((p) => p.sport == query.sport).toList();
      final kw = query.keyword.trim().toLowerCase();
      if (kw.isNotEmpty) {
        all = all.where((p) => '${p.content} ${p.authorName} ${p.sportName ?? ''}'.toLowerCase().contains(kw)).toList();
      }
    }
    all.sort(
      (a, b) => query.sort == PostSort.hot && !query.mine && a.hotScore != b.hotScore
          ? b.hotScore.compareTo(a.hotScore)
          : b.createdAt.compareTo(a.createdAt),
    );
    final from = (page - 1) * CommunityRepository.pageSize;
    final items = all.skip(from).take(CommunityRepository.pageSize).toList();
    return PostPage(items: items, hasMore: from + items.length < all.length);
  }

  @override
  Future<CommunityPost> createPost({
    required String content,
    List<String> mediaUrls = const [],
    Sport? sport,
    String? lfgCardId,
  }) async {
    await _delay();
    final text = content.trim();
    if (text.isEmpty) throw const CommunityException(CommunityStrings.contentRequired);
    final me = await SessionStore.readUser();
    if (me == null) throw const CommunityException(CommunityStrings.loginRequired);
    SharedLfg? shared;
    final lfgRepo = lfg?.call();
    if (lfgCardId != null && lfgRepo != null) {
      final m = await lfgRepo.getMatch(lfgCardId);
      shared = SharedLfg(
        id: m.id,
        sportName: m.sport.label,
        facilityName: m.facilityCourtLabel,
        start: m.start,
        remainingSlots: m.slotsLeft,
        totalSlots: m.totalSlots - 1,
        pricePerPerson: m.depositPerSlot,
        hostTeamName: m.hostTeam?.name,
        challengerTeamName: m.challengerTeam?.name,
      );
    }
    final post = CommunityPost(
      id: 'post-${_now().microsecondsSinceEpoch}-${++_counter}',
      authorId: me.id,
      authorName: me.fullName,
      authorAvatarUrl: me.avatarUrl,
      content: text,
      mediaUrls: mediaUrls,
      sport: sport ?? (shared == null ? null : Sport.values.where((s) => s.label == shared!.sportName).firstOrNull),
      sportName: sport?.label ?? shared?.sportName,
      createdAt: _now(),
      sharedLfg: shared,
    );
    final all = await _all()
      ..add(post);
    await _save(all);
    return _view(post, me.id, await _likes());
  }

  @override
  Future<CommunityPost> updatePost(String postId, String content) async {
    await _delay();
    final text = content.trim();
    if (text.isEmpty) throw const CommunityException(CommunityStrings.contentRequired);
    final (all, i) = await _mine(postId);
    final old = all[i];
    final edits = await _edits();
    (edits[postId] ??= []).add({'editedAt': _now().toIso8601String(), 'oldContent': old.content});
    await _saveEdits(edits);
    all[i] = old.copyWith(content: text, isEdited: true, updatedAt: _now());
    await _save(all);
    return _view(all[i], old.authorId, await _likes());
  }

  @override
  Future<void> deletePost(String postId) async {
    await _delay();
    final (all, i) = await _mine(postId);
    all[i] = all[i].copyWith(status: PostStatus.deleted);
    await _save(all);
  }

  @override
  Future<int?> setLiked(String postId, bool liked) async {
    await _delay();
    final myId = (await SessionStore.readUser())?.id ?? '';
    final likes = await _likes();
    final set = (likes[postId] ??= <String>{});
    liked ? set.add(myId) : set.remove(myId);
    await _saveLikes(likes);
    final post = (await _all()).where((p) => p.id == postId).firstOrNull;
    return post == null ? null : _view(post, myId, likes).likeCount;
  }

  @override
  Future<List<PostEdit>> getPostEdits(String postId) async {
    await _delay();
    final list = (await _edits())[postId] ?? const [];
    return [
      for (final e in list.reversed)
        PostEdit(editedAt: DateTime.parse(e['editedAt'] as String), oldContent: e['oldContent'] as String),
    ];
  }

  // ---------------- Bình luận ----------------

  static const String keyComments = 'community_comments_v1';
  static const String keyCommentEdits = 'community_comment_edits_v1';

  @override
  Future<List<PostComment>> getComments(String postId) async {
    await _delay();
    final myId = (await SessionStore.readUser())?.id ?? '';
    final flat = [for (final c in (await _comments())[postId] ?? const <Map<String, dynamic>>[]) _comment(c, myId)]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      for (final r in flat.where((c) => c.parentId == null))
        r.copyWith(replies: flat.where((c) => c.parentId == r.id).toList()),
    ];
  }

  @override
  Future<PostComment> addComment(String postId, String content, {String? parentId}) async {
    await _delay();
    final text = content.trim();
    if (text.isEmpty) throw const CommunityException(CommunityStrings.commentRequired);
    final me = await SessionStore.readUser();
    if (me == null) throw const CommunityException(CommunityStrings.loginRequired);
    final all = await _comments();
    final json = <String, dynamic>{
      'id': 'cmt-${_now().microsecondsSinceEpoch}-${++_counter}',
      'postId': postId,
      'userId': me.id,
      'userName': me.fullName,
      'content': text,
      'createdAt': _now().toIso8601String(),
      'parentId': parentId,
      'isEdited': false,
    };
    (all[postId] ??= []).add(json);
    await _saveComments(all);
    return _comment(json, me.id);
  }

  @override
  Future<PostComment> updateComment(String commentId, String content) async {
    await _delay();
    final text = content.trim();
    if (text.isEmpty) throw const CommunityException(CommunityStrings.commentRequired);
    final (all, c) = await _myComment(commentId);
    if (_now().difference(DateTime.parse(c['createdAt'] as String)) > PostComment.editWindow) {
      throw const CommunityException(CommunityStrings.editWindowPassed);
    }
    final edits = await _commentEdits();
    (edits[commentId] ??= []).add({'editedAt': _now().toIso8601String(), 'oldContent': c['content']});
    await (await SharedPreferences.getInstance()).setString(keyCommentEdits, jsonEncode(edits));
    c['content'] = text;
    c['isEdited'] = true;
    await _saveComments(all);
    return _comment(c, c['userId'] as String);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _delay();
    final (all, c) = await _myComment(commentId);
    // Xóa bình luận gốc thì xóa luôn các trả lời của nó.
    all[c['postId']]!.removeWhere((x) => x['id'] == commentId || x['parentId'] == commentId);
    await _saveComments(all);
  }

  @override
  Future<List<PostEdit>> getCommentEdits(String commentId) async {
    await _delay();
    final list = (await _commentEdits())[commentId] ?? const [];
    return [
      for (final e in list.reversed)
        PostEdit(editedAt: DateTime.parse(e['editedAt'] as String), oldContent: '${e['oldContent']}'),
    ];
  }

  PostComment _comment(Map<String, dynamic> c, String myId) => PostComment(
    id: c['id'] as String,
    userId: c['userId'] as String,
    userName: c['userName'] as String,
    content: c['content'] as String,
    createdAt: DateTime.parse(c['createdAt'] as String),
    isEdited: c['isEdited'] == true,
    isMine: c['userId'] == myId,
    parentId: c['parentId'] as String?,
  );

  Future<(Map<String, List<Map<String, dynamic>>>, Map<String, dynamic>)> _myComment(String id) async {
    final myId = (await SessionStore.readUser())?.id ?? '';
    final all = await _comments();
    final c = all.values.expand((l) => l).where((x) => x['id'] == id).firstOrNull;
    if (c == null) throw const CommunityException(CommunityStrings.commentNotFound);
    if (c['userId'] != myId) throw const CommunityException(CommunityStrings.notOwner);
    return (all, c);
  }

  Future<Map<String, int>> _commentCounts() async => (await _comments()).map((k, v) => MapEntry(k, v.length));

  Future<Map<String, List<Map<String, dynamic>>>> _comments() async {
    final raw = (await SharedPreferences.getInstance()).getString(keyComments);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).map(
      (k, v) => MapEntry('$k', [for (final e in v as List) Map<String, dynamic>.from(e as Map)]),
    );
  }

  Future<void> _saveComments(Map<String, List<Map<String, dynamic>>> all) async =>
      (await SharedPreferences.getInstance()).setString(keyComments, jsonEncode(all));

  Future<Map<String, List<Map<String, dynamic>>>> _commentEdits() async {
    final raw = (await SharedPreferences.getInstance()).getString(keyCommentEdits);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).map(
      (k, v) => MapEntry('$k', [for (final e in v as List) Map<String, dynamic>.from(e as Map)]),
    );
  }

  @override
  Future<String> uploadImage(String filePath) async {
    await _delay();
    return filePath;
  }

  // ---------------- Nội bộ ----------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  /// Số like = like mẫu + like trong máy; [CommunityPost.isLikedByMe] theo người dùng hiện tại.
  CommunityPost _view(
    CommunityPost p,
    String myId,
    Map<String, Set<String>> likes, [
    Map<String, int> counts = const {},
  ]) {
    final likers = likes[p.id] ?? const <String>{};
    return CommunityPost(
      id: p.id,
      authorId: p.authorId,
      authorName: p.authorName,
      authorAvatarUrl: p.authorAvatarUrl,
      content: p.content,
      mediaUrls: p.mediaUrls,
      sport: p.sport,
      sportName: p.sportName,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      isEdited: p.isEdited,
      likeCount: p.likeCount + likers.length,
      commentCount: p.commentCount + (counts[p.id] ?? 0),
      isLikedByMe: likers.contains(myId),
      isMine: myId.isNotEmpty && p.authorId == myId,
      status: p.status,
      hiddenReason: p.hiddenReason,
      sharedLfg: p.sharedLfg,
      sharedTournament: p.sharedTournament,
    );
  }

  Future<(List<CommunityPost>, int)> _mine(String postId) async {
    final myId = (await SessionStore.readUser())?.id ?? '';
    final all = await _all();
    final i = all.indexWhere((p) => p.id == postId);
    if (i < 0 || all[i].isRemoved) throw const CommunityException(CommunityStrings.notFound);
    if (all[i].authorId != myId) throw const CommunityException(CommunityStrings.notOwner);
    return (all, i);
  }

  List<CommunityPost> _seed() {
    final now = _now();
    CommunityPost seed(
      int n,
      String author,
      String name,
      String content,
      Sport sport,
      Duration ago, {
      int likes = 0,
      int comments = 0,
      PostStatus status = PostStatus.active,
    }) => CommunityPost(
      id: 'post-seed-$n',
      authorId: author,
      authorName: name,
      content: content,
      sport: sport,
      sportName: sport.label,
      createdAt: now.subtract(ago),
      likeCount: likes,
      commentCount: comments,
      status: status,
    );
    return [
      seed(
        1,
        'u-minhtuan',
        'Minh Tuấn',
        'Tối thứ 6 ai đánh đôi cầu lông ở Thiên Triều không? Trình trung bình, vui là chính.',
        Sport.badminton,
        const Duration(hours: 2),
        likes: 4,
      ),
      seed(
        2,
        'u-lananh',
        'Lan Anh',
        'Mới tập pickleball được 1 tháng, xin mọi người kinh nghiệm chọn vợt cho người mới.',
        Sport.pickleball,
        const Duration(hours: 9),
        likes: 11,
      ),
      seed(
        3,
        'u-fcsaigon',
        'FC Sài Gòn',
        'FC Sài Gòn tìm đối giao hữu sân 7 cuối tuần này, khu vực Quận 1 – Quận 3.',
        Sport.football,
        const Duration(days: 1),
        likes: 2,
      ),
      seed(
        4,
        'u-minhtuan',
        'Minh Tuấn',
        'Sân Thiên Triều vừa thay thảm mới, đánh êm chân hơn hẳn.',
        Sport.badminton,
        const Duration(days: 2),
        likes: 7,
      ),
    ];
  }

  Future<List<CommunityPost>> _all() async {
    final raw = (await SharedPreferences.getInstance()).getString(keyPosts);
    final stored = raw == null ? <CommunityPost>[] : [for (final e in jsonDecode(raw) as List) _fromJson(e as Map)];
    final ids = stored.map((p) => p.id).toSet();
    return [...stored, ..._seed().where((p) => !ids.contains(p.id))];
  }

  Future<void> _save(List<CommunityPost> all) async => (await SharedPreferences.getInstance()).setString(
    keyPosts,
    jsonEncode([
      for (final p in all)
        if (!p.id.startsWith('post-seed-') || p.isEdited || p.isRemoved) _toJson(p),
    ]),
  );

  Future<Map<String, Set<String>>> _likes() async {
    final raw = (await SharedPreferences.getInstance()).getString(keyLikes);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', {for (final u in v as List) '$u'}));
  }

  Future<void> _saveLikes(Map<String, Set<String>> likes) async => (await SharedPreferences.getInstance()).setString(
    keyLikes,
    jsonEncode(likes.map((k, v) => MapEntry(k, v.toList()))),
  );

  Future<Map<String, List<Map<String, dynamic>>>> _edits() async {
    final raw = (await SharedPreferences.getInstance()).getString(keyEdits);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).map(
      (k, v) => MapEntry('$k', [for (final e in v as List) Map<String, dynamic>.from(e as Map)]),
    );
  }

  Future<void> _saveEdits(Map<String, List<Map<String, dynamic>>> edits) async =>
      (await SharedPreferences.getInstance()).setString(keyEdits, jsonEncode(edits));

  static Map<String, dynamic> _toJson(CommunityPost p) => {
    'id': p.id,
    'authorId': p.authorId,
    'authorName': p.authorName,
    'authorAvatarUrl': p.authorAvatarUrl,
    'content': p.content,
    'mediaUrls': p.mediaUrls,
    'sport': p.sport?.name,
    'sportName': p.sportName,
    'createdAt': p.createdAt.toIso8601String(),
    'updatedAt': p.updatedAt?.toIso8601String(),
    'isEdited': p.isEdited,
    'likeCount': p.likeCount,
    'commentCount': p.commentCount,
    'status': p.status.apiValue,
    if (p.sharedLfg case final l?)
      'sharedLfg': {
        'id': l.id,
        'sportName': l.sportName,
        'facilityName': l.facilityName,
        'start': l.start?.toIso8601String(),
        'remainingSlots': l.remainingSlots,
        'totalSlots': l.totalSlots,
        'pricePerPerson': l.pricePerPerson,
        'hostTeamName': l.hostTeamName,
        'challengerTeamName': l.challengerTeamName,
      },
  };

  static CommunityPost _fromJson(Map raw) {
    final j = Map<String, dynamic>.from(raw);
    final l = j['sharedLfg'] as Map?;
    return CommunityPost(
      id: j['id'] as String,
      authorId: j['authorId'] as String,
      authorName: j['authorName'] as String,
      authorAvatarUrl: j['authorAvatarUrl'] as String?,
      content: j['content'] as String,
      mediaUrls: [for (final u in j['mediaUrls'] as List? ?? const []) '$u'],
      sport: Sport.values.where((s) => s.name == j['sport']).firstOrNull,
      sportName: j['sportName'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
      isEdited: j['isEdited'] == true,
      likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
      status: PostStatus.fromApi(j['status']),
      sharedLfg: l == null
          ? null
          : SharedLfg(
              id: l['id'] as String,
              sportName: l['sportName'] as String,
              facilityName: l['facilityName'] as String,
              start: l['start'] == null ? null : DateTime.parse(l['start'] as String),
              remainingSlots: (l['remainingSlots'] as num).toInt(),
              totalSlots: (l['totalSlots'] as num).toInt(),
              pricePerPerson: (l['pricePerPerson'] as num).toInt(),
              hostTeamName: l['hostTeamName'] as String?,
              challengerTeamName: l['challengerTeamName'] as String?,
            ),
    );
  }
}
