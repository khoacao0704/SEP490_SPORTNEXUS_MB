import 'package:flutter/material.dart';

import '../../widgets/common/text_prompt_dialog.dart';

import '../../core/strings/report_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/report_repository.dart';
import '../../models/player_report.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/photo_picker.dart';
import '../../widgets/report/report_form.dart';

/// Trợ giúp & Khiếu nại (như Trung tâm Trợ giúp & Khiếu nại ở Hồ sơ của Web): tab Gửi khiếu nại (đơn đặt sân)
/// và tab Khiếu nại của tôi (xem trạng thái, kết quả, rút khi đang chờ xử lý).
/// [initialBookingId]: mở từ "Đơn của tôi" với đơn chọn sẵn.
class SupportCenterScreen extends StatefulWidget {
  final String? initialBookingId;

  /// Mở thẳng tab Khiếu nại của tôi.
  final bool openMine;

  const SupportCenterScreen({super.key, this.initialBookingId, this.openMine = false});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.openMine ? 1 : 0);
  List<PlayerReport>? _reports;
  bool _failed = false;
  String? _withdrawingId;

  /// Đổi key để form gửi khiếu nại trống lại sau khi gửi.
  int _formKey = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final list = await AppRepositories.report.getMine();
      if (mounted) setState(() => _reports = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onSent() {
    setState(() => _formKey++);
    _tabs.animateTo(1);
    _load();
  }

  /// Không đồng ý với quyết định của BTC: nhập lý do (≤ 1000 ký tự) rồi chuyển Admin, một lần.
  Future<void> _escalate(PlayerReport r) async {
    final reason = await showTextPrompt(
      context,
      title: ReportStrings.escalate,
      hint: ReportStrings.escalateHint,
      confirm: ReportStrings.escalateSend,
      cancel: ReportStrings.keep,
      maxLength: 1000,
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (reason.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text(ReportStrings.escalateReasonRequired), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      await AppRepositories.report.escalate(r.id, reason);
      messenger.showSnackBar(const SnackBar(content: Text(ReportStrings.escalated)));
    } on ReportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
    await _load();
  }

  Future<void> _withdraw(PlayerReport r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ReportStrings.withdraw),
        content: const Text(ReportStrings.withdrawConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(ReportStrings.keep)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(ReportStrings.withdraw),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _withdrawingId = r.id);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await AppRepositories.report.withdraw(r.id);
      messenger.showSnackBar(const SnackBar(content: Text(ReportStrings.withdrawn)));
    } on ReportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(ReportStrings.loadError), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _withdrawingId = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          ReportStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          tabs: [
            const Tab(text: ReportStrings.tabCreate),
            Tab(text: ReportStrings.tabMine(_reports?.length ?? 0)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ReportForm(
            key: ValueKey(_formKey),
            target: ReportTarget.booking,
            initialBookingId: _formKey == 0 ? widget.initialBookingId : null,
            onSent: _onSent,
          ),
          _buildMine(),
        ],
      ),
    );
  }

  Widget _buildMine() {
    final reports = _reports;
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(ReportStrings.loadError, style: TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text(ReportStrings.retry)),
          ],
        ),
      );
    }
    if (reports == null) return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.flag_outlined, size: 56, color: AppColors.cardBorder),
                  SizedBox(height: 12),
                  Text(ReportStrings.mineEmpty, style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                    ReportStrings.mineEmptyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            for (final r in reports) _buildReport(r),
        ],
      ),
    );
  }

  static ({Color bg, Color fg}) _statusColors(ReportStatus s) => switch (s) {
    ReportStatus.pending || ReportStatus.unknown => (bg: AppColors.tagOrangeBg, fg: AppColors.tagOrangeText),
    ReportStatus.ownerResponded => (bg: const Color(0xFFE0F2FE), fg: const Color(0xFF0369A1)),
    ReportStatus.resolvedRefunded ||
    ReportStatus.resolvedNoRefund ||
    ReportStatus.resolved => (bg: AppColors.tagGreenBg, fg: AppColors.tagGreenText),
    ReportStatus.rejected => (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFDC2626)),
    ReportStatus.withdrawn => (bg: AppColors.divider, fg: AppColors.textSecondary),
  };

  Widget _buildReport(PlayerReport r) {
    final colors = _statusColors(r.status);
    Widget note(String label, String value, Color color) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ReportStrings.reportCode(r.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    Text(
                      Formatters.dateTime(r.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    r.status.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.fg),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: ReportStrings.reasonPrefix,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: r.reasonName ?? r.reason),
              ],
            ),
            style: const TextStyle(fontSize: 13),
          ),
          if (r.facilityName != null)
            Text(
              '${r.facilityName}${r.courtName == null ? '' : ' · ${r.courtName}'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          if (r.bookingId != null)
            Text(
              ReportStrings.bookingRef(r.bookingId!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          if (r.targetUserName != null)
            Text(
              ReportStrings.reportedUser(r.targetUserName!),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 6),
          Text('“${r.description}”', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
          if (r.evidenceImageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final url in r.evidenceImageUrls)
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: OwnerImage(url, width: 56, height: 56)),
              ],
            ),
          ],
          if (r.refereeNote != null) note(ReportStrings.refereeNote, r.refereeNote!, const Color(0xFFF5F3FF)),
          if (r.organizerDecisionNote != null)
            note(ReportStrings.organizerDecision, r.organizerDecisionNote!, const Color(0xFFFFFBEB)),
          if (r.isEscalatedToAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                r.escalationClosedAt != null ? ReportStrings.escalatedClosed : ReportStrings.escalatedWaiting,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
              ),
            ),
          if (r.canEscalateAt(DateTime.now()))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _escalate(r),
                icon: const Icon(Icons.gavel_outlined, size: 16),
                label: const Text(ReportStrings.escalate),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF6D28D9)),
              ),
            ),
          if (r.ownerResponse != null) note(ReportStrings.ownerResponse, r.ownerResponse!, const Color(0xFFEFF6FF)),
          if (r.resolution != null) note(ReportStrings.resolution, r.resolution!, const Color(0xFFF0FDF4)),
          if ((r.refundedAmount ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                ReportStrings.refunded(r.refundedAmount!),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
              ),
            ),
          if (r.status.canWithdraw) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _withdrawingId == null ? () => _withdraw(r) : null,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text(ReportStrings.withdraw),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Báo cáo bài viết / bình luận trên Bảng tin (ReportModal của Web, targetType COMMUNITY_POST / POST_COMMENT).
/// Pop `true` khi đã gửi.
class ReportContentScreen extends StatelessWidget {
  final ReportTarget target;
  final String title;
  final String subject;
  final String objectId;
  final String? authorId;

  const ReportContentScreen({
    super.key,
    required this.target,
    required this.title,
    required this.subject,
    required this.objectId,
    this.authorId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ReportForm(
        target: target,
        targetObjectId: objectId,
        targetUserId: authorId,
        onSent: () => Navigator.pop(context, true),
      ),
    );
  }
}

/// Báo cáo một người chơi (như ReportModal của Web, targetType USER). Pop `true` khi đã gửi.
class ReportPlayerScreen extends StatelessWidget {
  final String userId;
  final String name;

  const ReportPlayerScreen({super.key, required this.userId, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              ReportStrings.reportPlayerTitle,
              style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
      body: ReportForm(target: ReportTarget.user, targetUserId: userId, onSent: () => Navigator.pop(context, true)),
    );
  }
}
