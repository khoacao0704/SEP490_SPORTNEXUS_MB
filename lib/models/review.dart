import '../core/constants/fair_play_rules.dart';
import 'sport.dart';

enum ReviewTag {
  onTime('OnTime', 'Đúng giờ', isPositive: true),
  fairPlay('FairPlay', 'Chơi đẹp', isPositive: true),
  friendly('Friendly', 'Thân thiện', isPositive: true),
  late('Late', 'Đến trễ', isPositive: false),
  roughPlay('RoughPlay', 'Chơi xấu', isPositive: false),
  badAttitude('BadAttitude', 'Thái độ kém', isPositive: false);

  const ReviewTag(this.apiValue, this.label, {required this.isPositive});

  final String apiValue;
  final String label;
  final bool isPositive;
}

enum SessionType {
  booking('BOOKING'),
  lfg('LFG');

  const SessionType(this.apiValue);

  final String apiValue;

  static SessionType fromApi(String? value) => value == lfg.apiValue ? lfg : booking;
}

class ReviewablePlayer {
  final String userId;
  final String name;
  final String? avatarUrl;
  final bool isHost;

  const ReviewablePlayer({required this.userId, required this.name, this.avatarUrl, this.isHost = false});
}

/// Một trận đã chơi xong, còn trong hạn chấm điểm người chơi cùng trận.
class PendingReview {
  /// Id kèo LFG ([SessionType.lfg]) hoặc id đơn đặt sân ([SessionType.booking]).
  final String sessionId;
  final SessionType type;
  final String facilityId;
  final String facilityName;
  final String? courtName;
  final Sport? sport;

  /// Tên môn của BE, dùng khi không khớp môn nào của app.
  final String sportName;
  final DateTime start;
  final DateTime end;

  /// Hạn chấm (giờ kết thúc + 24 giờ). Hết hạn thì BE chốt điểm.
  final DateTime deadline;

  /// Người chơi cùng trận còn chưa chấm (không gồm chính mình).
  final List<ReviewablePlayer> players;

  const PendingReview({
    required this.sessionId,
    required this.type,
    required this.facilityId,
    required this.facilityName,
    this.courtName,
    this.sport,
    this.sportName = '',
    required this.start,
    required this.end,
    required this.deadline,
    this.players = const [],
  });

  String get sportLabel => sport?.label ?? sportName;

  bool isExpired(DateTime now) => !deadline.isAfter(now);
}

class PlayerReviewInput {
  final String playerId;
  final int stars;
  final Set<ReviewTag> tags;
  final String comment;

  const PlayerReviewInput({required this.playerId, required this.stars, this.tags = const {}, this.comment = ''});

  /// BE không có trường thẻ: ghép thẻ vào đầu nhận xét, vd. "Đúng giờ, Chơi đẹp. Đánh hay".
  String get commentWithTags {
    final text = comment.trim();
    if (tags.isEmpty) return text;
    final labels = ReviewTag.values.where(tags.contains).map((t) => t.label).join(', ');
    return text.isEmpty ? labels : '$labels. $text';
  }
}

class FacilityReviewInput {
  final int stars;
  final String comment;

  const FacilityReviewInput({required this.stars, this.comment = ''});
}

/// Người dùng có được đánh giá cơ sở không (điều kiện: đã từng check-in ở cơ sở đó).
class ReviewEligibility {
  final bool canReview;

  /// Lý do không được đánh giá, BE soạn sẵn.
  final String? reason;

  /// Có khi đã đánh giá cơ sở này rồi.
  final String? existingReviewId;

  const ReviewEligibility({required this.canReview, this.reason, this.existingReviewId});

  bool get alreadyReviewed => existingReviewId != null;
}

/// Một đánh giá cơ sở. Thông tin cơ sở và trạng thái ẩn chỉ có ở danh sách đánh giá của chính mình.
class FacilityReviewItem {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final int stars;
  final String comment;
  final DateTime createdAt;
  final String? ownerReply;
  final DateTime? repliedAt;

  final String? facilityId;
  final String? facilityName;
  final String? facilityAddress;
  final String? facilityThumbnailUrl;

