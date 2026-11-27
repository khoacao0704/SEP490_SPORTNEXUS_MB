import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/report_strings.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_report_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/mock/mock_report_repository.dart';
import 'package:test1/data/repositories/report_repository.dart';
import 'package:test1/models/player_report.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi.
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

void main() {
  group('ApiReportRepository', () {
    late _FakeServer server;
    late ApiReportRepository repo;

    setUp(() async {
      server = _FakeServer();
      final tokens = MemoryTokenStore();
      await tokens.write('token');
      final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
      repo = ApiReportRepository(api: ApiClient(tokens: tokens, dio: dio));
    });

    test('lý do: gửi targetType, đọc title / label; bỏ lý do không có mã', () async {
      server.ok('GET', ApiReportRepository.reasonsPath, [
        {'code': 'FACILITY_POOR_QUALITY', 'targetType': 'BOOKING', 'title': 'Sân xuống cấp', 'description': 'Mô tả'},
        {'code': 'OTHER', 'label': 'Lý do khác'},
        {'title': 'Không có mã'},
      ]);
      final reasons = await repo.getReasons(ReportTarget.booking);
      expect(server.requests.single.queryParameters, {'targetType': 'BOOKING'});
      expect(reasons.map((r) => r.code), ['FACILITY_POOR_QUALITY', 'OTHER']);
      expect(reasons.first.description, 'Mô tả');
      expect(reasons.last.title, 'Lý do khác');
    });

    test('gửi khiếu nại đơn: như Web, % muốn hoàn luôn 0; báo cáo người chơi gửi targetUserId', () async {
      server.ok('POST', ApiReportRepository.reportsPath, {'id': 'r1'});
      await repo.create(const NewPlayerReport(
        target: ReportTarget.booking,
        reason: 'OTHER',
        description: '  Sân tối, đèn hỏng hai bóng  ',
        bookingId: 'b1',
        evidenceImageUrls: ['https://img/1.jpg'],
      ));
      await repo.create(const NewPlayerReport(
        target: ReportTarget.user,
        reason: 'SKILL_MISREPRESENTATION',
        description: 'Khai trình độ mới chơi nhưng đánh rất giỏi',
        targetUserId: 'u-x',
      ));
      expect(server.requests[0].data, {
        'targetType': 'BOOKING',
        'bookingId': 'b1',
        'facilityId': null,
        'targetUserId': null,
        'targetObjectId': null,
        'reason': 'OTHER',
        'description': 'Sân tối, đèn hỏng hai bóng',
        'evidenceImageUrls': ['https://img/1.jpg'],
        'requestedRefundPercentage': 0,
      });
      expect(server.requests[1].data['targetType'], 'USER');
      expect(server.requests[1].data['targetUserId'], 'u-x');
      expect(server.requests[1].data['bookingId'], isNull);
    });

    test('khiếu nại của tôi: đọc mảng hoặc {items}, mới nhất trước, trạng thái của BE', () async {
      server.ok('GET', ApiReportRepository.minePath, {
        'items': [
          {
            'id': 'r1',
            'status': 'OwnerResponded',
            'targetType': 'BOOKING',
            'reason': 'OTHER',
            'description': 'Cũ',
            'bookingId': 'b1',
            'ownerResponse': 'Đã sửa đèn',
            'createdAt': '2026-11-20T10:00:00Z',
          },
          {
            'id': 'r2',
            'status': 'RESOLVED_REFUNDED',
            'reason': 'FACILITY_POOR_QUALITY',
            'reasonName': 'Sân xuống cấp',
            'description': 'Mới',
            'adminNote': 'Hoàn 50%',
            'refundedAmount': 80000.0,
            'createdAt': '2026-11-25T10:00:00Z',
          },
        ],
      });
      final mine = await repo.getMine();
      expect(mine.map((r) => r.id), ['r2', 'r1']);
      expect(mine[0].status, ReportStatus.resolvedRefunded);
      expect(mine[0].resolution, 'Hoàn 50%');
      expect(mine[0].refundedAmount, 80000);
      expect(mine[1].status, ReportStatus.ownerResponded);
      expect(mine[1].status.canWithdraw, isFalse);
      expect(mine[1].ownerResponse, 'Đã sửa đèn');
    });

    test('rút khiếu nại gửi kèm ghi chú; lỗi BE giữ nguyên câu', () async {
      server.ok('POST', ApiReportRepository.withdrawPath('r1'), null);
      await repo.withdraw('r1');
      expect(server.requests.single.data, {'note': ReportStrings.withdrawNote});

      server.fail('POST', ApiReportRepository.reportsPath, 400, 'Đơn này đã có khiếu nại đang mở.');
      await expectLater(
        repo.create(const NewPlayerReport(target: ReportTarget.booking, reason: 'OTHER', description: '1234567890')),
        throwsA(isA<ReportException>().having((e) => e.message, 'message', 'Đơn này đã có khiếu nại đang mở.')),
      );
    });
  });

  group('MockReportRepository', () {
    late MockReportRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = MockReportRepository(latency: Duration.zero);
    });

    test('gửi → có trong Khiếu nại của tôi (chờ xử lý) → rút; mỗi đơn một khiếu nại đang mở', () async {
      final reasons = await repo.getReasons(ReportTarget.booking);
      const report = NewPlayerReport(
        target: ReportTarget.booking,
        reason: 'OTHER',
        description: 'Sân bị trùng giờ với người khác',
        bookingId: 'b1',
      );
      await repo.create(report);
      await expectLater(repo.create(report), throwsA(isA<ReportException>()));

      var mine = await repo.getMine();
      expect(mine.single.status, ReportStatus.pending);
      expect(mine.single.reasonName, reasons.last.title);

      await repo.withdraw(mine.single.id);
      mine = await repo.getMine();
      expect(mine.single.status, ReportStatus.withdrawn);
      await expectLater(repo.withdraw(mine.single.id), throwsA(isA<ReportException>()));
      // Đã rút thì gửi lại được.
      await repo.create(report);
      expect((await repo.getMine()).length, 2);
    });

    test('mô tả dưới 10 ký tự bị chặn', () async {
      await expectLater(
        repo.create(const NewPlayerReport(target: ReportTarget.user, reason: 'OTHER', description: 'ngắn')),
        throwsA(isA<ReportException>().having((e) => e.message, 'message', ReportStrings.descriptionTooShort)),
      );
    });
  });
}
