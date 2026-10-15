import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi giữ JWT của phiên đăng nhập.
abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Lưu JWT trong Keystore (Android) / Keychain (iOS), không để ở SharedPreferences.
class SecureTokenStore implements TokenStore {
  static const String _key = 'auth_token';

  final FlutterSecureStorage _storage;

  /// Đọc một lần rồi giữ trong bộ nhớ, tránh gọi Keystore cho mọi request.
  String? _cached;
  bool _loaded = false;

  SecureTokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() async {
    if (!_loaded) {
      _cached = await _storage.read(key: _key);
      _loaded = true;
    }
    return _cached;
  }

  @override
  Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}

/// Dùng trong test.
class MemoryTokenStore implements TokenStore {
  String? _token;

  MemoryTokenStore([this._token]);

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
