import 'package:flutter/material.dart';

import '../../core/strings/community_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/community_repository.dart';
import '../../models/community_post.dart';
import '../../screens/lfg/lfg_match_detail_screen.dart';
import '../../theme/app_colors.dart';
import '../owner/photo_picker.dart' show OwnerImage;
import '../../models/player_report.dart';
import '../../screens/report/support_center_screen.dart';
import 'comments_sheet.dart';

/// Một bài viết trên Bảng tin (như thẻ bài viết của Web): người đăng (bấm để xem bài của họ), giờ đăng, đã sửa +
/// lịch sử sửa, nhãn Đã xóa / Bị Admin ẩn, nội dung, ảnh, kèo / giải đính kèm, like, số bình luận.
/// Bài của mình: Sửa nội dung, Xóa.
class PostCard extends StatefulWidget {
  final CommunityPost post;
  final DateTime now;
  final void Function(String authorId, String authorName)? onAuthor;
  final ValueChanged<CommunityPost> onChanged;
  final ValueChanged<String> onRemoved;

  const PostCard({
    super.key,
    required this.post,
    required this.now,
    required this.onChanged,
    required this.onRemoved,
    this.onAuthor,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  TextEditingController? _editing;
  bool _saving = false;
  late bool _liked = widget.post.isLikedByMe;
  late int _likes = widget.post.likeCount;

  /// Số bình luận sau khi mở phần bình luận (thêm / xóa cập nhật ngay trên thẻ).
  int? _commentCount;

  void _openComments() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.9,
          child: CommentsSheet(
            post: widget.post,
            onCountChanged: (n) {
              if (mounted) setState(() => _commentCount = n);
            },
          ),
        ),
      );

