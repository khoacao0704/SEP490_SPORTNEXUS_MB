import '../../models/player_report.dart';
import '../api/api_error_codes.dart';

/// Lỗi khiếu nại; [message] sẵn sàng để hiển thị (câu của BE khi gọi API thật).
class ReportException implements Exception, CodedError {
  @override
  final String message;

  @override
  final String? code;

  @override
  final Map<String, dynamic>? detail;

  const ReportException(this.message, {this.code, this.detail});

  ReportException.fromApi(CodedError e) : this(e.message, code: e.code, detail: e.detail);

  @override
  String toString() => 'ReportException: $message';
}

/// Khiếu nại đơn đặt sân / báo cáo người chơi phía Player (như Trung tâm Trợ giúp & Khiếu nại của Web).
abstract class ReportRepository {
  /// Mô tả tối thiểu (như Web).
  static const int minDescription = 10;
  static const int maxDescription = 2000;
  static const int maxImages = 5;

  /// Lý do theo loại đối tượng, lấy từ BE (không tự viết cứng như Web khi BE lỗi).
  Future<List<ReportReason>> getReasons(ReportTarget target);

  /// Gửi khiếu nại / báo cáo. BE kiểm tra quyền (đơn của mình, trùng khiếu nại…) và báo lỗi bằng câu tiếng Việt.
  Future<void> create(NewPlayerReport report);

  /// Khiếu nại / báo cáo của tôi, mới nhất trước.
  Future<List<PlayerReport>> getMine();

  /// Rút khiếu nại đang chờ xử lý.
  Future<void> withdraw(String reportId);

  /// Khiếu nại kết quả trận: không đồng ý với BTC, chuyển Admin phân xử (một lần, [reason] ≤ 1000 ký tự).
  Future<void> escalate(String reportId, String reason);

  /// Tải ảnh bằng chứng lên, trả về link.
  Future<String> uploadEvidence(String filePath);
}
