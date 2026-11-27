import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/community_strings.dart';
import '../../core/strings/report_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/community_repository.dart';
import '../../models/community_post.dart';
import '../../models/player_report.dart';
import '../../screens/report/support_center_screen.dart';
import '../../theme/app_colors.dart';

/// Like bình luận giống Web: BE chưa có API nên chỉ lưu trong máy (chỉ mình thấy, đổi máy là mất).
class CommentLikeStore {
  static const String key = 'community_comment_likes_v1';

  static Future<Map<String, ({int count, bool liked})>> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).map(
      (k, v) => MapEntry('$k', (count: ((v as Map)['count'] as num).toInt(), liked: v['liked'] == true)),
    );
  }

  static Future<({int count, bool liked})> toggle(String commentId) async {
    final all = await read();
    final prev = all[commentId] ?? (count: 0, liked: false);
    final next = (count: (prev.count + (prev.liked ? -1 : 1)).clamp(0, 1 << 30), liked: !prev.liked);
    all[commentId] = next;
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(all.map((k, v) => MapEntry(k, {'count': v.count, 'liked': v.liked}))),
    );
    return next;
  }
}

/// Nội dung bình luận có tô màu các thẻ tag "@Tên" (ưu tiên tên trong [names], như Web).
class MentionText extends StatelessWidget {
  final String text;
  final List<String> names;

  const MentionText(this.text, {super.key, this.names = const []});

  @override
  Widget build(BuildContext context) {
    final escaped = [...names]..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(
      escaped.isEmpty
          ? r'@[\p{L}\p{N}_.-]+'
          : '@(?:${escaped.map(RegExp.escape).join('|')})|@[\\p{L}\\p{N}_.-]+',
      unicode: true,
    );
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
        text: m.group(0),
        style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.4));
  }
}

/// Phần bình luận của một bài (Comments của Web): viết / trả lời, gõ @ để tag người chơi (đồng đội + người đã
/// bình luận), like bình luận (chỉ lưu trong máy như Web), sửa trong 15 phút, xóa, lịch sử sửa, báo cáo.
/// [onCountChanged] báo số bình luận mới để thẻ bài cập nhật.
class CommentsSheet extends StatefulWidget {
  final CommunityPost post;
  final ValueChanged<int> onCountChanged;

