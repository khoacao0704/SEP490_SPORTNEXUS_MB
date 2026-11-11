import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_ai_chat_repository.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_booking_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_notification_repository.dart';
import 'package:test1/data/mock/mock_player_profile_repository.dart';
import 'package:test1/data/mock/mock_player_tournament_repository.dart';
import 'package:test1/data/mock/mock_rating_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/push/push_platform.dart';
import 'package:test1/data/push/push_service.dart';
import 'package:test1/screens/main/main_navigation_screen.dart';
import 'package:test1/screens/team/my_teams_screen.dart';
import 'package:test1/screens/wallet/transaction_history_screen.dart';

import '../helpers/fake_push_platform.dart';

PushMessage _push(String referenceType, {String referenceId = ''}) => PushMessage(
      title: 'Thông báo',
      body: 'Nội dung',
      data: {'notificationId': 'n-1', 'type': 'WALLET', 'referenceType': referenceType, 'referenceId': referenceId},
    );

void main() {
  late FakePushPlatform platform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    final facility = MockFacilityRepository(latency: Duration.zero);
    final review = MockReviewRepository(latency: Duration.zero);
    final teams = MockTeamRepository(latency: Duration.zero);
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.wallet = AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.lfgWallet = wallet;
    AppRepositories.facility = AppRepositories.lfgFacility = facility;
    AppRepositories.booking = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    AppRepositories.review = review;
    AppRepositories.team = teams;
    AppRepositories.lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    AppRepositories.notification = MockNotificationRepository(latency: Duration.zero);
    AppRepositories.aiChat = MockAiChatRepository(facility: facility, latency: Duration.zero);
    AppRepositories.rating = MockRatingRepository();
    AppRepositories.playerProfile = MockPlayerProfileRepository();
    AppRepositories.playerTournament = MockPlayerTournamentRepository(teams: teams, latency: Duration.zero);
    AppRepositories.sportOfCategory = AppRepositories.mockSportOfCategory;
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');

    platform = FakePushPlatform();
    // BE giả không có route: đăng ký token lỗi 404 và được bỏ qua, việc mở màn không phụ thuộc.
    AppRepositories.push = PushService(api: ApiClient(tokens: MemoryTokenStore()), platform: platform);
  });

  /// Dựng màn chính rồi chạy [body]. Trang chủ tải ảnh mạng (test không có mạng): bỏ qua lỗi ảnh, giữ lỗi khác.
  Future<void> withMainScreen(WidgetTester tester, Future<void> Function() body) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      previous?.call(details);
    };
    try {
      await tester.runAsync(() => AppRepositories.push.start());
      await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
      await settle(tester);
      await body();
    } finally {
      FlutterError.onError = previous;
    }
  }

  testWidgets('bấm thông báo đẩy khi app đang chạy: mở đúng màn', (tester) async {
    await withMainScreen(tester, () async {
      // Firebase giả được nghe trong vùng async thật (start chạy bằng runAsync).
      await tester.runAsync(() async {
        platform.openedApp.add(_push('WALLET', referenceId: 'deposit-1'));
        await Future<void>.delayed(Duration.zero);
      });
      await settle(tester);
      expect(find.byType(TransactionHistoryScreen), findsOneWidget);
    });
  });

  testWidgets('mở app từ thông báo khi app đang tắt: màn chính mở luôn màn liên quan', (tester) async {
    platform.initialMessage = _push('TEAM_INVITATION', referenceId: 'inv-1');
    await withMainScreen(tester, () async {
      expect(find.byType(MyTeamsScreen), findsOneWidget);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
