// Kiểm bố cục MỌI màn phía người chơi còn dùng (ngoài các màn đã có trong responsive_layout_test.dart;
// bỏ các màn cũ không còn mở tới: CommunityScreen, CreateLfgScreen, FlashClaimCheckoutScreen, LfgCheckoutScreen, CourtBookingScreen)
// trên nhiều cỡ máy + cỡ chữ phóng to: không được tràn chữ.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/services/location_service.dart';
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
import 'package:test1/data/mock/mock_split_payment_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/repositories/auth_repository.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/bank_account.dart';
import 'package:test1/models/booking.dart';
import 'package:test1/models/facility_search.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/user_role.dart';
import 'package:test1/screens/ai_chat/ai_chat_screen.dart';
import 'package:test1/screens/ai_chat/ai_sessions_screen.dart';
import 'package:test1/screens/auth/add_phone_screen.dart';
import 'package:test1/screens/auth/forgot_password_screen.dart';
import 'package:test1/screens/auth/login_screen.dart';
import 'package:test1/screens/auth/otp_verification_screen.dart';
import 'package:test1/screens/auth/owner_pending_screen.dart';
import 'package:test1/screens/auth/register_screen.dart';
import 'package:test1/screens/auth/reset_password_screen.dart';
import 'package:test1/screens/booking/booking_checkout_screen.dart';
import 'package:test1/screens/booking/my_bookings_screen.dart';
import 'package:test1/screens/booking/split_booking_screen.dart';
import 'package:test1/screens/booking/split_payment_screen.dart';
import 'package:test1/screens/booking/split_payments_screen.dart';
import 'package:test1/screens/facility/facility_detail_screen.dart';
import 'package:test1/screens/facility/facility_search_screen.dart';
import 'package:test1/screens/fair_play/fair_play_screen.dart';
import 'package:test1/screens/lfg/lfg_payment_screen.dart';
import 'package:test1/screens/lfg/lfg_screen.dart';
import 'package:test1/screens/main/main_navigation_screen.dart';
import 'package:test1/screens/notification/notification_settings_screen.dart';
import 'package:test1/screens/notification/notifications_screen.dart';
import 'package:test1/screens/profile/change_password_screen.dart';
import 'package:test1/screens/profile/top_up_wallet_screen.dart';
import 'package:test1/screens/review/facility_reviews_screen.dart';
import 'package:test1/screens/review/my_reviews_screen.dart';
import 'package:test1/screens/review/pending_reviews_screen.dart';
import 'package:test1/screens/review/write_facility_review_screen.dart';
import 'package:test1/screens/team/my_teams_screen.dart';
import 'package:test1/screens/tournament/tournament_detail_screen.dart';
import 'package:test1/screens/tournament/tournament_register_screen.dart';
import 'package:test1/screens/tournament/tournament_ticket_screen.dart';
import 'package:test1/screens/tournament/tournaments_screen.dart';
import 'package:test1/screens/wallet/add_bank_account_screen.dart';
import 'package:test1/screens/wallet/transaction_history_screen.dart';
import 'package:test1/screens/wallet/vietqr_payment_screen.dart';
import 'package:test1/screens/wallet/withdraw_screen.dart';

import '../helpers/layout_check.dart';

/// Test không có GPS: coi như không lấy được vị trí.
class _NoLocation extends LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> getCurrentLocation() async => const LocationResult(LocationStatus.unavailable);
}

