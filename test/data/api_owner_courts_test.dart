import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_owner_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/owner_repository.dart';
import 'package:test1/models/facility_review.dart';
import 'package:test1/models/owner_complaint.dart';
import 'package:test1/models/owner_court.dart';
import 'package:test1/models/owner_promotion.dart';
import 'package:test1/models/owner_shop.dart';
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

  test('đánh giá: lọc gửi đúng query, đọc userFullName / ownerReply; thống kê; POST gửi, PUT sửa, DELETE xóa', () async {
    server.ok('GET', ApiOwnerRepository.reviewsPath, {
      'items': [
        {
          'id': 'r1',
          'facilityId': 'f1',
          'facilityName': 'Sân A',
          'userFullName': 'Minh Anh',
          'rating': 4,
          'comment': 'Tốt',
          'createdAt': '2026-11-20T08:00:00Z',
          'ownerReply': 'Cảm ơn',
          'repliedAt': '2026-11-21T08:00:00Z',
          'isHidden': false,
        },
      ],
      'totalCount': 25,
    });
    final page = await repo.getFacilityReviews(facilityId: 'f1', rating: 4, replied: true, page: 2);
    expect(server.requests.last.queryParameters, {'FacilityId': 'f1', 'Rating': 4, 'Replied': true, 'Page': 2, 'PageSize': 10});
    expect(page.totalPages, 3);
    expect(page.items.single.userName, 'Minh Anh');
    expect(page.items.single.hasReply, isTrue);

    server.ok('GET', ApiOwnerRepository.reviewStatsPath, {
      'totalReviews': 10,
      'averageRating': 4.2,
      'unrepliedCount': 3,
      'replyRate': 0.7,
      'newReviewsLast30Days': 2,
      'ratingDistribution': {'5': 6, '4': 2, '1': 2},
    });
    final s = await repo.getReviewStats();
    expect(s.replyPercent, 70);
    expect(s.countOf(5), 6);
    expect(s.countOf(3), 0);

    server.ok('POST', ApiOwnerRepository.reviewReplyPath('r1'), null);
    server.ok('PUT', ApiOwnerRepository.reviewReplyPath('r1'), null);
    server.ok('DELETE', ApiOwnerRepository.reviewReplyPath('r1'), null);
    await repo.replyToReview('r1', ' Cảm ơn ');
    expect(server.requests.last.method, 'POST');
    expect(server.requests.last.data, {'reply': 'Cảm ơn'});
    await repo.replyToReview('r1', 'Sửa', edit: true);
    expect(server.requests.last.method, 'PUT');
    await repo.deleteReviewReply('r1');
    expect(server.requests.last.method, 'DELETE');
  });

  test('báo cáo đánh giá: BE chưa có API thì báo "đang chờ hệ thống"', () async {
    await expectLater(
      repo.reportReview('r1', ReportReason.spam),
      throwsA(isA<OwnerException>().having((e) => e.unavailable, 'unavailable', isTrue)),
    );
    expect(server.requests, isEmpty);
  });

  test('khiếu nại: đọc số đếm + trạng thái; giải trình và hoàn tiền gửi đúng body', () async {
    server.ok('GET', ApiOwnerRepository.complaintsPath, {
      'items': [
        {
          'id': 'c1',
          'status': 'OwnerResponded',
          'reporterName': 'Bảo',
          'facilityName': 'Sân A',
          'courtName': 'Sân 1',
          'reason': 'Hư đèn',
          'bookingStartTime': '2026-11-20T10:00:00Z',
          'bookingTotalAmount': 160000,
          'bookingStatus': 'CheckedIn',
          'createdAt': '2026-11-20T12:00:00Z',
          'evidenceImageUrls': ['https://x/1.jpg'],
        },
      ],
      'totalCount': 1,
      'pendingCount': 3,
      'ownerRespondedCount': 1,
    });
    final page = await repo.getComplaints(status: ComplaintStatus.pending, keyword: ' Bảo ');
    expect(server.requests.last.queryParameters, {'Status': 'PENDING', 'SearchKeyword': 'Bảo', 'PageIndex': 1, 'PageSize': 10});
    expect(page.counts.pending, 3);
    final c = page.items.single;
    expect(c.status, ComplaintStatus.ownerResponded);
    expect(c.status.canAct, isTrue);
    expect(c.bookingStatus, 'CHECKED_IN');

    server.ok('POST', '${ApiOwnerRepository.complaintPath('c1')}/respond', null);
    await repo.respondComplaint('c1', response: ' Đã sửa ', evidenceUrls: const ['u1']);
    expect(server.requests.last.data, {'ownerResponse': 'Đã sửa', 'ownerEvidenceUrls': ['u1']});

    server.ok('POST', '${ApiOwnerRepository.complaintPath('c1')}/accept-refund', null);
    await repo.acceptComplaintRefund('c1', response: 'Hoàn', refundPercent: 50, lockSlot: true);
    expect(server.requests.last.data, {
      'ownerResponse': 'Hoàn',
      'ownerEvidenceUrls': <String>[],
      'refundPercentage': 50,
      'lockSlotForMaintenance': true,
    });
  });

  test('tổng quan: gửi FacilityId / From / To theo ngày, đọc đủ số liệu', () async {
    server.ok('GET', ApiOwnerRepository.dashboardPath, {
      'totalBookings': 12,
      'checkedInBookings': 8,
      'occupancyRate': 42.5,
      'bookedSlots': 17,
      'sellableSlots': 40,
      'totalRevenue': 1200000,
      'openReports': 1,
      'bookingsByHour': [
        {'hour': 18, 'bookings': 5},
        {'hour': 7, 'bookings': 2},
      ],
      'revenueByDay': [
        {'date': '2026-11-25T00:00:00', 'revenue': 300000, 'bookings': 3},
      ],
      'revenueByCourt': [
        {'courtId': 'c1', 'courtName': 'Sân 1', 'bookings': 12, 'bookedSlots': 17, 'sellableSlots': 40, 'revenue': 1200000},
      ],
    });
    final d = await repo.getDashboard(facilityId: 'f1', from: DateTime(2026, 10, 27), to: DateTime(2026, 11, 25));
    expect(server.requests.last.queryParameters, {'FacilityId': 'f1', 'From': '2026-10-27', 'To': '2026-11-25'});
    expect(d.peakHour, (18, 5));
    expect(d.revenueByDay.single.date, DateTime(2026, 11, 25));
    expect(d.revenueByCourt.single.occupancy, 43);
    expect(d.openReports, 1);
  });

  test('quảng bá: gói cho cơ sở (targetType=FACILITY), mua gửi packageId + targetId, đọc lượt đã mua', () async {
    server.ok('GET', ApiOwnerRepository.promotionPackagesPath, [
      {'id': 'p1', 'name': 'Nổi bật', 'targetType': 'FACILITY', 'durationDays': 7, 'price': 150000},
    ]);
    expect((await repo.getPromotionPackages()).single.durationDays, 7);
    expect(server.requests.last.queryParameters, {'targetType': 'FACILITY'});

    server.ok('POST', ApiOwnerRepository.promotionsPath, null);
    await repo.purchasePromotion(packageId: 'p1', facilityId: 'f1');
    expect(server.requests.last.data, {'packageId': 'p1', 'targetId': 'f1'});

    server.ok('GET', ApiOwnerRepository.myPromotionsPath, {
      'items': [
        {'id': 'm1', 'packageName': 'Nổi bật', 'targetName': 'Sân A', 'status': 'Active', 'price': 150000, 'endAt': '2030-01-01T00:00:00Z'},
      ],
    });
    final mine = await repo.getMyPromotions(activeOnly: true);
    expect(mine.single.status, PromotionStatus.active);
    expect(server.requests.last.queryParameters['activeOnly'], true);
  });

  test('shop: sản phẩm gồm cả ẩn, upsert gửi đúng body, đơn đọc trạng thái, PATCH đổi trạng thái', () async {
    server.ok('GET', ApiOwnerRepository.shopProductsPath('f1'), [
      {'id': 's1', 'facilityId': 'f1', 'name': 'Nước', 'price': 10000, 'stock': 5, 'isActive': false},
    ]);
    expect((await repo.getShopProducts('f1')).single.isActive, isFalse);
    expect(server.requests.last.queryParameters, {'includeInactive': true});

    server.ok('POST', ApiOwnerRepository.shopProductsPath('f1'), null);
    await repo.createShopProduct('f1', const ShopProductInput(name: ' Nước ', description: ' ', price: 10000, stock: 5));
    expect(server.requests.last.data,
        {'name': 'Nước', 'description': null, 'price': 10000, 'stock': 5, 'imageUrl': null, 'isActive': true});

    server.ok('GET', ApiOwnerRepository.shopOrdersPath('f1'), [
      {'id': 'o1', 'productName': 'Nước', 'quantity': 2, 'totalAmount': 20000, 'status': 'PickedUp', 'createdAt': '2026-11-26T08:00:00Z'},
    ]);
    expect((await repo.getShopOrders('f1', status: ShopOrderStatus.pickedUp)).single.status, ShopOrderStatus.pickedUp);
    expect(server.requests.last.queryParameters, {'status': 'PICKED_UP'});

    server.ok('PATCH', ApiOwnerRepository.shopOrderStatusPath('o1'), null);
    await repo.updateShopOrderStatus('o1', ShopOrderStatus.ready);
    expect(server.requests.last.data, {'status': 'READY'});
  });

  test('giờ mở cửa gửi TimeSpan', () async {
    server.ok('PUT', '/api/v1/facilities/f1', null);
    await repo.updateOpenHours('f1', openTime: '06:00', closeTime: '22:30');
    expect(server.requests.single.data, {'openTime': '06:00:00', 'closeTime': '22:30:00'});
  });
}
