enum NotificationCategory {
  booking('Đặt sân & LFG'),
  wallet('Ví'),
  review('Đánh giá');

  const NotificationCategory(this.label);

  final String label;
}

/// Màn hình mở ra khi bấm vào thông báo.
enum NotificationTarget { none, myBookings, myLfgMatches, transactions, pendingReviews, fairPlay }

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
  lfgRestriction('LfgRestriction', NotificationCategory.review, NotificationTarget.fairPlay);

  const NotificationType(this.apiValue, this.category, this.target);

  final String apiValue;
  final NotificationCategory category;
  final NotificationTarget target;

  static NotificationType? fromApi(String value) => values.where((t) => t.apiValue == value).firstOrNull;
}

/// Một thông báo trong hộp thư của người dùng. Nội dung do BE soạn sẵn.
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Mã đối tượng liên quan (booking, kèo, giao dịch...) để mở đúng mục sau này.
  final String? referenceId;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.referenceId,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        referenceId: referenceId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.apiValue,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        if (referenceId != null) 'referenceId': referenceId,
      };

  /// Trả về `null` nếu loại thông báo chưa được app hỗ trợ (BE thêm loại mới).
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
