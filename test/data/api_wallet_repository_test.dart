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

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiWalletRepository(api: ApiClient(tokens: tokens, dio: dio));
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
    expect(await repo.getPendingWithdrawalAmount(), 0);
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
  });

  test('trạng thái: NO_REFUND_* là không được hoàn, còn lại đều là thành công', () {
    for (final s in ['SUCCESS', 'LFG_JOIN', 'PRIZE_1ST', 'REFUNDED', 'WALKIN_CANCELLED', 'REFUNDED_BY_ADMIN_REPORT']) {
      expect(ApiWalletRepository.statusFromApi(s), TransactionStatus.success, reason: s);
    }
    expect(ApiWalletRepository.statusFromApi('NO_REFUND_LATE_CANCEL'), TransactionStatus.notRefunded);
    expect(ApiWalletRepository.statusFromApi('NO_REFUND_BY_ADMIN'), TransactionStatus.notRefunded);
  });

  test('chi tiết giao dịch tìm trong lịch sử; không có thì báo không tìm thấy', () async {
    server.transactionPages[1] = {'page': 1, 'pageSize': 100, 'totalItems': 1, 'items': [_tx(7)]};

    expect((await repo.getTransaction('tx-7')).description, 'Giao dịch 7');
    await expectLater(
      repo.getTransaction('khong-co'),
      throwsA(isA<WalletException>().having((e) => e.message, 'message', WalletStrings.transactionNotFound)),
    );
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

  test('nạp / rút / ngân hàng / thanh toán: báo đang phát triển, không gọi BE', () async {
    expect(repo.supportsTopUp, isFalse);
    expect(repo.supportsWithdrawal, isFalse);
    final inDevelopment = throwsA(
      isA<WalletException>().having((e) => e.message, 'message', WalletStrings.featureInDevelopment),
    );
    const account = BankAccount(id: 'b', bankCode: 'VCB', bankName: 'Vietcombank', accountNumber: '0123456789', accountHolder: 'A');

    await expectLater(repo.createTopUp(100000), inDevelopment);
    await expectLater(repo.cancelTopUp('x'), inDevelopment);
    await expectLater(repo.getBankAccounts(), inDevelopment);
    await expectLater(repo.removeBankAccount('b'), inDevelopment);
    await expectLater(repo.requestWithdrawal(amount: 50000, account: account), inDevelopment);
    await expectLater(
      repo.pay(amount: 1, type: TransactionType.bookingPayment, description: 'x'),
      inDevelopment,
    );
    expect(server.requests, isEmpty);
  });
}
