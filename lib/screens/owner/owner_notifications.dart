import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../notification/notifications_screen.dart';
import 'listing_fee_screen.dart';
import 'owner_finance_screen.dart';
import 'owner_reviews_screen.dart';

/// Tab của khung Chủ sân mà thông báo có thể mở tới.
enum OwnerTab { overview, schedule, scan, facilities, account }

/// Hộp thư thông báo của Chủ sân: chỉ các nhóm của Chủ sân, bấm vào mở đúng mục.
/// [onSelectTab] chuyển tab trong khung chính (Lịch đặt, Cơ sở).
Widget ownerNotificationsScreen({required ValueChanged<OwnerTab> onSelectTab}) => NotificationsScreen(
  categories: NotificationCategory.ownerCategories,
  onOpen: (context, n) async {
    void backToTab(OwnerTab tab) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      onSelectTab(tab);
    }

    Future<void> push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    switch (n.type.target) {
      case NotificationTarget.ownerSchedule:
        backToTab(OwnerTab.schedule);
      case NotificationTarget.ownerFacilities:
        backToTab(OwnerTab.facilities);
      case NotificationTarget.ownerFinance:
        await push(const OwnerFinanceScreen());
      case NotificationTarget.ownerListingFee:
        await push(const ListingFeeScreen());
      case NotificationTarget.ownerReviews:
        await push(const OwnerReviewsScreen());
      case NotificationTarget.none:
      case NotificationTarget.myBookings:
      case NotificationTarget.myLfgMatches:
      case NotificationTarget.transactions:
      case NotificationTarget.pendingReviews:
      case NotificationTarget.fairPlay:
        return;
    }
  },
);
