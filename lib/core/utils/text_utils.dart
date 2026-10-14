class TextUtils {
  TextUtils._();

  static const String _withDiacritics =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const String _withoutDiacritics =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  static final Map<String, String> _map = {
    for (var i = 0; i < _withDiacritics.length; i++) _withDiacritics[i]: _withoutDiacritics[i],
  };

  /// "Thủ Đức" -> "thu duc". Dùng để tìm kiếm không phân biệt dấu và hoa thường.
  static String normalize(String input) {
    final lower = input.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(_map[char] ?? char);
    }
    return buffer.toString();
  }

  static bool containsIgnoringDiacritics(String text, String query) {
    if (query.trim().isEmpty) return true;
    return normalize(text).contains(normalize(query));
  }
}
