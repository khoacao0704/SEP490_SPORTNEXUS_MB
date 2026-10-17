import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/facility_strings.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_facility_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/facility_repository.dart';
import 'package:test1/models/court_type.dart';
import 'package:test1/models/facility.dart';
import 'package:test1/models/facility_search.dart';
import 'package:test1/models/geo_point.dart';
import 'package:test1/models/sport.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  void ok(String path, Object? data) => routes['GET $path'] = (200, {'statusCode': 200, 'message': 'Success', 'data': data});

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

const _badmintonId = 'cat-badminton';
const _footballId = 'cat-football';

Map<String, dynamic> _searchItem({List<Map<String, dynamic>>? sports, num? lat = 10.77, int courtCount = 4}) => {
  'id': 'f1',
  'name': 'Sân ABC',
  'address': '12 Lê Lợi, Quận 1, TP.HCM',
  'latitude': lat,
  'longitude': lat == null ? null : 106.69,
  'status': 'Active',
  'thumbnailUrl': 'https://img/1.jpg',
  'openTime': '06:00:00',
  'closeTime': '22:00:00',
  'distanceKm': 1.25,
  'minPrice': 100000.00,
  'maxPrice': 200000.00,
  'averageRating': 4.3333,
  'reviewCount': 12,
  'courtCount': courtCount,
  'sports': sports ?? [
    {'id': _badmintonId, 'name': 'Cầu lông', 'rulesDescription': null},
  ],
  'amenities': [
    {'id': 'a1', 'name': 'Bãi xe', 'iconCode': 'parking'},
  ],
};

