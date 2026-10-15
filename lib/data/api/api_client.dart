import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../core/strings/api_strings.dart';
import 'token_store.dart';

/// Lỗi khi gọi Backend; [message] đã sẵn sàng để hiển thị.
class ApiException implements Exception {
  /// Mã HTTP (hoặc statusCode trong body); `null` khi không tới được server.
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Gọi Backend SportNexus.
///
/// - BE bọc kết quả dạng {"statusCode", "message", "data"}: hàm gọi trả về phần `data`.
/// - Tự gắn `Authorization: Bearer <token>`; request có token mà bị 401 thì gọi [onUnauthorized]
///   (phiên hết hạn sau 7 ngày, BE không có refresh token).
/// - Mọi lỗi (mạng, hết giờ, lỗi BE) đều thành [ApiException].
class ApiClient {
  final Dio _dio;
  final TokenStore _tokens;

  /// Gọi khi phiên đăng nhập hết hạn (app đăng xuất và về màn đăng nhập).
  void Function()? onUnauthorized;

  ApiClient({required this._tokens, Dio? dio, this.onUnauthorized})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
              // Tự xử lý mọi mã lỗi trong _unwrap để đọc được message của BE.
              validateStatus: (_) => true,
            ),
          );

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) => _send('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body, bool auth = true}) => _send('PUT', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = true}) => _send('DELETE', path, auth: auth);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    required bool auth,
  }) async {
    final token = auth ? await _tokens.read() : null;
    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: {'Authorization': ?(token == null ? null : 'Bearer $token')}),
      );
    } on DioException catch (e) {
      throw _networkError(e);
    }
    return _unwrap(response, sentToken: token != null);
  }

  dynamic _unwrap(Response<dynamic> response, {required bool sentToken}) {
    final status = response.statusCode ?? 0;
    final body = response.data;
    final envelope = body is Map<String, dynamic> && body.containsKey('statusCode') ? body : null;
    final code = (envelope?['statusCode'] as num?)?.toInt() ?? status;

    if (status >= 200 && status < 300 && code < 400) {
      return envelope != null ? envelope['data'] : body;
    }
    if (code == 401 && sentToken) onUnauthorized?.call();
    throw ApiException(_errorMessage(body, code), statusCode: code);
  }

  /// Lấy câu lỗi của BE: {"message"} hoặc ProblemDetails {"errors": {field: [..]}}; không có thì theo mã HTTP.
  static String _errorMessage(dynamic body, int code) {
    if (body is Map<String, dynamic>) {
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
    }
    return switch (code) {
      401 => ApiStrings.unauthorized,
      403 => ApiStrings.forbidden,
      404 => ApiStrings.notFound,
      >= 500 => ApiStrings.server,
      _ => ApiStrings.unknown,
    };
  }

  static ApiException _networkError(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const ApiException(ApiStrings.timeout),
    DioExceptionType.connectionError => const ApiException(ApiStrings.noConnection),
    _ => const ApiException(ApiStrings.unknown),
  };
}
