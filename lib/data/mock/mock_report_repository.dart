import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/report_strings.dart';
import '../../models/player_report.dart';
import '../repositories/report_repository.dart';

/// Bản giả lập [ReportRepository]: lý do mẫu theo BE, khiếu nại lưu trong máy, ảnh giữ đường dẫn trong máy.
class MockReportRepository implements ReportRepository {
  static const String keyReports = 'player_reports_v1';

  final Duration latency;
  final DateTime Function() _now;

  MockReportRepository({this.latency = const Duration(milliseconds: 300), DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const Map<ReportTarget, List<ReportReason>> reasons = {
    ReportTarget.booking: [
      ReportReason(code: 'FACILITY_POOR_QUALITY', title: 'Sân / cơ sở vật chất không đúng mô tả'),
      ReportReason(code: 'OVERBOOKING_OR_CLOSED', title: 'Sân bị trùng lịch hoặc đóng cửa không báo trước'),
      ReportReason(code: 'ATTITUDE_COMPLAINT', title: 'Thái độ phục vụ không tốt'),
      ReportReason(code: 'OTHER', title: 'Lý do khác'),
    ],
    ReportTarget.communityPost: [
      ReportReason(
        code: 'SPAM_OR_INAPPROPRIATE_POST',
        title: 'Bài viết spam / quảng cáo trái phép / nội dung phản cảm',
      ),
      ReportReason(code: 'TOXIC_BEHAVIOR', title: 'Ngôn từ kích động, xúc phạm hoặc quấy rối người chơi khác'),
      ReportReason(code: 'OTHER', title: 'Lý do khác'),
    ],
    ReportTarget.postComment: [
      ReportReason(code: 'INAPPROPRIATE_COMMENT', title: 'Bình luận xúc phạm / spam / nội dung phản cảm'),
      ReportReason(code: 'OTHER', title: 'Lý do khác'),
    ],
    ReportTarget.match: [
      ReportReason(code: 'WRONG_SCORE', title: 'Tỉ số ghi sai'),
      ReportReason(code: 'RULE_VIOLATION', title: 'Đối thủ vi phạm luật thi đấu'),
      ReportReason(code: 'OTHER', title: 'Lý do khác'),
    ],
    ReportTarget.user: [
      ReportReason(code: 'NO_SHOW', title: 'Bùng kèo / không đến'),
      ReportReason(code: 'UNSPORTSMANLIKE', title: 'Hành vi phi thể thao'),
      ReportReason(
        code: 'SKILL_MISREPRESENTATION',
        title: 'Khai gian trình độ',
        description: 'Trình độ thật khác xa trình độ / Elo đã khai.',
      ),
      ReportReason(code: 'OTHER', title: 'Lý do khác'),
    ],
  };

  @override
  Future<List<ReportReason>> getReasons(ReportTarget target) async {
    await _delay();
    return reasons[target] ?? const [];
  }

  @override
  Future<void> create(NewPlayerReport report) async {
    await _delay();
    final text = report.description.trim();
    if (text.length < ReportRepository.minDescription) throw const ReportException(ReportStrings.descriptionTooShort);
    final all = await _load();
    // Như BE: mỗi đơn chỉ một khiếu nại đang mở.
    if (report.bookingId != null &&
        all.any((r) => r.bookingId == report.bookingId && r.status == ReportStatus.pending)) {
      throw const ReportException(ReportStrings.duplicateOpen);
    }
    final reason = reasons[report.target]?.where((r) => r.code == report.reason).firstOrNull;
    all.insert(
      0,
      PlayerReport(
        id: 'rp-${_now().millisecondsSinceEpoch}',
        status: ReportStatus.pending,
        targetType: report.target.apiValue,
        reason: report.reason,
        reasonName: reason?.title,
        description: text,
        bookingId: report.bookingId,
        evidenceImageUrls: report.evidenceImageUrls,
        createdAt: _now(),
      ),
    );
    await _save(all);
  }

  @override
  Future<List<PlayerReport>> getMine() async {
    await _delay();
    return _load();
  }

  @override
  Future<void> withdraw(String reportId) async {
    await _delay();
    final all = await _load();
    final i = all.indexWhere((r) => r.id == reportId);
    if (i < 0 || !all[i].status.canWithdraw) throw const ReportException(ReportStrings.cannotWithdraw);
    all[i] = all[i].withStatus(ReportStatus.withdrawn);
    await _save(all);
  }

  @override
  Future<void> escalate(String reportId, String reason) async {
    await _delay();
    final all = await _load();
    final i = all.indexWhere((r) => r.id == reportId);
    if (i < 0 || !all[i].isMatch || all[i].isEscalatedToAdmin) {
      throw const ReportException(ReportStrings.cannotEscalate);
    }
    all[i] = all[i].escalated();
    await _save(all);
  }

  @override
  Future<String> uploadEvidence(String filePath) async {
    await _delay();
    return filePath;
  }

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<List<PlayerReport>> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(keyReports);
    if (raw == null) return [];
    return [for (final e in jsonDecode(raw) as List) PlayerReport.fromJson(Map<String, dynamic>.from(e as Map))];
  }

  Future<void> _save(List<PlayerReport> all) async =>
      (await SharedPreferences.getInstance()).setString(keyReports, jsonEncode([for (final r in all) r.toJson()]));
}
