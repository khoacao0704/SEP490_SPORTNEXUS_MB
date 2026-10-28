import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/split_payment_strings.dart';
import 'package:test1/data/api/api_booking_repository.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/booking_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/booking.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/time_slot.dart';
import 'package:test1/models/user_role.dart';

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

const _me = 'u-me';

Map<String, dynamic> _summary(String id, String start, {String status = 'PAID', String role = 'Host', String pay = 'HELD', int people = 1}) => {
  'bookingId': id,
  'myRole': role,
  'bookingStatus': status,
  'createdAt': '2030-01-01T08:00:00+00:00',
  'facilityName': 'Hà Nội Badminton Center',
  'facilityAddress': '36 Trần Duy Hưng, Cầu Giấy, Hà Nội',
  'courtName': 'Sân 1',
  'sportName': 'Cầu lông',
  'startTime': start,
  'endTime': start.replaceFirst('T06', 'T07'),
  'totalAmount': 100000.00,
  'myAmount': 100000.00,
  'myPaymentStatus': pay,
  'participantCount': people,
};

void main() {
  late _FakeServer server;
  late ApiBookingRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.save(
      const AppUser(id: _me, fullName: 'Khoa Cao', email: 'k@x.com', phone: '0978809952', role: UserRole.player),
      rememberMe: true,
    );
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiBookingRepository(api: ApiClient(tokens: tokens, dio: dio));
  });

  TimeSlot slot(String id, int hour) => TimeSlot(
        id: id,
        facilityId: 'f1',
        sport: Sport.badminton,
        courtName: 'Sân $hour',
        start: DateTime(2030, 1, 5, hour),
        end: DateTime(2030, 1, 5, hour + 1),
        price: 100000,
        isAvailable: true,
      );

  SlotHold hold(List<TimeSlot> slots) => SlotHold(holdId: 'local-1', slots: slots, expiresAt: DateTime(2030));

  Future<List<Booking>> book(SlotHold h, {BookingPaymentType type = BookingPaymentType.full}) => repo.createBooking(
        hold: h,
        paymentType: type,
        facilityName: 'Hà Nội Badminton Center',
        sportLabel: 'Cầu Lông',
        location: '36 Trần Duy Hưng',
        schedule: '',
      );

  test('chưa chia tiền bằng mã; vé đổi mã 30 giây', () {
    expect(repo.supportsSplitPayment, isFalse);
    expect(repo.ticketRefreshInterval, const Duration(seconds: 30));
  });

  test('đặt sân: gửi id các ca, mỗi ca một lượt đặt kèm đúng sân con', () async {
    server.routes['POST ${ApiBookingRepository.bookingsPath}'] = (
      201,
      {
        'statusCode': 201,
        'message': 'Đặt sân thành công',
        'data': {
          'id': 'b1',
          'bookingIds': ['b1', 'b2'],
          'totalAmount': 200000.00,
          'totalAmountPaid': 200000.00,
          'bookings': [
            {'bookingId': 'b2', 'courtSlotId': 's9', 'startTime': '2030-01-05T09:00:00+07:00', 'endTime': '2030-01-05T10:00:00+07:00', 'slotPrice': 100000.00, 'status': 'PAID'},
            {'bookingId': 'b1', 'courtSlotId': 's8', 'startTime': '2030-01-05T08:00:00+07:00', 'endTime': '2030-01-05T09:00:00+07:00', 'slotPrice': 100000.00, 'status': 'PAID'},
          ],
        },
      },
    );

    final bookings = await book(hold([slot('s9', 9), slot('s8', 8)]));

    expect(server.requests.single.data, {
      'courtSlotIds': ['s8', 's9'],
    });
    expect(bookings.map((b) => b.id), ['b1', 'b2']);
    expect(bookings.first.courtName, 'Sân 8');
    expect(bookings.first.bookerId, _me);
    expect(bookings.first.amountPaid, 100000);
    expect(bookings.first.paymentType, BookingPaymentType.full);
  });

  test('ca vừa có người đặt / ví không đủ: hiện câu của BE', () async {
    server.fail('POST', ApiBookingRepository.bookingsPath, 400, 'Ca sân 06:00 đã có người đặt hoặc đang bảo trì');
    await expectLater(
      book(hold([slot('s1', 6)])),
      throwsA(isA<BookingException>().having((e) => e.message, 'message', contains('đã có người đặt'))),
    );
  });

  test('lịch đặt: sắp diễn ra (gần nhất trước) rồi đã qua; đơn được mời góp không phải của mình', () async {
    server.ok('GET', ApiBookingRepository.myBookingsPath, [
      _summary('old', '2020-01-05T06:00:00+07:00', status: 'CHECKED_IN'),
      _summary('later', '2030-02-05T06:00:00+07:00'),
      _summary('soon', '2030-01-05T06:00:00+07:00', role: 'Participant', pay: 'PENDING', status: 'PENDING', people: 4),
      _summary('cancelled', '2030-03-05T06:00:00+07:00', status: 'CANCELLED'),
    ]);

    final list = await repo.getMyBookings();

    expect(list.map((b) => b.id), ['soon', 'later', 'cancelled', 'old']);
    final soon = list.first;
    expect(soon.bookerId, isNot(_me));
    expect(soon.amountPaid, 0);
    expect(soon.paymentType, BookingPaymentType.split);
    expect(soon.sportLabel, Sport.badminton.label);
    expect(soon.location, '36 Trần Duy Hưng, Cầu Giấy, Hà Nội');
    final later = list[1];
    expect(later.bookerId, _me);
    expect(later.amountPaid, 100000);
    expect(later.canCancel(DateTime(2030), _me), isTrue);
    expect(list[2].status(DateTime(2030)), BookingStatus.cancelled);
    expect(list.last.isCheckedIn, isTrue);
  });

  test('hủy: gửi mã lý do / lý do tự nhập, trả số tiền BE thực hoàn', () async {
    server.ok('POST', ApiBookingRepository.cancelPath('b1'), {
      'bookingId': 'b1',
      'status': 'CANCELLED',
      'refundStatus': 'NO_REFUND_LATE_CANCEL',
      'refundAmount': 0,
      'penaltyAmount': 100000,
    });
    server.ok('GET', ApiBookingRepository.bookingPath('b1'), {
      'bookingId': 'b1',
      'bookingStatus': 'CANCELLED',
      'hostId': _me,
      'facilityName': 'Hà Nội Badminton Center',
      'facilityAddress': '36 Trần Duy Hưng',
      'courtName': 'Sân 1',
      'sportName': 'Cầu lông',
      'startTime': '2030-01-05T06:00:00+07:00',
      'endTime': '2030-01-05T07:00:00+07:00',
      'totalAmount': 100000,
      'participants': [
        {'userId': _me, 'fullName': 'Khoa Cao', 'amountContributed': 100000, 'paymentStatus': 'REFUNDED', 'isHost': true},
      ],
      'cancellation': {'reason': 'Bận', 'refundAmount': 0, 'penaltyAmount': 100000, 'cancelledAt': '2030-01-05T00:00:00+07:00'},
    });

    final cancelled = await repo.cancelBooking('b1', reasonCode: 1, reason: 'Bận việc');
    expect(server.requests.first.data, {'reasonCode': 1, 'reason': 'Bận việc'});
    expect(cancelled.refunded, 0);
    expect(cancelled.status(DateTime(2030)), BookingStatus.cancelled);

    await repo.cancelBooking('b1', reason: '   ');
    expect(server.requests[2].data, isEmpty);
  });

  test('hủy xong mà không tải lại được chi tiết: chỉ báo đã hủy (refundAmount là của cả đơn)', () async {
    server.ok('POST', ApiBookingRepository.cancelPath('b1'), {'refundAmount': 100000});
    final cancelled = await repo.cancelBooking('b1');
    expect(cancelled.cancelledAt, isNotNull);
    expect(cancelled.refunded, 0);
  });

  test('hủy đơn chia tiền: chỉ hiện phần mình được hoàn, không phải refundAmount của cả đơn', () async {
    server.ok('POST', ApiBookingRepository.cancelPath('b1'), {'refundStatus': 'REFUNDED', 'refundAmount': 66667});
    server.ok('GET', ApiBookingRepository.bookingPath('b1'), {
      'bookingId': 'b1',
      'bookingStatus': 'CANCELLED',
      'hostId': _me,
      'facilityName': 'Hà Nội Badminton Center',
      'startTime': '2030-01-05T06:00:00+07:00',
      'endTime': '2030-01-05T07:00:00+07:00',
      'totalAmount': 100000,
      'participants': [
        {'userId': _me, 'fullName': 'Khoa Cao', 'amountContributed': 33334, 'paymentStatus': 'REFUNDED', 'isHost': true},
        {'userId': 'u-a', 'fullName': 'An', 'amountContributed': 33333, 'paymentStatus': 'REFUNDED'},
        {'userId': 'u-b', 'fullName': 'Bình', 'amountContributed': 33333, 'paymentStatus': 'PENDING'},
      ],
      'cancellation': {'reason': 'Bận', 'refundAmount': 66667, 'penaltyAmount': 0, 'cancelledAt': '2030-01-05T05:55:00+07:00'},
    });

    final cancelled = await repo.cancelBooking('b1');
    expect(cancelled.refunded, 33334);
    expect(cancelled.paymentType, BookingPaymentType.split);
    expect(cancelled.amountPaid, 66667);
  });

  test('người bị người đặt trả thay: ẩn khỏi lịch đặt và khỏi danh sách người góp', () async {
    server.ok('GET', ApiBookingRepository.myBookingsPath, [
      _summary('removed', '2030-01-05T06:00:00+07:00', role: 'Participant', pay: 'PENDING', status: 'PAID', people: 3),
      _summary('paid', '2030-01-06T06:00:00+07:00', role: 'Participant', pay: 'HELD', status: 'PAID', people: 3),
      _summary('gone', '2030-01-07T06:00:00+07:00', role: 'Participant', pay: 'PENDING', status: 'CANCELLED', people: 3),
    ]);
    expect((await repo.getMyBookings()).map((b) => b.id), ['paid', 'gone']);

    server.ok('GET', ApiBookingRepository.bookingPath('b1'), {
      'bookingId': 'b1',
      'bookingStatus': 'PAID',
      'hostId': _me,
      'facilityName': 'Hà Nội Badminton Center',
      'startTime': '2030-01-05T06:00:00+07:00',
      'endTime': '2030-01-05T07:00:00+07:00',
      'totalAmount': 100000,
      'participants': [
        {'userId': _me, 'fullName': 'Khoa Cao', 'amountContributed': 66667, 'paymentStatus': 'HELD', 'isHost': true},
        {'userId': 'u-a', 'fullName': 'An', 'amountContributed': 33333, 'paymentStatus': 'HELD'},
        {'userId': 'u-b', 'fullName': 'Bình', 'amountContributed': 33333, 'paymentStatus': 'PENDING'},
      ],
    });
    final b = await repo.getBooking('b1');
    expect(b.participants.map((p) => p.name), ['Khoa Cao', 'An']);
    expect(b.paymentType, BookingPaymentType.split);
  });

  test('đơn chia tiền còn chờ góp: hủy lúc nào cũng hoàn đủ', () async {
    server.ok('GET', ApiBookingRepository.bookingPath('b1'), {
      'bookingId': 'b1',
      'bookingStatus': 'PENDING',
      'hostId': _me,
      'facilityName': 'Hà Nội Badminton Center',
      'startTime': '2030-01-05T06:00:00+07:00',
      'endTime': '2030-01-05T07:00:00+07:00',
      'totalAmount': 100000,
      'participants': [
        {'userId': _me, 'fullName': 'Khoa Cao', 'amountContributed': 50000, 'paymentStatus': 'HELD', 'isHost': true},
        {'userId': 'u-a', 'fullName': 'An', 'amountContributed': 50000, 'paymentStatus': 'PENDING'},
      ],
    });
    final b = await repo.getBooking('b1');
    final oneHourBefore = DateTime.parse('2030-01-05T05:00:00+07:00').toLocal();
    expect(b.isFreeCancel(oneHourBefore), isFalse);
    expect(b.refundsInFull(oneHourBefore), isTrue);
    expect(b.cancelFee(oneHourBefore), 0);
  });

  group('chia tiền mời bạn', () {
    Map<String, dynamic> detail({String status = 'PENDING', bool friendPaid = false}) => {
          'bookingId': 'b1',
          'bookingStatus': status,
          'hostId': _me,
          'facilityName': 'Hà Nội Badminton Center',
          'facilityAddress': '36 Trần Duy Hưng',
          'courtName': 'Sân 1',
          'sportName': 'Cầu lông',
          'startTime': '2030-01-05T06:00:00+07:00',
          'endTime': '2030-01-05T07:00:00+07:00',
          'createdAt': '2030-01-05T05:50:00+07:00',
          'totalAmount': 100000,
          'participants': [
            {'userId': _me, 'fullName': 'Khoa Cao', 'amountContributed': 33334, 'paymentStatus': 'HELD', 'isHost': true},
            {'userId': 'u-a', 'fullName': 'An', 'amountContributed': 33333, 'paymentStatus': friendPaid ? 'HELD' : 'PENDING'},
            {'userId': 'u-b', 'fullName': 'Bình', 'amountContributed': 33333, 'paymentStatus': 'PENDING'},
          ],
          'cancellation': null,
        };

    test('luồng mời bạn bật, chia mã/link tắt', () {
      expect(repo.supportsSplitInvite, isTrue);
      expect(repo.supportsSplitPayment, isFalse);
    });

    test('tìm bạn theo SĐT; không có tài khoản thì báo', () async {
      server.ok('GET', ApiBookingRepository.lookupPath, {'id': 'u-a', 'fullName': 'An', 'phoneMasked': '******1234'});
      final player = await repo.findPlayerByPhone(' 0901231234 ');
      expect(server.requests.single.queryParameters, {'phone': '0901231234'});
      expect((player.id, player.fullName, player.phoneMasked), ('u-a', 'An', '******1234'));

      server.ok('GET', ApiBookingRepository.lookupPath, null);
      await expectLater(
        repo.findPlayerByPhone('0909999999'),
        throwsA(isA<BookingException>().having((e) => e.message, 'message', SplitPaymentStrings.playerNotFound)),
      );
    });

    test('tạo đơn chia tiền: gửi cờ + id bạn bè; người đặt trả phần mình (gồm số lẻ), đơn chờ góp', () async {
      server.routes['POST ${ApiBookingRepository.bookingsPath}'] = (
        201,
        {
          'statusCode': 201,
          'message': 'OK',
          'data': {
            'bookings': [
              {'bookingId': 'b1', 'courtSlotId': 's6', 'startTime': '2030-01-05T06:00:00+07:00', 'endTime': '2030-01-05T07:00:00+07:00', 'slotPrice': 100000, 'status': 'PENDING'},
            ],
          },
        },
      );

      final bookings = await repo.createSplitBooking(
        hold: hold([slot('s6', 6)]),
        inviteeIds: ['u-a', 'u-b'],
        facilityName: 'Hà Nội Badminton Center',
        sportLabel: 'Cầu Lông',
        location: '36 Trần Duy Hưng',
      );

      expect(server.requests.single.data, {
        'courtSlotIds': ['s6'],
        'isSplitPayment': true,
        'participantIds': ['u-a', 'u-b'],
      });
      final b = bookings.single;
      expect(b.awaitingPayment, isTrue);
      expect(b.myShare, 33334);
      expect(b.amountPaid, 33334);
      expect(b.paymentType, BookingPaymentType.split);

      server.requests.clear();
      await expectLater(
        repo.createSplitBooking(hold: hold([slot('s6', 6)]), inviteeIds: const [], facilityName: '', sportLabel: '', location: ''),
        throwsA(isA<BookingException>().having((e) => e.message, 'message', SplitPaymentStrings.inviteRequired)),
      );
      expect(server.requests, isEmpty);
    });

    test('chi tiết: ai đã góp / chưa góp, phần của mình, hạn góp', () async {
      server.ok('GET', ApiBookingRepository.bookingPath('b1'), detail(friendPaid: true));
      final b = await repo.getBooking('b1');

      expect(b.awaitingPayment, isTrue);
      expect(b.participants.map((p) => (p.name, p.isPaid, p.isHost)), [
        ('Khoa Cao', true, true),
        ('An', true, false),
        ('Bình', false, false),
      ]);
      expect(b.myShare, 33334);
      expect(b.amountPaid, 66667);
      expect(b.owesShare(_me), isFalse);
      expect(b.owesShare('u-b'), isTrue);
      // 30 phút sau khi tạo nhưng không quá giờ bắt đầu (06:00).
      expect(b.splitDeadline, DateTime.parse('2030-01-05T06:00:00+07:00').toLocal());
    });

    test('góp / mời thêm / trả nốt: gọi đúng API rồi tải lại chi tiết', () async {
      server.ok('POST', ApiBookingRepository.joinPath('b1'), {'bookingId': 'b1', 'status': 'PENDING'});
      server.ok('POST', ApiBookingRepository.participantsPath('b1'), null);
      server.ok('POST', ApiBookingRepository.payRemainingPath('b1'), null);
      server.ok('GET', ApiBookingRepository.bookingPath('b1'), detail(status: 'PAID'));

      await repo.joinSplit('b1');
      await repo.inviteMore('b1', ['u-c']);
      final done = await repo.payRemaining('b1');

      expect(server.requests.map((r) => '${r.method} ${r.path}'), [
        'POST ${ApiBookingRepository.joinPath('b1')}',
        'GET ${ApiBookingRepository.bookingPath('b1')}',
        'POST ${ApiBookingRepository.participantsPath('b1')}',
        'GET ${ApiBookingRepository.bookingPath('b1')}',
        'POST ${ApiBookingRepository.payRemainingPath('b1')}',
        'GET ${ApiBookingRepository.bookingPath('b1')}',
      ]);
      expect(server.requests[2].data, {
        'participantIds': ['u-c'],
      });
      expect(done.awaitingPayment, isFalse);
    });

    test('góp tiền lỗi (ví không đủ): hiện câu của BE', () async {
      server.fail('POST', ApiBookingRepository.joinPath('b1'), 400, 'Số dư không đủ để trả phần của bạn (cần 33.333đ)');
      await expectLater(
        repo.joinSplit('b1'),
        throwsA(isA<BookingException>().having((e) => e.message, 'message', contains('Số dư không đủ'))),
      );
    });

    test('lịch đặt: đơn được mời chưa góp hiện phần của mình', () async {
      server.ok('GET', ApiBookingRepository.myBookingsPath, [
        {..._summary('b1', '2030-01-05T06:00:00+07:00', role: 'Participant', pay: 'PENDING', status: 'PENDING', people: 3), 'myAmount': 33333},
      ]);
      final b = (await repo.getMyBookings()).single;
      expect(b.awaitingPayment, isTrue);
      expect(b.myShare, 33333);
      expect(b.amountPaid, 0);
    });
  });

  test('lý do hủy và vé QR (chuỗi hoặc bọc trong object)', () async {
    server.ok('GET', ApiBookingRepository.cancelReasonsPath, [
      {'code': 1, 'label': 'Bận việc đột xuất', 'isCustom': false},
      {'code': 6, 'label': 'Khác (Tự nhập lý do)', 'isCustom': true},
    ]);
    final reasons = await repo.getCancelReasons();
    expect(reasons.map((r) => (r.code, r.isCustom)), [(1, false), (6, true)]);

    final booking = (await (() async {
      server.ok('GET', ApiBookingRepository.myBookingsPath, [_summary('b1', '2030-01-05T06:00:00+07:00')]);
      return repo.getMyBookings();
    })())
        .single;
    server.ok('GET', ApiBookingRepository.ticketPath('b1'), 'TICKET_b1_u-me_123');
    expect(await repo.getTicketCode(booking), 'TICKET_b1_u-me_123');
    server.ok('GET', ApiBookingRepository.ticketPath('b1'), {'qrCode': 'TICKET_b1_u-me_124'});
    expect(await repo.getTicketCode(booking), 'TICKET_b1_u-me_124');
    server.fail('GET', ApiBookingRepository.ticketPath('b1'), 400, 'Đơn chưa đủ tiền nên chưa có vé');
    await expectLater(repo.getTicketCode(booking), throwsA(isA<BookingException>()));
  });
}
