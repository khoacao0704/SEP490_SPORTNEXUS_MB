import '../core/config/api_config.dart';
import '../models/sport.dart';
import 'api/api_ai_chat_repository.dart';
import 'api/api_auth_repository.dart';
import 'api/api_booking_repository.dart';
import 'api/api_client.dart';
import 'api/api_facility_repository.dart';
import 'api/api_identity_repository.dart';
import 'api/api_lfg_repository.dart';
import 'api/api_notification_repository.dart';
import 'api/api_player_tournament_repository.dart';
import 'api/api_review_repository.dart';
import 'api/api_team_repository.dart';
import 'api/api_voucher_repository.dart';
import 'api/api_wallet_repository.dart';
import 'api/notification_hub.dart';
import 'api/token_store.dart';
import 'api/api_owner_repository.dart';
import 'api/api_player_profile_repository.dart';
import 'api/api_rating_repository.dart';
import 'api/api_report_repository.dart';
import 'api/api_player_shop_repository.dart';
import 'api/api_court_recommendation_repository.dart';
import 'api/api_community_repository.dart';
import 'api/api_host_tournament_repository.dart';
import 'mock/mock_host_tournament_repository.dart';
import 'repositories/host_tournament_repository.dart';
import 'mock/mock_community_repository.dart';
import 'repositories/community_repository.dart';
import 'mock/mock_court_recommendation_repository.dart';
import 'repositories/court_recommendation_repository.dart';
import 'mock/mock_player_shop_repository.dart';
import 'repositories/player_shop_repository.dart';
import 'mock/mock_report_repository.dart';
import 'repositories/report_repository.dart';
import 'push/push_platform.dart';
import 'push/push_service.dart';
import 'mock/mock_ai_chat_repository.dart';
import 'mock/mock_auth_repository.dart';
import 'mock/mock_booking_repository.dart';
import 'mock/mock_facility_repository.dart';
import 'mock/mock_identity_repository.dart';
import 'mock/mock_lfg_repository.dart';
import 'mock/mock_notification_repository.dart';
import 'mock/mock_owner_repository.dart';
import 'mock/mock_player_profile_repository.dart';
import 'mock/mock_rating_repository.dart';
import 'mock/mock_player_tournament_repository.dart';
import 'mock/mock_review_repository.dart';
import 'mock/mock_split_payment_repository.dart';
import 'mock/mock_team_repository.dart';
import 'mock/mock_tournament_repository.dart';
import 'mock/mock_voucher_repository.dart';
import 'mock/mock_wallet_repository.dart';
import 'repositories/ai_chat_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/booking_repository.dart';
import 'repositories/facility_repository.dart';
import 'repositories/identity_repository.dart';
import 'repositories/lfg_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/organizer_tournament_repository.dart';
import 'repositories/owner_repository.dart';
import 'repositories/player_profile_repository.dart';
import 'repositories/rating_repository.dart';
import 'repositories/player_tournament_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/split_payment_repository.dart';
import 'repositories/team_repository.dart';
import 'repositories/tournament_repository.dart';
import 'repositories/voucher_repository.dart';
import 'repositories/wallet_repository.dart';

/// Nơi duy nhất quyết định UI dùng bản cài đặt nào của từng repository.
/// Đã nối API: đăng nhập / đăng ký / hồ sơ cá nhân / ví / tìm sân + chi tiết cơ sở / đặt sân thường + chia Điểm / LFG / thông báo / đánh giá + Fair Play / giải đấu + đội / AI chat. Còn lại vẫn là bản giả lập, nối dần từng phần (UI giữ nguyên).
class AppRepositories {
  AppRepositories._();

  static final MockWalletRepository _mockWallet = MockWalletRepository();
  static final MockFacilityRepository _mockFacility = MockFacilityRepository();

  /// Access token + refresh token của phiên đăng nhập (Keystore / Keychain).
  static final TokenStore tokenStore = SecureTokenStore();

  /// Gọi Backend; tự gắn token. main.dart gán [ApiClient.onUnauthorized] để xử lý phiên hết hạn.
  static final ApiClient api = ApiClient(tokens: tokenStore);

  /// Thông báo đẩy FCM (chỉ người chơi). main.dart gọi [PushService.start]; chưa start thì không làm gì.
  static PushService push =
      ApiConfig.useMockAuth ? PushService.disabled() : PushService(api: api, platform: FcmPushPlatform());

