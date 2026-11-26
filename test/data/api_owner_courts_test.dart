import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_owner_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/owner_court.dart';
import 'package:test1/models/owner_facility.dart';

/// Server giả: trả JSON theo "METHOD path", ghi lại request. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  void ok(String method, String path, Object? data) =>
      routes['$method $path'] = (200, {'statusCode': 200, 'message': 'OK', 'data': data});

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
  late _FakeServer server;
  late ApiOwnerRepository repo;

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiOwnerRepository(ApiClient(tokens: tokens, dio: dio));
  });

  test('danh sách sân đọc đúng trường CourtResponse (slotMinutes 0 = theo môn)', () async {
    server.ok('GET', ApiOwnerRepository.courtsPath('f1'), [
      {
        'id': 'c1',
        'categoryId': 's1',
        'categoryName': 'Cầu Lông',
        'name': 'Sân 1',
        'status': 'Active',
        'defaultPrice': 80000.0,
        'slotMinutes': 0,
        'effectiveSlotMinutes': 60,
        'teamSize': 2,
      },
    ]);
    final c = (await repo.getCourts('f1')).single;
    expect(c.isActive, isTrue);
    expect(c.defaultPrice, 80000);
    expect(c.slotMinutes, isNull);
    expect(c.effectiveSlotMinutes, 60);
  });

  test('sinh ca 1 sân gọi theo sân (không gửi courtIds); nhiều sân gọi theo cơ sở', () async {
    server.ok('POST', ApiOwnerRepository.courtGeneratePath('c1'), {'createdSlots': 12, 'skippedSlots': 1});
    final one = await repo.generateSlots(
      'f1',
      GenerateSlotsRequest(courtIds: const ['c1'], dateFrom: DateTime(2026, 12, 1), dateTo: DateTime(2026, 12, 1)),
      courtNames: const {'c1': 'Sân 1'},
    );
    expect(one.single.courtName, 'Sân 1');
    expect(one.single.created, 12);
    expect((server.requests.single.data as Map).containsKey('courtIds'), isFalse);

    server.ok('POST', ApiOwnerRepository.facilityGeneratePath('f1'), [
      {'courtId': 'c1', 'courtName': 'Sân 1', 'success': true, 'createdSlots': 5},
      {'courtId': 'c2', 'courtName': 'Sân 2', 'success': false, 'message': 'Sân đang tạm ngưng'},
    ]);
    final many = await repo.generateSlots(
      'f1',
      GenerateSlotsRequest(dateFrom: DateTime(2026, 12, 1), dateTo: DateTime(2026, 12, 7)),
    );
    expect(many, hasLength(2));
    expect(many.last.success, isFalse);
    expect((server.requests.last.data as Map)['courtIds'], isNull);
  });

  test('xóa ca hàng loạt gọi bulk-delete, còn lại gọi PUT bulk', () async {
    server.ok('POST', ApiOwnerRepository.bulkDeletePath('f1'), {'matchedSlots': 4, 'affectedSlots': 3, 'skippedSlots': 1});
    server.ok('PUT', ApiOwnerRepository.bulkPath('f1'), {'matchedSlots': 2, 'affectedSlots': 2, 'skippedSlots': 0});
    final del = await repo.bulkSlots(
      'f1',
      BulkSlotRequest(action: BulkSlotAction.delete, dateFrom: DateTime(2026, 12, 1), dateTo: DateTime(2026, 12, 1)),
    );
    expect(del.affected, 3);
    final lock = await repo.bulkSlots(
      'f1',
      BulkSlotRequest(action: BulkSlotAction.lock, dateFrom: DateTime(2026, 12, 1), dateTo: DateTime(2026, 12, 1)),
    );
    expect(lock.matched, 2);
    expect((server.requests.last.data as Map)['action'], 'LOCK');
  });

  test('đợt giá: BE chưa có API (404) thì báo "đang chờ", không coi là lỗi thường', () async {
    await expectLater(
      repo.getPricePeriods('f1'),
      throwsA(isA<OwnerException>().having((e) => e.unavailable, 'unavailable', isTrue)),
    );
    server.ok('GET', ApiOwnerRepository.pricePeriodsPath('f1'), [
      {'id': 'p1', 'name': 'Tết', 'fromDate': '2027-02-01T00:00:00', 'toDate': '2027-02-05', 'startTime': '17:00:00', 'price': 150000},
    ]);
    final p = (await repo.getPricePeriods('f1')).single;
    expect(p.fromDate, DateTime(2027, 2, 1));
    expect(p.startTime, '17:00');
    expect(p.endTime, isNull);
  });

  test('cơ sở: tạo gửi streetAddress + mã tỉnh / phường + tiện ích; sửa để null tiện ích / ảnh; đọc imageItems, isLocked',
      () async {
    final facility = {
      'id': 'f1',
      'name': 'Sân A',
      'streetAddress': '1 Lê Lợi',
      'provinceCode': '79',
      'provinceName': 'Hồ Chí Minh',
      'wardCode': '26734',
      'wardName': 'Phường Sài Gòn',
      'approvalStatus': 'Pending',
      'openTime': '06:00:00',
      'closeTime': '22:00:00',
      'rules': 'Dòng 1\nDòng 2',
      'autoGenerateSlots': false,
      'isLocked': true,
      'lockedReason': 'Vi phạm',
      'averageRating': 4.5,
      'reviewCount': 2,
      'imageItems': [
        {'id': 'i1', 'url': 'https://x/1.jpg', 'isThumbnail': false},
        {'id': 'i2', 'url': 'https://x/2.jpg', 'isThumbnail': true},
      ],
      'amenities': [
        {'id': 'a1', 'name': 'Wifi'},
      ],
      'courts': [{}, {}],
    };
    server.ok('POST', ApiOwnerRepository.facilitiesPath, {'id': 'f1'});
    server.ok('GET', ApiOwnerRepository.facilityPath('f1'), facility);
    const input = FacilityInput(
      name: 'Sân A',
      streetAddress: '1 Lê Lợi',
      provinceCode: '79',
      wardCode: '26734',
      recurringDiscountPercent: 0,
      amenityIds: ['a1'],
    );
    final created = await repo.createFacility(input);
    final body = server.requests.first.data as Map;
    expect(body['streetAddress'], '1 Lê Lợi');
    expect(body['provinceCode'], '79');
    expect(body['openTime'], '06:00:00');
    expect(body['amenityIds'], ['a1']);
    expect(body['isBulkDiscountEnabled'], isFalse);
    expect(created.profile.address, '1 Lê Lợi, Phường Sài Gòn, Hồ Chí Minh');
    expect(created.operations.rules, ['Dòng 1', 'Dòng 2']);
    expect(created.autoGenerateSlots, isFalse);
    expect(created.isLocked, isTrue);
    expect(created.rating, 4.5);
    expect(created.photos.singleWhere((p) => p.isThumbnail).id, 'i2');
    expect(created.amenityItems.single.id, 'a1');
    expect(created.courtCount, 2);

    server.ok('PUT', ApiOwnerRepository.facilityPath('f1'), null);
    await repo.updateFacility('f1', input);
    final put = server.requests.firstWhere((r) => r.method == 'PUT').data as Map;
    expect(put['amenityIds'], isNull);
    expect(put['imageUrls'], isNull);
    expect(put.containsKey('status'), isTrue);

    server.ok('PATCH', '${ApiOwnerRepository.facilityImagesPath('f1')}/i1/thumbnail', null);
    await repo.setFacilityThumbnail('f1', 'i1');
    expect(server.requests.last.method, 'PATCH');
  });

  test('giờ mở cửa gửi TimeSpan', () async {
    server.ok('PUT', '/api/v1/facilities/f1', null);
    await repo.updateOpenHours('f1', openTime: '06:00', closeTime: '22:30');
    expect(server.requests.single.data, {'openTime': '06:00:00', 'closeTime': '22:30:00'});
  });
}
