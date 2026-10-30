import 'sport.dart';

enum AiSender { user, bot }

/// Ý định AI nhận ra từ câu hỏi: quyết định hiện thẻ sân, thẻ kèo hay chỉ chữ.
enum AiIntent {
  searchCourt('SEARCH_COURT'),
  searchLfg('SEARCH_LFG'),
  appHelp('APP_HELP'),
  other('OTHER');

  const AiIntent(this.apiValue);

  final String apiValue;

  static AiIntent? fromApi(String? value) => values.where((i) => i.apiValue == value?.toUpperCase()).firstOrNull;
}

/// Một ca còn trống AI tìm được (dữ liệu tại lúc trả lời, có thể đã hết chỗ / đổi giá).
class AiSlot {
  final String courtSlotId;
  final String courtId;
  final String courtName;
  final DateTime start;
  final DateTime end;
  final int price;

  const AiSlot({
    required this.courtSlotId,
    this.courtId = '',
    required this.courtName,
    required this.start,
    required this.end,
    required this.price,
  });
}

/// Một sân AI gợi ý, kèm tối đa 6 ca trống sớm nhất.
class AiFacilitySuggestion {
  final String facilityId;
  final String facilityName;
  final String address;
  final Sport? sport;
  final String sportName;
  final int minPrice;
  final List<AiSlot> slots;

  const AiFacilitySuggestion({
    required this.facilityId,
    required this.facilityName,
    this.address = '',
    this.sport,
    this.sportName = '',
    this.minPrice = 0,
    this.slots = const [],
  });

  String get sportLabel => sport?.label ?? sportName;
}

/// Một kèo LFG AI gợi ý.
class AiLfgSuggestion {
  final String lfgCardId;
  final String facilityName;
  final String facilityAddress;
  final Sport? sport;
  final String sportName;
  final String hostName;
  final DateTime? start;
  final DateTime? end;
  final int remainingSlots;
  final int pricePerPerson;
  final String skillLevel;

  const AiLfgSuggestion({
    required this.lfgCardId,
    required this.facilityName,
    this.facilityAddress = '',
    this.sport,
    this.sportName = '',
    this.hostName = '',
    this.start,
    this.end,
    this.remainingSlots = 0,
    this.pricePerPerson = 0,
    this.skillLevel = '',
  });

  String get sportLabel => sport?.label ?? sportName;
}

class AiMessage {
  /// Câu kết BE thêm sau phần liệt kê khi có thẻ kèm theo.
  static const List<String> listIntroEndings = [
    'Bạn chọn ca muốn đặt bên dưới nhé',
    'Bạn bấm vào kèo để xem chi tiết và nhận suất nhé',
  ];

  final String id;
  final AiSender sender;
  final String text;
  final DateTime createdAt;
  final AiIntent? intent;
  final List<AiFacilitySuggestion> facilities;
  final List<AiLfgSuggestion> lfgCards;

  const AiMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.intent,
    this.facilities = const [],
    this.lfgCards = const [],
  });

  bool get hasCards => facilities.isNotEmpty || lfgCards.isNotEmpty;

  static final RegExp _listLine = RegExp(r'^\s*(\d+\.|•)');

  /// Nội dung để hiển thị: có thẻ thì bỏ phần liệt kê bằng chữ (dòng "1. …", "• …"), vì trùng với thẻ.
  /// BE đặt phần liệt kê giữa câu dẫn và câu kết.
  String get displayText {
    final trimmed = text.trim();
    if (!hasCards) return trimmed;
    final kept = trimmed.split('\n').where((line) => !_listLine.hasMatch(line)).join('\n');
    return kept.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

/// Một cuộc trò chuyện với AI.
class AiSession {
  final String id;
  final String title;
  final DateTime? createdAt;
  final int messageCount;
  final String lastMessage;
  final DateTime? lastMessageAt;

  const AiSession({
    required this.id,
    required this.title,
    this.createdAt,
    this.messageCount = 0,
    this.lastMessage = '',
    this.lastMessageAt,
  });
}

/// Kết quả gửi một tin: phiên (có thể vừa được tạo) và câu trả lời của AI.
class AiReply {
  final String sessionId;
  final AiMessage message;

  const AiReply({required this.sessionId, required this.message});
}