  static AuthRepository auth = ApiConfig.useMockAuth
      ? MockAuthRepository()
      : ApiAuthRepository(api: api, tokens: tokenStore, push: push);
  /// Tìm sân, chi tiết cơ sở, khung giờ: dữ liệu thật (giữ chỗ 10 phút đếm trên máy, BE chưa có API giữ chỗ).
  static FacilityRepository facility = ApiConfig.useMockAuth ? _mockFacility : _apiFacility;
  static final ApiFacilityRepository _apiFacility = ApiFacilityRepository(api: api);

  /// Sân mà luồng tạo kèo LFG tìm, xem khung giờ và giữ chỗ (cùng dữ liệu với [facility]).
  static FacilityRepository lfgFacility = ApiConfig.useMockAuth ? _mockFacility : _apiFacility;

  /// Ví người chơi: số dư, lịch sử, nạp Điểm PayOS, đổi Điểm ra tiền (BE 27/11/2026: Player rút được khi eKYC đã
  /// duyệt, tối thiểu 200.000, phí 5.000 trừ vào số rút; điều kiện đọc từ GET /wallet/withdrawals/config).
  static WalletRepository wallet = ApiConfig.useMockAuth ? _mockWallet : ApiWalletRepository(api: api);

  /// Xác minh danh tính eKYC (chụp CCCD + chân dung), dữ liệu thật; dùng chung Owner và Player.
  static IdentityRepository identity =
      ApiConfig.useMockAuth ? MockIdentityRepository() : ApiIdentityRepository(api: api);

  /// Khiếu nại đơn đặt sân / báo cáo người chơi phía Player (dữ liệu thật).
  static ReportRepository report = ApiConfig.useMockAuth ? MockReportRepository() : ApiReportRepository(api: api);

  /// Shop tại sân phía người chơi + lịch sử check-in (dữ liệu thật; cùng một lớp API).
  static final ApiPlayerShopRepository _apiPlayerShop = ApiPlayerShopRepository(api: api);
  static final MockPlayerShopRepository _mockPlayerShop = MockPlayerShopRepository();
  static PlayerShopRepository playerShop = ApiConfig.useMockAuth ? _mockPlayerShop : _apiPlayerShop;
  static CheckInHistoryRepository checkInHistory = ApiConfig.useMockAuth ? _mockPlayerShop : _apiPlayerShop;

  /// Bảng tin cộng đồng (dữ liệu thật).
  static CommunityRepository community = ApiConfig.useMockAuth
      ? MockCommunityRepository(lfg: () => lfg)
      : ApiCommunityRepository(api: api, facility: _apiFacility);

  /// Ca sân trống trong giờ rảnh (Trang chủ, dữ liệu thật).
  static CourtRecommendationRepository courtRecommendation = ApiConfig.useMockAuth
      ? MockCourtRecommendationRepository(facility: _mockFacility)
      : ApiCourtRecommendationRepository(api: api);

  /// Mã giảm giá của người chơi (chỉ xem, dữ liệu thật).
  static VoucherRepository voucher = ApiConfig.useMockAuth ? MockVoucherRepository() : ApiVoucherRepository(api: api);

  /// Ví mà các luồng chưa nối API (chia Điểm, LFG, giải đấu) kiểm tra số dư / trừ Điểm / nạp thêm.
  /// Tạm là ví giả lập nên có thể lệch với số dư thật; chuyển sang [wallet] khi nối từng luồng.
  static WalletRepository paymentWallet = _mockWallet;

  /// Ví màn thanh toán đặt sân kiểm tra số dư / nạp thêm: ví thật (BE trừ Điểm khi tạo đơn).
  static WalletRepository bookingWallet = ApiConfig.useMockAuth ? _mockWallet : wallet;
  /// Đánh giá cơ sở, chấm người chơi cùng trận, Fair Play: dữ liệu thật.
  /// Giải đấu phía người chơi (dữ liệu thật). [tournament] bên dưới vẫn là bản giả lập dùng chung với phần Chủ sân.
  /// Tổ chức giải (giải 1 tầng): người chơi làm Ban tổ chức (dữ liệu thật).
  static HostTournamentRepository hostTournament = ApiConfig.useMockAuth
      ? MockHostTournamentRepository()
      : ApiHostTournamentRepository(api: api);

  static PlayerTournamentRepository playerTournament = ApiConfig.useMockAuth
      ? MockPlayerTournamentRepository(teams: _mockTeams)
      : ApiPlayerTournamentRepository(api: api, facility: _apiFacility);

  /// Đội của người chơi (dữ liệu thật).
  static TeamRepository team =
      ApiConfig.useMockAuth ? _mockTeams : ApiTeamRepository(api: api, categoryIdOf: _apiFacility.categoryIdOf);
  static final MockTeamRepository _mockTeams = MockTeamRepository();

