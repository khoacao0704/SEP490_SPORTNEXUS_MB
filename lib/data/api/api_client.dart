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
/// - Tự gắn `Authorization: Bearer <token>`. Request có token mà bị 401 thì thử refresh token
///   một lần rồi gửi lại; refresh không được (hết hạn / bị thu hồi / tài khoản bị khóa) thì gọi [onUnauthorized].
/// - Mọi lỗi (mạng, hết giờ, lỗi BE) đều thành [ApiException].
class ApiClient {
  static const String refreshPath = '/api/auth/refresh-token';

  final Dio _dio;
  final TokenStore _tokens;

  /// Gọi khi phiên đăng nhập hết hạn (app đăng xuất và về màn đăng nhập).
  void Function()? onUnauthorized;

  /// Lượt refresh đang chạy: nhiều request cùng bị 401 thì dùng chung một lượt.
  Future<bool>? _refreshing;

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

  /// [refreshOnUnauthorized] = false: bị 401 thì chỉ báo lỗi, không refresh và không gọi [onUnauthorized]
  /// (vd. đăng xuất bằng token có thể đã bị thu hồi).
  Future<dynamic> post(String path, {Object? body, bool auth = true, bool refreshOnUnauthorized = true}) =>
      _send('POST', path, body: body, auth: auth, refreshOnUnauthorized: refreshOnUnauthorized);

  Future<dynamic> put(String path, {Object? body, bool auth = true}) => _send('PUT', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {Object? body, bool auth = true}) =>
      _send('DELETE', path, body: body, auth: auth);

  /// Gửi một file dạng multipart/form-data (vd. ảnh đại diện) trong trường [field].
  Future<dynamic> upload(String path, {required String filePath, String field = 'file'}) async {
    final form = FormData.fromMap({field: await MultipartFile.fromFile(filePath)});
    return _send('POST', path, body: form, auth: true);
  }

  Future<dynamic> uploadFiles(
      String path, {
        required List<String> filePaths,
        String field = 'files',
      }) async {
    final files = <MultipartFile>[];

    for (final filePath in filePaths) {
      files.add(await MultipartFile.fromFile(filePath));
    }

    final form = FormData.fromMap({
      field: files,
    });

    return _send('POST', path, body: form, auth: true);
  }
  /// Đổi refresh token lấy cặp token mới. `false` khi BE từ chối (hết hạn, đã thu hồi, tài khoản bị khóa).
  Future<bool> refreshSession() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return false;
    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        refreshPath,
        data: {'refreshToken': refreshToken},
        options: Options(method: 'POST'),
      );
    } on DioException catch (e) {
      throw _networkError(e);
    }
    final dynamic data;
    try {
      data = _unwrap(response);
    } on ApiException {
      return false;
    }
    if (data is! Map<String, dynamic> || data['token'] is! String) return false;
    await _tokens.write(data['token'] as String, refreshToken: data['refreshToken'] as String?);
    return true;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    required bool auth,
    bool isRetry = false,
    bool refreshOnUnauthorized = true,
  }) async {
    final token = auth ? await _tokens.read() : null;
    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        // FormData chỉ gửi được một lần: lần gửi lại sau refresh dùng bản sao.
        data: isRetry && body is FormData ? body.clone() : body,
        queryParameters: query,
        options: Options(method: method, headers: {'Authorization': ?(token == null ? null : 'Bearer $token')}),
      );
    } on DioException catch (e) {
      throw _networkError(e);
    }

    if (token != null && refreshOnUnauthorized && _statusOf(response) == 401) {
      if (!isRetry && await refreshSession()) {
        return _send(method, path, query: query, body: body, auth: auth, isRetry: true);
      }
      onUnauthorized?.call();
    }
    return _unwrap(response);
  }

  /// Mã lỗi thật: ưu tiên statusCode trong envelope của BE.
  static int _statusOf(Response<dynamic> response) {
    final body = response.data;
    final envelopeCode = body is Map<String, dynamic> ? (body['statusCode'] as num?)?.toInt() : null;
    final status = response.statusCode ?? 0;
    return status >= 400 ? status : (envelopeCode ?? status);
  }

  dynamic _unwrap(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final body = response.data;
    final envelope = body is Map<String, dynamic> && body.containsKey('statusCode') ? body : null;
    final code = (envelope?['statusCode'] as num?)?.toInt() ?? status;

    if (status >= 200 && status < 300 && code < 400) {
      return envelope != null ? envelope['data'] : body;
    }
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
