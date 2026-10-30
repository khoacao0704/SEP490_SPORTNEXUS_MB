/// Nhóm thông báo của BE (trường `type`). Cùng một nhóm có thể gửi cho cả người chơi và Chủ sân.
enum NotificationGroup {
  booking('BOOKING', 'Đặt sân', mandatory: true),
  lfg('LFG', 'Kèo LFG'),
  wallet('WALLET', 'Ví', mandatory: true),
  review('REVIEW', 'Đánh giá'),
  team('TEAM', 'Đội'),
  tournament('TOURNAMENT', 'Giải đấu'),
  community('COMMUNITY', 'Cộng đồng'),
  report('REPORT', 'Báo cáo', mandatory: true),
  system('SYSTEM', 'Hệ thống', mandatory: true);

  const NotificationGroup(this.apiValue, this.label, {this.mandatory = false});

  final String apiValue;
  final String label;

  /// Nhóm bắt buộc: không tắt được trong cài đặt (BE trả 400 nếu gửi lên).
  final bool mandatory;

  /// Giá trị lạ BE coi là SYSTEM.
  static NotificationGroup fromApi(String? value) =>
      values.where((g) => g.apiValue == value).firstOrNull ?? NotificationGroup.system;
}

/// Loại đối tượng mà `referenceId` trỏ tới (trường `referenceType` của BE).
enum NotificationReference {
  booking('BOOKING'),
  lfgCard('LFG_CARD'),
  team('TEAM'),
  teamInvitation('TEAM_INVITATION'),
  tournament('TOURNAMENT'),
  facilityReview('FACILITY_REVIEW'),
  facility('FACILITY'),
  communityPost('COMMUNITY_POST'),
  report('REPORT'),

  /// Ví (nạp tiền) hoặc yêu cầu rút tiền.
  wallet('WALLET');

  const NotificationReference(this.apiValue);

  final String apiValue;

  static NotificationReference? fromApi(String? value) => values.where((r) => r.apiValue == value).firstOrNull;
}

/// Nhóm lọc cũ của bản giả lập. Màn Chủ sân vẫn lọc theo các nhóm này.
enum NotificationCategory {
  booking('Đặt sân & LFG'),
  wallet('Ví'),
  review('Đánh giá'),

  // Phía Chủ sân
  ownerBooking('Đặt sân', forOwner: true),
  ownerMoney('Tiền', forOwner: true),
  ownerFacility('Hồ sơ cơ sở', forOwner: true),
  ownerReview('Đánh giá', forOwner: true);

  const NotificationCategory(this.label, {this.forOwner = false});

  final String label;

  /// Nhóm của Chủ sân; còn lại là của người chơi.
  final bool forOwner;

  static List<NotificationCategory> get playerCategories => values.where((c) => !c.forOwner).toList();
  static List<NotificationCategory> get ownerCategories => values.where((c) => c.forOwner).toList();
}

/// Màn hình mở ra khi bấm vào thông báo.
enum NotificationTarget {
  none,
  myBookings,
  myLfgMatches,
  transactions,
  pendingReviews,
  fairPlay,

  // Phía Chủ sân
  ownerSchedule,
  ownerFinance,
  ownerListingFee,
  ownerFacilities,
  ownerReviews,
}

/// Loại sự kiện chi tiết của bản giả lập. Dữ liệu BE chỉ có [NotificationGroup], loại ở đây
/// được suy ra bằng [NotificationType.forApi] để màn Chủ sân (lọc theo [category], mở theo [target]) vẫn dùng được.
enum NotificationType {
  bookingConfirmed('BookingConfirmed', NotificationCategory.booking, NotificationTarget.myBookings),
  matchReminder('MatchReminder', NotificationCategory.booking, NotificationTarget.myBookings),
  lfgPlayerJoined('LfgPlayerJoined', NotificationCategory.booking, NotificationTarget.myLfgMatches),
  lfgFull('LfgFull', NotificationCategory.booking, NotificationTarget.myLfgMatches),

  /// Kèo không đủ người tại T−48h: hủy và hoàn 100%.
  lfgCancelled('LfgCancelled', NotificationCategory.booking, NotificationTarget.myLfgMatches),
  topUpSucceeded('TopUpSucceeded', NotificationCategory.wallet, NotificationTarget.transactions),
  withdrawalApproved('WithdrawalApproved', NotificationCategory.wallet, NotificationTarget.transactions),
  withdrawalRejected('WithdrawalRejected', NotificationCategory.wallet, NotificationTarget.transactions),
  refunded('Refunded', NotificationCategory.wallet, NotificationTarget.transactions),
  reviewReminder('ReviewReminder', NotificationCategory.review, NotificationTarget.pendingReviews),
  fairPlayChanged('FairPlayChanged', NotificationCategory.review, NotificationTarget.fairPlay),

  /// Fair Play xuống dưới 30 (bị khóa) hoặc hồi lại đủ 30 (mở lại).
  lfgRestriction('LfgRestriction', NotificationCategory.review, NotificationTarget.fairPlay),

  // ---------------- Phía Chủ sân ----------------
  newBooking('NewBooking', NotificationCategory.ownerBooking, NotificationTarget.ownerSchedule),
  bookingCancelledByPlayer('BookingCancelledByPlayer', NotificationCategory.ownerBooking, NotificationTarget.ownerSchedule),
  lfgMatchConfirmed('LfgMatchConfirmed', NotificationCategory.ownerBooking, NotificationTarget.ownerSchedule),
  playerNoShow('PlayerNoShow', NotificationCategory.ownerBooking, NotificationTarget.ownerSchedule),
  escrowReleased('EscrowReleased', NotificationCategory.ownerMoney, NotificationTarget.ownerFinance),
  ownerWithdrawalApproved('OwnerWithdrawalApproved', NotificationCategory.ownerMoney, NotificationTarget.ownerFinance),
  ownerWithdrawalRejected('OwnerWithdrawalRejected', NotificationCategory.ownerMoney, NotificationTarget.ownerFinance),
  listingFeeIssued('ListingFeeIssued', NotificationCategory.ownerMoney, NotificationTarget.ownerListingFee),
  listingFeeDueSoon('ListingFeeDueSoon', NotificationCategory.ownerMoney, NotificationTarget.ownerListingFee),

