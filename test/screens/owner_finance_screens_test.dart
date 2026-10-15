import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/owner_finance_strings.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_owner_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/screens/owner/listing_fee_screen.dart';
import 'package:test1/screens/owner/owner_account_screen.dart';
import 'package:test1/screens/owner/owner_finance_screen.dart';

void main() {
  late AppUser owner;
  late MockWalletRepository wallet;

  // Dữ liệu cố định ở 15/10/2026: phí tháng 9 (hạn 07/10) chưa trả -> quá hạn.
  final fixedNow = DateTime(2026, 10, 15, 15, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    wallet = MockWalletRepository(
      latency: Duration.zero,
      keyPrefix: MockOwnerRepository.ownerWalletPrefix,
      initialBalance: 3200000,
    );
    AppRepositories.ownerWallet = wallet;
    AppRepositories.owner = MockOwnerRepository(latency: Duration.zero, now: () => fixedNow, wallet: wallet);
    owner = await auth.login('owner@sportnexus.vn', 'Owner@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('Doanh thu & Ví: số dư, doanh thu tháng, phí tạm tính, biểu đồ', (tester) async {
    await pump(tester, const OwnerFinanceScreen());
    expect(find.text(OwnerFinanceStrings.walletBalance), findsOneWidget);
    expect(find.text(OwnerFinanceStrings.totalRevenue), findsOneWidget);
    expect(find.text(OwnerFinanceStrings.atCourt), findsOneWidget);
    expect(find.text(OwnerFinanceStrings.estimatedFee), findsOneWidget);
    expect(find.text(OwnerFinanceStrings.chartHint), findsOneWidget);
    expect(find.text(OwnerFinanceStrings.byFacility), findsOneWidget);

    // Lùi về tháng 9 (đã có đủ số liệu), lọc một cơ sở.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFinanceStrings.monthLabel(DateTime(2026, 9))), findsOneWidget);
    final september = await AppRepositories.owner.getMonthlyRevenue(DateTime(2026, 9));
    expect(find.text(Formatters.vnd(september.total)), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sân Bóng Hoa Lư'));
    await tester.pumpAndSettle();
    final hoaLu = await AppRepositories.owner.getMonthlyRevenue(DateTime(2026, 9), facilityId: 'f-hcm-hoalu');
    expect(find.text(Formatters.vnd(hoaLu.total)), findsOneWidget);
    expect(find.text(OwnerFinanceStrings.byFacility), findsNothing);
  });

  testWidgets('nợ phí quá hạn: hiện cảnh báo cơ sở bị ẩn và chặn rút tiền', (tester) async {
    await pump(tester, const OwnerFinanceScreen());
    final sep = (await AppRepositories.owner.getListingFees()).first;
    expect(find.text(OwnerFinanceStrings.overdueBanner(sep.month, sep.amount)), findsOneWidget);

    await tester.tap(find.text(OwnerFinanceStrings.withdraw));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFinanceStrings.withdrawBlocked), findsOneWidget);
  });

  testWidgets('trả phí bằng ví: hết quá hạn', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${MockOwnerRepository.ownerWalletPrefix}${MockWalletRepository.keyBalance}', 50000000);
    await pump(tester, const ListingFeeScreen());
    expect(find.text(OwnerFinanceStrings.statusOverdue), findsOneWidget);
    expect(find.text(OwnerFinanceStrings.statusPaid), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, OwnerFinanceStrings.pay));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFinanceStrings.payByVietQr), findsOneWidget);
    await tester.tap(find.text(OwnerFinanceStrings.payByWallet));
    await tester.pumpAndSettle();

    expect(find.text(OwnerFinanceStrings.statusOverdue), findsNothing);
    expect(find.text(OwnerFinanceStrings.statusPaid), findsNWidgets(2));
  });

  testWidgets('ví không đủ: không chọn được trừ ví', (tester) async {
    await pump(tester, const ListingFeeScreen());
    await tester.tap(find.widgetWithText(ElevatedButton, OwnerFinanceStrings.pay));
    await tester.pumpAndSettle();
    expect(find.textContaining(OwnerFinanceStrings.insufficient), findsOneWidget);
    await tester.tap(find.text(OwnerFinanceStrings.payByWallet));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFinanceStrings.payByWallet), findsOneWidget); // vẫn ở sheet
  });

  testWidgets('tab Tài khoản mở được Doanh thu & Ví và Phí duy trì', (tester) async {
    await pump(tester, OwnerAccountScreen(user: owner));
    await tester.tap(find.text(OwnerStrings.menuRevenue));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFinanceStrings.title), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(OwnerStrings.menuListingFee));
    await tester.pumpAndSettle();
    expect(find.text(OwnerFinanceStrings.feeTitle), findsOneWidget);
  });
}
