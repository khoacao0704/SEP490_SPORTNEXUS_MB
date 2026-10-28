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
import 'package:test1/models/time_slot.dart';

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

  void locations() => server.ok(ApiFacilityRepository.locationsPath, [
        {'province': 'TP. Hồ Chí Minh', 'facilityCount': 4, 'districts': ['Quận 7', 'Quận 1', 'TP. Thủ Đức']},
        {'province': 'Hà Nội', 'facilityCount': 1, 'districts': []},
      ]);

  test('tìm sân: gửi đúng tham số (tỉnh/quận theo đúng tên của BE), đổi kết quả sang Facility', () async {
    locations();
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
      'province': 'TP. Hồ Chí Minh',
      'district': 'Quận 1',
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

    await repo.searchFacilities(const FacilitySearchQuery(city: '', sort: FacilitySort.priceHighToLow));
    expect(server.requests.last.queryParameters['sortBy'], 'price_desc');

    await repo.searchFacilities(const FacilitySearchQuery(city: '', sort: FacilitySort.newest));
    expect(server.requests.last.queryParameters['sortBy'], 'newest');
  });

  test('tìm sân: lọc khoảng giá / số sao / tiện ích; tiện ích gửi lặp tham số (BE không nhận dấu phẩy)', () async {
    server.ok(ApiFacilityRepository.searchPath, {'page': 1, 'pageSize': 50, 'totalItems': 0, 'totalPages': 0, 'items': []});

    await repo.searchFacilities(const FacilitySearchQuery(
      city: '',
      minPrice: 100000,
      maxPrice: 200000,
      minRating: 4.5,
      amenityIds: {'a1', 'a2'},
    ));

    final request = server.requests.last;
    expect(request.queryParameters['minPrice'], 100000);
    expect(request.queryParameters['maxPrice'], 200000);
    expect(request.queryParameters['minRating'], 4.5);
    expect(request.uri.query, contains('amenityIds=a1&amenityIds=a2'));

    // Không chọn gì thì không gửi.
    await repo.searchFacilities(const FacilitySearchQuery(city: ''));
    expect(server.requests.last.queryParameters.keys, unorderedEquals(['page', 'pageSize']));
  });

  test('tìm sân: cờ đẩy tin và icon tiện ích', () async {
    server.ok(ApiFacilityRepository.searchPath, {
      'page': 1,
      'pageSize': 50,
      'totalItems': 2,
      'totalPages': 1,
      'items': [
        {..._searchItem(), 'isPromoted': true},
        {..._searchItem(), 'id': 'f2'},
      ],
    });

    final results = await repo.searchFacilities(const FacilitySearchQuery(city: ''));

    expect(results.map((r) => r.facility.isPromoted), [true, false]);
    expect(results.first.facility.amenityIcons, {'Bãi xe': 'parking'});
  });

  test('danh mục tiện ích: tải một lần rồi dùng lại', () async {
    server.ok(ApiFacilityRepository.amenitiesPath, [
      {'id': 'a1', 'name': 'Bãi gửi xe', 'iconCode': 'parking'},
      {'id': 'a2', 'name': 'Wifi miễn phí', 'iconCode': null},
    ]);

    final first = await repo.getAmenities();
    await repo.getAmenities();

    expect(first.map((a) => (a.id, a.name, a.iconCode)), [('a1', 'Bãi gửi xe', 'parking'), ('a2', 'Wifi miễn phí', null)]);
    expect(server.requests.where((r) => r.path == ApiFacilityRepository.amenitiesPath), hasLength(1));
  });

  test('thông tin sân con: ghép các trường chủ sân đã khai báo, bỏ trường trống', () {
    expect(
      ApiFacilityRepository.courtDetail(
          {'courtType': 'Sân 5 người', 'isIndoor': true, 'surfaceType': 'Cỏ nhân tạo', 'maxPlayers': 10}),
      'Sân 5 người · ${FacilityStrings.indoor} · Cỏ nhân tạo · ${FacilityStrings.maxPlayers(10)}',
    );
    expect(ApiFacilityRepository.courtDetail({'isIndoor': false, 'surfaceType': ''}), FacilityStrings.outdoor);
    expect(
      ApiFacilityRepository.courtDetail({'courtType': null, 'isIndoor': null, 'surfaceType': null, 'maxPlayers': null}),
      isEmpty,
    );
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
        {'id': 'c1', 'categoryId': _badmintonId, 'categoryName': 'Cầu lông', 'name': 'Sân 1', 'status': 'Active', 'defaultPrice': 120000.00, 'isIndoor': true, 'surfaceType': 'Thảm PU'},
        {'id': 'c2', 'categoryId': _badmintonId, 'categoryName': 'Cầu lông', 'name': 'Sân 2', 'status': 'Active', 'defaultPrice': 90000.00},
        {'id': 'c3', 'categoryId': _badmintonId, 'categoryName': 'Cầu lông', 'name': 'Sân 3', 'status': 'Maintenance', 'defaultPrice': 50000.00},
        {'id': 'c4', 'categoryId': _footballId, 'categoryName': 'Bóng đá', 'name': 'Sân A', 'status': 'Active', 'defaultPrice': 500000.00},
        {'id': 'c6', 'categoryId': 'cat-pickleball', 'categoryName': 'Pickleball', 'name': 'Sân 1', 'status': 'Active', 'defaultPrice': 150000.00, 'isIndoor': false},
        {'id': 'c5', 'categoryId': 'cat-chess', 'categoryName': 'Cờ vua', 'name': 'Bàn 1', 'status': 'Active', 'defaultPrice': 1},
      ],
    });

    final f = await repo.getFacility('f1');

    expect(f.offeringFor(Sport.badminton)!.courtCount, 2);
    expect(f.offeringFor(Sport.badminton)!.priceFrom, 90000);
    expect(f.offeringFor(Sport.football)!.courtCount, 1);
    expect(f.sports, unorderedEquals([Sport.badminton, Sport.football, Sport.pickleball]));
    expect(f.description, 'Sân đẹp');
    expect(f.phone, '0909123456');
    expect(f.imageUrls, hasLength(2));
    expect(f.amenities, ['Wifi']);
    expect(f.amenityIcons, {'Wifi': 'wifi'});
    // Chỉ sân đã khai báo mới có thông tin thêm; hai môn cùng tên 'Sân 1' không lẫn nhau.
    expect(f.courtDetailOf(Sport.badminton, 'Sân 1'), '${FacilityStrings.indoor} · Thảm PU');
    expect(f.courtDetailOf(Sport.pickleball, 'Sân 1'), FacilityStrings.outdoor);
    expect(f.courtDetailOf(Sport.badminton, 'Sân 2'), isNull);
    expect(f.courtDetailOf(Sport.badminton, null), isNull);
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

  test('lọc khu vực: quận lấy từ /locations theo tên tỉnh của BE; tải danh sách một lần', () async {
    locations();
    expect(repo.supportsAreaFilter, isTrue);
    expect(await repo.getDistricts('Hồ Chí Minh'), ['Quận 1', 'Quận 7', 'TP. Thủ Đức']);
    expect(await repo.getDistricts('TP. Hồ Chí Minh'), ['Quận 1', 'Quận 7', 'TP. Thủ Đức']);
    expect(await repo.getDistricts('Hà Nội'), isEmpty);
    expect(await repo.getDistricts('Đà Nẵng'), isEmpty);
    expect(server.requests.where((r) => r.path == ApiFacilityRepository.locationsPath), hasLength(1));
    expect(Facility.noLocation, const GeoPoint(0, 0));
  });

  test('lọc khu vực: tỉnh chưa có cơ sở nào thì trả rỗng, không gọi tìm kiếm', () async {
    locations();
    final page = await repo.searchFacilitiesPage(const FacilitySearchQuery(city: 'Đà Nẵng'));
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
    expect(server.requests.where((r) => r.path == ApiFacilityRepository.searchPath), isEmpty);
  });

  test('phân trang màn Tìm sân: 20 cơ sở / trang, còn trang sau theo totalItems', () async {
    server.ok(ApiFacilityRepository.searchPath, {
      'page': 2, 'pageSize': 20, 'totalItems': 45, 'totalPages': 3,
      'items': List.generate(20, (i) => {..._searchItem(), 'id': 'f$i'}),
    });
    final page = await repo.searchFacilitiesPage(const FacilitySearchQuery(city: ''), page: 2);
    expect(server.requests.last.queryParameters, {'page': 2, 'pageSize': 20});
    expect(page.items, hasLength(20));
    expect(page.total, 45);
    expect(page.hasMore, isTrue);

    server.ok(ApiFacilityRepository.searchPath, {
      'page': 3, 'pageSize': 20, 'totalItems': 45, 'totalPages': 3,
      'items': List.generate(5, (i) => {..._searchItem(), 'id': 'g$i'}),
    });
    expect((await repo.searchFacilitiesPage(const FacilitySearchQuery(city: ''), page: 3)).hasMore, isFalse);
  });

  test('nội quy: mỗi dòng một ý, bỏ ký hiệu đầu dòng và dòng trống', () {
    expect(
      ApiFacilityRepository.rulesFromApi('- Mang giày thể thao\r\n\n• Không hút thuốc\n2) Đến trước 10 phút\nGiữ vệ sinh '),
      ['Mang giày thể thao', 'Không hút thuốc', 'Đến trước 10 phút', 'Giữ vệ sinh'],
    );
    expect(ApiFacilityRepository.rulesFromApi(null), isEmpty);
    expect(ApiFacilityRepository.rulesFromApi('  '), isEmpty);
  });

  test('loại sân theo teamSize: bóng đá 5/7/11, bóng rổ 3/5; chưa khai báo / số lạ / môn vợt → tiêu chuẩn', () {
    expect(ApiFacilityRepository.courtTypeOf(Sport.football, 5), CourtType.football5);
    expect(ApiFacilityRepository.courtTypeOf(Sport.football, 7), CourtType.football7);
    expect(ApiFacilityRepository.courtTypeOf(Sport.football, 11), CourtType.football11);
    expect(ApiFacilityRepository.courtTypeOf(Sport.basketball, 3), CourtType.basketballHalf);
    expect(ApiFacilityRepository.courtTypeOf(Sport.basketball, 5), CourtType.basketballFull);
    expect(ApiFacilityRepository.courtTypeOf(Sport.football, null), CourtType.standard);
    expect(ApiFacilityRepository.courtTypeOf(Sport.football, 6), CourtType.standard);
    expect(ApiFacilityRepository.courtTypeOf(Sport.badminton, 2), CourtType.standard);
  });

  test('loại sân: chi tiết tách loại theo teamSize; khung giờ chỉ lấy sân con của loại đã chọn', () async {
    server.ok(ApiFacilityRepository.facilityPath('f1'), {
      'id': 'f1',
      'name': 'Sân bóng',
      'address': '',
      'rules': 'Mang giày đinh dăm',
      'courts': [
        {'id': 'c1', 'categoryId': _footballId, 'categoryName': 'Bóng đá', 'name': 'Sân 5A', 'status': 'Active', 'defaultPrice': 400000, 'teamSize': 5},
        {'id': 'c2', 'categoryId': _footballId, 'categoryName': 'Bóng đá', 'name': 'Sân 7', 'status': 'Active', 'defaultPrice': 700000, 'teamSize': 7},
        {'id': 'c3', 'categoryId': _footballId, 'categoryName': 'Bóng đá', 'name': 'Sân cũ', 'status': 'Active', 'defaultPrice': 300000},
      ],
    });
    Map<String, dynamic> court(String id, String slot) => {
          'courtId': id, 'courtName': id, 'categoryId': _footballId,
          'slots': [
            {'id': slot, 'startTime': '2030-01-05T18:00:00+07:00', 'endTime': '2030-01-05T19:00:00+07:00', 'price': 1, 'isBookable': true},
          ],
        };
    server.ok(ApiFacilityRepository.availabilityPath('f1'), {
      'facilityId': 'f1',
      'courts': [court('c1', 's1'), court('c2', 's2'), court('c3', 's3')],
    });

    final f = await repo.getFacility('f1');
    expect(f.rules, ['Mang giày đinh dăm']);
    expect(
      f.offeringsFor(Sport.football).map((o) => (o.courtType, o.courtCount, o.priceFrom)),
      [(CourtType.standard, 1, 300000), (CourtType.football5, 1, 400000), (CourtType.football7, 1, 700000)],
    );

    final seven = await repo.getTimeSlots('f1', Sport.football, DateTime(2030, 1, 5), courtType: CourtType.football7);
    expect(seven.map((s) => (s.id, s.courtType)), [('s2', CourtType.football7)]);
    final all = await repo.getTimeSlots('f1', Sport.football, DateTime(2030, 1, 5));
    expect(all.map((s) => s.id), ['s1', 's2', 's3']);
    expect(server.requests.where((r) => r.path == ApiFacilityRepository.facilityPath('f1')), hasLength(1));
  });

  group('giữ chỗ trên máy (BE chưa có API giữ chỗ)', () {
    setUp(() {
      server.ok(ApiFacilityRepository.availabilityPath('f1'), {
        'facilityId': 'f1',
        'courts': [
          {
            'courtId': 'c1', 'courtName': 'Sân 1', 'categoryId': _badmintonId,
            'slots': [
              {'id': 's1', 'startTime': '2030-01-05T06:00:00+07:00', 'endTime': '2030-01-05T07:00:00+07:00', 'price': 100000, 'isBookable': true},
              {'id': 's2', 'startTime': '2030-01-05T07:00:00+07:00', 'endTime': '2030-01-05T08:00:00+07:00', 'price': 100000, 'isBookable': true},
              {'id': 's3', 'startTime': '2030-01-05T08:00:00+07:00', 'endTime': '2030-01-05T09:00:00+07:00', 'price': 100000, 'isBookable': false},
            ],
          },
        ],
      });
    });

    Future<List<TimeSlot>> slots() => repo.getTimeSlots('f1', Sport.badminton, DateTime(2030, 1, 5));

    test('kiểm tra lại khung còn trống (mỗi ngày tải một lần) rồi giữ 10 phút', () async {
      final all = await slots();
      final before = server.requests.length;

      final hold = await repo.holdSlots([all[1], all[0]]);

      expect(hold.slots.map((s) => s.id), ['s1', 's2']);
      expect(hold.expiresAt.difference(DateTime.now()).inMinutes, closeTo(10, 1));
      expect(server.requests.length - before, 1);
    });

    test('một khung vừa có người đặt thì không giữ khung nào, báo rõ khung đó', () async {
      final all = await slots();
      await expectLater(
        repo.holdSlots([all[0], all[2]]),
        throwsA(isA<FacilityException>().having((e) => e.message, 'message', contains('Sân 1'))),
      );
      await expectLater(repo.holdSlots(const []), throwsA(isA<FacilityException>()));
    });

    test('chuyển một phần chỗ giữ sang lượt mới; nhả rồi thì không chuyển được', () async {
      final hold = await repo.holdSlots((await slots()).take(2).toList());
      final until = DateTime(2030, 1, 5, 7);

      final moved = await repo.transferHold(hold.holdId, until: until, slotIds: ['s2']);
      expect(moved.slots.single.id, 's2');
      expect(moved.expiresAt, until);

      await repo.releaseHold(hold.holdId);
      await expectLater(repo.transferHold(hold.holdId, until: until), throwsA(isA<FacilityException>()));
    });
  });
}
