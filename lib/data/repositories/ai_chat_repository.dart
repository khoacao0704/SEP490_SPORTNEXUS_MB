import '../../models/ai_chat.dart';
import '../../models/geo_point.dart';

/// Lỗi trợ lý AI (gửi quá nhanh, AI quá tải...); [message] sẵn sàng để hiển thị.
class AiChatException implements Exception {
  final String message;

  const AiChatException(this.message);

  @override
  String toString() => 'AiChatException: $message';
}

/// Trợ lý AI: chỉ tìm sân / kèo / hướng dẫn dùng app, không tự đặt sân hay trừ tiền.
abstract class AiChatRepository {
  static const int maxMessageLength = 1000;

  /// Gửi một tin. [sessionId] = `null` thì BE tạo cuộc trò chuyện mới.
  /// [location] để ưu tiên sân / kèo gần.
  Future<AiReply> send(String message, {String? sessionId, GeoPoint? location});

  /// Các cuộc trò chuyện, mới nhất trước.
  Future<List<AiSession>> getSessions();

  /// Tin nhắn của một cuộc trò chuyện, cũ nhất trước.
  Future<List<AiMessage>> getMessages(String sessionId);

  Future<void> deleteSession(String sessionId);
}