  /// Elo theo môn, bảng xếp hạng, khảo sát trình độ.
  static RatingRepository rating = ApiConfig.useMockAuth
      ? MockRatingRepository()
      : ApiRatingRepository(api: api, categoryIdOf: _apiFacility.categoryIdOf, sportOf: _apiFacility.sportOfCategory);

  /// Môn của app ứng với categoryId của BE (mã lỗi RATING_REQUIRED chỉ trả categoryId).
  static Future<Sport?> Function(String categoryId) sportOfCategory =
      ApiConfig.useMockAuth ? mockSportOfCategory : _apiFacility.sportOfCategory;

  /// Bản giả lập dùng categoryId dạng `mock-<môn>`.
  static Future<Sport?> mockSportOfCategory(String categoryId) async =>
      Sport.values.where((s) => categoryId == 'mock-${s.name}').firstOrNull;

  /// Khảo sát người chơi / hồ sơ thể thao (bắt buộc trước khi vào app).
  static PlayerProfileRepository playerProfile = ApiConfig.useMockAuth
      ? MockPlayerProfileRepository()
      : ApiPlayerProfileRepository(
          api: api,
          categoryIdOf: _apiFacility.categoryIdOf,
          sportOf: _apiFacility.sportOfCategory,
        );

  /// Trợ lý AI (Gemini qua BE): chỉ gợi ý sân / kèo, không tự đặt.
  static AiChatRepository aiChat = ApiConfig.useMockAuth
      ? MockAiChatRepository(facility: _mockFacility)
      : ApiAiChatRepository(api: api);

  static ReviewRepository review = ApiConfig.useMockAuth ? MockReviewRepository() : ApiReviewRepository(api: api);
  /// Thông báo: dữ liệu thật + realtime SignalR (push FCM ở [push]).
  static NotificationRepository notification = ApiConfig.useMockAuth
      ? MockNotificationRepository()
      : ApiNotificationRepository(api: api, realtime: SignalRNotificationRealtime(tokens: tokenStore, api: api));

  /// Ví Chủ sân. Bản giả lập tách riêng với ví người chơi trên cùng máy;
  /// khi nối API dùng cùng WalletRepository (BE trả ví theo tài khoản đăng nhập).
  static final MockWalletRepository _mockOwnerWallet =
      MockWalletRepository(keyPrefix: MockOwnerRepository.ownerWalletPrefix, initialBalance: 3200000);
  static WalletRepository ownerWallet = _mockOwnerWallet;

  /// Phía Chủ sân — đã nối API cho danh sách cơ sở.
  static final MockOwnerRepository _mockOwner = MockOwnerRepository(wallet: _mockOwnerWallet);
  static OwnerRepository owner = ApiOwnerRepository(api);

// Nếu cần quay lại mock nhanh khi debug:
// static OwnerRepository owner = _mockOwner;

  /// Ghép kèo LFG: dữ liệu thật (trừ / hoàn qua ví thật).
  static LfgRepository lfg = ApiConfig.useMockAuth
      ? MockLfgRepository(wallet: _mockWallet)
      : ApiLfgRepository(api: api, facility: _apiFacility);

  /// Ví màn thanh toán LFG kiểm tra số dư / nạp thêm: ví thật (BE trừ Điểm khi tạo / vào kèo).
  static WalletRepository lfgWallet = ApiConfig.useMockAuth ? _mockWallet : wallet;

  /// Lệ phí giải đấu trừ/hoàn qua cùng ví giả lập. Cùng một kho cho người chơi và Chủ sân tổ chức giải.
  static final MockTournamentRepository _mockTournament = MockTournamentRepository(wallet: _mockWallet, owner: _mockOwner);
  static TournamentRepository tournament = _mockTournament;

  /// Chủ sân tạo / quản lý giải; tạm đóng sân và giải ngân lệ phí qua bản giả lập Chủ sân.
  static OrganizerTournamentRepository organizer = _mockTournament;

  static final MockBookingRepository _mockBookings = MockBookingRepository(facility: _mockFacility, wallet: _mockWallet);

  /// Đặt sân thường: dữ liệu thật (trừ / hoàn qua ví thật). Chia Điểm nhóm vẫn là bản giả lập.
  static BookingRepository booking = ApiConfig.useMockAuth ? _mockBookings : ApiBookingRepository(api: api);

  /// Chia Điểm giữ khung giờ qua cùng bản giả lập sân; đủ Điểm thì tạo lần đặt sân.
  static SplitPaymentRepository split =
      MockSplitPaymentRepository(facility: _mockFacility, wallet: _mockWallet, bookings: _mockBookings);
}