  const CommentsSheet({super.key, required this.post, required this.onCountChanged});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  List<PostComment>? _comments;
  bool _failed = false;
  bool _sending = false;
  PostComment? _replyTo;
  String? _editingId;
  final _editController = TextEditingController();
  Map<String, ({int count, bool liked})> _likes = {};
  List<String> _teammates = const [];
  String? _mentionQuery;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInput);
    _load();
    _loadTeammates();
    CommentLikeStore.read().then((v) {
      if (mounted) setState(() => _likes = v);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _editController.dispose();
    super.dispose();
  }

  int get _count => (_comments ?? const []).fold(0, (sum, c) => sum + 1 + c.replies.length);

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final list = await AppRepositories.community.getComments(widget.post.id);
      if (!mounted) return;
      setState(() => _comments = list);
      widget.onCountChanged(_count);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Đồng đội trong các đội của mình (như Web) để gợi ý khi tag.
  Future<void> _loadTeammates() async {
    try {
      final me = await AppRepositories.auth.getCurrentUser();
      final teams = await AppRepositories.team.getMyTeams();
      final names = {
        for (final t in teams)
          for (final m in t.members)
            if (m.accountId != me?.id && m.fullName.trim().isNotEmpty) m.fullName.trim(),
      };
      if (mounted) setState(() => _teammates = names.toList());
    } catch (_) {
      // Không tải được đội: vẫn gợi ý người đã bình luận.
    }
  }

  /// Người có thể tag: đồng đội + người viết bài + người đã bình luận.
  List<String> get _candidates {
    final names = <String>{..._teammates, widget.post.authorName};
    for (final c in _comments ?? const <PostComment>[]) {
      names.add(c.userName);
      for (final r in c.replies) {
        names.add(r.userName);
      }
    }
    names.removeWhere((n) => n.trim().isEmpty);
    return names.toList();
  }

  void _onInput() {
    final sel = _input.selection;
    final before = sel.isValid ? _input.text.substring(0, sel.baseOffset) : _input.text;
    final m = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(before);
    final q = m?.group(1)?.toLowerCase();
    if (q != _mentionQuery) setState(() => _mentionQuery = q);
  }

  void _insertMention(String name) {
    final sel = _input.selection;
    final caret = sel.isValid ? sel.baseOffset : _input.text.length;
    final before = _input.text.substring(0, caret).replaceFirst(RegExp(r'@[^\s@]*$'), '@$name ');
    final after = _input.text.substring(caret);
    _input.value = TextEditingValue(text: '$before$after', selection: TextSelection.collapsed(offset: before.length));
    setState(() => _mentionQuery = null);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null));
  }

  String _error(Object e, String fallback) => e is CommunityException ? e.message : fallback;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return _snack(CommunityStrings.commentRequired, error: true);
    setState(() => _sending = true);
    try {
      await AppRepositories.community.addComment(widget.post.id, text, parentId: _replyTo?.id);
      _input.clear();
      setState(() => _replyTo = null);
      await _load();
    } catch (e) {
      _snack(_error(e, CommunityStrings.commentError), error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _saveEdit(PostComment c) async {
    final text = _editController.text.trim();
    if (text.isEmpty) return _snack(CommunityStrings.commentRequired, error: true);
    try {
      await AppRepositories.community.updateComment(c.id, text);
      setState(() => _editingId = null);
      _snack(CommunityStrings.commentSaved);
      await _load();
    } catch (e) {
      _snack(_error(e, CommunityStrings.actionError), error: true);
    }
  }

  Future<void> _delete(PostComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(CommunityStrings.commentDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(CommunityStrings.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(CommunityStrings.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppRepositories.community.deleteComment(c.id);
      _snack(CommunityStrings.commentDeleted);
      await _load();
    } catch (e) {
      _snack(_error(e, CommunityStrings.actionError), error: true);
    }
  }

  Future<void> _toggleLike(PostComment c) async {
    final next = await CommentLikeStore.toggle(c.id);
    if (mounted) setState(() => _likes = {..._likes, c.id: next});
  }

  void _report(PostComment c) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportContentScreen(
            target: ReportTarget.postComment,
            title: CommunityStrings.reportCommentTitle,
            subject: c.userName,
            objectId: c.id,
            authorId: c.userId,
          ),
        ),
      );

  void _history(PostComment c) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.6,
          child: _CommentHistory(commentId: c.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final comments = _comments;
    final now = DateTime.now();
    final names = _candidates;
    final suggestions = _mentionQuery == null
        ? const <String>[]
        : names.where((n) => n.toLowerCase().contains(_mentionQuery!)).take(5).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${CommunityStrings.commentsTitle} (${comments == null ? widget.post.commentCount : _count})',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: _failed
                  ? Center(child: TextButton(onPressed: _load, child: const Text(CommunityStrings.retry)))
                  : comments == null
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                      : comments.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(CommunityStrings.noComments,
                                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              children: [
                                for (final c in comments) ...[
                                  _buildComment(c, now, names),
                                  for (final r in c.replies)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 36),
                                      child: _buildComment(r, now, names, parent: c),
                                    ),
                                ],
                              ],
                            ),
            ),
            if (suggestions.isNotEmpty)
              Material(
                color: AppColors.white,
                shape: const Border(top: BorderSide(color: AppColors.divider)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final n in suggestions)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.alternate_email, size: 18, color: AppColors.primaryGreen),
                        title: Text(n),
                        onTap: () => _insertMention(n),
                      ),
                  ],
                  ),
                ),
              ),
            if (_replyTo != null)
              Container(
                width: double.infinity,
                color: AppColors.lightGreen,
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(CommunityStrings.replyHint(_replyTo!.userName),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _replyTo = null),
                      child: const Text(CommunityStrings.cancelReply),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _replyTo == null ? CommunityStrings.commentHint : CommunityStrings.replyHint(_replyTo!.userName),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: CommunityStrings.send,
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send, color: AppColors.primaryGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComment(PostComment c, DateTime now, List<String> names, {PostComment? parent}) {
    final like = _likes[c.id] ?? (count: 0, liked: false);
    final editing = _editingId == c.id;
    final meta = [CommunityStrings.timeAgo(c.createdAt, now), if (c.isEdited) CommunityStrings.edited].join(' · ');
    Widget action(String label, VoidCallback onTap, {Color? color}) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? AppColors.textSecondary)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.lightGreen,
            backgroundImage: c.userAvatarUrl == null ? null : NetworkImage(c.userAvatarUrl!),
            child: c.userAvatarUrl != null
                ? null
                : Text(c.userName.isEmpty ? '?' : c.userName.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      if (editing) ...[
                        TextField(
                          controller: _editController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(isDense: true),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _editingId = null),
                              child: const Text(CommunityStrings.cancel),
                            ),
                            TextButton(onPressed: () => _saveEdit(c), child: const Text(CommunityStrings.save)),
                          ],
                        ),
                      ] else
                        MentionText(c.content, names: names),
                    ],
                  ),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 6, right: 4),
                      child: Text(meta, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    InkWell(
                      onTap: () => _toggleLike(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(like.liked ? Icons.favorite : Icons.favorite_border,
                                size: 14, color: like.liked ? Colors.red : AppColors.textSecondary),
                            if (like.count > 0) ...[
                              const SizedBox(width: 2),
                              Text('${like.count}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Trả lời một trả lời thì vẫn gắn vào bình luận gốc (một cấp như Web).
                    action(CommunityStrings.reply, () {
                      setState(() => _replyTo = parent ?? c);
                      if (parent != null && !_input.text.contains('@${c.userName}')) {
                        _input.text = '@${c.userName} ${_input.text}';
                      }
                      _focus.requestFocus();
                    }),
                    if (c.editableAt(now) && !editing)
                      action(CommunityStrings.edit, () {
                        _editController.text = c.content;
                        setState(() => _editingId = c.id);
                      }),
                    if (c.isMine) action(CommunityStrings.delete, () => _delete(c), color: Colors.red),
                    if (c.isEdited) action(CommunityStrings.editHistory, () => _history(c), color: AppColors.primaryGreen),
                    if (!c.isMine) action(ReportStrings.reportPlayer, () => _report(c), color: Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentHistory extends StatelessWidget {
  final String commentId;

  const _CommentHistory({required this.commentId});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(CommunityStrings.historyTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<PostEdit>>(
                  future: AppRepositories.community.getCommentEdits(commentId),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
                    }
                    final list = snap.data ?? const [];
                    if (snap.hasError || list.isEmpty) {
                      return const Text(CommunityStrings.historyEmpty, style: TextStyle(color: AppColors.textSecondary));
                    }
                    return ListView(
                      children: [
                        for (final h in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(CommunityStrings.historyItem(Formatters.dateTime(h.editedAt)),
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(h.oldContent, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}
