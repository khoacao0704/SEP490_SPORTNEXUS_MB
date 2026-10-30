import 'package:flutter/material.dart';

import '../../core/services/location_service.dart';
import '../../core/strings/ai_chat_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/ai_chat_repository.dart';
import '../../data/repositories/facility_repository.dart';
import '../../models/ai_chat.dart';
import '../../models/geo_point.dart';
import '../../models/time_slot.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_chat/ai_suggestion_cards.dart';
import '../../widgets/facility/slot_picker.dart';
import '../booking/booking_checkout_screen.dart';
import '../facility/facility_detail_screen.dart';
import '../lfg/lfg_match_detail_screen.dart';
import 'ai_sessions_screen.dart';

/// Một dòng trong khung chat: tin nhắn kèm trạng thái gửi lỗi (tin lỗi không được BE lưu).
class _ChatItem {
  final AiMessage message;
  final bool failed;

  const _ChatItem(this.message, {this.failed = false});
}

/// Trợ lý AI: hỏi bằng tiếng Việt để tìm sân trống / kèo LFG / cách dùng app.
/// AI chỉ gợi ý; bấm ca trống để giữ chỗ và sang thanh toán, bấm kèo để xem chi tiết và nhận suất.
class AiChatScreen extends StatefulWidget {
  /// Bỏ qua định vị (dùng trong test).
  final bool useLocation;

  const AiChatScreen({super.key, this.useLocation = true});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatItem> _items = [];
  String? _sessionId;
  bool _sending = false;
  bool _loadingSession = false;
  bool _busyBooking = false;

