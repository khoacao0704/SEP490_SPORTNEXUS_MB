/// Trạng thái khiếu nại (ReportStatus của BE), nhãn như Web (shared.js).
enum ComplaintStatus {
  pending('PENDING', 'Chờ xử lý'),
  ownerResponded('OWNER_RESPONDED', 'Đã giải trình'),
  resolvedRefunded('RESOLVED_REFUNDED', 'Đã hoàn tiền'),
  resolvedNoRefund('RESOLVED_NO_REFUND', 'Không hoàn tiền'),
  rejected('REJECTED', 'Bị từ chối'),
  withdrawn('WITHDRAWN', 'Khách rút đơn'),
  unknown('', '—');

  const ComplaintStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Còn xử lý được: gửi giải trình hoặc đồng ý hoàn tiền.
  bool get canAct => this == pending || this == ownerResponded;

  /// 'OwnerResponded' / 'owner_responded' / 'OWNER_RESPONDED' đều nhận.
  static ComplaintStatus fromApi(Object? value) {
    final key = '${value ?? ''}'.replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}').toUpperCase();
    return values.firstWhere((s) => s.apiValue == key && s != unknown, orElse: () => unknown);
  }
}

/// Tab lọc của màn Khiếu nại (giống Web).
enum ComplaintTab {
  all(null, 'Tất cả'),
  pending(ComplaintStatus.pending, 'Chờ giải trình'),
  responded(ComplaintStatus.ownerResponded, 'Đã giải trình'),
  refunded(ComplaintStatus.resolvedRefunded, 'Đã hoàn tiền'),
  noRefund(ComplaintStatus.resolvedNoRefund, 'Không hoàn tiền');

  const ComplaintTab(this.status, this.label);

  final ComplaintStatus? status;
  final String label;
}

/// Khiếu nại của khách tại cơ sở của Chủ sân (GET /reports/owner, /reports/owner/{id}).
class OwnerComplaint {
  final String id;
  final ComplaintStatus status;
  final String reporterName;
  final String? reporterPhone;
  final String? reporterEmail;
  final String facilityName;
  final String courtName;
  final String reason;
  final String description;
  final List<String> evidenceImageUrls;
  final int? requestedRefundPercentage;
  final DateTime? bookingStartTime;
  final int? bookingTotalAmount;
  /// Trạng thái đơn dạng PENDING / CHECKED_IN … (đã chuẩn hóa).
  final String? bookingStatus;
  final DateTime createdAt;

  final String? ownerResponse;
  final List<String> ownerEvidenceUrls;
  final DateTime? ownerRespondedAt;

  final String? adminNote;
  final String? resolvedByAdminName;
  final DateTime? resolvedAt;
  final int? refundedAmount;
  final int? appliedRefundPercentage;

  const OwnerComplaint({
    required this.id,
    required this.status,
    required this.reporterName,
    required this.facilityName,
    required this.createdAt,
    this.reporterPhone,
    this.reporterEmail,
    this.courtName = '',
    this.reason = '',
    this.description = '',
    this.evidenceImageUrls = const [],
    this.requestedRefundPercentage,
    this.bookingStartTime,
    this.bookingTotalAmount,
    this.bookingStatus,
    this.ownerResponse,
    this.ownerEvidenceUrls = const [],
    this.ownerRespondedAt,
    this.adminNote,
    this.resolvedByAdminName,
    this.resolvedAt,
    this.refundedAmount,
    this.appliedRefundPercentage,
  });

  String? get contact => reporterPhone ?? reporterEmail;

  /// Có kết luận của Admin để hiện.
  bool get hasAdminResult => adminNote != null || resolvedAt != null;

  OwnerComplaint copyWith({
    ComplaintStatus? status,
    String? ownerResponse,
    List<String>? ownerEvidenceUrls,
    DateTime? ownerRespondedAt,
    DateTime? resolvedAt,
    int? refundedAmount,
    int? appliedRefundPercentage,
  }) =>
      OwnerComplaint(
        id: id,
        status: status ?? this.status,
        reporterName: reporterName,
        reporterPhone: reporterPhone,
        reporterEmail: reporterEmail,
        facilityName: facilityName,
        courtName: courtName,
        reason: reason,
        description: description,
        evidenceImageUrls: evidenceImageUrls,
        requestedRefundPercentage: requestedRefundPercentage,
        bookingStartTime: bookingStartTime,
        bookingTotalAmount: bookingTotalAmount,
        bookingStatus: bookingStatus,
        createdAt: createdAt,
        ownerResponse: ownerResponse ?? this.ownerResponse,
        ownerEvidenceUrls: ownerEvidenceUrls ?? this.ownerEvidenceUrls,
        ownerRespondedAt: ownerRespondedAt ?? this.ownerRespondedAt,
        adminNote: adminNote,
        resolvedByAdminName: resolvedByAdminName,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        refundedAmount: refundedAmount ?? this.refundedAmount,
        appliedRefundPercentage: appliedRefundPercentage ?? this.appliedRefundPercentage,
      );

