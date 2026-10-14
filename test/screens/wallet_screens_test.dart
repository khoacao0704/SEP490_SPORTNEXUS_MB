import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/wallet_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/models/wallet_transaction.dart';
import 'package:test1/screens/profile/top_up_wallet_screen.dart';
import 'package:test1/screens/wallet/transaction_history_screen.dart';
import 'package:test1/screens/wallet/vietqr_payment_screen.dart';
import 'package:test1/screens/wallet/withdraw_screen.dart';

/// Màn VietQR có vòng xoay chờ và bộ hẹn giờ chạy liên tục nên không dùng được pumpAndSettle:
/// cho chạy đủ thời gian để chuyển màn / mở hộp thoại xong.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late MockWalletRepository wallet;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    wallet = MockWalletRepository(latency: Duration.zero);
    AppRepositories.wallet = wallet;
  });

  /// Mở [screen] từ một màn "launcher" để bắt được giá trị pop trả về.
  Future<List<Object?>> pumpLaunched(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final results = <Object?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                results.add(await Navigator.push(context, MaterialPageRoute(builder: (_) => screen)));
              },
              child: const Text('launch'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('launch'));
    await settle(tester);
    return results;
  }

  group('VietQR', () {
    testWidgets('giả lập đã chuyển khoản: cộng tiền, báo thành công, trả về true', (tester) async {
      final order = await wallet.createTopUp(200000);
      final results = await pumpLaunched(tester, VietQrPaymentScreen(order: order));

      expect(find.text(order.transferContent), findsOneWidget);
      expect(find.text(WalletStrings.sandboxNote), findsOneWidget);

      await tester.tap(find.text(WalletStrings.simulatePaid));
      await settle(tester);
      expect(find.text(WalletStrings.topUpSuccessTitle), findsOneWidget);

      await tester.tap(find.text(WalletStrings.done));
      await settle(tester);
      expect(results, [true]);
      expect(await wallet.getBalance(), 700000);
    });

    testWidgets('hủy giao dịch: hỏi xác nhận, lệnh chuyển sang đã hủy, trả về false', (tester) async {
      final order = await wallet.createTopUp(200000);
      final results = await pumpLaunched(tester, VietQrPaymentScreen(order: order));

      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.text(WalletStrings.cancelTopUpConfirm), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, WalletStrings.cancelTopUp).last);
      await settle(tester);

      expect(results, [false]);
      expect((await wallet.getTransaction(order.transactionId)).status, TransactionStatus.cancelled);
      expect(await wallet.getBalance(), 500000);
    });
  });

  testWidgets('Nạp tiền: MoMo chưa hỗ trợ; xác nhận thì sang màn VietQR', (tester) async {
    await pumpLaunched(tester, const TopUpWalletScreen());

    await tester.tap(find.text('Ví điện tử MoMo'));
    await settle(tester);
    expect(find.text(WalletStrings.onlyVietQr), findsOneWidget);

    final confirm = find.textContaining('Xác nhận nạp tiền');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await settle(tester);
    expect(find.byType(VietQrPaymentScreen), findsOneWidget);
    // Chưa chuyển khoản thì chưa cộng tiền.
    expect(await wallet.getBalance(), 500000);

    // Đóng màn VietQR để dừng các bộ hẹn giờ.
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, WalletStrings.cancelTopUp).last);
    await settle(tester);
  });

  testWidgets('Rút tiền: chặn dưới mức tối thiểu, gửi lệnh thì trừ số dư', (tester) async {
    await wallet.addBankAccount(
      bankCode: 'VCB',
      bankName: 'Vietcombank',
      accountNumber: '0123456789',
      accountHolder: 'NGUYEN VAN A',
    );
    final results = await pumpLaunched(tester, const WithdrawScreen());
    expect(find.textContaining('•••• 6789'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '30000');
    await tester.pump();
    expect(find.text('30.000'), findsOneWidget); // tự thêm dấu chấm
    await tester.tap(find.text(WalletStrings.withdrawButton));
    await settle(tester);
    expect(find.textContaining('tối thiểu'), findsWidgets);

    await tester.tap(find.text('100.000'));
    await settle(tester);
    await tester.tap(find.text(WalletStrings.withdrawButton));
    await settle(tester);
    await tester.tap(find.text(WalletStrings.confirm));
    await settle(tester);
    expect(find.text(WalletStrings.withdrawSubmittedTitle), findsOneWidget);

    await tester.tap(find.text(WalletStrings.understood));
    await settle(tester);
    expect(results, [true]);
    expect(await wallet.getBalance(), 400000);
    expect(await wallet.getPendingWithdrawalAmount(), 100000);
  });

  testWidgets('Lịch sử giao dịch: hiện giao dịch, lọc theo tiền vào / ra', (tester) async {
    await wallet.pay(amount: 140000, type: TransactionType.bookingPayment, description: 'Đặt sân Thiên Triều');
    await pumpLaunched(tester, const TransactionHistoryScreen());

    expect(find.text('Đặt sân Thiên Triều'), findsOneWidget);
    expect(find.text('Số dư ban đầu'), findsOneWidget);
    expect(find.text('-140.000 đ'), findsOneWidget);

    await tester.tap(find.text(WalletStrings.filterIn));
    await settle(tester);
    expect(find.text('Đặt sân Thiên Triều'), findsNothing);
    expect(find.text('Số dư ban đầu'), findsOneWidget);

    await tester.tap(find.text(WalletStrings.filterOut));
    await settle(tester);
    await tester.tap(find.text('Đặt sân Thiên Triều'));
    await settle(tester);
    expect(find.text(WalletStrings.transactionDetail), findsOneWidget);
  });
}
