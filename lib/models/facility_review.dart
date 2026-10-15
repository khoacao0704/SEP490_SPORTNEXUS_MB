import 'sport.dart';

/// Lý do Chủ sân báo cáo một đánh giá lên Admin.
enum ReportReason {
  offensive('Offensive', 'Ngôn từ tục tĩu, xúc phạm'),
  falseInfo('FalseInfo', 'Sai sự thật, bịa đặt'),
  spam('Spam', 'Spam / quảng cáo');

  const ReportReason(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ReportReason fromApi(String value) => values.firstWhere((r) => r.apiValue == value);
}

/// Kết quả Admin xử lý báo cáo.
enum ReportStatus {
  pending('Pending'),

  /// Admin thấy không vi phạm, giữ đánh giá.
  kept('Kept'),

  /// Admin ẩn đánh giá: không hiện cho người chơi, không tính vào điểm trung bình.
  hidden('Hidden');

  const ReportStatus(this.apiValue);

  final String apiValue;

  static ReportStatus fromApi(String value) => values.firstWhere((s) => s.apiValue == value);
}

class ReviewReport {
  final ReportReason reason;
  final String note;
  final ReportStatus status;
  final DateTime createdAt;

  const ReviewReport({required this.reason, required this.createdAt, this.note = '', this.status = ReportStatus.pending});

  factory ReviewReport.fromJson(Map<String, dynamic> json) => ReviewReport(
        reason: ReportReason.fromApi(json['reason'] as String),
        note: json['note'] as String? ?? '',
        status: ReportStatus.fromApi(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Câu trả lời công khai của Chủ sân (một câu cho mỗi đánh giá, sửa được).
class ReviewReply {
  final String text;
  final DateTime updatedAt;

  const ReviewReply({required this.text, required this.updatedAt});

  factory ReviewReply.fromJson(Map<String, dynamic> json) =>
      ReviewReply(text: json['text'] as String, updatedAt: DateTime.parse(json['updatedAt'] as String));
}

/// Đánh giá người chơi chấm cho cơ sở. Ẩn danh: không có tên người chấm.
class FacilityReview {
  final String id;
  final String facilityId;
  final String facilityName;
  final Sport sport;
  final int stars;
  final String comment;
  final DateTime createdAt;
  final ReviewReply? reply;
  final ReviewReport? report;

  const FacilityReview({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.sport,
    required this.stars,
    required this.createdAt,
    this.comment = '',
    this.reply,
    this.report,
  });

  bool get isHidden => report?.status == ReportStatus.hidden;

  /// Đã báo cáo thì không báo cáo lại; bị ẩn thì không trả lời nữa.
  bool get canReport => report == null;
  bool get canReply => !isHidden;

  FacilityReview copyWith({ReviewReply? reply, ReviewReport? report}) => FacilityReview(
        id: id,
        facilityId: facilityId,
        facilityName: facilityName,
        sport: sport,
        stars: stars,
        comment: comment,
        createdAt: createdAt,
        reply: reply ?? this.reply,
        report: report ?? this.report,
      );

  factory FacilityReview.fromJson(Map<String, dynamic> json) => FacilityReview(
        id: json['id'] as String,
        facilityId: json['facilityId'] as String,
        facilityName: json['facilityName'] as String,
        sport: Sport.fromApi(json['sport'] as String),
        stars: (json['stars'] as num).toInt(),
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        reply: json['reply'] == null ? null : ReviewReply.fromJson(json['reply'] as Map<String, dynamic>),
        report: json['report'] == null ? null : ReviewReport.fromJson(json['report'] as Map<String, dynamic>),
      );
}

/// Tổng hợp đánh giá (không tính đánh giá Admin đã ẩn).
class ReviewSummary {
  final List<FacilityReview> reviews;

  const ReviewSummary(this.reviews);

  List<FacilityReview> get _visible => reviews.where((r) => !r.isHidden).toList();

  int get count => _visible.length;

  double get average => count == 0 ? 0 : _visible.fold(0, (s, r) => s + r.stars) / count;

  /// Số đánh giá theo sao, chỉ số 0 = 1 sao.
  List<int> get distribution {
    final d = List.filled(5, 0);
    for (final r in _visible) {
      d[r.stars - 1]++;
    }
    return d;
  }

  int get unreplied => _visible.where((r) => r.reply == null).length;
}
