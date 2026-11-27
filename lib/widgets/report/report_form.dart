import 'package:flutter/material.dart';

import '../../core/strings/report_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/report_repository.dart';
import '../../models/booking.dart';
import '../../models/player_report.dart';
import '../../theme/app_colors.dart';
import '../owner/photo_picker.dart';

/// Form gửi khiếu nại đơn đặt sân ([ReportTarget.booking]) hoặc báo cáo người chơi ([ReportTarget.user]), như Web:
/// lý do lấy từ BE, mô tả ≥ 10 ký tự, ảnh bằng chứng không bắt buộc (tối đa 5). Không có % muốn hoàn.
/// Gửi xong gọi [onSent].
class ReportForm extends StatefulWidget {
  final ReportTarget target;

  /// Khiếu nại đơn: đơn chọn sẵn (mở từ "Đơn của tôi").
  final String? initialBookingId;

  /// Báo cáo người chơi (cũng gửi kèm khi báo cáo bài viết / bình luận: người viết).
  final String? targetUserId;

  /// Báo cáo bài viết / bình luận: mã bài / bình luận.
  final String? targetObjectId;

  final VoidCallback onSent;

  const ReportForm({
    super.key,
    required this.target,
    required this.onSent,
    this.initialBookingId,
    this.targetUserId,
    this.targetObjectId,
  });

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final _description = TextEditingController();
  final List<String> _images = [];
  List<ReportReason>? _reasons;
  bool _reasonsFailed = false;
  List<Booking>? _bookings;
  String? _reason;
  String? _bookingId;
  bool _uploading = false;
  bool _sending = false;

  bool get _isBooking => widget.target == ReportTarget.booking;

  @override
  void initState() {
    super.initState();
    _bookingId = widget.initialBookingId;
    _loadReasons();
    if (_isBooking) _loadBookings();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    setState(() => _reasonsFailed = false);
    try {
      final list = await AppRepositories.report.getReasons(widget.target);
      if (mounted) setState(() => _reasons = list);
    } catch (_) {
      if (mounted) setState(() => _reasonsFailed = true);
    }
  }

  Future<void> _loadBookings() async {
    try {
      final list = await AppRepositories.booking.getMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = list;
        if (_bookingId != null && !list.any((b) => b.id == _bookingId)) _bookingId = null;
      });
    } catch (_) {
      if (mounted) setState(() => _bookings = const []);
    }
  }

  Future<void> _addImages() async {
    final room = ReportRepository.maxImages - _images.length;
    if (room <= 0) return;
    final paths = (await pickPhotoPaths(context)).take(room).toList();
    if (paths.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final urls = await Future.wait(paths.map(AppRepositories.report.uploadEvidence));
      if (mounted) setState(() => _images.addAll(urls));
    } on ReportException catch (e) {
      _error(e.message);
    } catch (_) {
      _error(ReportStrings.uploadError);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final reason = _reason;
    final text = _description.text.trim();
    if (reason == null) return _error(ReportStrings.pickReason);
    if (_isBooking && _bookingId == null) return _error(ReportStrings.pickBooking);
    if (text.length < ReportRepository.minDescription) return _error(ReportStrings.descriptionTooShort);
    setState(() => _sending = true);
    try {
      await AppRepositories.report.create(NewPlayerReport(
        target: widget.target,
        reason: reason,
        description: text,
        bookingId: _isBooking ? _bookingId : null,
        targetUserId: widget.targetUserId,
        targetObjectId: widget.targetObjectId,
        evidenceImageUrls: List.of(_images),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
        content: Text(switch (widget.target) {
          ReportTarget.booking => ReportStrings.complaintSent,
          ReportTarget.user => ReportStrings.reportSent,
          ReportTarget.communityPost => ReportStrings.postReportSent,
          ReportTarget.postComment => ReportStrings.commentReportSent,
          ReportTarget.match => ReportStrings.matchReportSent,
        }),
        backgroundColor: AppColors.primaryGreen,
      ));
      widget.onSent();
    } on ReportException catch (e) {
      _error(e.message);
    } catch (_) {
      _error(ReportStrings.sendError);
    }
    if (mounted) setState(() => _sending = false);
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  static String _bookingLabel(Booking b) =>
      '${b.facilityName}${b.courtName == null ? '' : ' · ${b.courtName}'} '
      '(${Formatters.dateTime(b.start)})';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label(ReportStrings.reasonLabel),
        _buildReasons(),
        if (_reason == 'SKILL_MISREPRESENTATION') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(10)),
            child: const Text(ReportStrings.skillMisrepresentationHint, style: TextStyle(fontSize: 12, height: 1.4)),
          ),
        ],
        if (_isBooking) ...[
          const SizedBox(height: 16),
          _label(ReportStrings.bookingLabel),
          _buildBookingPicker(),
        ],
        const SizedBox(height: 16),
        _label(_isBooking ? ReportStrings.descriptionLabel : ReportStrings.descriptionShortLabel),
        TextField(
          controller: _description,
          maxLines: 4,
          maxLength: ReportRepository.maxDescription,
          decoration: InputDecoration(
            hintText: ReportStrings.descriptionHint,
            hintMaxLines: 3,
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        _label(ReportStrings.evidenceLabel(ReportRepository.maxImages)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final url in _images)
              Stack(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: OwnerImage(url, width: 72, height: 72)),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => setState(() => _images.remove(url)),
                      child: Tooltip(
                        message: ReportStrings.removeImage,
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (_images.length < ReportRepository.maxImages)
              OutlinedButton.icon(
                onPressed: _uploading ? null : _addImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_uploading ? ReportStrings.uploading : ReportStrings.addImage),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sending || _uploading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBooking ? AppColors.primaryGreen : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _sending
                  ? ReportStrings.sending
                  : _isBooking
                      ? ReportStrings.submitComplaint
                      : ReportStrings.submitReport,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasons() {
    final reasons = _reasons;
    if (_reasonsFailed || (reasons != null && reasons.isEmpty)) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(ReportStrings.reasonsError, style: TextStyle(fontSize: 12, color: Colors.red)),
          TextButton(onPressed: _loadReasons, child: const Text(ReportStrings.retry)),
        ],
      );
    }
    if (reasons == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: RadioGroup<String>(
        groupValue: _reason,
        onChanged: (v) => setState(() => _reason = v),
        child: Column(
          children: [
            for (final r in reasons)
              RadioListTile<String>(
                value: r.code,
                dense: true,
                title: Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: r.description == null ? null : Text(r.description!, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingPicker() {
    final bookings = _bookings;
    if (bookings == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (bookings.isEmpty) {
      return const Text(ReportStrings.noBookings, style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    }
    return DropdownButtonFormField<String>(
      initialValue: _bookingId,
      isExpanded: true,
      hint: const Text(ReportStrings.bookingHint),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        for (final b in bookings)
          DropdownMenuItem(
            value: b.id,
            child: Text(_bookingLabel(b), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
      ],
      selectedItemBuilder: (_) => [
        for (final b in bookings) Text(_bookingLabel(b), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
      onChanged: (v) => setState(() => _bookingId = v),
    );
  }

  static Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
      );
}