  /// Admin đã ẩn đánh giá (chỉ người viết thấy).
  final bool isHidden;
  final String? hiddenReason;

  const FacilityReviewItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.stars,
    this.comment = '',
    required this.createdAt,
    this.ownerReply,
    this.repliedAt,
    this.facilityId,
    this.facilityName,
    this.facilityAddress,
    this.facilityThumbnailUrl,
    this.isHidden = false,
    this.hiddenReason,
  });
}

/// Tổng hợp đánh giá của một cơ sở (luôn tính trên mọi đánh giá đang hiện, kể cả khi lọc theo sao).
class FacilityReviewStats {
  final double average;
  final int total;

  /// Số đánh giá theo từng mức sao 1–5.
  final Map<int, int> distribution;

  const FacilityReviewStats({required this.average, required this.total, this.distribution = const {}});

  static const empty = FacilityReviewStats(average: 0, total: 0);
}

class FacilityReviewPage {
  final List<FacilityReviewItem> items;
  final FacilityReviewStats stats;
  final bool hasMore;

  const FacilityReviewPage({required this.items, this.stats = FacilityReviewStats.empty, required this.hasMore});
}

enum FairPlayEventType {
  initial('INITIAL', 'Khởi tạo'),
  review('RATING', 'Đánh giá sau trận'),
  noShow('NO_SHOW', 'Vắng mặt'),
  late('LATE', 'Check-in trễ'),
  cancellation('CANCEL', 'Hủy'),
  recovery('RECOVERY', 'Hồi phục'),
  admin('ADMIN', 'Admin điều chỉnh'),
  report('REPORT', 'Khiếu nại');

  const FairPlayEventType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static FairPlayEventType fromApi(String? value) =>
      values.where((t) => t.apiValue == value).firstOrNull ?? FairPlayEventType.admin;
}

/// Một lần điểm Fair Play thay đổi (do BE ghi nhận).
class FairPlayEvent {
  final String id;
  final FairPlayEventType type;
  final int delta;

  /// Điểm sau thay đổi; `null` ở dữ liệu giả lập cũ.
  final int? scoreAfter;
  final String reason;
  final DateTime createdAt;

  const FairPlayEvent({
    required this.id,
    required this.type,
    required this.delta,
    this.scoreAfter,
    required this.reason,
    required this.createdAt,
  });
}

class FairPlaySummary {
  final int score;

  /// Điểm tối thiểu để ghép LFG (Admin chỉnh được trên BE).
  final int minScoreForLfg;

  /// Điểm tự hồi tới mức này thì dừng.
  final int recoveryCap;

  /// Bị chặn ghép LFG: điểm dưới [minScoreForLfg] hoặc đang bị Admin cấm.
  final bool isLfgBlocked;

  /// Có khi đang bị Admin cấm ghép LFG.
  final String? banReason;

  /// Hết cấm lúc này; `null` khi đang cấm = cấm vô thời hạn.
  final DateTime? bannedUntil;

  /// Số lượt được người chơi khác chấm và số sao trung bình.
  final int ratingCount;
  final double? averageRating;

  /// Lịch sử thay đổi, mới nhất trước (trang đã tải).
  final List<FairPlayEvent> history;
  final bool hasMoreHistory;

  const FairPlaySummary({
    required this.score,
    this.minScoreForLfg = FairPlayRules.minScoreForLfg,
    this.recoveryCap = FairPlayRules.recoveryCap,
    bool? isLfgBlocked,
    this.banReason,
    this.bannedUntil,
    this.ratingCount = 0,
    this.averageRating,
    this.history = const [],
    this.hasMoreHistory = false,
  }) : isLfgBlocked = isLfgBlocked ?? score < minScoreForLfg;

  bool get canJoinLfg => !isLfgBlocked;

  /// Bị chặn dù đủ điểm: đang bị Admin cấm.
  bool get isBanned => isLfgBlocked && (banReason != null || score >= minScoreForLfg);

  bool get isRecovering => score < recoveryCap;
}
