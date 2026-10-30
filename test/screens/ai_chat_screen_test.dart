import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/ai_chat_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_ai_chat_repository.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/repositories/ai_chat_repository.dart';
import 'package:test1/models/ai_chat.dart';
import 'package:test1/models/geo_point.dart';
import 'package:test1/screens/ai_chat/ai_chat_screen.dart';
import 'package:test1/screens/booking/booking_checkout_screen.dart';

/// Lần gửi đầu lỗi (vd. AI quá tải), lần sau chạy bình thường.
class _FlakyAiChat extends MockAiChatRepository {
  bool fail = true;

  _FlakyAiChat() : super(latency: Duration.zero);

  @override
  Future<AiReply> send(String message, {String? sessionId, GeoPoint? location}) {
    if (fail) {
      fail = false;
      throw const AiChatException('Trợ lý AI đang quá tải, vui lòng thử lại sau ít phút');
    }
    return super.send(message, sessionId: sessionId, location: location);
  }
}

void main() {
  late MockFacilityRepository facility;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    facility = MockFacilityRepository(latency: Duration.zero);
    AppRepositories.facility = facility;
    AppRepositories.aiChat = MockAiChatRepository(facility: facility, latency: Duration.zero);
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AiChatScreen(useLocation: false)));
    await tester.pumpAndSettle();
  }

  testWidgets('chào + gợi ý; hỏi tìm sân thì hiện thẻ sân (bỏ phần liệt kê trùng), bấm ca sang thanh toán', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(AiChatStrings.welcome), findsOneWidget);
    expect(find.text(AiChatStrings.suggestions.first), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tìm sân cầu lông');
    await tester.tap(find.byTooltip(AiChatStrings.send));
    await tester.pumpAndSettle();

    expect(find.text('tìm sân cầu lông'), findsOneWidget);
    expect(find.textContaining(AiMessage.listIntroEndings[0]), findsOneWidget);
    expect(find.textContaining('1. Sân Cầu Lông Thiên Triều'), findsNothing);
    expect(find.text('Sân Cầu Lông Thiên Triều'), findsOneWidget);
    expect(find.text(AiChatStrings.suggestions.first), findsNothing);

    final slot = find.byWidgetPredicate(
      (w) => w is ActionChip && (w.key as ValueKey?)?.value.toString().startsWith('ai-slot-') == true,
    );
    expect(slot, findsWidgets);
    await tester.ensureVisible(slot.first);
    await tester.tap(slot.first);
    await tester.pumpAndSettle();
    expect(find.byType(BookingCheckoutScreen), findsOneWidget);
  });

  testWidgets('hỏi tìm kèo thì hiện thẻ kèo; lịch sử mở lại được cuộc trò chuyện', (tester) async {
    await pump(tester);
    await tester.tap(find.text(AiChatStrings.suggestions[1]));
    await tester.pumpAndSettle();
    expect(find.textContaining(AiChatStrings.slotsLeft(2)), findsOneWidget);
    expect(find.textContaining(AiChatStrings.host('Quốc Bảo')), findsOneWidget);

    await tester.tap(find.byTooltip(AiChatStrings.newChat));
    await tester.pumpAndSettle();
    expect(find.text(AiChatStrings.suggestions[1]), findsOneWidget);

    await tester.tap(find.byTooltip(AiChatStrings.history));
    await tester.pumpAndSettle();
    expect(find.text(AiChatStrings.suggestions[1]), findsOneWidget);
    await tester.tap(find.text(AiChatStrings.suggestions[1]));
    await tester.pumpAndSettle();
    expect(find.textContaining(AiChatStrings.host('Quốc Bảo')), findsOneWidget);
  });

  testWidgets('gửi lỗi: báo lỗi của BE, câu hỏi có nút gửi lại; gửi lại thì có câu trả lời', (tester) async {
    AppRepositories.aiChat = _FlakyAiChat();
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'xin chào');
    await tester.tap(find.byTooltip(AiChatStrings.send));
    await tester.pumpAndSettle();

    expect(find.text('Trợ lý AI đang quá tải, vui lòng thử lại sau ít phút'), findsOneWidget);
    expect(find.text(AiChatStrings.retry), findsOneWidget);

    await tester.tap(find.text(AiChatStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AiChatStrings.retry), findsNothing);
    expect(find.text('xin chào'), findsOneWidget);
    expect(find.textContaining('Mình có thể giúp bạn'), findsOneWidget);
  });
}
