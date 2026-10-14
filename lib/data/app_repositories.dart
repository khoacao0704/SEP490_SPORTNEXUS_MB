import 'mock/mock_auth_repository.dart';
import 'mock/mock_facility_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/facility_repository.dart';

/// Nơi duy nhất quyết định UI dùng bản cài đặt nào của từng repository.
/// Khi nối Swagger: đổi `Mock...Repository()` thành bản gọi API, UI giữ nguyên.
class AppRepositories {
  AppRepositories._();

  static AuthRepository auth = MockAuthRepository();
  static FacilityRepository facility = MockFacilityRepository();
}
