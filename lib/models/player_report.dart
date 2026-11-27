/// Đối tượng của khiếu nại / báo cáo (ReportTargetType của BE). App Player dùng đơn đặt sân và người chơi.
enum ReportTarget {
  booking('BOOKING'),
  user('USER'),

  /// Bài viết / bình luận trên Bảng tin cộng đồng (mã đối tượng gửi qua targetObjectId).
  communityPost('COMMUNITY_POST'),
  postComment('POST_COMMENT'),

  /// Khiếu nại kết quả trận giải (targetObjectId = mã trận), trong 15 phút sau khi có kết quả.
  match('MATCH');

  const ReportTarget(this.apiValue);

  final String apiValue;
}

/// Trạng thái khiếu nại (ReportStatus của BE, giống màn Khiếu nại của Chủ sân).
enum ReportStatus {
  pending('PENDING', 'Đang chờ xử lý'),
  ownerResponded('OWNER_RESPONDED', 'Chủ sân đã giải trình'),
  resolvedRefunded('RESOLVED_REFUNDED', 'Đã giải quyết • có hoàn tiền'),
  resolvedNoRefund('RESOLVED_NO_REFUND', 'Đã giải quyết • không hoàn tiền'),
  resolved('RESOLVED', 'Đã giải quyết'),
  rejected('REJECTED', 'Đã từ chối'),
  withdrawn('WITHDRAWN', 'Đã rút khiếu nại'),
  unknown('', 'Đang chờ xử lý');

  const ReportStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Như Web: chỉ rút được khi đang chờ xử lý.
  bool get canWithdraw => this == pending;

  bool get isDone => this == resolvedRefunded || this == resolvedNoRefund || this == resolved;

  /// 'OwnerResponded' / 'owner_responded' / 'OWNER_RESPONDED' đều nhận.
  static ReportStatus fromApi(Object? value) {
    final key = '${value ?? ''}'.replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}').toUpperCase();
    if (key.isEmpty || key == 'WAITING') return pending;
    return values.firstWhere((s) => s.apiValue == key && s != unknown, orElse: () => unknown);
  }
}

/// Lý do khiếu nại do BE trả (GET /reports/reasons?targetType=).
class ReportReason {
  final String code;
  final String title;
  final String? description;

  const ReportReason({required this.code, required this.title, this.description});

  factory ReportReason.fromJson(Map<String, dynamic> json) {
    final code = '${json['code'] ?? json['id'] ?? ''}';
    final title = json['title'] ?? json['label'] ?? json['name'];
    final description = '${json['description'] ?? ''}'.trim();
    return ReportReason(
      code: code,
      title: title == null || '$title'.trim().isEmpty ? code : '$title',
      description: description.isEmpty ? null : description,
    );
  }
}

/// Một khiếu nại / báo cáo của người chơi (GET /reports/my-reports).
class PlayerReport {
  final String id;
  final ReportStatus status;
  final String targetType;

  /// Mã lý do; [reasonName] là tên BE trả kèm (nếu có).
  final String reason;
  final String? reasonName;
  final String description;
  final String? bookingId;
  final String? facilityName;
  final String? courtName;
  final String? targetUserName;
  final List<String> evidenceImageUrls;
  final DateTime createdAt;

  /// Giải trình của chủ sân, kết luận của Admin / BQT, số Điểm đã hoàn.
  final String? ownerResponse;
  final String? resolution;
  final int? refundedAmount;

  // ---- Khiếu nại kết quả trận (MATCH) ----
  final String? refereeNote;
  final String? organizerDecisionNote;
  final DateTime? organizerDecidedAt;
  final bool isEscalatedToAdmin;
  final DateTime? escalationClosedAt;
  final bool resolvedByAdmin;

  /// Như Web: được chuyển Admin một lần, trong 24 giờ sau khi BTC quyết định, hoặc khi BTC quá 24 giờ chưa xử lý.
  static const Duration escalateWindow = Duration(hours: 24);

  bool get isMatch => targetType.toUpperCase() == ReportTarget.match.apiValue;

  bool canEscalateAt(DateTime now) {
    if (!isMatch || isEscalatedToAdmin || resolvedByAdmin || status == ReportStatus.withdrawn) return false;
    final decided = organizerDecidedAt;
    if (decided != null) return now.difference(decided) < escalateWindow;
    return status == ReportStatus.pending && now.difference(createdAt) >= escalateWindow;
  }

