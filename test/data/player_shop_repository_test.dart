import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_player_shop_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/mock/mock_player_shop_repository.dart';
import 'package:test1/data/repositories/player_shop_repository.dart';
import 'package:test1/models/booking.dart';
import 'package:test1/models/check_in_record.dart';
import 'package:test1/models/owner_shop.dart';

class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  void ok(String method, String path, Object? data) =>
      routes['$method $path'] = (200, {'statusCode': 200, 'message': 'OK', 'data': data});

  void fail(String method, String path, int code, String message) =>
      routes['$method $path'] = (code, {'statusCode': code, 'message': message, 'data': null});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) return ResponseBody.fromString('', 404);
    final (status, body) = route;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Booking _booking({
  String? facilityId = 'f1',
  String facilityName = 'Sân A',
  Duration startIn = const Duration(days: 1),
  bool checkedIn = false,
  bool awaiting = false,
  bool cancelled = false,
}) {
  final now = DateTime.now();
  final start = now.add(startIn);
  return Booking(
    id: 'b1',
    bookerId: 'u1',
    facilityName: facilityName,
    facilityId: facilityId,
    location: '',
    sportLabel: 'Cầu Lông',
    schedule: '',
    start: start,
    end: start.add(const Duration(hours: 1)),
    totalPrice: 100000,
    paymentType: BookingPaymentType.full,
    payments: const [],
    createdAt: now,
    cancelledAt: cancelled ? now : null,
    isCheckedIn: checkedIn,
    awaitingPayment: awaiting,
  );
}

