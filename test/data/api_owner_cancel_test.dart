import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/constants/owner_rules.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_owner_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/owner_repository.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
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

void main() {
  late _FakeServer server;
  late ApiOwnerRepository repo;

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiOwnerRepository(ApiClient(tokens: tokens, dio: dio));
  });

  test('Chủ sân hủy đơn: gửi lý do + khóa ca, đọc tiền phạt / Fair Play BE trả', () async {
    server.ok('POST', ApiOwnerRepository.cancelBookingPath('b1'), {
      'bookingId': 'b1',
      'status': 'Cancelled',
      'refundAmount': 300000,
      'lateCancel': true,
      'ownerPenaltyAmount': 60000,
      'ownerFairPlayPenalty': 10,
      'vouchersIssued': 1,
    });

    final result = await repo.cancelBooking('b1', reasonCode: 6, reason: ' Sân hỏng đèn ', lockSlot: true);
    expect(server.requests.single.data, {'cancelReasonId': 6, 'reason': 'Sân hỏng đèn', 'lockSlotAfterCancel': true});
    expect(result.penaltyAmount, 60000);
    expect(result.fairPlayPenalty, 10);
    expect(result.refundAmount, 300000);
  });

  test('không chọn lý do thì gửi null (BE tự dùng lý do mặc định); lỗi BE giữ nguyên câu', () async {
    server.ok('POST', ApiOwnerRepository.cancelBookingPath('b2'), {'ownerPenaltyAmount': 30000, 'lateCancel': false});
    final result = await repo.cancelBooking('b2', reason: '  ');
    expect(server.requests.single.data, {'cancelReasonId': null, 'reason': null, 'lockSlotAfterCancel': false});
    expect(result.fairPlayPenalty, 0);

    server.fail('POST', ApiOwnerRepository.cancelBookingPath('b3'), 400, 'Đơn đã bị hủy');
    await expectLater(
      repo.cancelBooking('b3'),
      throwsA(isA<OwnerException>().having((e) => e.message, 'message', 'Đơn đã bị hủy')),
    );
  });

  test('tiền phạt dự kiến: dưới 48h 20%, từ 48h trở lên 10% (làm tròn như BE)', () {
    final start = DateTime(2026, 11, 22, 18);
    expect(OwnerCancelRules.isLate(start, DateTime(2026, 11, 20, 18)), isFalse);
    expect(OwnerCancelRules.isLate(start, DateTime(2026, 11, 20, 18, 1)), isTrue);
    expect(OwnerCancelRules.penaltyFor(300000, late: true), 60000);
    expect(OwnerCancelRules.penaltyFor(300000, late: false), 30000);
    expect(OwnerCancelRules.penaltyFor(125005, late: false), 12501);
    expect(OwnerCancelRules.penaltyFor(300000, late: true, walkIn: true), 0, reason: 'vãng lai không phạt');
    expect(OwnerCancelRules.fairPlayFor(late: true, walkIn: true), 0);
    expect(OwnerCancelRules.fairPlayFor(late: true), 10);
    expect(OwnerCancelRules.fairPlayFor(late: false), 0);
  });
}
