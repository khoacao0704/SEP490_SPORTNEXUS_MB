/// Lý do Chủ sân báo cáo một đánh giá lên Admin (chỉ có trên mobile, BE chưa có API).
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
}

/// Đánh giá của khách về cơ sở của Chủ sân (GET /owner/facility-reviews, các trường như Web đọc).
class FacilityReview {
  final String id;
  final String facilityId;
  final String facilityName;
  final String userName;
  final String? userAvatarUrl;
  final int rating;
  final String comment;
  final DateTime createdAt;

  /// Mỗi đánh giá chỉ có một phản hồi: lần đầu gửi, sau đó sửa / xóa.
  final String? ownerReply;
  final DateTime? repliedAt;

  /// Admin đã ẩn đánh giá.
  final bool isHidden;
  final String? hiddenReason;

  /// Báo cáo vi phạm của Chủ sân (chỉ mobile).
  final ReviewReport? report;

  const FacilityReview({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.userName,
    required this.rating,
    required this.createdAt,
    this.userAvatarUrl,
    this.comment = '',
    this.ownerReply,
    this.repliedAt,
    this.isHidden = false,
    this.hiddenReason,
    this.report,
  });

  bool get hasReply => (ownerReply ?? '').trim().isNotEmpty;

  /// Đã báo cáo hoặc đã bị ẩn thì không báo cáo nữa.
  bool get canReport => report == null && !isHidden;

  FacilityReview copyWith({
    String? ownerReply,
    DateTime? repliedAt,
    bool clearReply = false,
    ReviewReport? report,
    bool? isHidden,
  }) =>
      FacilityReview(
        id: id,
        facilityId: facilityId,
        facilityName: facilityName,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        rating: rating,
        comment: comment,
        createdAt: createdAt,
        ownerReply: clearReply ? null : (ownerReply ?? this.ownerReply),
        repliedAt: clearReply ? null : (repliedAt ?? this.repliedAt),
        isHidden: isHidden ?? this.isHidden,
        hiddenReason: hiddenReason,
        report: report ?? this.report,
      );

  factory FacilityReview.fromJson(Map<String, dynamic> json) {
    String? str(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    DateTime? date(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    return FacilityReview(
      id: '${json['id'] ?? ''}',
      facilityId: '${json['facilityId'] ?? ''}',
      facilityName: str(json['facilityName']) ?? '',
      userName: str(json['userFullName'] ?? json['userName']) ?? '',
      userAvatarUrl: str(json['userAvatarUrl']),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: str(json['comment']) ?? '',
      createdAt: date(json['createdAt']) ?? DateTime.now(),
      ownerReply: str(json['ownerReply']),
      repliedAt: date(json['repliedAt']),
      isHidden: json['isHidden'] == true,
      hiddenReason: str(json['hiddenReason']),
    );
  }
}

/// Một trang đánh giá.
class ReviewPage {
  final List<FacilityReview> items;
  final int total;
  final int totalPages;

  const ReviewPage({required this.items, required this.total, required this.totalPages});

  static const empty = ReviewPage(items: [], total: 0, totalPages: 1);

  factory ReviewPage.fromJson(Object? data, {required int pageSize}) {
    final map = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final raw = data is List ? data : (map['items'] ?? map['data'] ?? const []) as List;
    final items = raw.whereType<Map>().map((e) => FacilityReview.fromJson(Map<String, dynamic>.from(e))).toList();
    final total = (map['totalCount'] ?? map['total'] ?? map['totalItems']) as num?;
    final count = total?.toInt() ?? items.length;
    final pages = (map['totalPages'] as num?)?.toInt() ?? 0;
    return ReviewPage(
      items: items,
      total: count,
      totalPages: pages > 0 ? pages : (count / pageSize).ceil().clamp(1, 1 << 30),
    );
  }
}

/// Thống kê đánh giá (GET /owner/facility-reviews/statistics).
class ReviewStats {
  final int totalReviews;
  final double? averageRating;
  final int repliedCount;
  final int unrepliedCount;

  /// Tỉ lệ phản hồi, BE có thể trả 0..1 hoặc 0..100.
  final double? replyRate;
  final int newLast30Days;

  /// Số đánh giá theo sao (1..5).
  final Map<int, int> distribution;

  const ReviewStats({
    required this.totalReviews,
    required this.repliedCount,
    required this.unrepliedCount,
    required this.newLast30Days,
    required this.distribution,
    this.averageRating,
    this.replyRate,
  });

  /// Tỉ lệ phản hồi theo %, làm tròn như Web.
  int? get replyPercent => replyRate == null ? null : (replyRate! <= 1 ? replyRate! * 100 : replyRate!).round();

  int countOf(int star) => distribution[star] ?? 0;

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final dist = <int, int>{};
    final raw = json['ratingDistribution'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final star = int.tryParse('$k');
        if (star != null) dist[star] = n(v);
      });
    }
    return ReviewStats(
      totalReviews: n(json['totalReviews']),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      repliedCount: n(json['repliedCount']),
      unrepliedCount: n(json['unrepliedCount']),
      replyRate: (json['replyRate'] as num?)?.toDouble(),
      newLast30Days: n(json['newReviewsLast30Days']),
      distribution: dist,
    );
  }
}