  /// Quá hạn phí: các cơ sở bị ẩn.
  listingFeeOverdue('ListingFeeOverdue', NotificationCategory.ownerMoney, NotificationTarget.ownerListingFee),
  facilityApproved('FacilityApproved', NotificationCategory.ownerFacility, NotificationTarget.ownerFacilities),
  facilityRejected('FacilityRejected', NotificationCategory.ownerFacility, NotificationTarget.ownerFacilities),
  profileChangeApproved('ProfileChangeApproved', NotificationCategory.ownerFacility, NotificationTarget.ownerFacilities),
  profileChangeRejected('ProfileChangeRejected', NotificationCategory.ownerFacility, NotificationTarget.ownerFacilities),
  newFacilityReview('NewFacilityReview', NotificationCategory.ownerReview, NotificationTarget.ownerReviews),

  /// Admin đã xử lý báo cáo đánh giá (giữ lại hoặc ẩn).
  reviewReportResolved('ReviewReportResolved', NotificationCategory.ownerReview, NotificationTarget.ownerReviews),

  /// Thông báo BE không khớp loại nào ở trên: không mở màn nào, không hiện trong bộ lọc của Chủ sân.
  general('General', NotificationCategory.booking, NotificationTarget.none);

  const NotificationType(this.apiValue, this.category, this.target);

  final String apiValue;
  final NotificationCategory category;
  final NotificationTarget target;

  static NotificationType? fromApi(String value) => values.where((t) => t.apiValue == value).firstOrNull;

  /// Nhóm BE tương ứng (dùng cho dữ liệu giả lập).
  NotificationGroup get group {
    switch (this) {
      case bookingConfirmed:
      case matchReminder:
      case newBooking:
      case bookingCancelledByPlayer:
      case playerNoShow:
        return NotificationGroup.booking;
      case lfgPlayerJoined:
      case lfgFull:
      case lfgCancelled:
      case lfgMatchConfirmed:
        return NotificationGroup.lfg;
      case topUpSucceeded:
      case withdrawalApproved:
      case withdrawalRejected:
      case refunded:
      case escrowReleased:
      case ownerWithdrawalApproved:
      case ownerWithdrawalRejected:
      case listingFeeIssued:
      case listingFeeDueSoon:
      case listingFeeOverdue:
        return NotificationGroup.wallet;
      case reviewReminder:
      case fairPlayChanged:
      case lfgRestriction:
      case newFacilityReview:
      case reviewReportResolved:
        return NotificationGroup.review;
      case facilityApproved:
      case facilityRejected:
      case profileChangeApproved:
      case profileChangeRejected:
      case general:
        return NotificationGroup.system;
    }
  }

  /// Loại suy ra từ dữ liệu BE. Màn người chơi mở theo [NotificationReference], chỉ dùng [target]
  /// khi thông báo không có đối tượng (Fair Play sau trận); các loại còn lại phục vụ màn Chủ sân.
  static NotificationType forApi(NotificationGroup group, NotificationReference? reference) {
    switch (group) {
      case NotificationGroup.booking:
        return newBooking;
      case NotificationGroup.lfg:
        return lfgMatchConfirmed;
      case NotificationGroup.wallet:
        return escrowReleased;
      case NotificationGroup.review:
        if (reference == null) return fairPlayChanged;
        return reference == NotificationReference.facilityReview ? newFacilityReview : general;
      case NotificationGroup.system:
        return reference == NotificationReference.facility ? facilityApproved : general;
      case NotificationGroup.team:
      case NotificationGroup.tournament:
      case NotificationGroup.community:
      case NotificationGroup.report:
        return general;
    }
  }
}

/// Một thông báo trong hộp thư của người dùng. Nội dung do BE soạn sẵn.
class AppNotification {
  final String id;
  final NotificationType type;
  final NotificationGroup group;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Đối tượng liên quan (đơn đặt sân, kèo, ví...) để mở đúng màn; cả hai có thể `null`.
  final NotificationReference? referenceType;
  final String? referenceId;

  AppNotification({
    required this.id,
    required this.type,
    NotificationGroup? group,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.referenceType,
    this.referenceId,
  }) : group = group ?? type.group;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    group: group,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    referenceType: referenceType,
    referenceId: referenceId,
  );

  /// Dạng lưu của bản giả lập (`type` là loại chi tiết, khác với `type` của BE).
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.apiValue,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    if (referenceId != null) 'referenceId': referenceId,
  };

  /// Trả về `null` nếu loại thông báo chưa được app hỗ trợ.
  static AppNotification? fromJson(Map<String, dynamic> json) {
    final type = NotificationType.fromApi(json['type'] as String? ?? '');
    if (type == null) return null;
    return AppNotification(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      referenceId: json['referenceId'] as String?,
    );
  }
}

/// Một trang thông báo.
class NotificationPage {
  final List<AppNotification> items;
  final bool hasMore;

  const NotificationPage({required this.items, required this.hasMore});
}

/// Số thông báo chưa đọc: tổng và theo nhóm (chỉ nhóm có thông báo chưa đọc).
class UnreadNotifications {
  final int total;
  final Map<NotificationGroup, int> byGroup;

  const UnreadNotifications({required this.total, this.byGroup = const {}});
}
