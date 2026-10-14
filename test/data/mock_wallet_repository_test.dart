import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/constants/wallet_rules.dart';
import 'package:test1/core/strings/wallet_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/core/utils/input_formatters.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/wallet_repository.dart';
import 'package:test1/models/bank_account.dart';
import 'package:test1/models/wallet_transaction.dart';

void main() {
  late DateTime clock;
  late MockWalletRepository repo;

  MockWalletRepository newRepo() =>
      MockWalletRepository(latency: Duration.zero, now: () => clock, random: Random(1));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 14, 9, 0);
    repo = newRepo();
  });

  Matcher walletError(String message) =>
      throwsA(isA<WalletException>().having((e) => e.message, 'message', message));

  group('khởi tạo', () {
    test('máy mới: số dư mặc định 500.000 và 1 giao dịch "Số dư ban đầu"', () async {
      expect(await repo.getBalance(), 500000);
      final txs = await repo.getTransactions();
      expect(txs, hasLength(1));
      expect(txs.single.description, 'Số dư ban đầu');
      expect(txs.single.amount, 500000);
    });

    test('giữ nguyên số dư cũ của người dùng (key wallet_balance)', () async {
      SharedPreferences.setMockInitialValues({'wallet_balance': 320000});
      final r = newRepo();
      expect(await r.getBalance(), 320000);
      expect((await r.getTransactions()).single.amount, 320000);
    });
  });

  group('thanh toán bằng ví', () {
    test('trừ số dư và ghi giao dịch thành công', () async {
      final tx = await repo.pay(amount: 140000, type: TransactionType.bookingPayment, description: 'Đặt sân A');
      expect(tx.status, TransactionStatus.success);
      expect(tx.signedAmount, -140000);
      expect(await repo.getBalance(), 360000);
      expect((await repo.getTransactions()).first.description, 'Đặt sân A');
    });

    test('không đủ số dư thì báo lỗi, số dư giữ nguyên', () async {
      expect(
        () => repo.pay(amount: 600000, type: TransactionType.lfgDeposit, description: 'Cọc'),
        walletError(WalletStrings.insufficientBalance),
      );
      expect(await repo.getBalance(), 500000);
    });
  });

  group('nạp tiền VietQR', () {
    test('tạo lệnh: chờ thanh toán, CHƯA cộng tiền; có nội dung CK và hạn 15 phút', () async {
      final order = await repo.createTopUp(200000);
      expect(order.transferContent, matches(RegExp(r'^SPN [A-Z2-9]{6}$')));
      expect(order.expiresAt, clock.add(WalletRules.topUpExpiry));
      expect(order.qrData, isNot(startsWith('000201'))); // không phải mã chuyển khoản ngân hàng thật
      expect(await repo.getBalance(), 500000);
      expect((await repo.getTransaction(order.transactionId)).status, TransactionStatus.pending);
    });

    test('BE xác nhận đã nhận tiền thì mới cộng ví', () async {
      final order = await repo.createTopUp(200000);
      await repo.simulateTopUpReceived(order.transactionId);
      expect(await repo.getBalance(), 700000);
      expect((await repo.getTransaction(order.transactionId)).status, TransactionStatus.success);
    });

    test('xác nhận 2 lần không cộng tiền 2 lần', () async {
      final order = await repo.createTopUp(200000);
      await repo.simulateTopUpReceived(order.transactionId);
      expect(() => repo.simulateTopUpReceived(order.transactionId), walletError(WalletStrings.topUpNotPending));
      expect(await repo.getBalance(), 700000);
    });

    test('quá 15 phút chưa nhận tiền thì hết hạn, không cộng được nữa', () async {
      final order = await repo.createTopUp(200000);
      clock = clock.add(WalletRules.topUpExpiry);
      expect((await repo.getTransaction(order.transactionId)).status, TransactionStatus.expired);
      expect(() => repo.simulateTopUpReceived(order.transactionId), throwsA(isA<WalletException>()));
      expect(await repo.getBalance(), 500000);
    });

    test('hủy lệnh nạp', () async {
      final order = await repo.createTopUp(200000);
      await repo.cancelTopUp(order.transactionId);
      expect((await repo.getTransaction(order.transactionId)).status, TransactionStatus.cancelled);
    });

    test('ngoài hạn mức nạp thì báo lỗi', () async {
      expect(() => repo.createTopUp(WalletRules.minTopUp - 1), throwsA(isA<WalletException>()));
      expect(() => repo.createTopUp(WalletRules.maxTopUp + 1), throwsA(isA<WalletException>()));
    });
  });

  group('rút tiền', () {
    late BankAccount account;

    setUp(() async {
      account = await repo.addBankAccount(
        bankCode: 'VCB',
        bankName: 'Vietcombank',
        accountNumber: '0123456789',
        accountHolder: 'nguyen van a',
      );
    });

    test('lưu tài khoản: tên chủ TK in hoa, số TK che bớt khi hiển thị', () async {
      expect(account.accountHolder, 'NGUYEN VAN A');
      expect(account.maskedNumber, '•••• 6789');
      expect(await repo.getBankAccounts(), hasLength(1));
    });

    test('không lưu trùng tài khoản; xóa được', () async {
      expect(
        () => repo.addBankAccount(bankCode: 'VCB', bankName: 'Vietcombank', accountNumber: '0123456789', accountHolder: 'X'),
        walletError(WalletStrings.accountExists),
      );
      await repo.removeBankAccount(account.id);
      expect(await repo.getBankAccounts(), isEmpty);
    });

    test('gửi lệnh: trừ số dư ngay, trạng thái chờ xử lý', () async {
      final tx = await repo.requestWithdrawal(amount: 200000, account: account);
      expect(tx.status, TransactionStatus.pending);
      expect(tx.reference, contains('0123456789'));
      expect(await repo.getBalance(), 300000);
      expect(await repo.getPendingWithdrawalAmount(), 200000);
    });

    test('được duyệt: thành công, không hoàn tiền', () async {
      final tx = await repo.requestWithdrawal(amount: 200000, account: account);
      await repo.simulateWithdrawalProcessed(tx.id, approved: true);
      expect((await repo.getTransaction(tx.id)).status, TransactionStatus.success);
      expect(await repo.getBalance(), 300000);
      expect(await repo.getPendingWithdrawalAmount(), 0);
    });

    test('bị từ chối: hoàn lại tiền vào ví', () async {
      final tx = await repo.requestWithdrawal(amount: 200000, account: account);
      await repo.simulateWithdrawalProcessed(tx.id, approved: false);
      expect((await repo.getTransaction(tx.id)).status, TransactionStatus.failed);
      expect(await repo.getBalance(), 500000);
    });

    test('dưới mức tối thiểu hoặc vượt số dư thì báo lỗi', () async {
      expect(
        () => repo.requestWithdrawal(amount: WalletRules.minWithdrawal - 1000, account: account),
        walletError(WalletStrings.belowMinWithdrawal(Formatters.vnd(WalletRules.minWithdrawal))),
      );
      expect(
        () => repo.requestWithdrawal(amount: 500001, account: account),
        walletError(WalletStrings.insufficientBalance),
      );
      expect(await repo.getBalance(), 500000);
    });
  });

  test('lịch sử: mới nhất trước, còn nguyên sau khi khởi động lại app', () async {
    await repo.pay(amount: 100000, type: TransactionType.bookingPayment, description: 'A');
    clock = clock.add(const Duration(minutes: 5));
    await repo.pay(amount: 50000, type: TransactionType.flashClaim, description: 'B');

    final txs = await newRepo().getTransactions();
    expect(txs.map((t) => t.description).take(2), ['B', 'A']);
    expect(await newRepo().getBalance(), 350000);
  });

  group('ThousandsInputFormatter', () {
    TextEditingValue fmt(String text) =>
        ThousandsInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

    test('thêm dấu chấm hàng nghìn, bỏ ký tự lạ', () {
      expect(fmt('1500000').text, '1.500.000');
      expect(fmt('12a3').text, '123');
      expect(fmt('').text, '');
      expect(ThousandsInputFormatter.parse('1.500.000'), 1500000);
      expect(ThousandsInputFormatter.parse(''), 0);
    });
  });
}
