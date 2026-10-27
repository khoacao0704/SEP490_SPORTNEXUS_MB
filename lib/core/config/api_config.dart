/// Cấu hình kết nối Backend.
///
/// Đổi khi chạy bằng --dart-define, ví dụ:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
///   flutter run --dart-define=USE_MOCK_AUTH=true   (đăng nhập bằng dữ liệu giả, không cần mạng)
class ApiConfig {
  ApiConfig._();

  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://sep490-sportnexus-be.onrender.com');

  /// Server Render gói miễn phí ngủ khi không ai dùng; lần gọi đầu có thể mất gần 1 phút.
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// Web Client ID (OAuth client type 3 trong google-services.json): Google ký idToken cho client này
  /// và BE kiểm tra token theo đúng ID đó.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '427346774153-gssv9kie90n28i719e28ia0ar6gjq295.apps.googleusercontent.com',
  );

  /// `true`: đăng nhập / đăng ký dùng dữ liệu giả như trước khi nối API.
  static const bool useMockAuth = bool.fromEnvironment('USE_MOCK_AUTH');
}
