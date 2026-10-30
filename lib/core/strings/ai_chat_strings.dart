import '../utils/formatters.dart';

/// Chuỗi hiển thị cho trợ lý AI.
class AiChatStrings {
  AiChatStrings._();

  static const String title = 'SportNexus AI';
  static const String subtitle = 'Trợ lý tìm sân & kèo';
  static const String newChat = 'Cuộc trò chuyện mới';
  static const String history = 'Lịch sử trò chuyện';
  static const String welcome =
      'Xin chào! Mình là trợ lý SportNexus. Mình có thể tìm sân còn trống, tìm kèo LFG đang thiếu người '
      'hoặc hướng dẫn bạn dùng app. Bạn muốn chơi gì hôm nay?';
  static const List<String> suggestions = [
    'Tìm sân cầu lông tối nay ở Quận 7',
    'Có kèo pickleball nào cuối tuần không?',
    'Sân bóng đá dưới 300k ngày mai',
    'Hủy đặt sân thì có được hoàn tiền không?',
  ];
  static const String inputHint = 'Nhập câu hỏi…';
  static const String send = 'Gửi';
  static const String thinking = 'Đang tìm…';
  static const String disclaimer = 'AI chỉ gợi ý. Bạn tự chọn ca và thanh toán, AI không tự đặt sân.';
  static const String retry = 'Gửi lại';
  static const String sendError = 'Không gửi được câu hỏi. Vui lòng thử lại.';

  // Thẻ
  static String fromPrice(int price) => 'Từ ${Formatters.vnd(price)}';
  static String pricePerPerson(int price) => '${Formatters.vnd(price)}/người';
  static String slotsLeft(int n) => 'Còn $n chỗ';
  static String host(String name) => 'Chủ kèo: $name';
  static const String viewFacility = 'Xem sân';
  static const String viewMatch = 'Xem kèo';
  static const String staleNote = 'Ca trống và giá là dữ liệu lúc AI trả lời, có thể đã thay đổi.';
  static const String sportUnsupported = 'Môn này chưa đặt được trên app.';

  // Lịch sử
  static const String noSessions = 'Chưa có cuộc trò chuyện nào';
  static const String deleteTitle = 'Xoá cuộc trò chuyện?';
  static const String deleteMessage = 'Cuộc trò chuyện sẽ bị xoá khỏi lịch sử.';
  static const String delete = 'Xoá';
  static const String cancel = 'Hủy';
  static const String deleted = 'Đã xoá cuộc trò chuyện';
  static const String loadError = 'Không tải được dữ liệu. Vui lòng thử lại.';

  // Lỗi (bản giả lập)
  static const String invalidMessage = 'Câu hỏi phải có nội dung và không quá 1000 ký tự.';
  static const String sessionNotFound = 'Không tìm thấy cuộc trò chuyện.';
}
