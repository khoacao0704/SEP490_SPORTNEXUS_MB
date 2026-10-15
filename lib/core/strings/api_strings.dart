/// Câu báo lỗi chung khi gọi Backend (BE trả lẫn tiếng Anh / tiếng Việt, app hiển thị tiếng Việt).
class ApiStrings {
  ApiStrings._();

  static const String noConnection = 'Không có kết nối mạng. Vui lòng kiểm tra Internet và thử lại.';
  static const String timeout = 'Máy chủ phản hồi quá lâu. Vui lòng thử lại sau ít phút.';
  static const String unauthorized = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const String forbidden = 'Bạn không có quyền thực hiện thao tác này.';
  static const String notFound = 'Không tìm thấy dữ liệu yêu cầu.';
  static const String server = 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
  static const String unknown = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
  static const String sessionExpired = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
}
