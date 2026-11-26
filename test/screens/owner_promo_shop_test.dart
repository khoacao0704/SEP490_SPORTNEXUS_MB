import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_shop_strings.dart';
import 'package:test1/core/strings/owner_slot_strings.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/owner_promotion.dart';
import 'package:test1/models/owner_shop.dart';
import 'package:test1/models/wallet_transaction.dart';
import 'package:test1/screens/owner/owner_account_screen.dart';
import 'package:test1/screens/owner/owner_promotions_screen.dart';
import 'package:test1/screens/owner/owner_shop_screen.dart';

import '../helpers/layout_check.dart';

void main() {
  late MockOwnerRepository repo;
  late MockWalletRepository wallet;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    wallet = MockWalletRepository(latency: Duration.zero, keyPrefix: MockOwnerRepository.ownerWalletPrefix, initialBalance: 600000);
    AppRepositories.ownerWallet = wallet;
    repo = MockOwnerRepository(latency: Duration.zero, wallet: wallet);
    AppRepositories.owner = repo;
    await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  Matcher throwsOwner(String message) =>
      throwsA(isA<OwnerException>().having((e) => e.message, 'message', message));

  group('Quảng bá', () {
    test('mua gói trừ ví; đang chạy thì nối thời hạn (Chờ chạy); không đủ tiền thì báo', () async {
      expect((await repo.getPromotionPackages()).map((p) => p.id), ['pk-7', 'pk-30']);
      expect(await repo.getMyPromotions(activeOnly: true), hasLength(1));

      await repo.purchasePromotion(packageId: 'pk-7', facilityId: 'f-hcm-thientrieu');
      expect(await wallet.getBalance(), 450000);
      final first = (await repo.getMyPromotions()).first;
      expect(first.status, PromotionStatus.scheduled);
      expect(first.endAt!.difference(first.startAt!).inDays, 7);

      await repo.purchasePromotion(packageId: 'pk-7', facilityId: 'f-hcm-hoalu');
      expect((await repo.getMyPromotions()).first.status, PromotionStatus.active);

      await expectLater(repo.purchasePromotion(packageId: 'pk-30', facilityId: 'f-hcm-hoalu'), throwsA(isA<OwnerException>()));
      await expectLater(
        repo.purchasePromotion(packageId: 'pk-7', facilityId: 'f-own-pending'),
        throwsOwner(OwnerPromoStrings.pickTarget),
      );
    });
  });

  group('Shop tại sân', () {
    test('sản phẩm: thêm / sửa / xóa, kiểm tên - giá - tồn kho; gồm cả sản phẩm ẩn', () async {
      expect((await repo.getShopProducts('f-hcm-thientrieu')).where((p) => !p.isActive), hasLength(1));
      await expectLater(
        repo.createShopProduct('f-hcm-thientrieu', const ShopProductInput(name: ' ', price: 1, stock: 1)),
        throwsOwner(OwnerShopStrings.errName),
      );
      await repo.createShopProduct('f-hcm-hoalu', const ShopProductInput(name: 'Khăn lạnh', price: 5000, stock: 100));
      final added = (await repo.getShopProducts('f-hcm-hoalu')).last;
      await repo.updateShopProduct(added.id, const ShopProductInput(name: 'Khăn lạnh', price: 6000, stock: 90, isActive: false));
      expect((await repo.getShopProducts('f-hcm-hoalu')).last.price, 6000);
      await repo.deleteShopProduct(added.id);
      expect(await repo.getShopProducts('f-hcm-hoalu'), hasLength(1));
    });

    test('đơn: Chờ chuẩn bị → Sẵn sàng → Đã nhận; hủy được khi chưa nhận; lọc trạng thái', () async {
      expect((await repo.getShopOrders('f-hcm-thientrieu', status: ShopOrderStatus.pending)).single.id, 'so-1');
      await repo.updateShopOrderStatus('so-1', ShopOrderStatus.ready);
      await repo.updateShopOrderStatus('so-1', ShopOrderStatus.pickedUp);
      await expectLater(repo.updateShopOrderStatus('so-1', ShopOrderStatus.cancelled), throwsOwner(OwnerShopStrings.badTransition));
      await expectLater(repo.updateShopOrderStatus('so-2', ShopOrderStatus.pending), throwsOwner(OwnerShopStrings.badTransition));
      await repo.updateShopOrderStatus('so-2', ShopOrderStatus.cancelled);
      expect((await repo.getShopOrders('f-hcm-thientrieu', status: ShopOrderStatus.cancelled)).single.id, 'so-2');
    });
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('quảng bá: mua gói qua bảng xác nhận, hiện trong lượt đã mua', (tester) async {
    await pump(tester, const OwnerPromotionsScreen());
    expect(find.text('Nổi bật 7 ngày'), findsWidgets);
    await tester.tap(find.text(OwnerPromoStrings.buy).first);
    await tester.pumpAndSettle();
    expect(find.text(OwnerPromoStrings.buyTitle('Nổi bật 7 ngày')), findsOneWidget);
    expect(find.text('600.000 Điểm'), findsOneWidget);
    await tester.tap(find.text(OwnerPromoStrings.pay('150.000 Điểm')));
    await tester.pumpAndSettle();
    expect(find.text(OwnerPromoStrings.bought('Nổi bật 7 ngày')), findsOneWidget);
    expect(find.text(PromotionStatus.scheduled.label), findsOneWidget);
  });

  testWidgets('quảng bá: số dư không đủ thì khóa nút thanh toán', (tester) async {
    await pump(tester, const OwnerPromotionsScreen());
    await wallet.pay(amount: 500000, type: TransactionType.walletPayment, description: 'x');
    await tester.tap(find.text(OwnerPromoStrings.buy).last);
    await tester.pumpAndSettle();
    expect(find.text(OwnerPromoStrings.notEnough), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, OwnerPromoStrings.pay('500.000 Điểm')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('shop: đơn chuyển bước, hủy có xác nhận; thêm sản phẩm', (tester) async {
    await pump(tester, const OwnerShopScreen(initialFacilityId: 'f-hcm-thientrieu'));
    expect(find.text('${OwnerShopStrings.tabOrders} (1)'), findsOneWidget);
    await tester.tap(find.text('Báo đã chuẩn bị xong'));
    await tester.pumpAndSettle();
    expect(find.text(OwnerShopStrings.orderUpdated), findsOneWidget);
    expect(find.text('Khách đã nhận & trả tiền'), findsNWidgets(2));

    await tester.tap(find.text(OwnerShopStrings.cancelOrder).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerSlotStrings.confirm));
    await tester.pumpAndSettle();
    expect(find.text(OwnerShopStrings.orderCancelled), findsOneWidget);

    await tester.tap(find.text(OwnerShopStrings.tabProducts(3)));
    await tester.pumpAndSettle();
    expect(find.text(OwnerShopStrings.hidden), findsOneWidget);
    await tester.tap(find.text(OwnerShopStrings.addProduct).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerShopStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(OwnerShopStrings.errName), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, OwnerShopStrings.fName), 'Khăn lạnh');
    await tester.enterText(find.widgetWithText(TextField, OwnerShopStrings.fPrice), '5000');
    await tester.enterText(find.widgetWithText(TextField, OwnerShopStrings.fStock), '20');
    await tester.tap(find.text(OwnerShopStrings.save));
    await tester.pumpAndSettle();
    expect(find.text('Khăn lạnh'), findsOneWidget);
    expect(find.text(OwnerShopStrings.tabProducts(4)), findsOneWidget);
  });

  testWidgets('tab Tài khoản mở Quảng bá và Shop tại sân', (tester) async {
    final owner = (await AppRepositories.auth.getCurrentUser())!;
    await pump(tester, OwnerAccountScreen(user: owner, onSelectTab: (_) {}));
    await tester.tap(find.text(OwnerStrings.menuPromotions));
    await tester.pumpAndSettle();
    expect(find.text(OwnerPromoStrings.packagesTitle), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerStrings.menuShop));
    await tester.pumpAndSettle();
    expect(find.text(OwnerShopStrings.subtitle), findsOneWidget);
  });

  Future<void> scrollAll(WidgetTester t) async {
    for (var i = 0; i < 20; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -500), warnIfMissed: false);
      await t.pump();
    }
  }

  testWidgets('bố cục Quảng bá và Shop: nhiều cỡ máy + chữ phóng to không tràn', (tester) async {
    final problems = [
      ...await collectLayoutProblems(tester, 'Quảng bá', () => const OwnerPromotionsScreen(), interact: (t) async {
        await scrollAll(t);
        await t.tap(find.text(OwnerPromoStrings.buy).first, warnIfMissed: false);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }),
      ...await collectLayoutProblems(tester, 'Shop - đơn', () => const OwnerShopScreen(), interact: scrollAll),
      ...await collectLayoutProblems(tester, 'Shop - sản phẩm', () => const OwnerShopScreen(), interact: (t) async {
        await t.tap(find.text(OwnerShopStrings.tabProducts(3)), warnIfMissed: false);
        await t.pump();
        await scrollAll(t);
        await t.tap(find.text(OwnerShopStrings.edit).first, warnIfMissed: false);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }),
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
