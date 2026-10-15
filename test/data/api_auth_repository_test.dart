import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/api_strings.dart';
import 'package:test1/core/strings/auth_strings.dart';
import 'package:test1/core/utils/jwt_utils.dart';
import 'package:test1/data/api/api_auth_repository.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/auth_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/models/user_role.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];
  DioExceptionType? failWith;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (failWith != null) throw DioException(requestOptions: options, type: failWith!);
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

/// JWT giả (chỉ payload có ý nghĩa với app).
String _jwt({required DateTime expiresAt}) {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}.signature';
}

void main() {
  const userId = '605f68be-505e-4179-b198-95f8c2e66fb8';
  const ownerId = '1a5c617e-0ddb-44a0-ac39-2d5b3c5aaa21';
  late _FakeServer server;
  late MemoryTokenStore tokens;
  late ApiClient api;
  late ApiAuthRepository repo;
  late int unauthorizedCalls;
  final validToken = _jwt(expiresAt: DateTime.now().add(const Duration(days: 7)));

  Map<String, dynamic> account(String id, String username, String role) => {
    'id': id,
    'username': username,
    'fullName': role == 'Owner' ? 'Test Owner' : 'Test User',
    'phone': '0123456789',
    'email': '$username@example.com',
    'avatarUrl': null,
    'fairPlayScore': 100.00,
    'isActive': true,
    'roleId': '11111111-1111-1111-1111-111111111111',
    'roleName': role,
    'walletBalance': 0.00,
    'createAt': '2026-10-06T17:43:31.770215+00:00',
    'modifiedAt': null,
  };

  void loginReturns(String id, String role) {
    server.routes['POST /api/auth/login'] = (
      200,
      {
        'statusCode': 200,
        'message': 'Login successful',
        'data': {'token': validToken, 'userId': id, 'fullName': 'Test', 'role': role},
      },
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _FakeServer();
    tokens = MemoryTokenStore();
    unauthorizedCalls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    api = ApiClient(tokens: tokens, dio: dio, onUnauthorized: () => unauthorizedCalls++);
    repo = ApiAuthRepository(api: api, tokens: tokens);
  });

  group('đăng nhập', () {
    test('Người chơi: lưu token, lấy hồ sơ có gắn Bearer token, lưu phiên', () async {
      loginReturns(userId, 'Player');
      server.routes['GET /api/accounts/$userId'] = (
        200,
        {'statusCode': 200, 'message': 'Success', 'data': account(userId, 'User1', 'Player')},
      );

      final user = await repo.login(' User1 ', 'user1');

      expect(user.role, UserRole.player);
      expect(user.username, 'User1');
      expect(user.email, 'User1@example.com');
      expect(user.fairPlayScore, 100);
      expect(await tokens.read(), validToken);
      expect(server.requests.first.data, {'username': 'User1', 'password': 'user1'});
      expect(server.requests.first.headers['Authorization'], isNull);
      expect(server.requests.last.headers['Authorization'], 'Bearer $validToken');
      expect((await SessionStore.readUser())!.id, userId);
    });

    test('role "Owner" của BE là Chủ sân', () async {
      loginReturns(ownerId, 'Owner');
      server.routes['GET /api/accounts/$ownerId'] = (
        200,
        {'statusCode': 200, 'message': 'Success', 'data': account(ownerId, 'CourtOwner1', 'Owner')},
      );
      expect((await repo.login('CourtOwner1', 'x')).role, UserRole.courtOwner);
    });

    test('không lấy được hồ sơ vẫn vào app bằng thông tin từ kết quả đăng nhập', () async {
      loginReturns(ownerId, 'Owner');
      server.routes['GET /api/accounts/$ownerId'] = (500, null);
      final user = await repo.login('CourtOwner1', 'x');
      expect(user.id, ownerId);
      expect(user.role, UserRole.courtOwner);
    });

    test('sai tài khoản: báo tiếng Việt, không coi là phiên hết hạn', () async {
      server.routes['POST /api/auth/login'] = (
        401,
        {'statusCode': 401, 'message': 'Invalid username or password', 'data': null},
      );
      await expectLater(
        repo.login('User1', 'sai'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', AuthStrings.wrongCredentials)),
      );
      expect(unauthorizedCalls, 0);
      expect(await tokens.read(), isNull);
    });

    test('mất mạng / server ngủ quá lâu', () async {
      server.failWith = DioExceptionType.connectionError;
      await expectLater(
        repo.login('User1', 'x'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', ApiStrings.noConnection)),
      );
      server.failWith = DioExceptionType.receiveTimeout;
      await expectLater(
        repo.login('User1', 'x'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', ApiStrings.timeout)),
      );
    });
  });

  group('đăng ký', () {
    const request = RegisterRequest(
      username: 'nguyenvana',
      fullName: 'Nguyễn Văn A',
      email: 'a@gmail.com',
      phone: '0912345678',
      password: 'Matkhau123',
      role: UserRole.courtOwner,
    );

    test('gửi đúng dữ liệu, Chủ sân gửi role "owner"', () async {
      server.routes['POST /api/auth/register'] = (
        200,
        {'statusCode': 200, 'message': 'Registration successful', 'data': null},
      );
      await repo.register(request);
      expect(server.requests.single.data, {
        'username': 'nguyenvana',
        'password': 'Matkhau123',
        'fullName': 'Nguyễn Văn A',
        'phone': '0912345678',
        'email': 'a@gmail.com',
        'role': 'owner',
      });
    });

    test('trùng tên đăng nhập: hiện nguyên câu tiếng Việt của BE', () async {
      server.routes['POST /api/auth/register'] = (
        400,
        {'statusCode': 400, 'message': 'Tên đăng nhập đã tồn tại.', 'data': null},
      );
      await expectLater(
        repo.register(request),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Tên đăng nhập đã tồn tại.')),
      );
    });

    test('lỗi validate kiểu ProblemDetails: lấy câu lỗi đầu tiên', () async {
      server.routes['POST /api/auth/register'] = (
        400,
        {
          'title': 'One or more validation errors occurred.',
          'status': 400,
          'errors': {
            'Password': ['The Password field is required.'],
          },
        },
      );
      await expectLater(
        repo.register(request),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'The Password field is required.')),
      );
    });

    test('OTP / quên mật khẩu: báo đang phát triển', () async {
      expect(repo.supportsOtp, isFalse);
      await expectLater(
        repo.requestPasswordReset('a@gmail.com'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', AuthStrings.featureInDevelopment)),
      );
    });
  });

  group('phiên đăng nhập', () {
    Future<void> loggedIn({required String token, bool rememberMe = true}) async {
      loginReturns(userId, 'Player');
      server.routes['POST /api/auth/login'] = (
        200,
        {
          'statusCode': 200,
          'message': 'Login successful',
          'data': {'token': token, 'userId': userId, 'fullName': 'Test User', 'role': 'Player'},
        },
      );
      server.routes['GET /api/accounts/$userId'] = (
        200,
        {'statusCode': 200, 'message': 'Success', 'data': account(userId, 'User1', 'Player')},
      );
      await repo.login('User1', 'user1', rememberMe: rememberMe);
    }

    test('mở lại app: còn hạn thì vào thẳng', () async {
      await loggedIn(token: validToken);
      expect((await repo.getCurrentUser())!.username, 'User1');
    });

    test('token hết hạn hoặc không ghi nhớ: bắt đăng nhập lại và xóa phiên', () async {
      await loggedIn(token: _jwt(expiresAt: DateTime.now().subtract(const Duration(minutes: 1))));
      expect(await repo.getCurrentUser(), isNull);
      expect(await tokens.read(), isNull);
      expect(await SessionStore.readUser(), isNull);

      await loggedIn(token: validToken, rememberMe: false);
      expect(await repo.getCurrentUser(), isNull);
    });

    test('request có token bị 401: báo phiên hết hạn', () async {
      await tokens.write(validToken);
      server.routes['GET /api/v1/wallet'] = (
        401,
        {'statusCode': 401, 'message': 'Bạn chưa đăng nhập hoặc phiên làm việc đã hết hạn...', 'data': null},
      );
      await expectLater(api.get('/api/v1/wallet'), throwsA(isA<ApiException>()));
      expect(unauthorizedCalls, 1);
    });

    test('đăng xuất xóa token và phiên', () async {
      await loggedIn(token: validToken);
      await repo.logout();
      expect(await tokens.read(), isNull);
      expect(await repo.getCurrentUser(), isNull);
    });
  });

  test('đọc hạn token', () {
    final exp = DateTime.utc(2026, 10, 22, 10);
    expect(JwtUtils.expiry(_jwt(expiresAt: exp)), exp);
    expect(JwtUtils.isExpired(_jwt(expiresAt: exp), now: DateTime.utc(2026, 10, 22, 9)), isFalse);
    expect(JwtUtils.isExpired(_jwt(expiresAt: exp), now: DateTime.utc(2026, 10, 22, 10)), isTrue);
    expect(JwtUtils.isExpired('khong-phai-jwt'), isTrue);
  });
}
