import 'dart:convert';

/// Đọc phần payload của JWT (không kiểm chữ ký: việc đó là của BE).
class JwtUtils {
  JwtUtils._();

  static Map<String, dynamic>? payload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final json = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Thời điểm hết hạn (claim "exp"); `null` nếu không đọc được.
  static DateTime? expiry(String token) {
    final exp = payload(token)?['exp'];
    return exp is num ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true) : null;
  }

  /// Token hỏng hoặc đã hết hạn.
  static bool isExpired(String token, {DateTime? now}) {
    final exp = expiry(token);
    return exp == null || !exp.isAfter((now ?? DateTime.now()).toUtc());
  }
}
