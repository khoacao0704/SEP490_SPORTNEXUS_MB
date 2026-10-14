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

enum SessionType { booking, lfg }

class ReviewablePlayer {
  final String userId;
  final String name;
  final bool isHost;

  const ReviewablePlayer({required this.userId, required this.name, this.isHost = false});
}

/// Một buổi chơi đã được chủ sân check-out (đã giải ngân), đang chờ người chơi đánh giá.
class PendingReview {
  final String sessionId;
  final SessionType type;
  final String facilityId;
  final String facilityName;
  final Sport sport;
  final DateTime start;
  final DateTime end;
  final DateTime checkedOutAt;

  /// Người chơi cùng trận (không gồm chính mình). Rỗng với đặt sân thường.
  final List<ReviewablePlayer> players;

  const PendingReview({
    required this.sessionId,
    required this.type,
    required this.facilityId,
    required this.facilityName,
    required this.sport,
    required this.start,
    required this.end,
    required this.checkedOutAt,
    this.players = const [],
  });

  DateTime get deadline => checkedOutAt.add(FairPlayRules.reviewWindow);

  bool isExpired(DateTime now) => !deadline.isAfter(now);
}

class PlayerReviewInput {
  final String playerId;
  final int stars;
  final Set<ReviewTag> tags;
  final String comment;

  const PlayerReviewInput({required this.playerId, required this.stars, this.tags = const {}, this.comment = ''});
}

class FacilityReviewInput {
  final int stars;
  final String comment;

  const FacilityReviewInput({required this.stars, this.comment = ''});
}

enum FairPlayEventType { initial, review, noShow, cancellation, recovery }

/// Một lần điểm Fair Play thay đổi (do BE ghi nhận).
class FairPlayEvent {
  final String id;
  final FairPlayEventType type;
  final int delta;
  final String reason;
  final DateTime createdAt;

  const FairPlayEvent({
    required this.id,
    required this.type,
    required this.delta,
    required this.reason,
    required this.createdAt,
  });
}

class FairPlaySummary {
  final int score;

  /// Lịch sử thay đổi, mới nhất trước.
  final List<FairPlayEvent> history;

  const FairPlaySummary({required this.score, this.history = const []});

  bool get canJoinLfg => FairPlayRules.canJoinLfg(score);
}
