import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/wallet_strings.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_wallet_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/wallet_repository.dart';
import 'package:test1/models/bank_account.dart';
import 'package:test1/models/wallet_transaction.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  /// Phản hồi theo số trang cho GET /api/v1/wallet/transactions.
  final Map<int, Object?> transactionPages = {};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    (int, Object?)? route = routes[key];
    if (options.path == ApiWalletRepository.transactionsPath) {
      final page = options.queryParameters['page'] as int;
      route = (200, {'statusCode': 200, 'message': 'OK', 'data': transactionPages[page]});
    }
    if (route == null) return ResponseBody.fromString('', 404);
    final (status, body) = route;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _tx(int i, {String type = 'DEPOSIT', String status = 'SUCCESS', num amount = 100000.00}) => {
  'id': 'tx-$i',
  'type': type,
  'amount': amount,
  'status': status,
  'description': 'Giao dịch $i',
  'referenceId': i.isEven ? 'ref-$i' : null,
  'createdAt': '2026-10-16T03:00:00+00:00',
};

void main() {
  late _FakeServer server;
  late ApiWalletRepository repo;
  late ApiClient api;

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    api = ApiClient(tokens: tokens, dio: dio);
    repo = ApiWalletRepository(api: api);
  });

  test('số dư lấy availableBalance, tạm giữ lấy frozenBalance, dùng chung một request khi gọi cùng lúc', () async {
    server.routes['GET ${ApiWalletRepository.walletPath}'] = (
      200,
      {
        'statusCode': 200,
        'message': 'OK',
        'data': {'balance': 450000.00, 'frozenBalance': 50000.00, 'availableBalance': 450000.00, 'totalBalance': 500000.00},
      },
    );

    final result = await Future.wait([repo.getBalance(), repo.getFrozenBalance()]);

    expect(result, [450000, 50000]);
    expect(server.requests.where((r) => r.path == ApiWalletRepository.walletPath), hasLength(1));
  });

  test('lịch sử: đổi loại / trạng thái / giờ địa phương và tải hết các trang', () async {
    server.transactionPages[1] = {
      'page': 1,
      'pageSize': 100,
      'totalItems': 101,
      'items': [
        _tx(0, type: 'FREEZE', status: 'LFG_HOLD', amount: 75000.00),
        ...List.generate(99, (i) => _tx(i + 1)),
      ],
    };
    server.transactionPages[2] = {
      'page': 2,
      'pageSize': 100,
      'totalItems': 101,
      'items': [_tx(100, type: 'RELEASE', status: 'LFG_REFUND')],
    };

    final txs = await repo.getTransactions();

    expect(txs, hasLength(101));
    expect(server.requests.map((r) => r.queryParameters['pageSize']).toSet(), {100});
    final hold = txs.first;
    expect(hold.type, TransactionType.hold);
    expect(hold.type.isCredit, isFalse);
    expect(hold.status, TransactionStatus.success);
    expect(hold.amount, 75000);
    expect(hold.reference, 'ref-0');
    expect(hold.createdAt, DateTime.utc(2026, 10, 16, 3).toLocal());
    expect(txs[1].type, TransactionType.deposit);
    expect(txs[1].reference, isNull);
    expect(txs.last.type, TransactionType.holdRelease);
  });

  test('chiều tiền theo type; PAYOUT xét thêm status', () {
    TransactionType type(String t, [String s = 'SUCCESS']) => ApiWalletRepository.typeFromApi(t, s);

    expect(type('DEPOSIT', 'LFG_RELEASE').isCredit, isTrue);
    expect(type('FREEZE', 'LFG_HOLD').isCredit, isFalse);
    expect(type('REFUND', 'LFG_REFUND').isCredit, isTrue);
    expect(type('RELEASE', 'LFG_RELEASE').isCredit, isFalse);
    expect(type('PAYOUT'), TransactionType.walletPayment);
    expect(type('PAYOUT', 'LFG_REFUND'), TransactionType.walletPayment);
    expect(type('PAYOUT', 'PRIZE_1ST'), TransactionType.prize);
    expect(type('PAYOUT', 'PRIZE_2ND').isCredit, isTrue);

    // Loại lạ (vd. Admin cộng / trừ tay): theo dấu balanceChange.
    expect(ApiWalletRepository.typeFromApi('ADJUST', 'SUCCESS', -20000).isCredit, isFalse);
    expect(ApiWalletRepository.typeFromApi('ADJUST', 'SUCCESS', 20000).isCredit, isTrue);
    expect(ApiWalletRepository.typeFromApi('ADJUST').isCredit, isTrue);
    expect(ApiWalletRepository.typeFromApi('REFUND', 'SUCCESS', 0), TransactionType.refund);
  });

  test('trạng thái: NO_REFUND_* là không được hoàn, còn lại đều là thành công', () {
    for (final s in ['SUCCESS', 'LFG_JOIN', 'PRIZE_1ST', 'REFUNDED', 'WALKIN_CANCELLED', 'REFUNDED_BY_ADMIN_REPORT']) {
      expect(ApiWalletRepository.statusFromApi(s), TransactionStatus.success, reason: s);
    }
    expect(ApiWalletRepository.statusFromApi('NO_REFUND_LATE_CANCEL'), TransactionStatus.notRefunded);
    expect(ApiWalletRepository.statusFromApi('NO_REFUND_BY_ADMIN'), TransactionStatus.notRefunded);
  });

  test('trạng thái lệnh nạp / rút: chờ, đã hủy, thất bại; nạp đã hủy trong lịch sử không tính là thành công', () {
    expect(ApiWalletRepository.statusFromApi('PENDING_PAYMENT'), TransactionStatus.pending);
    expect(ApiWalletRepository.statusFromApi('PENDING'), TransactionStatus.pending);
    expect(ApiWalletRepository.statusFromApi('CANCELLED'), TransactionStatus.cancelled);
    expect(ApiWalletRepository.statusFromApi('FAILED'), TransactionStatus.failed);
    expect(ApiWalletRepository.statusFromApi('REJECTED'), TransactionStatus.failed);
    expect(ApiWalletRepository.statusFromApi('COMPLETED'), TransactionStatus.success);
    expect(ApiWalletRepository.typeFromApi('WITHDRAWAL'), TransactionType.withdrawal);

    final tx = ApiWalletRepository.transactionFromApi(_tx(1, status: 'CANCELLED', amount: 10000.00));
    expect(tx.type, TransactionType.deposit);
    expect(tx.status, TransactionStatus.cancelled);
  });

  test('chi tiết giao dịch: GET /transactions/{id} (không tải cả lịch sử); không có (404) thì báo không tìm thấy', () async {
    server.routes['GET ${ApiWalletRepository.transactionPath('tx-7')}'] =
        (200, {'statusCode': 200, 'message': 'OK', 'data': _tx(7)});
    server.routes['GET ${ApiWalletRepository.transactionPath('khong-co')}'] =
        (404, {'statusCode': 404, 'message': 'Không tìm thấy giao dịch', 'data': null});

    expect((await repo.getTransaction('tx-7')).description, 'Giao dịch 7');
    expect(server.requests.single.path, '/api/v1/wallet/transactions/tx-7');
    await expectLater(
      repo.getTransaction('khong-co'),
      throwsA(isA<WalletException>().having((e) => e.message, 'message', WalletStrings.transactionNotFound)),
    );
  });

  test('lệnh nạp hết hạn (EXPIRED) là "Hết hạn", không phải thành công', () {
    expect(ApiWalletRepository.statusFromApi('EXPIRED'), TransactionStatus.expired);
    expect(ApiWalletRepository.transactionFromApi(_tx(1, status: 'EXPIRED')).status, TransactionStatus.expired);
  });

  test('ghi chú (note) của BE: có thì hiện, rỗng / null thì bỏ', () {
    expect(
      ApiWalletRepository.transactionFromApi({..._tx(1, type: 'WITHDRAW'), 'note': ' Mã giao dịch ngân hàng: FT123 '}).note,
      'Mã giao dịch ngân hàng: FT123',
    );
    expect(ApiWalletRepository.transactionFromApi({..._tx(1), 'note': '  '}).note, isNull);
    expect(ApiWalletRepository.transactionFromApi(_tx(1)).note, isNull);
  });

  test('lỗi BE thành WalletException mang câu tiếng Việt', () async {
    server.routes['GET ${ApiWalletRepository.walletPath}'] = (
      500,
      {'statusCode': 500, 'message': 'Lỗi hệ thống: abc', 'data': null},
    );

    await expectLater(
      repo.getBalance(),
      throwsA(isA<WalletException>().having((e) => e.message, 'message', 'Lỗi hệ thống: abc')),
    );
  });

  Map<String, dynamic> ok(Object? data) => {'statusCode': 200, 'message': 'OK', 'data': data};
  Map<String, dynamic> fail(int code, String message) => {'statusCode': code, 'message': message, 'data': null};
  Matcher walletError(String message) =>
      throwsA(isA<WalletException>().having((e) => e.message, 'message', message));
  const account = BankAccount(
    id: 'default',
    bankCode: 'VCB',
    bankName: 'Vietcombank',
    accountNumber: '0123456789',
    accountHolder: 'NGUYEN VAN A',
  );

  group('nạp tiền PayOS', () {
    test('tạo lệnh: đếm ngược theo expiresAt của BE', () async {
      server.routes['POST ${ApiWalletRepository.depositPath}'] = (
        201,
        ok({
          'orderCode': 1,
          'amount': 10000,
          'status': 'PENDING_PAYMENT',
          'checkoutUrl': 'https://pay.payos.vn/web/abc',
          'qrCode': '0002...',
          'expiresAt': '2026-10-27T08:15:00+00:00',
        }),
      );
      final order = await repo.createTopUp(10000);
      expect(order.expiresAt, DateTime.utc(2026, 10, 27, 8, 15).toLocal());
    });

    test('tạo lệnh: QR + trang thanh toán của PayOS; BE không trả hạn thì tự đặt 15 phút, không có chuyển khoản tay',
        () async {
      server.routes['POST ${ApiWalletRepository.depositPath}'] = (
        201,
        {
          'statusCode': 201,
          'message': 'Đã tạo yêu cầu nạp tiền',
          'data': {
            'orderCode': 17924735835970,
            'amount': 10000,
            'status': 'PENDING_PAYMENT',
            'checkoutUrl': 'https://pay.payos.vn/web/abc',
            'qrCode': '000201010212...',
          },
        },
      );
      final before = DateTime.now();
      final order = await repo.createTopUp(10000);

      expect(server.requests.single.data, {'amount': 10000});
      expect(order.transactionId, '17924735835970');
      expect(order.amount, 10000);
      expect(order.qrData, '000201010212...');
      expect(order.checkoutUrl, 'https://pay.payos.vn/web/abc');
      expect(order.hasTransferInfo, isFalse);
      expect(order.expiresAt.difference(before).inMinutes, 15);
    });

    test('số tiền sai / chưa cấu hình PayOS: hiện câu của BE', () async {
      server.routes['POST ${ApiWalletRepository.depositPath}'] = (
        400,
        fail(400, 'Số tiền nạp phải là số nguyên từ 10,000đ đến 50,000,000đ'),
      );
      await expectLater(repo.createTopUp(9999), walletError('Số tiền nạp phải là số nguyên từ 10,000đ đến 50,000,000đ'));
    });

    test('hỏi trạng thái theo orderCode', () async {
      for (final (status, expected) in [
        ('PENDING_PAYMENT', TransactionStatus.pending),
        ('SUCCESS', TransactionStatus.success),
        ('CANCELLED', TransactionStatus.cancelled),
        ('EXPIRED', TransactionStatus.expired),
        ('FAILED', TransactionStatus.failed),
      ]) {
        server.routes['GET ${ApiWalletRepository.depositStatusPath('123')}'] = (
          200,
          ok({'orderCode': '123', 'amount': 10000.00, 'status': status, 'createdAt': '2026-10-20T05:19:43+00:00'}),
        );
        expect(await repo.getTopUpStatus('123'), expected, reason: status);
      }
    });

    test('hủy lệnh; lệnh không còn chờ (400) thì bỏ qua, lỗi khác thì báo', () async {
      server.routes['POST ${ApiWalletRepository.depositCancelPath('123')}'] = (200, ok(null));
      await repo.cancelTopUp('123');
      expect(server.requests.single.path, '/api/v1/wallet/deposits/123/cancel');

      server.routes['POST ${ApiWalletRepository.depositCancelPath('123')}'] = (
        400,
        fail(400, 'Không có yêu cầu nạp tiền đang chờ thanh toán'),
      );
      await repo.cancelTopUp('123');

      server.routes['POST ${ApiWalletRepository.depositCancelPath('123')}'] = (500, fail(500, 'Lỗi hệ thống'));
      await expectLater(repo.cancelTopUp('123'), walletError('Lỗi hệ thống'));
    });
  });

  group('tài khoản ngân hàng & rút tiền', () {
    test('chưa lưu tài khoản: các trường null → danh sách rỗng', () async {
      expect(repo.singleBankAccount, isTrue);
      server.routes['GET ${ApiWalletRepository.bankAccountPath}'] = (
        200,
        ok({'bankName': null, 'bankAccountNumber': null, 'bankAccountHolder': null}),
      );
      expect(await repo.getBankAccounts(), isEmpty);
    });

    test('đã lưu: một tài khoản, ghép mã ngân hàng theo tên', () async {
      server.routes['GET ${ApiWalletRepository.bankAccountPath}'] = (
        200,
        ok({'bankName': 'Vietcombank', 'bankAccountNumber': '0123456789', 'bankAccountHolder': 'NGUYEN VAN A'}),
      );
      final accounts = await repo.getBankAccounts();
      expect(accounts.single.bankCode, 'VCB');
      expect(accounts.single.shortLabel, 'VCB •••• 6789');
    });

    test('lưu tài khoản: PUT ghi đè; xóa thì BE không hỗ trợ', () async {
      server.routes['PUT ${ApiWalletRepository.bankAccountPath}'] = (
        200,
        ok({'bankName': 'Vietcombank', 'bankAccountNumber': '0123456789', 'bankAccountHolder': 'NGUYEN VAN A'}),
      );
      final saved = await repo.addBankAccount(
        bankCode: 'VCB',
        bankName: 'Vietcombank',
        accountNumber: ' 0123456789 ',
        accountHolder: 'NGUYEN VAN A',
      );
      expect(server.requests.single.method, 'PUT');
      expect(server.requests.single.data, {
        'bankName': 'Vietcombank',
        'bankAccountNumber': '0123456789',
        'bankAccountHolder': 'NGUYEN VAN A',
      });
      expect(saved.accountNumber, '0123456789');
      await expectLater(repo.removeBankAccount('default'), walletError(WalletStrings.featureInDevelopment));
    });

    test('gửi lệnh rút: chỉ gửi số tiền, trạng thái chờ xử lý', () async {
      server.routes['POST ${ApiWalletRepository.withdrawalsPath}'] = (
        200,
        ok({'id': 'w-1', 'amount': 50000.00, 'status': 'PENDING', 'createdAt': '2026-10-20T05:00:00+00:00'}),
      );
      final tx = await repo.requestWithdrawal(amount: 50000, account: account);
      expect(server.requests.single.data, {'amount': 50000});
      expect(tx.id, 'w-1');
      expect(tx.type, TransactionType.withdrawal);
      expect(tx.status, TransactionStatus.pending);
      expect(tx.amount, 50000);
    });

    test('BE chặn (chưa lưu tài khoản / không đủ số dư / Người chơi chưa được rút): hiện câu của BE', () async {
      server.routes['POST ${ApiWalletRepository.withdrawalsPath}'] = (
        400,
        fail(400, 'Vui lòng lưu tài khoản ngân hàng trước khi rút tiền'),
      );
      await expectLater(
        repo.requestWithdrawal(amount: 50000, account: account),
        walletError('Vui lòng lưu tài khoản ngân hàng trước khi rút tiền'),
      );

      server.routes['GET ${ApiWalletRepository.bankAccountPath}'] = (
        403,
        fail(403, 'Bạn không có quyền truy cập vào tài nguyên này.'),
      );
      await expectLater(repo.getBankAccounts(), walletError('Bạn không có quyền truy cập vào tài nguyên này.'));
    });

    test('Người chơi rút được tiền (mặc định bật); tắt thì tiền chờ rút là 0, không gọi BE', () async {
      expect(repo.supportsWithdrawal, isTrue);
      repo = ApiWalletRepository(api: api, supportsWithdrawal: false);
      expect(await repo.getPendingWithdrawalAmount(), 0);
      expect(server.requests, isEmpty);
    });

    test('hủy yêu cầu rút: tìm lệnh PENDING (id lệnh rút) rồi POST cancel', () async {
      server.routes['GET ${ApiWalletRepository.withdrawalsPath}'] = (
        200,
        ok({
          'items': [
            {'id': 'w-2', 'amount': 70000.00, 'status': 'COMPLETED'},
            {'id': 'w-1', 'amount': 50000.00, 'status': 'PENDING'},
          ],
        }),
      );
      server.routes['POST ${ApiWalletRepository.withdrawalCancelPath('w-1')}'] = (200, ok(null));
      final pending = ApiWalletRepository.transactionFromApi(_tx(9, type: 'WITHDRAW', status: 'PENDING'));
      expect(pending.isPendingWithdrawal, isTrue);

      await repo.cancelWithdrawal(pending);

      expect(server.requests.last.method, 'POST');
      expect(server.requests.last.path, '/api/v1/wallet/withdrawals/w-1/cancel');
    });

    test('hủy yêu cầu rút khi Admin vừa xử lý xong (không còn lệnh chờ): báo, không gọi hủy', () async {
      server.routes['GET ${ApiWalletRepository.withdrawalsPath}'] = (
        200,
        ok({
          'items': [
            {'id': 'w-1', 'amount': 50000.00, 'status': 'COMPLETED'},
          ],
        }),
      );
      await expectLater(
        repo.cancelWithdrawal(ApiWalletRepository.transactionFromApi(_tx(9, type: 'WITHDRAW', status: 'PENDING'))),
        walletError(WalletStrings.noPendingWithdrawal),
      );
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    test('tiền đang chờ rút = tổng lệnh PENDING; không có quyền rút (403) thì 0', () async {
      server.routes['GET ${ApiWalletRepository.withdrawalsPath}'] = (
        200,
        ok({
          'page': 1,
          'pageSize': 100,
          'totalItems': 3,
          'items': [
            {'id': 'w-1', 'amount': 50000.00, 'status': 'PENDING'},
            {'id': 'w-2', 'amount': 70000.00, 'status': 'COMPLETED'},
            {'id': 'w-3', 'amount': 30000.00, 'status': 'REJECTED'},
          ],
        }),
      );
      expect(await repo.getPendingWithdrawalAmount(), 50000);

      server.routes['GET ${ApiWalletRepository.withdrawalsPath}'] = (403, fail(403, 'Không có quyền'));
      expect(await repo.getPendingWithdrawalAmount(), 0);
    });
  });

  test('thanh toán bằng ví: chưa nối, không gọi BE', () async {
    await expectLater(
      repo.pay(amount: 1, type: TransactionType.bookingPayment, description: 'x'),
      walletError(WalletStrings.featureInDevelopment),
    );
    expect(server.requests, isEmpty);
  });
}
