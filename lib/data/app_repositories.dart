import '../core/config/api_config.dart';
import 'api/api_auth_repository.dart';
import 'api/api_client.dart';
import 'api/api_facility_repository.dart';
import 'api/api_wallet_repository.dart';
import 'api/token_store.dart';
import 'mock/mock_auth_repository.dart';
import 'mock/mock_booking_repository.dart';
import 'mock/mock_facility_repository.dart';
import 'mock/mock_lfg_repository.dart';
import 'mock/mock_notification_repository.dart';
import 'mock/mock_owner_repository.dart';
import 'mock/mock_review_repository.dart';
import 'mock/mock_split_payment_repository.dart';
import 'mock/mock_tournament_repository.dart';
import 'mock/mock_wallet_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/booking_repository.dart';
import 'repositories/facility_repository.dart';
import 'repositories/lfg_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/organizer_tournament_repository.dart';
import 'repositories/owner_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/split_payment_repository.dart';
import 'repositories/tournament_repository.dart';
import 'repositories/wallet_repository.dart';

/// Nơi duy nhất quyết định UI dùng bản cài đặt nào của từng repository.
/// Đã nối API: đăng nhập / đăng ký / hồ sơ cá nhân / số dư + lịch sử ví / tìm sân + chi tiết cơ sở. Còn lại vẫn là bản giả lập, nối dần từng phần (UI giữ nguyên).
class AppRepositories {
  AppRepositories._();

  static final MockWalletRepository _mockWallet = MockWalletRepository();
  static final MockFacilityRepository _mockFacility = MockFacilityRepository();

  /// Access token + refresh token của phiên đăng nhập (Keystore / Keychain).
  static final TokenStore tokenStore = SecureTokenStore();

  /// Gọi Backend; tự gắn token. main.dart gán [ApiClient.onUnauthorized] để xử lý phiên hết hạn.
  static final ApiClient api = ApiClient(tokens: tokenStore);

  static AuthRepository auth = ApiConfig.useMockAuth
      ? MockAuthRepository()
      : ApiAuthRepository(api: api, tokens: tokenStore);
  /// Tìm sân, chi tiết cơ sở, khung giờ: dữ liệu thật (giữ chỗ / đặt sân chưa nối → báo đang phát triển).
  static FacilityRepository facility = ApiConfig.useMockAuth ? _mockFacility : ApiFacilityRepository(api: api);

  /// Sân mà luồng tạo kèo LFG (chưa nối API) tìm, xem khung giờ và giữ chỗ. Tạm là sân giả lập;
  /// chuyển sang [facility] khi nối LFG.
  static FacilityRepository lfgFacility = _mockFacility;

  /// Ví người chơi: số dư + lịch sử giao dịch thật (nạp / rút BE chưa có → báo đang phát triển).
  static WalletRepository wallet = ApiConfig.useMockAuth ? _mockWallet : ApiWalletRepository(api: api);

  /// Ví mà các luồng chưa nối API (đặt sân, chia tiền, LFG, giải đấu) kiểm tra số dư / trừ tiền / nạp thêm.
  /// Tạm là ví giả lập nên có thể lệch với số dư thật; chuyển sang [wallet] khi nối từng luồng.
  static WalletRepository paymentWallet = _mockWallet;
  static ReviewRepository review = MockReviewRepository();
  static NotificationRepository notification = MockNotificationRepository();

  /// Ví Chủ sân. Bản giả lập tách riêng với ví người chơi trên cùng máy;
  /// khi nối API dùng cùng WalletRepository (BE trả ví theo tài khoản đăng nhập).
  static final MockWalletRepository _mockOwnerWallet =
      MockWalletRepository(keyPrefix: MockOwnerRepository.ownerWalletPrefix, initialBalance: 3200000);
  static WalletRepository ownerWallet = _mockOwnerWallet;

  /// Phía Chủ sân: cơ sở, lượt sân, check-in / check-out, doanh thu & phí. Giải ngân vào ví Chủ sân.
  static final MockOwnerRepository _mockOwner = MockOwnerRepository(wallet: _mockOwnerWallet);
  static OwnerRepository owner = _mockOwner;

  /// Bản giả lập LFG trừ/hoàn cọc qua cùng ví giả lập ở trên.
  static LfgRepository lfg = MockLfgRepository(wallet: _mockWallet);

  /// Lệ phí giải đấu trừ/hoàn qua cùng ví giả lập. Cùng một kho cho người chơi và Chủ sân tổ chức giải.
  static final MockTournamentRepository _mockTournament = MockTournamentRepository(wallet: _mockWallet, owner: _mockOwner);
  static TournamentRepository tournament = _mockTournament;

  /// Chủ sân tạo / quản lý giải; tạm đóng sân và giải ngân lệ phí qua bản giả lập Chủ sân.
  static OrganizerTournamentRepository organizer = _mockTournament;

  static final MockBookingRepository _mockBookings = MockBookingRepository(facility: _mockFacility, wallet: _mockWallet);

  /// Đặt sân giữ khung giờ qua bản giả lập sân, trừ/hoàn qua ví giả lập.
  static BookingRepository booking = _mockBookings;

  /// Chia tiền giữ khung giờ qua cùng bản giả lập sân; đủ tiền thì tạo lần đặt sân.
  static SplitPaymentRepository split =
      MockSplitPaymentRepository(facility: _mockFacility, wallet: _mockWallet, bookings: _mockBookings);
}