  const PlayerReport({
    required this.id,
    required this.status,
    required this.targetType,
    required this.reason,
    required this.description,
    required this.createdAt,
    this.reasonName,
    this.bookingId,
    this.facilityName,
    this.courtName,
    this.targetUserName,
    this.evidenceImageUrls = const [],
    this.ownerResponse,
    this.resolution,
    this.refundedAmount,
    this.refereeNote,
    this.organizerDecisionNote,
    this.organizerDecidedAt,
    this.isEscalatedToAdmin = false,
    this.escalationClosedAt,
    this.resolvedByAdmin = false,
  });

  bool get isBooking => targetType.toUpperCase() == ReportTarget.booking.apiValue;

  PlayerReport withStatus(ReportStatus status) => PlayerReport(
        id: id,
        status: status,
        targetType: targetType,
        reason: reason,
        reasonName: reasonName,
        description: description,
        bookingId: bookingId,
        facilityName: facilityName,
        courtName: courtName,
        targetUserName: targetUserName,
        evidenceImageUrls: evidenceImageUrls,
        createdAt: createdAt,
        ownerResponse: ownerResponse,
        resolution: resolution,
        refundedAmount: refundedAmount,
        refereeNote: refereeNote,
        organizerDecisionNote: organizerDecisionNote,
        organizerDecidedAt: organizerDecidedAt,
        isEscalatedToAdmin: isEscalatedToAdmin,
        escalationClosedAt: escalationClosedAt,
        resolvedByAdmin: resolvedByAdmin,
      );

  PlayerReport escalated() => PlayerReport(
        id: id,
        status: status,
        targetType: targetType,
        reason: reason,
        reasonName: reasonName,
        description: description,
        bookingId: bookingId,
        createdAt: createdAt,
        isEscalatedToAdmin: true,
      );

  factory PlayerReport.fromJson(Map<String, dynamic> json) {
    String? str(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    final urls = json['evidenceImageUrls'];
    return PlayerReport(
      id: str(json['id'] ?? json['reportId']) ?? '',
      status: ReportStatus.fromApi(json['status']),
      targetType: str(json['targetType']) ?? ReportTarget.booking.apiValue,
      reason: str(json['reason'] ?? json['reasonId'] ?? json['reasonCode']) ?? '',
      reasonName: str(json['reasonName'] ?? json['reasonTitle']),
      description: str(json['description'] ?? json['content']) ?? '',
      bookingId: str(json['bookingId']),
      facilityName: str(json['facilityName']),
      courtName: str(json['courtName']),
      targetUserName: str(json['targetUserName'] ?? json['reportedUserName']),
      evidenceImageUrls: urls is List ? [for (final u in urls) if (str(u) != null) str(u)!] : const [],
      createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
      ownerResponse: str(json['ownerResponse']),
      resolution: str(json['resolution'] ?? json['adminNote']),
      refundedAmount: (json['refundedAmount'] as num?)?.round(),
      refereeNote: str(json['refereeNote']),
      organizerDecisionNote: str(json['organizerDecisionNote']),
      organizerDecidedAt: DateTime.tryParse('${json['organizerDecidedAt']}')?.toLocal(),
      isEscalatedToAdmin: json['isEscalatedToAdmin'] == true,
      escalationClosedAt: DateTime.tryParse('${json['escalationClosedAt']}')?.toLocal(),
      resolvedByAdmin: json['resolvedByAdminId'] != null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.apiValue,
        'targetType': targetType,
        'reason': reason,
        'reasonName': ?reasonName,
        'description': description,
        'bookingId': ?bookingId,
        'facilityName': ?facilityName,
        'courtName': ?courtName,
        'targetUserName': ?targetUserName,
        'evidenceImageUrls': evidenceImageUrls,
        'createdAt': createdAt.toIso8601String(),
        if (isEscalatedToAdmin) 'isEscalatedToAdmin': true,
      };
}

/// Nội dung gửi khiếu nại mới (POST /reports). Không có % muốn hoàn (như Web, mức hoàn do chủ sân / Admin quyết).
class NewPlayerReport {
  final ReportTarget target;
  final String reason;
  final String description;
  final String? bookingId;
  final String? targetUserId;
  final String? targetObjectId;
  final List<String> evidenceImageUrls;

  const NewPlayerReport({
    required this.target,
    required this.reason,
    required this.description,
    this.bookingId,
    this.targetUserId,
    this.targetObjectId,
    this.evidenceImageUrls = const [],
  });
}