void main() {
  late _FakeServer server;
  late ApiFacilityRepository repo;

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiFacilityRepository(api: ApiClient(tokens: tokens, dio: dio));
    server.ok(ApiFacilityRepository.sportsPath, [
      {'id': _badmintonId, 'name': 'Cầu lông', 'rulesDescription': null},
      {'id': _footballId, 'name': 'Bóng đá', 'rulesDescription': null},
      {'id': 'cat-chess', 'name': 'Cờ vua', 'rulesDescription': null},
    ]);
  });

  test('ghép tên môn của BE với môn của app', () {
    expect(ApiFacilityRepository.sportFromName('Cầu lông'), Sport.badminton);
    expect(ApiFacilityRepository.sportFromName('BÓNG ĐÁ'), Sport.football);
    expect(ApiFacilityRepository.sportFromName('Bóng rổ'), Sport.basketball);
    expect(ApiFacilityRepository.sportFromName('Pickleball'), Sport.pickleball);
    expect(ApiFacilityRepository.sportFromName('Tennis'), Sport.tennis);
    expect(ApiFacilityRepository.sportFromName('Tennis bàn'), isNull);
    expect(ApiFacilityRepository.sportFromName('Cờ vua'), isNull);
    expect(ApiFacilityRepository.sportFromName(null), isNull);
  });

  test('tìm sân: gửi đúng tham số, đổi kết quả sang Facility', () async {
    server.ok(ApiFacilityRepository.searchPath, {
      'page': 1, 'pageSize': 50, 'totalItems': 1, 'totalPages': 1,
      'items': [_searchItem()],
    });

    final results = await repo.searchFacilities(const FacilitySearchQuery(
      city: 'Hồ Chí Minh',
      district: 'Quận 1',
      sport: Sport.football,
      keyword: '  ABC ',
      userLocation: GeoPoint(10.7, 106.6),
    ));

    final search = server.requests.lastWhere((r) => r.path == ApiFacilityRepository.searchPath);
    expect(search.queryParameters, {
      'page': 1,
      'pageSize': 50,
      'keyword': 'ABC',
      'lat': 10.7,
      'lng': 106.6,
      'sortBy': 'distance',
      'categoryId': _footballId,
    });
    final r = results.single;
    expect(r.distanceKm, 1.25);
    final f = r.facility;
    expect(f.name, 'Sân ABC');
    expect(f.fullAddress, '12 Lê Lợi, Quận 1, TP.HCM');
    expect(f.location, const GeoPoint(10.77, 106.69));
    expect(f.hasLocation, isTrue);
    expect(f.sports, [Sport.badminton]);
    expect(f.offerings.single.courtCount, 4);
    expect(f.offerings.single.courtType, CourtType.standard);
    expect(f.priceFrom, 100000);
    expect(f.rating, 4.3);
    expect(f.imageUrls, ['https://img/1.jpg']);
    expect(f.amenities, ['Bãi xe']);
    expect(f.openTime, '06:00');
    expect(f.closeTime, '22:00');
  });

  test('tìm sân: "gần nhất" mà không có vị trí thì không gửi sortBy; giá / đánh giá đổi đúng tên', () async {
    server.ok(ApiFacilityRepository.searchPath, {'page': 1, 'pageSize': 50, 'totalItems': 0, 'totalPages': 0, 'items': []});

    await repo.searchFacilities(const FacilitySearchQuery(city: ''));
    expect(server.requests.last.queryParameters, {'page': 1, 'pageSize': 50});

    await repo.searchFacilities(const FacilitySearchQuery(city: '', sort: FacilitySort.priceLowToHigh));
    expect(server.requests.last.queryParameters['sortBy'], 'price_asc');

    await repo.searchFacilities(const FacilitySearchQuery(city: '', sort: FacilitySort.rating));
    expect(server.requests.last.queryParameters['sortBy'], 'rating');
  });

  test('tìm sân: môn chưa có trên server thì trả rỗng, không gọi tìm kiếm', () async {
    final results = await repo.searchFacilities(const FacilitySearchQuery(city: '', sport: Sport.tennis));

    expect(results, isEmpty);
    expect(server.requests.where((r) => r.path == ApiFacilityRepository.searchPath), isEmpty);
  });

  test('tìm sân: cơ sở nhiều môn để số sân theo môn = 0; chưa có tọa độ / môn lạ', () async {
    server.ok(ApiFacilityRepository.searchPath, {
      'page': 1, 'pageSize': 50, 'totalItems': 2, 'totalPages': 1,
      'items': [
        _searchItem(sports: [
          {'id': _badmintonId, 'name': 'Cầu lông'},
          {'id': _footballId, 'name': 'Bóng đá'},
        ]),
        {..._searchItem(lat: null, sports: [{'id': 'cat-chess', 'name': 'Cờ vua'}]), 'thumbnailUrl': null},
      ],
    });

    final results = await repo.searchFacilities(const FacilitySearchQuery(city: ''));

    expect(results[0].facility.offerings.map((o) => o.courtCount), [0, 0]);
    final noData = results[1].facility;
    expect(noData.hasLocation, isFalse);
    expect(noData.sports, isEmpty);
    expect(noData.priceFrom, 0);
    expect(noData.imageUrls, isEmpty);
  });

  test('chi tiết: gom sân con đang hoạt động theo môn, giá từ = DefaultPrice thấp nhất', () async {
    server.ok(ApiFacilityRepository.facilityPath('f1'), {
      'id': 'f1',
      'name': 'Sân ABC',
      'address': '12 Lê Lợi',
      'latitude': 10.77,
      'longitude': 106.69,
      'description': 'Sân đẹp',
      'phone': '0909123456',
      'openTime': '05:30:00',
      'closeTime': '23:00:00',
      'images': ['https://img/1.jpg', 'https://img/2.jpg'],
      'amenities': [
        {'id': 'a1', 'name': 'Wifi', 'iconCode': 'wifi'},
      ],
      'averageRating': 5,
      'reviewCount': 3,
      'courts': [
        {'id': 'c1', 'categoryId': _badmintonId, 'categoryName': 'Cầu lông', 'name': 'Sân 1', 'status': 'Active', 'defaultPrice': 120000.00},
        {'id': 'c2', 'categoryId': _badmintonId, 'categoryName': 'Cầu lông', 'name': 'Sân 2', 'status': 'Active', 'defaultPrice': 90000.00},
        {'id': 'c3', 'categoryId': _badmintonId, 'categoryName': 'Cầu lông', 'name': 'Sân 3', 'status': 'Maintenance', 'defaultPrice': 50000.00},
        {'id': 'c4', 'categoryId': _footballId, 'categoryName': 'Bóng đá', 'name': 'Sân A', 'status': 'Active', 'defaultPrice': 500000.00},
        {'id': 'c5', 'categoryId': 'cat-chess', 'categoryName': 'Cờ vua', 'name': 'Bàn 1', 'status': 'Active', 'defaultPrice': 1},
      ],
    });

    final f = await repo.getFacility('f1');

    expect(f.offeringFor(Sport.badminton)!.courtCount, 2);
    expect(f.offeringFor(Sport.badminton)!.priceFrom, 90000);
    expect(f.offeringFor(Sport.football)!.courtCount, 1);
    expect(f.sports, unorderedEquals([Sport.badminton, Sport.football]));
    expect(f.description, 'Sân đẹp');
    expect(f.phone, '0909123456');
    expect(f.imageUrls, hasLength(2));
    expect(f.amenities, ['Wifi']);
    expect(f.rules, isEmpty);
    expect(f.openTime, '05:30');
    expect(f.rating, 5.0);
  });

  test('khung giờ: theo từng sân con của môn, giờ VN, trống = isBookable', () async {
    server.ok(ApiFacilityRepository.availabilityPath('f1'), {
      'facilityId': 'f1',
      'courts': [
        {
          'courtId': 'c1', 'courtName': 'Sân 1', 'categoryId': _badmintonId, 'isBookable': true,
          'slots': [
            {'id': 's1', 'startTime': '2026-10-18T06:00:00+07:00', 'endTime': '2026-10-18T07:00:00+07:00', 'price': 100000.00, 'status': 'Available', 'isPast': false, 'isBookable': true},
            {'id': 's2', 'startTime': '2026-10-18T07:00:00+07:00', 'endTime': '2026-10-18T08:30:00+07:00', 'price': 150000.00, 'status': 'Booked', 'isPast': false, 'isBookable': false},
          ],
        },
        {'courtId': 'c9', 'courtName': 'Sân bóng', 'categoryId': _footballId, 'slots': [
          {'id': 's9', 'startTime': '2026-10-18T06:00:00+07:00', 'endTime': '2026-10-18T07:00:00+07:00', 'price': 1, 'isBookable': true},
        ]},
      ],
    });

    final slots = await repo.getTimeSlots('f1', Sport.badminton, DateTime(2026, 10, 18, 15));

    final request = server.requests.last;
    expect(request.queryParameters, {'date': '2026-10-18', 'categoryId': _badmintonId});
    expect(slots.map((s) => s.id), ['s1', 's2']);
    expect(slots.first.courtName, 'Sân 1');
    expect(slots.first.start, DateTime.utc(2026, 10, 17, 23).toLocal());
    expect(slots[1].end.difference(slots[1].start), const Duration(minutes: 90));
    expect(slots.first.isAvailable, isTrue);
    expect(slots[1].isAvailable, isFalse);
    expect(slots[1].price, 150000);
  });

  test('lỗi BE thành FacilityException mang câu tiếng Việt', () async {
    server.routes['GET ${ApiFacilityRepository.facilityPath('x')}'] = (
      404,
      {'statusCode': 404, 'message': 'Không tìm thấy cơ sở', 'data': null},
    );

    await expectLater(
      repo.getFacility('x'),
      throwsA(isA<FacilityException>().having((e) => e.message, 'message', 'Không tìm thấy cơ sở')),
    );
  });

  test('không lọc khu vực, giữ chỗ báo đang phát triển', () async {
    expect(repo.supportsAreaFilter, isFalse);
    expect(await repo.getDistricts('Hồ Chí Minh'), isEmpty);
    await expectLater(
      repo.holdSlots(const []),
      throwsA(isA<FacilityException>().having((e) => e.message, 'message', FacilityStrings.featureInDevelopment)),
    );
    expect(Facility.noLocation, const GeoPoint(0, 0));
  });
}