  /// Vị trí chỉ lấy một lần, ở lần gửi đầu tiên (lúc đó người dùng đang cần tìm sân gần).
  GeoPoint? _location;
  bool _locationTried = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<GeoPoint?> _currentLocation() async {
    if (!widget.useLocation || _locationTried) return _location;
    _locationTried = true;
    final result = await const LocationService().getCurrentLocation();
    return _location = result.point;
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    if (text.length > AiChatRepository.maxMessageLength) {
      _snack(AiChatStrings.invalidMessage);
      return;
    }
    final userMessage = AiMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      sender: AiSender.user,
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      // Gửi lại: bỏ dòng lỗi cũ của cùng câu hỏi.
      _items.removeWhere((i) => i.failed && i.message.text == text);
      _items.add(_ChatItem(userMessage));
      _sending = true;
      if (preset == null) _input.clear();
    });
    _scrollToEnd();
    try {
      final location = await _currentLocation();
      final reply = await AppRepositories.aiChat.send(text, sessionId: _sessionId, location: location);
      if (!mounted) return;
      setState(() {
        _sessionId = reply.sessionId.isEmpty ? _sessionId : reply.sessionId;
        _items.add(_ChatItem(reply.message));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items.removeLast();
        _items.add(_ChatItem(userMessage, failed: true));
      });
      _snack(e is AiChatException ? e.message : AiChatStrings.sendError);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _newChat() {
    setState(() {
      _sessionId = null;
      _items.clear();
    });
  }

  Future<void> _openHistory() async {
    final result = await Navigator.push<AiSessionsResult>(
      context,
      MaterialPageRoute(builder: (_) => const AiSessionsScreen()),
    );
    if (result == null || !mounted) return;
    if (result.open != null) {
      await _openSession(result.open!);
    } else if (_sessionId != null && result.deleted.contains(_sessionId)) {
      _newChat();
    }
  }

  Future<void> _openSession(String sessionId) async {
    setState(() => _loadingSession = true);
    try {
      final messages = await AppRepositories.aiChat.getMessages(sessionId);
      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        _items
          ..clear()
          ..addAll(messages.map(_ChatItem.new));
      });
      _scrollToEnd();
    } catch (_) {
      _snack(AiChatStrings.loadError);
    } finally {
      if (mounted) setState(() => _loadingSession = false);
    }
  }

  /// Giữ ca AI gợi ý rồi sang màn thanh toán (giống đặt từ chi tiết sân).
  Future<void> _bookSlot(AiFacilitySuggestion facility, AiSlot s) async {
    final sport = facility.sport;
    if (sport == null) {
      _snack(AiChatStrings.sportUnsupported);
      return;
    }
    if (_busyBooking) return;
    setState(() => _busyBooking = true);
    final SlotHold hold;
    try {
      hold = await AppRepositories.facility.holdSlots([
        TimeSlot(
          id: s.courtSlotId,
          facilityId: facility.facilityId,
          sport: sport,
          courtName: s.courtName,
          start: s.start,
          end: s.end,
          price: s.price,
          isAvailable: true,
        ),
      ]);
    } on FacilityException catch (e) {
      if (mounted) setState(() => _busyBooking = false);
      _snack(e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _busyBooking = false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingCheckoutScreen(
          sport: sport.label,
          courtName: facility.facilityName,
          location: facility.address,
          dateTime: describeSlotSchedule(hold.slots),
          totalAmount: hold.totalPrice,
          initialSecondsRemaining: hold.secondsRemaining(DateTime.now()),
          hold: hold,
        ),
      ),
    );
    // Thanh toán xong thì app về Trang chủ (màn này đã đóng); còn ở đây là người dùng quay lại: nhả chỗ.
    if (mounted) await AppRepositories.facility.releaseHold(hold.holdId);
  }

  Future<void> _viewFacility(AiFacilitySuggestion f) async {
    try {
      final facility = await AppRepositories.facility.getFacility(f.facilityId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FacilityDetailScreen(facility: facility, initialSport: f.sport),
        ),
      );
    } catch (_) {
      _snack(AiChatStrings.loadError);
    }
  }

  void _openMatch(AiLfgSuggestion card) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => LfgMatchDetailScreen(matchId: card.lfgCardId)));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryGreen,
              child: Icon(Icons.smart_toy, color: Colors.white),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AiChatStrings.title,
                  style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(AiChatStrings.subtitle, style: TextStyle(color: AppColors.primaryGreen, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AiChatStrings.newChat,
            onPressed: _sending || _items.isEmpty ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.textMain),
          ),
          IconButton(
            tooltip: AiChatStrings.history,
            onPressed: _sending ? null : _openHistory,
            icon: const Icon(Icons.history, color: AppColors.textMain),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingSession
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : Stack(
                    children: [
                      ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
                          _botBubble(AiChatStrings.welcome),
                          if (_items.isEmpty) _buildSuggestions(),
                          for (final item in _items) _buildItem(item),
                          if (_sending) _typingBubble(),
                        ],
                      ),
                      if (_busyBooking)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x33000000),
                            child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                          ),
                        ),
                    ],
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in AiChatStrings.suggestions)
            ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onPressed: () => _send(s),
              backgroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.cardBorder),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(_ChatItem item) {
    final m = item.message;
    if (m.sender == AiSender.user) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _userBubble(m.text),
            if (item.failed)
              TextButton.icon(
                onPressed: _sending ? null : () => _send(m.text),
                icon: const Icon(Icons.error_outline, size: 16, color: Colors.red),
                label: const Text(AiChatStrings.retry, style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _botBubble(m.displayText),
          for (final f in m.facilities)
            AiFacilityCard(facility: f, onSlot: (s) => _bookSlot(f, s), onView: () => _viewFacility(f)),
          for (final c in m.lfgCards) AiLfgCard(card: c, onTap: () => _openMatch(c)),
          if (m.facilities.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(AiChatStrings.staleNote, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _botBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.textMain, height: 1.4)),
      ),
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, height: 1.4)),
      ),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
              ),
              SizedBox(width: 8),
              Text(AiChatStrings.thinking, style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: AiChatRepository.maxMessageLength,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: AiChatStrings.inputHint,
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: AiChatStrings.send,
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(AiChatStrings.disclaimer, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
