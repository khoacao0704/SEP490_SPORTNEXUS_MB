import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/api_strings.dart';
import 'package:test1/core/strings/auth_strings.dart';
import 'package:test1/core/strings/profile_strings.dart';
import 'package:test1/core/utils/jwt_utils.dart';
import 'package:test1/data/api/api_auth_repository.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/auth_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/user_role.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};

  /// Phản hồi lần lượt cho cùng một route (hết hàng đợi thì dùng [routes]).
  final Map<String, List<(int, Object?)>> queued = {};
  final List<RequestOptions> requests = [];
  DioExceptionType? failWith;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    await requestStream?.drain<void>(); // đọc hết body (đóng file khi upload)
    if (failWith != null) throw DioException(requestOptions: options, type: failWith!);
    final key = '${options.method} ${options.path}';
    final queue = queued[key];
    final route = queue != null && queue.isNotEmpty ? queue.removeAt(0) : routes[key];
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
    'isPhoneVerified': false,
    'createdAt': '2026-10-06T17:43:31.770215+00:00',
    'modifiedAt': null,
  };

  void meReturns(Map<String, dynamic> profile) {
    server.routes['GET /api/auth/me'] = (200, {'statusCode': 200, 'message': 'OK', 'data': profile});
  }

  void loginReturns(String id, String role) {
    server.routes['POST /api/auth/login'] = (
      200,
      {
        'statusCode': 200,
        'message': 'Login successful',
        'data': {
          'token': validToken,
          'refreshToken': 'refresh-1',
          'expiresIn': 604800,
          'userId': id,
          'username': role == 'Owner' ? 'CourtOwner1' : 'User1',
          'fullName': 'Test',
          'role': role,
          'phone': '0123456789',
          'email': 'test@example.com',
          'isPhoneVerified': false,
        },
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
    test('Người chơi: lưu cả 2 token, lấy hồ sơ qua /auth/me có gắn Bearer token, lưu phiên', () async {
      loginReturns(userId, 'Player');
      meReturns(account(userId, 'User1', 'Player'));

      final user = await repo.login(' User1 ', 'user1');

      expect(user.role, UserRole.player);
      expect(user.username, 'User1');
      expect(user.email, 'User1@example.com');
      expect(user.fairPlayScore, 100);
      expect(await tokens.read(), validToken);
      expect(await tokens.readRefreshToken(), 'refresh-1');
      expect(server.requests.last.path, '/api/auth/me');
      expect(server.requests.first.data, {'username': 'User1', 'password': 'user1'});
      expect(server.requests.first.headers['Authorization'], isNull);
      expect(server.requests.last.headers['Authorization'], 'Bearer $validToken');
      expect((await SessionStore.readUser())!.id, userId);
    });

    test('role "Owner" của BE là Chủ sân', () async {
      loginReturns(ownerId, 'Owner');
      meReturns(account(ownerId, 'CourtOwner1', 'Owner'));
      expect((await repo.login('CourtOwner1', 'x')).role, UserRole.courtOwner);
    });

    test('không lấy được hồ sơ vẫn vào app bằng thông tin từ kết quả đăng nhập', () async {
      loginReturns(ownerId, 'Owner');
      server.routes['GET /api/auth/me'] = (500, null);
      final user = await repo.login('CourtOwner1', 'x');
      expect(user.id, ownerId);
      expect(user.role, UserRole.courtOwner);
      expect(user.username, 'CourtOwner1');
      expect(user.phone, '0123456789');
      expect(user.email, 'test@example.com');
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
          'data': {'token': token, 'refreshToken': 'refresh-1', 'userId': userId, 'fullName': 'Test User', 'role': 'Player'},
        },
      );
      meReturns(account(userId, 'User1', 'Player'));
      await repo.login('User1', 'user1', rememberMe: rememberMe);
    }

    test('mở lại app: còn hạn thì vào thẳng', () async {
      await loggedIn(token: validToken);
      expect((await repo.getCurrentUser())!.username, 'User1');
    });

    test('access token hết hạn: refresh được thì vào thẳng, lưu cặp token mới', () async {
      await loggedIn(token: _jwt(expiresAt: DateTime.now().subtract(const Duration(minutes: 1))));
      server.routes['POST /api/auth/refresh-token'] = (
        200,
        {
          'statusCode': 200,
          'message': 'OK',
          'data': {'token': validToken, 'refreshToken': 'refresh-2', 'userId': userId, 'role': 'Player'},
        },
      );
      expect((await repo.getCurrentUser())!.id, userId);
      expect(server.requests.last.data, {'refreshToken': 'refresh-1'});
      expect(await tokens.read(), validToken);
      expect(await tokens.readRefreshToken(), 'refresh-2');
    });

    test('token hết hạn mà refresh bị từ chối, hoặc không ghi nhớ: bắt đăng nhập lại và xóa phiên', () async {
      await loggedIn(token: _jwt(expiresAt: DateTime.now().subtract(const Duration(minutes: 1))));
      server.routes['POST /api/auth/refresh-token'] = (
        401,
        {'statusCode': 401, 'message': 'Refresh Token không hợp lệ hoặc đã hết hạn.', 'data': null},
      );
      expect(await repo.getCurrentUser(), isNull);
      expect(await tokens.read(), isNull);
      expect(await SessionStore.readUser(), isNull);

      await loggedIn(token: validToken, rememberMe: false);
      expect(await repo.getCurrentUser(), isNull);
    });

    test('request bị 401: refresh rồi gửi lại với token mới, không đăng xuất', () async {
      await tokens.write('old-token', refreshToken: 'refresh-1');
      server.queued['GET /api/v1/wallet'] = [
        (401, {'statusCode': 401, 'message': 'Bạn chưa đăng nhập...', 'data': null}),
        (200, {'statusCode': 200, 'message': 'OK', 'data': {'balance': 0}}),
      ];
      server.routes['POST /api/auth/refresh-token'] = (
        200,
        {'statusCode': 200, 'message': 'OK', 'data': {'token': 'new-token', 'refreshToken': 'refresh-2'}},
      );

      expect(await api.get('/api/v1/wallet'), {'balance': 0});
      expect(server.requests.last.headers['Authorization'], 'Bearer new-token');
      expect(await tokens.readRefreshToken(), 'refresh-2');
      expect(unauthorizedCalls, 0);
    });

    test('nhiều request cùng bị 401 chỉ refresh một lần', () async {
      await tokens.write('old-token', refreshToken: 'refresh-1');
      server.queued['GET /a'] = [(401, null), (200, {'statusCode': 200, 'message': 'OK', 'data': 1})];
      server.queued['GET /b'] = [(401, null), (200, {'statusCode': 200, 'message': 'OK', 'data': 2})];
      server.routes['POST /api/auth/refresh-token'] = (
        200,
        {'statusCode': 200, 'message': 'OK', 'data': {'token': 'new-token', 'refreshToken': 'refresh-2'}},
      );
      expect(await Future.wait([api.get('/a'), api.get('/b')]), [1, 2]);
      expect(server.requests.where((r) => r.path == '/api/auth/refresh-token'), hasLength(1));
    });

    test('request có token bị 401 mà không refresh được (bị khóa / hết hạn): báo phiên hết hạn', () async {
      await tokens.write(validToken, refreshToken: 'refresh-1');
      server.routes['POST /api/auth/refresh-token'] = (
        403,
        {'statusCode': 403, 'message': 'Tài khoản của bạn đã bị khóa hoặc ngừng hoạt động.', 'data': null},
      );
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

  group('hồ sơ', () {
    setUp(() async {
      await tokens.write(validToken, refreshToken: 'refresh-1');
      await SessionStore.save(AppUser.fromProfileJson(account(userId, 'User1', 'Player')), rememberMe: true);
    });

    Map<String, dynamic> ok(Map<String, dynamic> profile) => {'statusCode': 200, 'message': 'OK', 'data': profile};
    Matcher authError(String message) => throwsA(isA<AuthException>().having((e) => e.message, 'message', message));

    test('tải hồ sơ: đọc ảnh, Fair Play thập phân, giờ UTC; lưu lại vào phiên', () async {
      meReturns({
        ...account(userId, 'User1', 'Player'),
        'fullName': 'Nguyễn Văn A',
        'avatarUrl': 'https://res.cloudinary.com/a.jpg',
        'fairPlayScore': 87.6,
      });
      final user = await repo.getProfile();
      expect(user.fullName, 'Nguyễn Văn A');
      expect(user.avatarUrl, 'https://res.cloudinary.com/a.jpg');
      expect(user.fairPlayScore, 88);
      expect(user.createdAt, DateTime.utc(2026, 10, 6, 17, 43, 31, 770, 215).toLocal());
      expect(user.initial, 'A');
      expect((await SessionStore.readUser())!.fullName, 'Nguyễn Văn A');
    });

    test('đổi họ tên: PUT /auth/me chỉ gửi fullName', () async {
      server.routes['PUT /api/auth/me'] = (200, ok({...account(userId, 'User1', 'Player'), 'fullName': 'Tên Mới'}));
      final user = await repo.updateFullName('  Tên Mới ');
      expect(server.requests.single.data, {'fullName': 'Tên Mới'});
      expect(user.fullName, 'Tên Mới');
      expect((await SessionStore.readUser())!.fullName, 'Tên Mới');
    });

    test('xóa ảnh: gửi avatarUrl rỗng; BE trả chuỗi rỗng thì coi là chưa có ảnh', () async {
      server.routes['PUT /api/auth/me'] = (200, ok({...account(userId, 'User1', 'Player'), 'avatarUrl': ''}));
      final user = await repo.removeAvatar();
      expect(server.requests.single.data, {'avatarUrl': ''});
      expect(user.avatarUrl, isNull);
    });

    test('tải ảnh đại diện: multipart trường "file"; ảnh quá 5MB chặn ngay trên máy', () async {
      final dir = await Directory.systemTemp.createTemp('avatar');
      addTearDown(() => dir.delete(recursive: true));
      final small = File('${dir.path}/a.jpg')..writeAsBytesSync(List.filled(1000, 1));
      server.routes['POST /api/auth/me/avatar'] =
          (200, ok({...account(userId, 'User1', 'Player'), 'avatarUrl': 'https://res.cloudinary.com/new.jpg'}));

      final user = await repo.uploadAvatar(small.path);
      final form = server.requests.single.data as FormData;
      expect(form.files.single.key, 'file');
      expect(user.avatarUrl, 'https://res.cloudinary.com/new.jpg');

      final big = File('${dir.path}/b.jpg')..writeAsBytesSync(List.filled(ApiAuthRepository.maxAvatarBytes + 1, 1));
      await expectLater(repo.uploadAvatar(big.path), authError(ProfileStrings.avatarTooLarge));
      expect(server.requests, hasLength(1));
    });

    test('đổi mật khẩu: gửi đủ 3 trường; thành công thì đăng xuất tại máy', () async {
      server.routes['POST /api/auth/change-password'] = (200, {'statusCode': 200, 'message': 'OK', 'data': null});
      await repo.changePassword(oldPassword: 'cu123456', newPassword: 'moi12345', confirmPassword: 'moi12345');
      expect(server.requests.single.data, {
        'oldPassword': 'cu123456',
        'newPassword': 'moi12345',
        'confirmPassword': 'moi12345',
      });
      expect(await tokens.read(), isNull);
      expect(await tokens.readRefreshToken(), isNull);
      expect(await SessionStore.readUser(), isNull);
    });

    test('đổi mật khẩu sai mật khẩu cũ: hiện câu của BE, vẫn giữ phiên', () async {
      server.routes['POST /api/auth/change-password'] =
          (400, {'statusCode': 400, 'message': 'Mật khẩu hiện tại không chính xác.', 'data': null});
      await expectLater(
        repo.changePassword(oldPassword: 'sai', newPassword: 'moi12345', confirmPassword: 'moi12345'),
        authError('Mật khẩu hiện tại không chính xác.'),
      );
      expect(await tokens.read(), validToken);
    });

    test('xóa tài khoản: DELETE /auth/me có body; bị chặn thì hiện câu của BE, xóa xong thì đăng xuất', () async {
      const blocked = 'Ví của bạn vẫn còn số dư. Vui lòng sử dụng hoặc rút hết tiền trước khi xóa tài khoản.';
      server.queued['DELETE /api/auth/me'] = [
        (400, {'statusCode': 400, 'message': blocked, 'data': null}),
        (200, {'statusCode': 200, 'message': 'Tài khoản của bạn đã được xóa thành công.', 'data': null}),
      ];

      await expectLater(repo.deleteAccount(password: 'matkhau1', reason: '  '), authError(blocked));
      expect(server.requests.single.data, {'password': 'matkhau1'});
      expect(await tokens.read(), validToken);

      await repo.deleteAccount(password: 'matkhau1', reason: 'Không dùng nữa');
      expect(server.requests.last.data, {'password': 'matkhau1', 'reason': 'Không dùng nữa'});
      expect(await tokens.read(), isNull);
      expect(await SessionStore.readUser(), isNull);
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