  void _report() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportContentScreen(
            target: ReportTarget.communityPost,
            title: CommunityStrings.reportPostTitle,
            subject: widget.post.authorName,
            objectId: widget.post.id,
            authorId: widget.post.authorId,
          ),
        ),
      );

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    if (old.post != widget.post) {
      _liked = widget.post.isLikedByMe;
      _likes = widget.post.likeCount;
    }
  }

  @override
  void dispose() {
    _editing?.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null));
  }

  /// Like ngay trên màn rồi gửi BE; lỗi thì trả lại như cũ (như Web).
  Future<void> _toggleLike() async {
    final next = !_liked;
    setState(() {
      _liked = next;
      _likes += next ? 1 : -1;
    });
    try {
      final count = await AppRepositories.community.setLiked(widget.post.id, next);
      if (count != null && mounted) setState(() => _likes = count);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = !next;
        _likes += next ? -1 : 1;
      });
      _snack(e is CommunityException ? e.message : CommunityStrings.actionError, error: true);
    }
  }

  Future<void> _save() async {
    final text = _editing!.text.trim();
    if (text.isEmpty) return _snack(CommunityStrings.contentRequired, error: true);
    setState(() => _saving = true);
    try {
      final updated = await AppRepositories.community.updatePost(widget.post.id, text);
      if (!mounted) return;
      setState(() {
        _editing?.dispose();
        _editing = null;
      });
      _snack(CommunityStrings.saved);
      widget.onChanged(updated);
    } catch (e) {
      _snack(e is CommunityException ? e.message : CommunityStrings.saveError, error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(CommunityStrings.deleteConfirm),
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
      await AppRepositories.community.deletePost(widget.post.id);
      _snack(CommunityStrings.deleted);
      widget.onRemoved(widget.post.id);
    } catch (e) {
      _snack(e is CommunityException ? e.message : CommunityStrings.deleteError, error: true);
    }
  }

  void _showHistory() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => FractionallySizedBox(heightFactor: 0.7, child: PostEditHistory(postId: widget.post.id)),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final editing = _editing;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(p),
          const SizedBox(height: 10),
          if (editing != null) ...[
            TextField(
              controller: editing,
              maxLines: 6,
              minLines: 2,
              maxLength: CommunityRepository.maxContent,
              decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _editing?.dispose();
                            _editing = null;
                          }),
                  child: const Text(CommunityStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                  child: const Text(CommunityStrings.save),
                ),
              ],
            ),
          ] else
            Text(p.content, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textMain)),
          if (p.mediaUrls.isNotEmpty) ...[const SizedBox(height: 10), _buildImages(p.mediaUrls)],
          if (p.sharedLfg != null) ...[const SizedBox(height: 10), _buildLfg(p.sharedLfg!)],
          if (p.sharedTournament != null) ...[const SizedBox(height: 10), _buildTournament(p.sharedTournament!)],
          if (!p.isRemoved) ...[
            const Divider(height: 20, color: AppColors.divider),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _toggleLike,
                  icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, size: 18),
                  label: Text('$_likes'),
                  style: TextButton.styleFrom(
                    foregroundColor: _liked ? Colors.red : AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: TextButton.icon(
                    onPressed: _openComments,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Text(CommunityStrings.comments(_commentCount ?? p.commentCount),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(CommunityPost p) {
    final meta = [
      CommunityStrings.timeAgo(p.createdAt, widget.now),
      if (p.isEdited) CommunityStrings.edited,
      ?p.sport?.label ?? p.sportName,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryGreen,
          backgroundImage: p.authorAvatarUrl == null ? null : NetworkImage(p.authorAvatarUrl!),
          child: p.authorAvatarUrl != null
              ? null
              : Text(
                  p.authorName.isEmpty ? '?' : p.authorName.characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: widget.onAuthor == null ? null : () => widget.onAuthor!(p.authorId, p.authorName),
                child: Text(p.authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
              ),
              Text(meta, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (p.isEdited)
                InkWell(
                  onTap: _showHistory,
                  child: const Text(CommunityStrings.editHistory,
                      style: TextStyle(fontSize: 12, color: AppColors.primaryGreen, decoration: TextDecoration.underline)),
                ),
              if (p.isRemoved) ...[
                const SizedBox(height: 4),
                _badge(p.status == PostStatus.hidden ? CommunityStrings.hiddenBadge : CommunityStrings.deletedBadge,
                    p.status == PostStatus.hidden),
                if (p.hiddenReason != null)
                  Text(CommunityStrings.hiddenReason(p.hiddenReason!),
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
              ],
            ],
          ),
        ),
        if (p.isMine && !p.isRemoved && _editing == null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (v) {
              if (v == 'edit') setState(() => _editing = TextEditingController(text: p.content));
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text(CommunityStrings.edit)),
              PopupMenuItem(value: 'delete', child: Text(CommunityStrings.delete, style: TextStyle(color: Colors.red))),
            ],
          )
        else if (!p.isMine && !p.isRemoved)
          IconButton(
            tooltip: CommunityStrings.report,
            onPressed: _report,
            icon: const Icon(Icons.flag_outlined, color: AppColors.textSecondary, size: 20),
          ),
      ],
    );
  }

  static Widget _badge(String text, bool red) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: red ? const Color(0xFFFEE2E2) : AppColors.divider,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: red ? Colors.red : AppColors.textSecondary)),
      );

  /// Ảnh: 1 ảnh to; nhiều ảnh xếp lưới 2–3 cột, tối đa 6 (như Web). Bấm để xem to.
  Widget _buildImages(List<String> urls) {
    final shown = urls.take(6).toList();
    return LayoutBuilder(
      builder: (context, c) {
        final cols = shown.length == 1 ? 1 : (shown.length == 2 || shown.length == 4 ? 2 : 3);
        const gap = 6.0;
        final size = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final url in shown)
              GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(child: InteractiveViewer(child: OwnerImage(url, fit: BoxFit.contain))),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: OwnerImage(url, width: size, height: cols == 1 ? size * 0.6 : size),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLfg(SharedLfg l) {
    final when = l.start == null ? '' : Formatters.dateTime(l.start!);
    return Material(
      color: AppColors.lightGreen,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: l.id.isEmpty
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => LfgMatchDetailScreen(matchId: l.id))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(Icons.group, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.isTeamMatch
                          ? CommunityStrings.teamTitle(l.hostTeamName!, l.challengerTeamName, l.sportName)
                          : CommunityStrings.lfgTitle(l.sportName),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                    ),
                    Text(
                      CommunityStrings.lfgDetail(l.facilityName, when, l.remainingSlots, l.totalSlots, l.pricePerPerson),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  /// Giải đấu đính kèm: chỉ hiện thông tin (mobile chưa làm giải đấu).
  Widget _buildTournament(SharedTournament t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.tagOrangeBg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: AppColors.tagOrangeText),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(CommunityStrings.tournamentTitle(t.name),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.tagOrangeText)),
                  Text(CommunityStrings.tournamentDetail(t.facilityName, t.entryFee),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Lịch sử sửa của một bài: nội dung trước mỗi lần sửa.
class PostEditHistory extends StatelessWidget {
  final String postId;

  const PostEditHistory({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(CommunityStrings.historyTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<PostEdit>>(
                future: AppRepositories.community.getPostEdits(postId),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
                  }
                  if (snap.hasError) {
                    final e = snap.error;
                    return Text(e is CommunityException ? e.message : CommunityStrings.loadError,
                        style: const TextStyle(color: AppColors.textSecondary));
                  }
                  final list = snap.data ?? const [];
                  if (list.isEmpty) {
                    return const Text(CommunityStrings.historyEmpty, style: TextStyle(color: AppColors.textSecondary));
                  }
                  return ListView(
                    children: [
                      for (final h in list)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(CommunityStrings.historyItem(Formatters.dateTime(h.editedAt)),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
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
}
