import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_ai_chat_repository.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/ai_chat_repository.dart';
import 'package:test1/models/ai_chat.dart';
import 'package:test1/models/geo_point.dart';
import 'package:test1/models/sport.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) return ResponseBody.fromString('', 404);
    final (status, body) = route;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ok(Object? data) => {'statusCode': 200, 'message': 'OK', 'data': data};

const _intro = 'Mình tìm được 1 sân cầu lông còn trống tối nay. Bạn chọn ca muốn đặt bên dưới nhé.';

Map<String, dynamic> _facility() => {
  'facilityId': 'f-1',
  'facilityName': 'Sân A',
  'address': 'Quận 7',
  'sportName': 'Cầu lông',
  'minPrice': 120000.0,
  'slots': [
    {
      'courtSlotId': 'cs-1',
      'courtId': 'c-1',
      'courtName': 'Sân 2',
      'startTime': '2026-10-30T11:00:00Z',
      'endTime': '2026-10-30T12:00:00Z',
      'price': 120000.0,
    },
  ],
};

void main() {
  late _FakeServer server;
  late ApiAiChatRepository repo;

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    repo = ApiAiChatRepository(
      api: ApiClient(tokens: tokens, dio: dio),
    );
  });

  test('gửi tin: kèm vị trí và phiên; đọc câu trả lời, ý định, thẻ sân và ca trống', () async {
    server.routes['POST ${ApiAiChatRepository.chatPath}'] = (
      200,
      _ok({
        'sessionId': 's-1',
        'reply': {
          'message': '$_intro\n1. Sân A • Quận 7\n   • 18:00-19:00 Sân 2 120.000đ',
          'intent': {'intent': 'SEARCH_COURT', 'sport': 'Cầu lông', 'date': '2026-10-30'},
          'facilities': [_facility()],
          'lfgCards': <Object>[],
        },
      }),
    );

    final reply = await repo.send('  tìm sân cầu lông  ', sessionId: 's-0', location: const GeoPoint(10.7, 106.7));

    expect(server.requests.single.data, {'message': 'tìm sân cầu lông', 'sessionId': 's-0', 'lat': 10.7, 'lng': 106.7});
    expect(reply.sessionId, 's-1');
    final m = reply.message;
    expect(m.sender, AiSender.bot);
    expect(m.intent, AiIntent.searchCourt);
    expect(m.displayText, _intro);
    final f = m.facilities.single;
    expect(f.sport, Sport.badminton);
    expect(f.minPrice, 120000);
    final slot = f.slots.single;
    expect(slot.courtSlotId, 'cs-1');
    expect(slot.courtName, 'Sân 2');
    expect(slot.start, DateTime.utc(2026, 10, 30, 11).toLocal());
  });

  test('gửi tin mới: không gửi sessionId / vị trí; câu trả lời chỉ có chữ thì giữ nguyên', () async {
    server.routes['POST ${ApiAiChatRepository.chatPath}'] = (
      200,
      _ok({
        'sessionId': 's-9',
        'reply': {
          'message': 'Bạn có thể hủy đặt sân trong mục Lịch Đặt.\n1. Mở Lịch Đặt\n2. Chọn đơn',
          'intent': 'APP_HELP',
        },
      }),
    );

    final reply = await repo.send('hủy sân thế nào');

    expect(server.requests.single.data, {'message': 'hủy sân thế nào'});
    expect(reply.sessionId, 's-9');
    expect(reply.message.intent, AiIntent.appHelp);
    expect(reply.message.displayText, contains('2. Chọn đơn'));
  });

  test('lịch sử: danh sách phiên, tin nhắn có người gửi và thẻ kèo cũ', () async {
    server.routes['GET ${ApiAiChatRepository.sessionsPath}'] = (
      200,
      _ok([
        {
          'id': 's-1',
          'title': 'tìm kèo pickleball',
          'createdAt': '2026-10-30T01:00:00Z',
          'messageCount': 2,
          'lastMessage': 'Mình tìm được…',
          'lastMessageAt': '2026-10-30T01:01:00Z',
        },
      ]),
    );
    server.routes['GET ${ApiAiChatRepository.messagesPath('s-1')}'] = (
      200,
      _ok([
        {
          'id': 'm1',
          'sessionId': 's-1',
          'sender': 'USER',
          'message': 'tìm kèo pickleball',
          'createdAt': '2026-10-30T01:00:00Z',
        },
        {
          'id': 'm2',
          'sessionId': 's-1',
          'sender': 'BOT',
          'message': 'Mình tìm được 1 kèo. Bạn bấm vào kèo để xem chi tiết và nhận suất nhé.\n1. Kèo A',
          'createdAt': '2026-10-30T01:01:00Z',
          'intent': {'intent': 'SEARCH_LFG'},
          'lfgCards': [
            {
              'lfgCardId': 'lfg-1',
              'facilityName': 'Sân B',
              'sportName': 'Pickleball',
              'hostName': 'Bảo',
              'startTime': '2026-10-31T11:00:00Z',
              'remainingSlots': 2,
              'pricePerPerson': 50000,
              'skillLevelTag': 'Trung bình',
            },
          ],
        },
      ]),
    );

    final session = (await repo.getSessions()).single;
    expect(session.title, 'tìm kèo pickleball');
    expect(session.messageCount, 2);

    final messages = await repo.getMessages('s-1');
    expect(messages.map((m) => m.sender), [AiSender.user, AiSender.bot]);
    final bot = messages.last;
    expect(bot.intent, AiIntent.searchLfg);
    expect(bot.displayText, 'Mình tìm được 1 kèo. Bạn bấm vào kèo để xem chi tiết và nhận suất nhé.');
    final card = bot.lfgCards.single;
    expect(card.lfgCardId, 'lfg-1');
    expect(card.sport, Sport.pickleball);
    expect(card.remainingSlots, 2);
    expect(card.skillLevel, 'Trung bình');
  });

  test('lỗi BE (gửi quá nhanh, AI quá tải) thành AiChatException kèm message', () async {
    server.routes['POST ${ApiAiChatRepository.chatPath}'] = (
      429,
      {'statusCode': 429, 'message': 'Bạn gửi câu hỏi quá nhanh, vui lòng đợi khoảng 1 phút rồi thử lại', 'data': null},
    );

    expect(
      () => repo.send('alo'),
      throwsA(isA<AiChatException>().having((e) => e.message, 'message', contains('quá nhanh'))),
    );
  });

  test('xoá phiên gọi DELETE đúng đường dẫn', () async {
    server.routes['DELETE ${ApiAiChatRepository.sessionPath('s-1')}'] = (200, _ok(null));
    await repo.deleteSession('s-1');
    expect(server.requests.single.path, ApiAiChatRepository.sessionPath('s-1'));
  });

  test('định dạng thật: phần liệt kê nằm giữa câu dẫn và câu kết thì bị bỏ, giữ hai câu', () {
    final m = AiMessage(
      id: 'm',
      sender: AiSender.bot,
      createdAt: DateTime(2026),
      text:
          'Mình tìm được 1 cơ sở còn ca trống:\n'
          '1. Hà Nội Badminton Center - 36 Trần Duy Hưng (Cầu lông, từ 1.000đ/giờ)\n'
          '   • Sân lucky: 06:00-07:00 31/10 - 1.000đ\n'
          '   • Sân 2: 06:00-07:00 31/10 - 100.000đ\n'
          '\n'
          'Bạn chọn ca muốn đặt bên dưới nhé.',
      facilities: const [AiFacilitySuggestion(facilityId: 'f', facilityName: 'Hà Nội Badminton Center')],
    );
    expect(m.displayText, 'Mình tìm được 1 cơ sở còn ca trống:\n\nBạn chọn ca muốn đặt bên dưới nhé.');
  });
}