void main() {
  group('Booking.allowsShopAt (shop chỉ mở cho người có đơn ở cơ sở đó, trước check-in)', () {
    final now = DateTime.now();
    bool allows(Booking b, {String id = 'f1', String name = 'Sân A'}) =>
        b.allowsShopAt(facilityId: id, facilityName: name, now: now);

    test('đơn sắp tới chưa check-in ở đúng cơ sở thì mở; sai cơ sở thì không', () {
      expect(allows(_booking()), isTrue);
      expect(allows(_booking(), id: 'f2'), isFalse);
    });

    test('đang chơi nhưng chưa check-in vẫn mở; đã check-in / hết giờ / đã hủy / còn chờ góp thì không', () {
      expect(allows(_booking(startIn: const Duration(minutes: -30))), isTrue);
      expect(allows(_booking(checkedIn: true)), isFalse);
      expect(allows(_booking(startIn: const Duration(hours: -2))), isFalse);
      expect(allows(_booking(cancelled: true)), isFalse);
      expect(allows(_booking(awaiting: true)), isFalse);
    });

    test('BE không trả mã cơ sở thì so theo tên', () {
      expect(allows(_booking(facilityId: null), id: 'khác'), isTrue);
      expect(allows(_booking(facilityId: null), name: 'Sân B'), isFalse);
    });
  });

  group('ApiPlayerShopRepository', () {
    late _FakeServer server;
    late ApiPlayerShopRepository repo;

    setUp(() async {
      server = _FakeServer();
      final tokens = MemoryTokenStore();
      await tokens.write('token');
      final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
      repo = ApiPlayerShopRepository(api: ApiClient(tokens: tokens, dio: dio));
    });

    test('sản phẩm: chỉ giữ hàng đang bán', () async {
      server.ok('GET', ApiPlayerShopRepository.productsPath('f1'), [
        {'id': 'p1', 'facilityId': 'f1', 'name': 'Nước', 'price': 10000, 'stock': 5, 'isActive': true},
        {'id': 'p2', 'facilityId': 'f1', 'name': 'Ẩn', 'price': 5000, 'stock': 5, 'isActive': false},
      ]);
      expect((await repo.getProducts('f1')).map((p) => p.id), ['p1']);
    });

    test('đặt hàng gửi productId + quantity + note (rỗng thì null); hủy; đơn của tôi mới nhất trước', () async {
      server.ok('POST', ApiPlayerShopRepository.ordersPath, {'id': 'o1'});
      server.ok('POST', ApiPlayerShopRepository.cancelPath('o1'), null);
      server.ok('GET', ApiPlayerShopRepository.myOrdersPath, {
        'items': [
          {'id': 'o1', 'productName': 'Nước', 'quantity': 2, 'totalAmount': 20000, 'status': 'PENDING',
            'facilityName': 'Sân A', 'createdAt': '2026-11-20T10:00:00Z'},
          {'id': 'o2', 'productName': 'Cầu', 'quantity': 1, 'totalAmount': 220000, 'status': 'PickedUp',
            'createdAt': '2026-11-25T10:00:00Z'},
        ],
      });
      await repo.order(productId: 'p1', quantity: 2, note: '  lấy lúc 19h ');
      await repo.order(productId: 'p1', quantity: 1, note: '   ');
      await repo.cancelOrder('o1');
      final mine = await repo.getMyOrders();
      expect(server.requests[0].data, {'productId': 'p1', 'quantity': 2, 'note': 'lấy lúc 19h'});
      expect(server.requests[1].data, {'productId': 'p1', 'quantity': 1, 'note': null});
      expect(server.requests[2].path, ApiPlayerShopRepository.cancelPath('o1'));
      expect(mine.map((o) => o.id), ['o2', 'o1']);
      expect(mine[0].status, ShopOrderStatus.pickedUp);
      expect(mine[1].facilityName, 'Sân A');
    });

    test('lỗi BE (hết hàng…) giữ nguyên câu', () async {
      server.fail('POST', ApiPlayerShopRepository.ordersPath, 400, 'Sản phẩm đã hết hàng.');
      await expectLater(
        repo.order(productId: 'p1', quantity: 1),
        throwsA(isA<PlayerShopException>().having((e) => e.message, 'message', 'Sản phẩm đã hết hàng.')),
      );
    });

    test('lịch sử check-in: gửi page + pageSize 20, đọc {items, totalItems}', () async {
      server.ok('GET', ApiPlayerShopRepository.historyPath, {
        'items': [
          {'id': 'c1', 'type': 'LFG', 'checkedInAt': '2026-11-25T11:05:00Z', 'facilityName': 'Sân A',
            'courtName': 'Sân 2', 'sportName': 'Cầu Lông', 'startTime': '2026-11-25T11:00:00Z',
            'endTime': '2026-11-25T12:00:00Z', 'isLate': true},
          {'id': 'c2', 'type': 'TOURNAMENT', 'checkedInAt': '2026-11-24T08:00:00Z', 'tournamentName': 'Giải X'},
        ],
        'totalItems': 42,
      });
      final page = await repo.getHistory(page: 2);
      expect(server.requests.single.queryParameters, {'page': 2, 'pageSize': 20});
      expect(page.totalItems, 42);
      expect(page.items.first.type, CheckInTicketType.lfg);
      expect(page.items.first.isLate, isTrue);
      expect(page.items.last.tournamentName, 'Giải X');
    });
  });

  group('MockPlayerShopRepository', () {
    late MockPlayerShopRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = MockPlayerShopRepository(latency: Duration.zero);
    });

    test('đặt trừ tồn kho, quá tồn kho bị chặn; hủy đơn chờ chuẩn bị thì trả lại tồn kho', () async {
      ShopProduct cau() => MockPlayerShopRepository.products.firstWhere((p) => p.id == 'p-tt-2');
      Future<int> stock() async => (await repo.getProducts('f-hcm-thientrieu')).firstWhere((p) => p.id == 'p-tt-2').stock;

      await repo.order(productId: 'p-tt-2', quantity: 2, note: 'sân 2');
      expect(await stock(), cau().stock - 2);
      await expectLater(repo.order(productId: 'p-tt-2', quantity: 99), throwsA(isA<PlayerShopException>()));

      final order = (await repo.getMyOrders()).single;
      expect(order.totalAmount, 2 * cau().price);
      expect(order.facilityName, 'Sân Cầu Lông Thiên Triều');
      await repo.cancelOrder(order.id);
      expect((await repo.getMyOrders()).single.status, ShopOrderStatus.cancelled);
      expect(await stock(), cau().stock);
      await expectLater(repo.cancelOrder(order.id), throwsA(isA<PlayerShopException>()));
    });

    test('lịch sử check-in chia trang 20', () async {
      final first = await repo.getHistory();
      final second = await repo.getHistory(page: 2);
      expect(first.items.length, CheckInHistoryRepository.pageSize);
      expect(second.items.length, repo.historyCount - CheckInHistoryRepository.pageSize);
      expect(first.totalItems, repo.historyCount);
    });
  });
}
