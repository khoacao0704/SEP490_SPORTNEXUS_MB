import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/player_shop_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_data.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_player_shop_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/owner_shop.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/screens/booking/my_bookings_screen.dart';
import 'package:test1/screens/facility/facility_detail_screen.dart';
import 'package:test1/screens/shop/my_shop_orders_screen.dart';
import 'package:test1/widgets/shop/player_shop.dart';

import '../helpers/layout_check.dart';

/// B5 shop tại sân phía người chơi + B6 lịch sử check-in (bản giả lập).
/// Đơn mẫu của player@: Thiên Triều (còn 4 ngày), Hoa Lư (còn ~12 giờ), Eco Sport Q7 (đã qua).
void main() {
  late MockPlayerShopRepository shop;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    final facility = MockFacilityRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    final bookings = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    shop = MockPlayerShopRepository(latency: Duration.zero);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.facility = AppRepositories.lfgFacility = facility;
    AppRepositories.review = review;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.booking = bookings;
    AppRepositories.split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, wallet: wallet, bookings: bookings);
    AppRepositories.lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    AppRepositories.playerShop = shop;
    AppRepositories.checkInHistory = shop;
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Widget shopSection(String facilityId) {
    final f = MockFacilityData.facilities.firstWhere((x) => x.id == facilityId);
    return Scaffold(body: ListView(children: [FacilityShopSection(facilityId: f.id, facilityName: f.name)]));
  }

  testWidgets('có đơn sắp tới ở cơ sở: hiện shop, đặt trước (giới hạn tồn kho), có trong Đơn mua tại sân rồi hủy',
      (tester) async {
    await pump(tester, shopSection('f-hcm-thientrieu'));
    expect(find.text(PlayerShopStrings.sectionTitle), findsOneWidget);
    expect(find.text(PlayerShopStrings.outOfStock), findsOneWidget); // quấn cán hết hàng

    await tester.tap(find.text(PlayerShopStrings.order).at(1)); // ống cầu, còn 6
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byIcon(Icons.add));
    }
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);
    expect(find.text(PlayerShopStrings.subtotal(6 * 220000)), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'lấy lúc 19h');
    await tester.tap(find.text(PlayerShopStrings.submit));
    await tester.pumpAndSettle();
    expect(find.text(PlayerShopStrings.ordered(6, 'Ống cầu lông Thành Công (12 quả)')), findsOneWidget);
    expect(find.text(PlayerShopStrings.outOfStock), findsNWidgets(2)); // ống cầu vừa hết

    await tester.tap(find.text(PlayerShopStrings.myOrders));
    await tester.pumpAndSettle();
    expect(find.byType(MyShopOrdersScreen), findsOneWidget);
    expect(find.text('6 × Ống cầu lông Thành Công (12 quả)'), findsOneWidget);
    expect(find.textContaining('lấy lúc 19h'), findsOneWidget);
    expect(find.text(ShopOrderStatus.pending.label), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, PlayerShopStrings.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, PlayerShopStrings.cancel));
    await tester.pumpAndSettle();
    expect(find.text(PlayerShopStrings.cancelled), findsOneWidget);
    expect(find.text(ShopOrderStatus.cancelled.label), findsOneWidget);
    expect(find.widgetWithText(TextButton, PlayerShopStrings.cancel), findsNothing);
  });

  testWidgets('không có đơn ở cơ sở / đơn đã qua: không hiện shop', (tester) async {
    await pump(tester, shopSection('f-hcm-eco-q7')); // đơn đã qua
    expect(find.text(PlayerShopStrings.sectionTitle), findsNothing);
    await pump(tester, shopSection('f-hcm-govap')); // chưa đặt ở đây
    expect(find.text(PlayerShopStrings.sectionTitle), findsNothing);
  });

  testWidgets('chi tiết sân có mục Shop tại sân khi có đơn', (tester) async {
    final f = MockFacilityData.facilities.firstWhere((x) => x.id == 'f-hcm-thientrieu');
    await pump(tester, FacilityDetailScreen(facility: f, initialSport: Sport.badminton));
    await tester.scrollUntilVisible(find.text(PlayerShopStrings.sectionTitle), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(PlayerShopStrings.sectionTitle), findsOneWidget);
  });

  testWidgets('Đơn của tôi: đơn sắp tới có nút Đặt đồ tại sân; đơn đã qua thì không', (tester) async {
    await pump(tester, const MyBookingsScreen());
    expect(find.text(PlayerShopStrings.openShop), findsNWidgets(2)); // Hoa Lư + Thiên Triều
    await tester.tap(find.text(PlayerShopStrings.openShop).first);
    await tester.pumpAndSettle();
    expect(find.byType(FacilityShopScreen), findsOneWidget);
    expect(find.text('Revive chanh muối'), findsOneWidget);
  });

  testWidgets('Lịch sử check-in: 20 lượt đầu, kéo xuống cuối thì tải thêm; có loại vé và nhãn Trễ', (tester) async {
    await pump(tester, const MyBookingsScreen());
    await tester.tap(find.text(PlayerShopStrings.historyTabShort));
    await tester.pumpAndSettle();
    expect(find.text(PlayerShopStrings.historyCount(shop.historyCount)), findsOneWidget);
    expect(find.text(PlayerShopStrings.late), findsWidgets);
    expect(find.text('Vé kèo LFG'), findsWidgets);

    // Lượt cuối cùng (số 26, nằm ở trang 2) chỉ hiện sau khi kéo xuống cuối tải thêm.
    final now = DateTime.now();
    final last = DateTime(now.year, now.month, now.day - shop.historyCount, 18).subtract(const Duration(minutes: 5));
    final lastText = find.text(Formatters.dateTime(last));
    expect(lastText, findsNothing);
    await tester.scrollUntilVisible(lastText, 400, scrollable: find.byType(Scrollable).last, maxScrolls: 100);
    expect(lastText, findsOneWidget);
  });

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('bố cục: shop, form đặt, Đơn mua tại sân, shop từ thẻ đơn, Lịch sử check-in', (tester) async {
    await tester.runAsync(() async {
      await shop.order(productId: 'p-tt-1', quantity: 3, note: 'Ghi chú dài để kiểm tra xuống dòng ở máy nhỏ, chữ to');
      await shop.order(productId: 'p-hl-2', quantity: 1);
    });
    await expectNoOverflow(tester, 'Shop tại sân', () => shopSection('f-hcm-thientrieu'), interact: (t) async {
      await t.tap(find.text(PlayerShopStrings.order).first);
      await settleFrames(t);
    });
    await expectNoOverflow(tester, 'Đơn mua tại sân', () => const MyShopOrdersScreen(autoRefresh: false),
        interact: scrollToEnd);
    await expectNoOverflow(tester, 'Shop từ thẻ đơn',
        () => const FacilityShopScreen(facilityId: 'f-hcm-thientrieu', facilityName: 'Sân Cầu Lông Thiên Triều'));
    await expectNoOverflow(tester, 'Lịch đặt (3 tab + lịch sử)', () => const MyBookingsScreen(initialTab: 2),
        interact: scrollToEnd);
  });
}
