import 'mock/mock_auth_repository.dart';
import 'mock/mock_facility_repository.dart';
import 'mock/mock_lfg_repository.dart';
import 'mock/mock_notification_repository.dart';
import 'mock/mock_review_repository.dart';
import 'mock/mock_tournament_repository.dart';
import 'mock/mock_wallet_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/facility_repository.dart';
import 'repositories/lfg_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/tournament_repository.dart';
import 'repositories/wallet_repository.dart';

/// Nơi duy nhất quyết định UI dùng bản cài đặt nào của từng repository.
/// Khi nối Swagger: đổi `Mock...Repository()` thành bản gọi API, UI giữ nguyên.
class AppRepositories {
  AppRepositories._();

  static final MockWalletRepository _mockWallet = MockWalletRepository();

  static AuthRepository auth = MockAuthRepository();
  static FacilityRepository facility = MockFacilityRepository();
  static WalletRepository wallet = _mockWallet;
  static ReviewRepository review = MockReviewRepository();
  static NotificationRepository notification = MockNotificationRepository();

  /// Bản giả lập LFG trừ/hoàn cọc qua cùng ví giả lập ở trên.
  static LfgRepository lfg = MockLfgRepository(wallet: _mockWallet);

  /// Lệ phí giải đấu trừ/hoàn qua cùng ví giả lập.
  static TournamentRepository tournament = MockTournamentRepository(wallet: _mockWallet);
}
