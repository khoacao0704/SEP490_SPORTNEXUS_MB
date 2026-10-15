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

  /// `true`: đăng nhập / đăng ký dùng dữ liệu giả như trước khi nối API.
  static const bool useMockAuth = bool.fromEnvironment('USE_MOCK_AUTH');
}
