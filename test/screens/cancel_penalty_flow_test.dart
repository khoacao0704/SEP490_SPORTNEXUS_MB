import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/lfg_strings.dart';
import 'package:test1/core/strings/owner_strings.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_facility_repository.dart';
import 'package:test1/data/api/api_lfg_repository.dart';
import 'package:test1/data/api/api_owner_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/user_role.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';
import 'package:test1/screens/owner/owner_session_detail_screen.dart';

/// Kịch bản hủy có phạt chạy qua repository API thật + màn hình thật, server giả trả JSON dạng BE.
/// Mỗi route là một hàm nên trạng thái "server" đổi được sau khi bấm hủy.
class _Server implements HttpClientAdapter {
  final Map<String, Object? Function(RequestOptions)> routes = {};
  final Map<String, (int, String)> failures = {};
  final List<RequestOptions> requests = [];

  void on(String method, String path, Object? Function(RequestOptions r) data) => routes['$method $path'] = data;

  List<RequestOptions> posts(String path) => requests.where((r) => r.method == 'POST' && r.path == path).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    final fail = failures[key];
    if (fail != null) {
      return ResponseBody.fromString(jsonEncode({'statusCode': fail.$1, 'message': fail.$2, 'data': null}), fail.$1,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    final route = routes[key];
    if (route == null) return ResponseBody.fromString('', 404);
    return ResponseBody.fromString(
      jsonEncode({'statusCode': 200, 'message': 'OK', 'data': route(options)}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

const _me = 'u-player-001';
const _cardId = 'c1';

/// Kèo như BE trả: `totalSlots` / `remainingSlots` KHÔNG tính host; có `hostCancelUntil` = T−48h.
Map<String, dynamic> _card({
  required Duration startsIn,
  required int totalSlots,
  required int remaining,
  int courtPrice = 150000,
  bool cancelled = false,
  bool withParticipants = false,
}) {
  final start = DateTime.now().add(startsIn).toUtc();
  final joined = totalSlots - remaining;
  return {
    'id': _cardId,
    'bookingId': 'b-$_cardId',
    'hostId': _me,
    'hostName': 'Khoa Cao',
    'hostFairPlayScore': 93,
    'facilityId': 'f1',
    'facilityName': 'Hà Nội Badminton Center',
    'facilityAddress': '36 Trần Duy Hưng, Cầu Giấy, Hà Nội',
    'courtName': 'Sân 1',
    'sportName': 'Cầu lông',
    'startTime': start.toIso8601String(),
    'endTime': start.add(const Duration(hours: 1)).toIso8601String(),
    'hostCancelUntil': start.subtract(const Duration(hours: 48)).toIso8601String(),
    'totalSlots': totalSlots,
    'remainingSlots': remaining,
    'pricePerPerson': (courtPrice / (totalSlots + 1)).round(),
    'bookingTotalAmount': courtPrice,
    'status': cancelled ? 'CANCELLED' : (remaining == 0 ? 'FILLED' : 'PENDING'),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    if (withParticipants)
      'participants': [
        for (var i = 0; i < joined; i++)
          {'userId': 'u-j$i', 'fullName': 'Người chơi $i', 'fairPlayScore': 90, 'status': 'ACCEPTED'},
        // Người được mời chưa trả tiền: không phải joiner, không được bồi thường.
        if (remaining > 0) {'userId': 'u-inv', 'fullName': 'Được mời', 'status': 'INVITED'},
      ],
  };
}

/// Lượt sân phía Chủ sân như /bookings/owner/{id} trả (dạng trường của BE, không phải JSON của app).
Map<String, dynamic> _ownerBooking({
  required String id,
  required Duration startsIn,
  required int total,
  String kind = 'Booking',
  int players = 1,
  bool cancelled = false,
}) {
  final start = DateTime.now().add(startsIn);
  return {
    'bookingId': id,
    'facilityId': 'f1',
    'facilityName': 'Sân Cầu Lông Thiên Triều',
    'startTime': start.toIso8601String(),
    'endTime': start.add(const Duration(hours: 1)).toIso8601String(),
    'sportName': 'Badminton',
    'type': kind,
    'totalPrice': total,
    'paidAmount': total,
    'courtName': 'Sân 2',
    'participants': [
      for (var i = 0; i < players; i++) {'userId': 'u$i', 'fullName': 'Khách $i', 'ticketCode': 'T$i'},
    ],
    if (cancelled) 'cancelledAt': DateTime.now().toIso8601String(),
  };
}

void main() {
  late _Server server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.save(
      const AppUser(id: _me, fullName: 'Khoa Cao', email: 'k@x.com', phone: '0978809952', role: UserRole.player, fairPlayScore: 93),
      rememberMe: true,
    );
    final auth = MockAuthRepository(latency: Duration.zero);
    await auth.login('player@sportnexus.vn', 'Player@123');
    AppRepositories.auth = auth;

    server = _Server();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    final api = ApiClient(tokens: tokens, dio: dio);
    AppRepositories.lfg = ApiLfgRepository(api: api, facility: ApiFacilityRepository(api: api));
    AppRepositories.owner = ApiOwnerRepository(api);
    server.on('GET', ApiFacilityRepository.sportsPath, (_) => [
          {'id': 'cat-badminton', 'name': 'Cầu lông'},
        ]);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  /// Server: GET kèo trả [card]; POST cancel thì kèo chuyển CANCELLED.
  void serveCard(Map<String, dynamic> Function({bool cancelled}) card) {
    var cancelled = false;
    server.on('GET', ApiLfgRepository.cardPath(_cardId), (_) => card(cancelled: cancelled));
    server.on('POST', ApiLfgRepository.cancelPath(_cardId), (_) {
      cancelled = true;
      return {'lfgCardId': _cardId};
    });
  }

  Future<void> openDialog(WidgetTester tester) async {
    await pump(tester, const LfgMatchDetailScreen(matchId: _cardId));
    expect(find.text('Yêu cầu hủy kèo'), findsNothing, reason: 'không còn nút vote hủy');
    await tester.tap(find.text(LfgStrings.cancelMatch));
    await tester.pumpAndSettle();
  }

  group('Host hủy kèo LFG', () {
    testWidgets('ĐỦ NGƯỜI, dưới 48h (2 người vào, sân 150k): mất 75.000đ, mỗi người 37.500đ, −20 FP', (tester) async {
      serveCard(({bool cancelled = false}) =>
          _card(startsIn: const Duration(hours: 20), totalSlots: 2, remaining: 0, cancelled: cancelled));
      await openDialog(tester);

      expect(find.text(LfgStrings.lateCancelWarning), findsOneWidget);
      expect(find.text('−${Formatters.vnd(75000)}'), findsOneWidget);
      expect(find.text(LfgStrings.lateCancelCompensation(2)), findsOneWidget);
      expect(find.text(Formatters.vnd(37500)), findsOneWidget);
      expect(find.text(LfgStrings.lateCancelFairPlay), findsOneWidget);

      await tester.tap(find.text(LfgStrings.lateCancelConfirm));
      await tester.pumpAndSettle();
      expect(server.posts(ApiLfgRepository.cancelPath(_cardId)), hasLength(1));
      expect(find.text(LfgStrings.lateCancelledMessage(75000)), findsOneWidget);
      expect(find.text(LfgStrings.statusCancelled), findsOneWidget);
      expect(find.text(LfgStrings.cancelMatch), findsNothing);
    });

    testWidgets('CHƯA ĐỦ NGƯỜI, dưới 48h (1/3 người vào, có 1 người được mời): bồi thường chỉ cho người đã vào',
        (tester) async {
      serveCard(({bool cancelled = false}) => _card(
          startsIn: const Duration(hours: 30), totalSlots: 3, remaining: 2, cancelled: cancelled, withParticipants: true));
      await openDialog(tester);

      expect(find.text(LfgStrings.lateCancelWarning), findsOneWidget);
      expect(find.text('−${Formatters.vnd(75000)}'), findsOneWidget);
      expect(find.text(LfgStrings.lateCancelCompensation(1)), findsOneWidget);
      expect(find.text(Formatters.vnd(75000)), findsOneWidget);
    });

    testWidgets('CHƯA AI VÀO, dưới 48h: không mất tiền sân, vẫn −20 FP', (tester) async {
      serveCard(({bool cancelled = false}) =>
          _card(startsIn: const Duration(hours: 5), totalSlots: 3, remaining: 3, cancelled: cancelled));
      await openDialog(tester);

      expect(find.text(LfgStrings.lateCancelWarningNoJoiner), findsOneWidget);
      expect(find.text(LfgStrings.lateCancelLossLabel), findsNothing);
      await tester.tap(find.text(LfgStrings.lateCancelConfirm));
      await tester.pumpAndSettle();
      expect(find.text(LfgStrings.lateCancelledMessage(0)), findsOneWidget);
    });

    testWidgets('ĐỦ NGƯỜI, còn hơn 48h: popup thường (hoàn 100%, −10 FP), không phải cảnh báo gắt', (tester) async {
      serveCard(({bool cancelled = false}) =>
          _card(startsIn: const Duration(days: 3), totalSlots: 2, remaining: 0, cancelled: cancelled));
      await openDialog(tester);

      expect(find.text(LfgStrings.hostCancelMessage(150000)), findsOneWidget);
      expect(find.text(LfgStrings.lateCancelTitle), findsNothing);
      await tester.tap(find.widgetWithText(ElevatedButton, LfgStrings.cancelMatch));
      await tester.pumpAndSettle();
      expect(find.text(LfgStrings.hostCancelledMessage), findsOneWidget);
    });

    testWidgets('Quay lại thì không gọi BE; BE từ chối (đã check-in) thì hiện đúng câu của BE', (tester) async {
      serveCard(({bool cancelled = false}) =>
          _card(startsIn: const Duration(minutes: 20), totalSlots: 2, remaining: 0, cancelled: cancelled));
      await openDialog(tester);
      await tester.tap(find.text(LfgStrings.lateCancelBack));
      await tester.pumpAndSettle();
      expect(server.posts(ApiLfgRepository.cancelPath(_cardId)), isEmpty);

      server.failures['POST ${ApiLfgRepository.cancelPath(_cardId)}'] = (400, 'Kèo đã check-in, không thể hủy.');
      await tester.tap(find.text(LfgStrings.cancelMatch));
      await tester.pumpAndSettle();
      await tester.tap(find.text(LfgStrings.lateCancelConfirm));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kèo đã check-in, không thể hủy.'), findsOneWidget);
      expect(find.text(LfgStrings.cancelMatch), findsOneWidget);
    });

    testWidgets('đã tới giờ chơi: không còn nút hủy', (tester) async {
      serveCard(({bool cancelled = false}) =>
          _card(startsIn: const Duration(minutes: -10), totalSlots: 2, remaining: 0, cancelled: cancelled));
      await pump(tester, const LfgMatchDetailScreen(matchId: _cardId));
      expect(find.text(LfgStrings.cancelMatch), findsNothing);
    });
  });

  group('Chủ sân hủy đơn', () {
    /// GET lượt sân trả [json]; POST cancel ghi nhận và trả số phạt BE (cố ý khác số dự kiến 1đ để chắc app đọc số thật).
    void serveOwner(Map<String, dynamic> Function({bool cancelled}) json, {required int bePenalty, required int beFp}) {
      var cancelled = false;
      final id = json()['bookingId'] as String;
      server.on('GET', '/api/v1/bookings/owner/$id', (_) => json(cancelled: cancelled));
      server.on('POST', ApiOwnerRepository.cancelBookingPath(id), (_) {
        cancelled = true;
        return {
          'bookingId': id,
          'status': 'Cancelled',
          'lateCancel': beFp > 0,
          'ownerPenaltyAmount': bePenalty,
          'ownerFairPlayPenalty': beFp,
          'refundAmount': 300000,
          'vouchersIssued': 1,
        };
      });
    }

    Future<void> openOwner(WidgetTester tester, String id) async {
      final session = await tester.runAsync(() => AppRepositories.owner.getSession(id));
      await pump(tester, OwnerSessionDetailScreen(session: session!));
      await tester.tap(find.text(OwnerStrings.cancelBooking));
      await tester.pumpAndSettle();
    }

    testWidgets('đơn thường, dưới 48h: phạt 20% (60.000đ) + −10 FP; gửi lý do + khóa ca; hiện số BE trả',
        (tester) async {
      serveOwner(({bool cancelled = false}) =>
          _ownerBooking(id: 'b1', startsIn: const Duration(hours: 10), total: 300000, cancelled: cancelled),
          bePenalty: 60001, beFp: 10);
      await openOwner(tester, 'b1');

      expect(find.text(OwnerStrings.cancelLateWarning), findsOneWidget);
      expect(find.text('−${Formatters.vnd(60000)}'), findsOneWidget);
      expect(find.text(OwnerStrings.cancelFairPlay(10)), findsOneWidget);

      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Sân hỏng đèn');
      await tester.tap(find.text(OwnerStrings.cancelLockSlot));
      await tester.tap(find.text(OwnerStrings.cancelConfirm));
      await tester.pumpAndSettle();

      final post = server.posts(ApiOwnerRepository.cancelBookingPath('b1')).single;
      expect(post.data, {'reason': 'Sân hỏng đèn', 'lockSlotAfterCancel': true});
      expect(find.text('Đã hủy đơn. Bạn bị phạt ${Formatters.vnd(60001)} và trừ 10 điểm Fair Play.'), findsOneWidget);
      expect(find.text(OwnerStrings.statusCancelled), findsOneWidget);
      expect(find.text(OwnerStrings.cancelBooking), findsNothing);
    });

    testWidgets('đơn thường, còn hơn 48h: phạt 10% (30.000đ), không trừ FP, không khóa ca', (tester) async {
      serveOwner(({bool cancelled = false}) =>
          _ownerBooking(id: 'b2', startsIn: const Duration(days: 3), total: 300000, cancelled: cancelled),
          bePenalty: 30000, beFp: 0);
      await openOwner(tester, 'b2');

      expect(find.text(OwnerStrings.cancelEarlyWarning), findsOneWidget);
      expect(find.text('−${Formatters.vnd(30000)}'), findsOneWidget);
      expect(find.text(OwnerStrings.cancelFairPlayLabel), findsNothing);

      await tester.tap(find.text(OwnerStrings.cancelConfirm));
      await tester.pumpAndSettle();
      expect(server.posts(ApiOwnerRepository.cancelBookingPath('b2')).single.data, {'lockSlotAfterCancel': false});
      expect(find.text('Đã hủy đơn. Bạn bị phạt ${Formatters.vnd(30000)}.'), findsOneWidget);
    });

    testWidgets('lượt sân kèo LFG ĐỦ NGƯỜI, dưới 48h: có ghi chú mọi người trong kèo được hoàn', (tester) async {
      serveOwner(({bool cancelled = false}) => _ownerBooking(
          id: 'b3', startsIn: const Duration(hours: 3), total: 400000, kind: 'Lfg', players: 4, cancelled: cancelled),
          bePenalty: 80000, beFp: 10);
      await openOwner(tester, 'b3');

      expect(find.text(OwnerStrings.cancelLfgNote), findsOneWidget);
      expect(find.text('−${Formatters.vnd(80000)}'), findsOneWidget);
      await tester.tap(find.text(OwnerStrings.cancelConfirm));
      await tester.pumpAndSettle();
      expect(find.text(OwnerStrings.statusCancelled), findsOneWidget);
    });

    testWidgets('lượt sân kèo LFG CHƯA ĐỦ NGƯỜI (chỉ host), còn hơn 48h: phạt 10%', (tester) async {
      serveOwner(({bool cancelled = false}) => _ownerBooking(
          id: 'b4', startsIn: const Duration(days: 4), total: 200000, kind: 'Lfg', cancelled: cancelled),
          bePenalty: 20000, beFp: 0);
      await openOwner(tester, 'b4');

      expect(find.text(OwnerStrings.cancelEarlyWarning), findsOneWidget);
      expect(find.text(OwnerStrings.cancelLfgNote), findsOneWidget);
      expect(find.text('−${Formatters.vnd(20000)}'), findsOneWidget);
    });

    testWidgets('BE báo đơn đã hủy (400): hiện câu của BE, Quay lại thì không gọi BE', (tester) async {
      serveOwner(({bool cancelled = false}) =>
          _ownerBooking(id: 'b5', startsIn: const Duration(hours: 10), total: 300000, cancelled: cancelled),
          bePenalty: 0, beFp: 0);
      await openOwner(tester, 'b5');
      await tester.tap(find.text(OwnerStrings.cancelBack));
      await tester.pumpAndSettle();
      expect(server.posts(ApiOwnerRepository.cancelBookingPath('b5')), isEmpty);

      server.failures['POST ${ApiOwnerRepository.cancelBookingPath('b5')}'] = (400, 'Đơn đã bị hủy trước đó.');
      await tester.tap(find.text(OwnerStrings.cancelBooking));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OwnerStrings.cancelConfirm));
      await tester.pumpAndSettle();
      expect(find.text('Đơn đã bị hủy trước đó.'), findsOneWidget);
    });

    testWidgets('đơn đã hủy: không còn nút Hủy đơn', (tester) async {
      serveOwner(({bool cancelled = false}) =>
          _ownerBooking(id: 'b6', startsIn: const Duration(hours: 10), total: 300000, cancelled: true),
          bePenalty: 0, beFp: 0);
      final session = await tester.runAsync(() => AppRepositories.owner.getSession('b6'));
      await pump(tester, OwnerSessionDetailScreen(session: session!));
      expect(find.text(OwnerStrings.cancelBooking), findsNothing);
    });
  });
}
