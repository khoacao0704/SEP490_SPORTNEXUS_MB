import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi giữ JWT (access token) và refresh token của phiên đăng nhập.
abstract class TokenStore {
  Future<String?> read();

  Future<String?> readRefreshToken();

  /// Lưu cặp token mới (sau đăng nhập / refresh). BE thu hồi refresh token cũ mỗi lần refresh.
  Future<void> write(String token, {String? refreshToken});

  Future<void> clear();
}

/// Lưu token trong Keystore (Android) / Keychain (iOS), không để ở SharedPreferences.
class SecureTokenStore implements TokenStore {
  static const String _key = 'auth_token';
  static const String _refreshKey = 'auth_refresh_token';

  final FlutterSecureStorage _storage;

  /// Đọc một lần rồi giữ trong bộ nhớ, tránh gọi Keystore cho mọi request.
  String? _cached;
  String? _cachedRefresh;
  bool _loaded = false;

  SecureTokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  Future<void> _load() async {
    if (_loaded) return;
    _cached = await _storage.read(key: _key);
    _cachedRefresh = await _storage.read(key: _refreshKey);
    _loaded = true;
  }

  @override
  Future<String?> read() async {
    await _load();
    return _cached;
  }

  @override
  Future<String?> readRefreshToken() async {
    await _load();
    return _cachedRefresh;
  }

  @override
  Future<void> write(String token, {String? refreshToken}) async {
    _cached = token;
    _cachedRefresh = refreshToken;
    _loaded = true;
    await _storage.write(key: _key, value: token);
    if (refreshToken == null) {
      await _storage.delete(key: _refreshKey);
    } else {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _cachedRefresh = null;
    _loaded = true;
    await _storage.delete(key: _key);
    await _storage.delete(key: _refreshKey);
  }
}

/// Dùng trong test.
class MemoryTokenStore implements TokenStore {
  String? _token;
  String? _refresh;

  MemoryTokenStore([this._token, this._refresh]);

  @override
  Future<String?> read() async => _token;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> write(String token, {String? refreshToken}) async {
    _token = token;
    _refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    _token = null;
    _refresh = null;
  }
}