void main() {
  late MockWalletRepository wallet;
  late MockFacilityRepository facility;
  late MockBookingRepository booking;
  late MockSplitPaymentRepository split;
  late MockPlayerTournamentRepository tournaments;
  late MockReviewRepository review;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wallet = MockWalletRepository(latency: Duration.zero);
    facility = MockFacilityRepository(latency: Duration.zero);
    review = MockReviewRepository(latency: Duration.zero);
    final teams = MockTeamRepository(latency: Duration.zero);
    booking = MockBookingRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    split = MockSplitPaymentRepository(facility: facility, latency: Duration.zero, wallet: wallet);
    tournaments = MockPlayerTournamentRepository(teams: teams, latency: Duration.zero);
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.wallet = AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.lfgWallet = wallet;
    AppRepositories.facility = AppRepositories.lfgFacility = facility;
    AppRepositories.booking = booking;
    AppRepositories.split = split;
    AppRepositories.review = review;
    AppRepositories.team = teams;
    AppRepositories.lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    AppRepositories.notification = MockNotificationRepository(latency: Duration.zero);
    AppRepositories.aiChat = MockAiChatRepository(facility: facility, latency: Duration.zero);
    AppRepositories.rating = MockRatingRepository();
    AppRepositories.playerProfile = MockPlayerProfileRepository();
    AppRepositories.playerTournament = tournaments;
    AppRepositories.sportOfCategory = AppRepositories.mockSportOfCategory;
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  /// Kiểm nhiều màn trong một test, báo gộp mọi lỗi.
  Future<void> checkAll(WidgetTester tester, Map<String, Widget Function()> screens) async {
    final problems = <String>[];
    for (final entry in screens.entries) {
      problems.addAll(await collectLayoutProblems(tester, entry.key, entry.value));
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  }

  testWidgets('Đăng nhập / đăng ký / OTP / quên mật khẩu', (tester) async {
    final owner = const AppUser(id: 'o', fullName: 'Chủ Sân Có Tên Rất Dài Ơi Là Dài', email: 'o@x.vn', phone: '09', role: UserRole.courtOwner);
    await checkAll(tester, {
      'Đăng nhập': () => const LoginScreen(),
      'Đăng ký': () => const RegisterScreen(),
      'Quên mật khẩu': () => const ForgotPasswordScreen(),
      'OTP': () => const OtpVerificationScreen(phone: '0901234567', purpose: OtpPurpose.register, devOtp: '123456'),
      'Đặt lại mật khẩu': () => const ResetPasswordScreen(phone: '0901234567', resetToken: 't'),
      'Thêm SĐT': () => const AddPhoneScreen(),
      'Chủ sân chờ duyệt': () => OwnerPendingScreen(user: owner),
    });
  });

  testWidgets('Trang chủ + thanh điều hướng, thông báo', (tester) async {
    await checkAll(tester, {
      'Trang chủ': () => const MainNavigationScreen(),
      'Thông báo': () => const NotificationsScreen(),
      'Cài đặt thông báo': () => const NotificationSettingsScreen(),
    });
  });

  testWidgets('Tìm sân, chi tiết sân, đánh giá sân', (tester) async {
    final f = (await tester.runAsync(
      () => facility.searchFacilities(const FacilitySearchQuery(city: 'Hồ Chí Minh', sport: Sport.badminton)),
    ))!.first.facility;
    await checkAll(tester, {
      'Tìm sân': () => const FacilitySearchScreen(locationService: _NoLocation()),
      'Chi tiết sân': () => FacilityDetailScreen(facility: f, distanceKm: 12.4, initialSport: Sport.badminton),
      'Đánh giá sân': () => FacilityReviewsScreen(facilityId: f.id, facilityName: f.name),
      'Viết đánh giá sân': () => WriteFacilityReviewScreen(facilityId: f.id, facilityName: f.name),
    });
  });

  testWidgets('Đặt sân, lịch đặt, chia tiền', (tester) async {
    final bookings = (await tester.runAsync(booking.getMyBookings))!;
    final splitBooking = bookings.where((b) => b.paymentType == BookingPaymentType.split).firstOrNull;
    final splits = (await tester.runAsync(split.getMine))!;
    await checkAll(tester, {
      'Thanh toán đặt sân': () => const BookingCheckoutScreen(
        sport: 'Cầu Lông',
        courtName: 'Trung Tâm Thể Thao Phú Thọ Quận 11 • Sân số 12',
        location: '1 Lữ Gia, Phường 15, Quận 11, TP. Hồ Chí Minh',
        dateTime: 'Thứ Bảy, 20/12/2026 • 18:00 – 20:00',
        totalAmount: 1250000,
      ),
      'Lịch đặt': () => const MyBookingsScreen(),
      'Lịch đặt (đã qua)': () => const MyBookingsScreen(initialTab: 1),
      'Chia tiền sân': () => const SplitPaymentsScreen(),
      if (splitBooking != null) 'Đơn chia tiền': () => SplitBookingScreen(bookingId: splitBooking.id),
      if (splits.isNotEmpty) 'Góp tiền': () => SplitPaymentScreen(splitId: splits.first.id),
    });
  });

  testWidgets('Ví: nạp, VietQR, rút, ngân hàng, lịch sử', (tester) async {
    await checkAll(tester, {
      'Nạp tiền': () => const TopUpWalletScreen(),
      'VietQR': () => VietQrPaymentScreen(
        order: TopUpOrder(
          transactionId: 'NAP-202612201800-ABCDEF',
          amount: 25000000,
          transferContent: 'SPN NAP 202612201800 ABCDEF',
          receiverBankName: 'Ngân hàng TMCP Ngoại thương Việt Nam (Vietcombank)',
          receiverAccountNumber: '0123456789012',
          receiverAccountName: 'CONG TY CO PHAN SPORTNEXUS VIET NAM',
          qrData: '00020101021238570010A000000727',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
        wallet: wallet,
      ),
      'Rút tiền': () => WithdrawScreen(wallet: wallet),
      'Thêm ngân hàng': () => AddBankAccountScreen(wallet: wallet),
      'Lịch sử giao dịch': () => TransactionHistoryScreen(wallet: wallet),
      'Đổi mật khẩu': () => const ChangePasswordScreen(),
    });
  });

  testWidgets('LFG: thanh toán, kèo của tôi', (tester) async {
    await checkAll(tester, {
      'Thanh toán kèo': () => LfgPaymentScreen(
        summary: LfgPaymentSummary(
          heading: 'Tạo kèo',
          sport: Sport.football,
          format: LfgFormat.teamVsTeam,
          facilityName: 'Sân Bóng Đá Mini Hoa Lư Quận 1 • Sân số 12',
          district: 'Quận 1, TP. Hồ Chí Minh',
          start: DateTime(2026, 12, 20, 18),
          end: DateTime(2026, 12, 20, 20),
        ),
        amount: 1250000,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        onConfirm: () async => throw UnimplementedError(),
        onRelease: () async {},
      ),
      'Kèo của tôi': () => const MyLfgMatchesScreen(),
      'Bảng tin LFG (tab Kèo của tôi)': () => const LfgScreen(initialTab: 1),
    });
  });

  testWidgets('Đánh giá, Fair Play, đội', (tester) async {
    await checkAll(tester, {
      'Chờ đánh giá': () => const PendingReviewsScreen(),
      'Đánh giá của tôi': () => const MyReviewsScreen(),
      'Fair Play': () => const FairPlayScreen(),
      'Đội của tôi': () => const MyTeamsScreen(),
    });
  });

  testWidgets('Giải đấu: danh sách 3 tab, chi tiết, đăng ký, vé', (tester) async {
    final details = (await tester.runAsync(() => tournaments.getDetails('pt-pickle-q7')))!;
    await checkAll(tester, {
      'Giải đấu – Khám phá': () => const TournamentsScreen(),
      'Giải đấu – Đã đăng ký': () => const TournamentsScreen(initialTab: 1),
      'Giải đấu – Lịch đấu': () => const TournamentsScreen(initialTab: 2),
      'Chi tiết giải': () => const TournamentDetailScreen(tournamentId: 'pt-pickle-q7'),
      'Đăng ký giải (đơn)': () => TournamentRegisterScreen(details: details, division: details.divisions.first),
      'Đăng ký giải (đội)': () => TournamentRegisterScreen(details: details, division: details.divisions[1]),
      'Vé giải': () => const TournamentTicketScreen(divisionId: 'pd-bm-singles'),
    });
  });

  testWidgets('Trợ lý AI', (tester) async {
    await checkAll(tester, {
      'AI chat': () => const AiChatScreen(useLocation: false),
      'Lịch sử AI': () => const AiSessionsScreen(),
    });
  });
}
