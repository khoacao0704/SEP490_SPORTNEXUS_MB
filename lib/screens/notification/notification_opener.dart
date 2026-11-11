import 'package:flutter/material.dart';
import '../../data/app_repositories.dart';
import '../../models/app_notification.dart';
import '../../models/booking.dart';
import '../booking/split_booking_screen.dart';
import '../fair_play/fair_play_screen.dart';
import '../lfg/lfg_match_detail_screen.dart';
import '../lfg/lfg_screen.dart';
import '../main/main_navigation_screen.dart';
import '../review/pending_reviews_screen.dart';
import '../team/my_teams_screen.dart';
import '../team/team_detail_screen.dart';
import '../tournament/tournament_detail_screen.dart';
import '../wallet/transaction_history_screen.dart';

/// Mở màn liên quan tới thông báo của người chơi (bấm trong danh sách hoặc bấm thông báo đẩy).
/// Thông báo không có màn tương ứng thì không làm gì.
Future<void> openPlayerNotification(NavigatorState navigator, AppNotification n) async {
  final id = n.referenceId;
  Widget? page;
  switch (n.referenceType) {
    case NotificationReference.booking:
      await _openBooking(navigator, id!);
      return;
    case NotificationReference.lfgCard:
      page = LfgMatchDetailScreen(matchId: id!);
    case NotificationReference.wallet:
      page = const TransactionHistoryScreen();
    case NotificationReference.team:
      page = TeamDetailScreen(teamId: id!);
    case NotificationReference.teamInvitation:
      page = const MyTeamsScreen();
    case NotificationReference.tournament:
      page = TournamentDetailScreen(tournamentId: id!);
    case NotificationReference.facilityReview:
    case NotificationReference.facility:
    case NotificationReference.communityPost:
    case NotificationReference.report:
      // Chưa có màn tương ứng phía người chơi.
      return;
    case null:
      page = _legacyPage(navigator, n.type.target);
      if (page == null) return;
  }
  if (!navigator.mounted) return;
  await navigator.push(MaterialPageRoute(builder: (_) => page!));
}

/// Đơn chia tiền mở màn góp tiền; đơn thường mở tab Lịch Đặt.
Future<void> _openBooking(NavigatorState navigator, String bookingId) async {
  try {
    final booking = await AppRepositories.booking.getBooking(bookingId);
    if (!navigator.mounted) return;
    if (booking.paymentType == BookingPaymentType.split) {
      await navigator.push(MaterialPageRoute(builder: (_) => SplitBookingScreen(bookingId: bookingId)));
      return;
    }
  } catch (_) {
    // Không tải được đơn: vẫn mở Lịch Đặt.
  }
  if (!navigator.mounted) return;
  _openMyBookings(navigator);
}

void _openMyBookings(NavigatorState navigator) {
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 3)),
    (route) => false,
  );
}

/// Thông báo không có đối tượng liên quan (Fair Play sau trận, dữ liệu giả lập).
Widget? _legacyPage(NavigatorState navigator, NotificationTarget target) {
  switch (target) {
    case NotificationTarget.none:
    case NotificationTarget.ownerSchedule:
    case NotificationTarget.ownerFinance:
    case NotificationTarget.ownerListingFee:
    case NotificationTarget.ownerFacilities:
    case NotificationTarget.ownerReviews:
      return null;
    case NotificationTarget.myBookings:
      _openMyBookings(navigator);
      return null;
    case NotificationTarget.myLfgMatches:
      return const MyLfgMatchesScreen();
    case NotificationTarget.transactions:
      return const TransactionHistoryScreen();
    case NotificationTarget.pendingReviews:
      return const PendingReviewsScreen();
    case NotificationTarget.fairPlay:
      return const FairPlayScreen();
  }
}
