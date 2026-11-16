import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_voucher_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/voucher_repository.dart';
import 'package:test1/models/voucher.dart';

/// Giả lập server: một phản hồi cố định cho mọi request, ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  (int, Object?) response = (200, {'statusCode': 200, 'message': 'OK', 'data': []});
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = response;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeServer server;
  late ApiVoucherRepository repo;

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiVoucherRepository(api: ApiClient(tokens: tokens, dio: dio));
  });

  test('gửi status theo tab và đọc đủ các trường voucher', () async {
    server.response = (
      200,
      {
        'statusCode': 200,
        'message': 'OK',
        'data': [
          {
            'id': 'v-1',
            'discountPercent': 10,
            'status': 'ACTIVE',
            'expiredDate': '2026-12-16T10:00:00Z',
            'sourceBookingId': 'bk-9',
            'createdAt': '2026-11-16T10:00:00Z',
          },
        ],
      },
    );

    final items = await repo.getMyVouchers(status: VoucherStatus.active);

    expect(server.requests.single.path, ApiVoucherRepository.vouchersPath);
    expect(server.requests.single.queryParameters, {'status': 'ACTIVE'});
    final v = items.single;
    expect(v.id, 'v-1');
    expect(v.discountPercent, 10);
    expect(v.status, VoucherStatus.active);
    expect(v.sourceBookingId, 'bk-9');
    expect(v.expiresAt, DateTime.utc(2026, 12, 16, 10).toLocal());
  });

  test('không truyền status thì không gửi tham số; rỗng trả danh sách rỗng', () async {
    server.response = (200, {'statusCode': 200, 'message': 'Bạn chưa có mã giảm giá nào', 'data': []});

    expect(await repo.getMyVouchers(), isEmpty);
    expect(server.requests.single.queryParameters, isEmpty);
  });

  test('lỗi của BE thành VoucherException', () async {
    server.response = (400, {'statusCode': 400, 'message': 'Trạng thái không hợp lệ', 'data': null});

    expect(() => repo.getMyVouchers(status: VoucherStatus.used), throwsA(isA<VoucherException>()));
  });
}