  factory OwnerComplaint.fromJson(Map<String, dynamic> json) {
    String? str(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    DateTime? date(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    int? n(Object? v) => (v as num?)?.round();
    List<String> urls(Object? v) => v is List ? [for (final e in v) if (str(e) != null) str(e)!] : const [];
    return OwnerComplaint(
      id: '${json['id'] ?? ''}',
      status: ComplaintStatus.fromApi(json['status']),
      reporterName: str(json['reporterName']) ?? '',
      reporterPhone: str(json['reporterPhone']),
      reporterEmail: str(json['reporterEmail']),
      facilityName: str(json['facilityName']) ?? '',
      courtName: str(json['courtName']) ?? '',
      reason: str(json['reason']) ?? '',
      description: str(json['description']) ?? '',
      evidenceImageUrls: urls(json['evidenceImageUrls']),
      requestedRefundPercentage: n(json['requestedRefundPercentage']),
      bookingStartTime: date(json['bookingStartTime']),
      bookingTotalAmount: n(json['bookingTotalAmount']),
      bookingStatus: str(json['bookingStatus'])?.replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}').toUpperCase(),
      createdAt: date(json['createdAt']) ?? DateTime.now(),
      ownerResponse: str(json['ownerResponse']),
      ownerEvidenceUrls: urls(json['ownerEvidenceUrls']),
      ownerRespondedAt: date(json['ownerRespondedAt']),
      adminNote: str(json['adminNote']),
      resolvedByAdminName: str(json['resolvedByAdminName']),
      resolvedAt: date(json['resolvedAt']),
      refundedAmount: n(json['refundedAmount']),
      appliedRefundPercentage: n(json['appliedRefundPercentage']),
    );
  }
}

/// Số khiếu nại theo trạng thái (hiện trên tab).
class ComplaintCounts {
  final int pending;
  final int responded;
  final int refunded;
  final int noRefund;
  final int closed;

  const ComplaintCounts({this.pending = 0, this.responded = 0, this.refunded = 0, this.noRefund = 0, this.closed = 0});

  int? of(ComplaintTab tab) => switch (tab) {
        ComplaintTab.all => null,
        ComplaintTab.pending => pending,
        ComplaintTab.responded => responded,
        ComplaintTab.refunded => refunded,
        ComplaintTab.noRefund => noRefund,
      };
}

class ComplaintPage {
  final List<OwnerComplaint> items;
  final int total;
  final int totalPages;
  final ComplaintCounts counts;

  const ComplaintPage({required this.items, required this.total, required this.totalPages, required this.counts});

  static const empty = ComplaintPage(items: [], total: 0, totalPages: 1, counts: ComplaintCounts());

  /// OwnerReportListResponse: totalCount, pendingCount, ownerRespondedCount, resolvedRefundedCount,
  /// resolvedNoRefundCount, rejectedOrWithdrawnCount, items[].
  factory ComplaintPage.fromJson(Object? data, {required int pageSize}) {
    final map = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final raw = data is List ? data : (map['items'] ?? map['data'] ?? const []) as List;
    final items = raw.whereType<Map>().map((e) => OwnerComplaint.fromJson(Map<String, dynamic>.from(e))).toList();
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final total = (map['totalCount'] as num?)?.toInt() ?? items.length;
    return ComplaintPage(
      items: items,
      total: total,
      totalPages: (total / pageSize).ceil().clamp(1, 1 << 30),
      counts: ComplaintCounts(
        pending: n(map['pendingCount']),
        responded: n(map['ownerRespondedCount']),
        refunded: n(map['resolvedRefundedCount']),
        noRefund: n(map['resolvedNoRefundCount']),
        closed: n(map['rejectedOrWithdrawnCount']),
      ),
    );
  }
}
