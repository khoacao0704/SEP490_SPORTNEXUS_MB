import '../../core/strings/report_strings.dart';
import '../../models/player_report.dart';
import '../repositories/report_repository.dart';
import 'api_client.dart';

/// [ReportRepository] gọi Backend thật (cùng API Web dùng ở Trung tâm Trợ giúp & Khiếu nại):
/// - GET /reports/reasons?targetType=BOOKING|USER → [{code, targetType, title, description, …}]
/// - POST /reports {targetType, bookingId, targetUserId, reason, description, evidenceImageUrls,
///   requestedRefundPercentage: 0}. Không có % muốn hoàn (như Web).
/// - GET /reports/my-reports → mảng hoặc {items}; POST /reports/{id}/withdraw {note}.
/// - Ảnh: POST /uploads/images?purpose=report (field `file`) → url.
class ApiReportRepository implements ReportRepository {
  static const String reportsPath = '/api/v1/reports';
  static const String reasonsPath = '/api/v1/reports/reasons';
  static const String minePath = '/api/v1/reports/my-reports';
  static String withdrawPath(String id) => '/api/v1/reports/$id/withdraw';
  static const String uploadPath = '/api/v1/uploads/images';

  final ApiClient _api;

  ApiReportRepository({required this._api});

  @override
  Future<List<ReportReason>> getReasons(ReportTarget target) async {
    final data = await _call(() => _api.get(reasonsPath, query: {'targetType': target.apiValue}));
    return [
      for (final r in _list(data))
        if (ReportReason.fromJson(r) case final reason when reason.code.isNotEmpty) reason,
    ];
  }

  @override
  Future<void> create(NewPlayerReport report) => _call(
    () => _api.post(
      reportsPath,
      body: {
        'targetType': report.target.apiValue,
        'bookingId': report.bookingId,
        'facilityId': null,
        'targetUserId': report.targetUserId,
        'targetObjectId': report.targetObjectId,
        'reason': report.reason,
        'description': report.description.trim(),
        'evidenceImageUrls': report.evidenceImageUrls,
        'requestedRefundPercentage': 0,
      },
    ),
  );

  @override
  Future<List<PlayerReport>> getMine() async {
    final data = await _call(() => _api.get(minePath));
    return [for (final r in _list(data)) PlayerReport.fromJson(r)]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> withdraw(String reportId) =>
      _call(() => _api.post(withdrawPath(reportId), body: const {'note': ReportStrings.withdrawNote}));

  static String escalatePath(String id) => '/api/v1/match-complaints/$id/escalate';

  /// POST /match-complaints/{id}/escalate {reason}.
  @override
  Future<void> escalate(String reportId, String reason) =>
      _call(() => _api.post(escalatePath(reportId), body: {'reason': reason.trim()}));

  @override
  Future<String> uploadEvidence(String filePath) async {
    final data = await _call(() => _api.upload(uploadPath, filePath: filePath, query: const {'purpose': 'report'}));
    final url = data is String ? data : (data is Map ? (data['url'] ?? data['imageUrl']) : null);
    if (url == null || '$url'.isEmpty) throw const ReportException(ReportStrings.uploadError);
    return '$url';
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
      throw ReportException.fromApi(e);
    }
  }
}
