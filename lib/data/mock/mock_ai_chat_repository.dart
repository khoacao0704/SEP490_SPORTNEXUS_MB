import '../../core/strings/ai_chat_strings.dart';
import '../../models/ai_chat.dart';
import '../../models/geo_point.dart';
import '../../models/sport.dart';
import '../repositories/ai_chat_repository.dart';
import '../repositories/facility_repository.dart';

/// Bản giả lập [AiChatRepository] (trong bộ nhớ), trả lời theo từ khoá:
/// có "kèo" → thẻ kèo; có tên môn hoặc "sân" → thẻ sân lấy ca trống thật từ [facility]; còn lại → hướng dẫn.
class MockAiChatRepository implements AiChatRepository {
  static const String demoFacilityId = 'f-hcm-thientrieu';

  final FacilityRepository? _facility;
  final Duration latency;
  final DateTime Function() _now;
  final List<({AiSession session, List<AiMessage> messages})> _sessions = [];
  int _seq = 0;

  MockAiChatRepository({
    this._facility,
    this.latency = const Duration(milliseconds: 600),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<AiReply> send(String message, {String? sessionId, GeoPoint? location}) async {
    if (latency > Duration.zero) await Future.delayed(latency);
    final text = message.trim();
    if (text.isEmpty || text.length > AiChatRepository.maxMessageLength) {
      throw const AiChatException(AiChatStrings.invalidMessage);
    }
    var index = sessionId == null ? -1 : _sessions.indexWhere((s) => s.session.id == sessionId);
    if (sessionId != null && index < 0) throw const AiChatException(AiChatStrings.sessionNotFound);
    if (index < 0) {
      _sessions.insert(0, (
        session: AiSession(id: 'ai-${++_seq}', title: _title(text), createdAt: _now()),
        messages: [],
      ));
      index = 0;
    }
    final entry = _sessions[index];
    final user = AiMessage(id: 'm-${++_seq}', sender: AiSender.user, text: text, createdAt: _now());
    final bot = await _answer(text);
    final messages = [...entry.messages, user, bot];
    final session = AiSession(
      id: entry.session.id,
      title: entry.session.title,
      createdAt: entry.session.createdAt,
      messageCount: messages.length,
      lastMessage: bot.text.length > 80 ? '${bot.text.substring(0, 80)}…' : bot.text,
      lastMessageAt: bot.createdAt,
    );
    _sessions
      ..removeAt(index)
      ..insert(0, (session: session, messages: messages));
    return AiReply(sessionId: session.id, message: bot);
  }

  @override
  Future<List<AiSession>> getSessions() async => [for (final s in _sessions) s.session];

  @override
  Future<List<AiMessage>> getMessages(String sessionId) async {
    final entry = _sessions.where((s) => s.session.id == sessionId).firstOrNull;
    if (entry == null) throw const AiChatException(AiChatStrings.sessionNotFound);
    return entry.messages;
  }

  @override
  Future<void> deleteSession(String sessionId) async => _sessions.removeWhere((s) => s.session.id == sessionId);

  String _title(String text) => text.length > 60 ? text.substring(0, 60) : text;

  Future<AiMessage> _answer(String text) async {
    final lower = text.toLowerCase();
    final id = 'm-${++_seq}';
    if (lower.contains('kèo')) {
      final start = DateTime(_now().year, _now().month, _now().day + 1, 18);
      return AiMessage(
        id: id,
        sender: AiSender.bot,
        text:
            'Mình tìm được 1 kèo phù hợp cho bạn. ${AiMessage.listIntroEndings[1]}.\n1. Kèo Pickleball • Eco Sport Quận 7',
        createdAt: _now(),
        intent: AiIntent.searchLfg,
        lfgCards: [
          AiLfgSuggestion(
            lfgCardId: 'lfg-demo-1',
            facilityName: 'Eco Sport Quận 7',
            sport: Sport.pickleball,
            sportName: Sport.pickleball.label,
            hostName: 'Quốc Bảo',
            start: start,
            end: start.add(const Duration(hours: 1)),
            remainingSlots: 2,
            pricePerPerson: 50000,
            skillLevel: 'Trung bình',
          ),
        ],
      );
    }
    final sport = Sport.values.where((s) => lower.contains(s.label.toLowerCase())).firstOrNull;
    if (sport != null || lower.contains('sân')) {
      final chosen = sport ?? Sport.badminton;
      final today = _now();
      var slots = <AiSlot>[];
      try {
        final available = await _facility?.getTimeSlots(
          demoFacilityId,
          chosen,
          DateTime(today.year, today.month, today.day + 1),
        );
        slots = [
          for (final s in (available ?? const []).where((s) => s.isAvailable).take(6))
            AiSlot(courtSlotId: s.id, courtName: s.courtName, start: s.start, end: s.end, price: s.price),
        ];
      } catch (_) {
        slots = [];
      }
      if (slots.isEmpty) {
        return AiMessage(
          id: id,
          sender: AiSender.bot,
          text: 'Tiếc quá, hiện chưa có sân trống phù hợp.',
          createdAt: _now(),
          intent: AiIntent.searchCourt,
        );
      }
      return AiMessage(
        id: id,
        sender: AiSender.bot,
        text:
            'Mình tìm được sân ${chosen.label} còn trống ngày mai. ${AiMessage.listIntroEndings[0]}.\n1. Sân Cầu Lông Thiên Triều',
        createdAt: _now(),
        intent: AiIntent.searchCourt,
        facilities: [
          AiFacilitySuggestion(
            facilityId: demoFacilityId,
            facilityName: 'Sân Cầu Lông Thiên Triều',
            address: '25 Đường số 17, P. Tân Thuận Đông, Quận 7',
            sport: chosen,
            sportName: chosen.label,
            minPrice: slots.map((s) => s.price).reduce((a, b) => a < b ? a : b),
            slots: slots,
          ),
        ],
      );
    }
    return AiMessage(
      id: id,
      sender: AiSender.bot,
      text: 'Mình có thể giúp bạn tìm sân trống, tìm kèo LFG hoặc hướng dẫn dùng app. Bạn muốn chơi môn gì, ở đâu, lúc nào?',
      createdAt: _now(),
      intent: AiIntent.appHelp,
    );
  }
}
