import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/auth_strings.dart';
import 'package:test1/core/strings/home_recommend_strings.dart';
import 'package:test1/core/strings/profile_strings.dart';
import 'package:test1/core/strings/security_strings.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_court_recommendation_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_court_recommendation_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/court_recommendation_repository.dart';
import 'package:test1/models/court_recommendation.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/screens/auth/login_screen.dart';
import 'package:test1/screens/booking/booking_checkout_screen.dart';
import 'package:test1/screens/profile/change_password_screen.dart';
import 'package:test1/screens/profile/security_screen.dart';
import 'package:test1/widgets/home/recommended_courts_section.dart';

import '../helpers/layout_check.dart';

class _FakeServer implements HttpClientAdapter {
  final Map<String, Object?> routes = {};
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final data = routes['${options.method} ${options.path}'];
    return ResponseBody.fromString(jsonEncode({'statusCode': 200, 'message': 'OK', 'data': data}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _FailingRecommendations implements CourtRecommendationRepository {
  @override
  Future<List<CourtRecommendation>> getRecommendedCourts({int limit = 6}) async => throw Exception('lỗi');
}

void main() {
  late MockFacilityRepository facility;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    facility = MockFacilityRepository(latency: Duration.zero);
    AppRepositories.wallet = wallet;
    AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.facility = AppRepositories.lfgFacility = facility;
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.courtRecommendation = MockCourtRecommendationRepository(facility: facility);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  group('Bảo mật', () {
    testWidgets('có 3 mục; mở đổi mật khẩu', (tester) async {
      await pump(tester, const SecurityScreen());
      expect(find.text(SecurityStrings.passwordSection), findsOneWidget);
      expect(find.text(SecurityStrings.emailSection), findsOneWidget);
      expect(find.text(SecurityStrings.devicesSection), findsOneWidget);
      expect(find.textContaining('player@sportnexus.vn', findRichText: true), findsOneWidget);
      await tester.tap(find.text(ProfileStrings.changePassword));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('xác thực email: gửi mã → nhập 6 số → sai báo lỗi, đúng báo thành công', (tester) async {
      await pump(tester, const SecurityScreen());
      await tester.tap(find.text(SecurityStrings.sendOtp));
      await tester.pumpAndSettle();
      expect(find.text(SecurityStrings.otpSent), findsOneWidget);
      expect(find.text(SecurityStrings.otpLabel), findsOneWidget);

      final verify = find.widgetWithText(ElevatedButton, SecurityStrings.verify);
      expect(tester.widget<ElevatedButton>(verify).onPressed, isNull); // chưa đủ 6 số
      await tester.enterText(find.byType(TextField), '111111');
      await tester.pump();
      await tester.tap(verify);
      await tester.pumpAndSettle();
      expect(find.text(AuthStrings.wrongOtp), findsOneWidget);

      await tester.enterText(find.byType(TextField), MockAuthRepository.mockOtp);
      await tester.pump();
      await tester.tap(verify);
      await tester.pumpAndSettle();
      expect(find.text(SecurityStrings.verified), findsOneWidget);
      expect(find.text(SecurityStrings.sendOtp), findsOneWidget); // quay về trạng thái ban đầu
    });

    testWidgets('đăng xuất khỏi tất cả thiết bị: hỏi xác nhận, đồng ý thì về Đăng nhập', (tester) async {
      await pump(tester, const SecurityScreen());
      await tester.tap(find.text(SecurityStrings.logoutAll));
      await tester.pumpAndSettle();
      expect(find.text(SecurityStrings.logoutAllConfirm), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, SecurityStrings.logoutAll));
      await tester.pumpAndSettle();
      tester.takeException(); // ảnh nền màn đăng nhập tải từ mạng, trong test luôn lỗi
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(SecurityStrings.loggedOutAll), findsOneWidget);
      expect(await tester.runAsync(AppRepositories.auth.getCurrentUser), isNull);
    });
  });

  group('Sân trống trong giờ rảnh', () {
    test('API: gửi limit, đọc ca; bỏ phần tử thiếu ca; môn lạ thì không đặt được', () async {
      final server = _FakeServer();
      final tokens = MemoryTokenStore();
      await tokens.write('t');
      final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
      final repo = ApiCourtRecommendationRepository(api: ApiClient(tokens: tokens, dio: dio));
      server.routes['GET ${ApiCourtRecommendationRepository.path}'] = [
        {'facilityId': 'f1', 'facilityName': 'Sân A', 'address': 'Q1', 'sportName': 'Cầu lông', 'distanceKm': 2.34,
          'courtSlotId': 's1', 'courtName': 'Sân 2', 'startTime': '2026-11-28T11:00:00Z',
          'endTime': '2026-11-28T12:00:00Z', 'price': 120000.0},
        {'facilityId': 'f2', 'facilityName': 'Thiếu ca', 'sportName': 'Cầu lông'},
        {'facilityId': 'f3', 'facilityName': 'Môn lạ', 'sportName': 'Cờ vua', 'courtSlotId': 's3',
          'startTime': '2026-11-28T11:00:00Z', 'endTime': '2026-11-28T12:00:00Z', 'price': 1},
      ];
      final items = await repo.getRecommendedCourts();
      expect(server.requests.single.queryParameters, {'limit': 6});
      expect(items.map((c) => c.courtSlotId), ['s1', 's3']);
      expect(items.first.sport, Sport.badminton);
      expect(items.first.price, 120000);
      expect(items.last.sport, isNull);
    });

    testWidgets('hiện ca gợi ý; Đặt ca giữ ca rồi mở màn thanh toán (chưa trừ Điểm)', (tester) async {
      await pump(tester, const Scaffold(body: SingleChildScrollView(child: RecommendedCourtsSection())));
      expect(find.text(HomeRecommendStrings.title), findsOneWidget);
      expect(find.text(HomeRecommendStrings.findOther), findsOneWidget);
      final before = await tester.runAsync(AppRepositories.wallet.getBalance);
      await tester.tap(find.text(HomeRecommendStrings.book).first);
      await tester.pumpAndSettle();
      expect(find.byType(BookingCheckoutScreen), findsOneWidget);
      expect(await tester.runAsync(AppRepositories.wallet.getBalance), before);
    });

    testWidgets('lỗi / không có gợi ý thì ẩn cả khối', (tester) async {
      AppRepositories.courtRecommendation = _FailingRecommendations();
      await pump(tester, const Scaffold(body: SingleChildScrollView(child: RecommendedCourtsSection())));
      expect(find.text(HomeRecommendStrings.title), findsNothing);
    });
  });

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('bố cục: Bảo mật (trước và sau khi gửi mã), khối gợi ý sân', (tester) async {
    await expectNoOverflow(tester, 'Bảo mật', () => const SecurityScreen(), interact: (t) async {
      await t.ensureVisible(find.text(SecurityStrings.sendOtp));
      await settleFrames(t);
      await t.tap(find.text(SecurityStrings.sendOtp));
      await settleFrames(t);
      expect(find.text(SecurityStrings.otpLabel), findsOneWidget);
      await scrollToEnd(t);
    });
    await expectNoOverflow(tester, 'Sân trống trong giờ rảnh',
        () => const Scaffold(body: SingleChildScrollView(child: RecommendedCourtsSection())),
        interact: scrollToEnd);
  });
}
