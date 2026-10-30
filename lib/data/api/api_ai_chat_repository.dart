import '../../models/ai_chat.dart';
import '../../models/geo_point.dart';
import '../repositories/ai_chat_repository.dart';
import 'api_client.dart';
import 'api_facility_repository.dart';

/// Trợ lý AI qua BE (Gemini + dữ liệu thật). Câu trả lời là chữ thường kèm thẻ sân / kèo có cấu trúc.
class ApiAiChatRepository implements AiChatRepository {
  static const String chatPath = '/api/v1/ai/chat';
  static const String sessionsPath = '/api/v1/ai/sessions';
  static String sessionPath(String id) => '/api/v1/ai/sessions/$id';
  static String messagesPath(String id) => '/api/v1/ai/sessions/$id/messages';

  final ApiClient _api;

  ApiAiChatRepository({required this._api});

  @override
  Future<AiReply> send(String message, {String? sessionId, GeoPoint? location}) async {
    final data = await _call(
      () => _api.post(
        chatPath,
        body: {
          'message': message.trim(),
          'sessionId': ?sessionId,
          if (location != null) ...{'lat': location.latitude, 'lng': location.longitude},
        },
      ),
    );
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final rawReply = map['reply'];
    // Phần trả lời thường nằm trong `reply`; đọc được cả khi BE để thẳng ở `data`.
    final reply = rawReply is Map ? Map<String, dynamic>.from(rawReply) : map;
    final text = rawReply is String ? rawReply : _str(reply['message'] ?? reply['content'] ?? reply['text']);
    final id = _opt(map['sessionId']) ?? _opt(reply['sessionId']) ?? sessionId ?? '';
    return AiReply(
      sessionId: id,
      message: messageFromApi({...reply, 'message': text, 'sender': 'BOT', 'id': reply['id'] ?? map['messageId']}),
    );
  }

  @override
  Future<List<AiSession>> getSessions() async {
    final data = await _call(() => _api.get(sessionsPath));
    return _maps(data)
        .map(
          (m) => AiSession(
            id: _str(m['id']),
            title: _str(m['title']),
            createdAt: _date(m['createdAt']),
            messageCount: (m['messageCount'] as num?)?.toInt() ?? 0,
            lastMessage: _str(m['lastMessage']),
            lastMessageAt: _date(m['lastMessageAt']),
          ),
        )
        .toList();
  }

  @override
  Future<List<AiMessage>> getMessages(String sessionId) async {
    final data = await _call(() => _api.get(messagesPath(sessionId)));
    return _maps(data).map(messageFromApi).toList();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _call(() => _api.delete(sessionPath(sessionId)));
  }

  // ---------------- Chuyển đổi ----------------

  static AiMessage messageFromApi(Map<String, dynamic> m) {
    final rawIntent = m['intent'];
    final intent = rawIntent is Map ? _opt(rawIntent['intent']) : _opt(rawIntent);
    return AiMessage(
      id: _str(m['id']),
      sender: _str(m['sender']).toUpperCase() == 'USER' ? AiSender.user : AiSender.bot,
      text: _str(m['message']),
      createdAt: _date(m['createdAt']) ?? DateTime.now(),
      intent: AiIntent.fromApi(intent),
      facilities: _maps(m['facilities']).map(facilityFromApi).toList(),
      lfgCards: _maps(m['lfgCards']).map(lfgFromApi).toList(),
    );
  }

  static AiFacilitySuggestion facilityFromApi(Map<String, dynamic> m) {
    final sportName = _str(m['sportName']);
    return AiFacilitySuggestion(
      facilityId: _str(m['facilityId']),
      facilityName: _str(m['facilityName']),
      address: _str(m['address']),
      sport: ApiFacilityRepository.sportFromName(sportName),
      sportName: sportName,
      minPrice: _int(m['minPrice']),
      slots: _maps(m['slots'])
          .map(
            (s) => AiSlot(
              courtSlotId: _str(s['courtSlotId']),
              courtId: _str(s['courtId']),
              courtName: _str(s['courtName']),
              start: _date(s['startTime']) ?? DateTime.now(),
              end: _date(s['endTime']) ?? DateTime.now(),
              price: _int(s['price']),
            ),
          )
          .toList(),
    );
  }

  static AiLfgSuggestion lfgFromApi(Map<String, dynamic> m) {
    final sportName = _str(m['sportName']);
    return AiLfgSuggestion(
      lfgCardId: _str(m['lfgCardId']),
      facilityName: _str(m['facilityName']),
      facilityAddress: _str(m['facilityAddress']),
      sport: ApiFacilityRepository.sportFromName(sportName),
      sportName: sportName,
      hostName: _str(m['hostName']),
      start: _date(m['startTime']),
      end: _date(m['endTime']),
      remainingSlots: _int(m['remainingSlots']),
      pricePerPerson: _int(m['pricePerPerson']),
      skillLevel: _str(m['skillLevelTag']),
    );
  }

  static Iterable<Map<String, dynamic>> _maps(Object? raw) =>
      (raw is List ? raw : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e));

  static String _str(Object? v) => v?.toString() ?? '';

  static String? _opt(Object? v) {
    final s = v?.toString();
    return s == null || s.isEmpty ? null : s;
  }

  static int _int(Object? v) => (v as num?)?.round() ?? 0;

  static DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw AiChatException(e.message);
    }
  }
}
