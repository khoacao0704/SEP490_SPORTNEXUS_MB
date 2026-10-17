import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/auth_strings.dart';
import 'package:test1/core/strings/profile_strings.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/repositories/auth_repository.dart';
import 'package:test1/models/user_role.dart';

void main() {
  late MockAuthRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = MockAuthRepository(latency: Duration.zero);
  });

  group('login', () {
    test('đăng nhập bằng email hoặc số điện thoại và trả về đúng role', () async {
      final player = await repo.login('player@sportnexus.vn', 'Player@123');
      expect(player.role, UserRole.player);

      final owner = await repo.login('+84907654321', 'Owner@123');
      expect(owner.role, UserRole.courtOwner);
    });

    test('sai mật khẩu ném AuthException', () async {
      expect(
        () => repo.login('player@sportnexus.vn', 'sai-mat-khau'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', AuthStrings.wrongCredentials)),
      );
    });

    test('ghi các key phiên mà màn hình cũ đang đọc', () async {
      await repo.login('player@sportnexus.vn', 'Player@123');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_logged_in'), isTrue);
      expect(prefs.getString('user_name'), 'Khoa Cao');
      expect(prefs.getString('user_role'), 'Player');
    });
  });

  group('phiên đăng nhập', () {
    test('ghi nhớ đăng nhập thì khôi phục được người dùng', () async {
      await repo.login('player@sportnexus.vn', 'Player@123', rememberMe: true);
      final user = await MockAuthRepository(latency: Duration.zero).getCurrentUser();
      expect(user?.email, 'player@sportnexus.vn');
    });

    test('không ghi nhớ thì lần mở sau phải đăng nhập lại', () async {
      await repo.login('player@sportnexus.vn', 'Player@123', rememberMe: false);
      expect(await MockAuthRepository(latency: Duration.zero).getCurrentUser(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_logged_in'), isNull);
    });

    test('đăng xuất giữ lại số dư ví và lịch đặt', () async {
      SharedPreferences.setMockInitialValues({
        'wallet_balance': 300000,
        'my_bookings_data': ['{}'],
      });
      await repo.login('player@sportnexus.vn', 'Player@123');
      await repo.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(await repo.getCurrentUser(), isNull);
      expect(prefs.getInt('wallet_balance'), 300000);
      expect(prefs.getStringList('my_bookings_data'), ['{}']);
    });
  });

  group('đăng ký', () {
    const request = RegisterRequest(
      username: 'nguyenvana',
      fullName: 'Nguyễn Văn A',
      email: 'NguyenA@Gmail.com',
      phone: '0912345678',
      password: 'Matkhau123',
    );

    test('chưa xác thực OTP thì chưa đăng nhập được', () async {
      await repo.register(request);
      expect(
        () => repo.login('nguyena@gmail.com', 'Matkhau123'),
        throwsA(isA<AuthException>().having((e) => e.needsVerification, 'needsVerification', isTrue)),
      );
    });

    test('sai OTP bị từ chối, đúng OTP thì đăng nhập được với role Player', () async {
      await repo.register(request);
      expect(() => repo.verifyRegisterOtp('nguyena@gmail.com', '000000'), throwsA(isA<AuthException>()));

      await repo.verifyRegisterOtp('nguyena@gmail.com', MockAuthRepository.mockOtp);
      final user = await repo.login('0912345678', 'Matkhau123');
      expect(user.role, UserRole.player);
      expect(user.fairPlayScore, 100);
    });

    test('tài khoản mới vẫn còn sau khi khởi động lại app', () async {
      await repo.register(request);
      await repo.verifyRegisterOtp('nguyena@gmail.com', MockAuthRepository.mockOtp);

      final restarted = MockAuthRepository(latency: Duration.zero);
      final user = await restarted.login('nguyena@gmail.com', 'Matkhau123');
      expect(user.fullName, 'Nguyễn Văn A');
      // Đăng nhập được bằng tên đăng nhập như BE thật.
      expect((await restarted.login('nguyenvana', 'Matkhau123')).username, 'nguyenvana');
    });

    test('đăng ký Chủ sân và trùng tên đăng nhập', () async {
      await repo.register(const RegisterRequest(
        username: 'chusanmoi',
        fullName: 'Chủ Sân Mới',
        email: 'chusan@gmail.com',
        phone: '0933334444',
        password: 'Matkhau123',
        role: UserRole.courtOwner,
      ));
      await repo.verifyRegisterOtp('chusan@gmail.com', MockAuthRepository.mockOtp);
      expect((await repo.login('chusanmoi', 'Matkhau123')).role, UserRole.courtOwner);

      expect(
        () => repo.register(const RegisterRequest(
          username: 'player1',
          fullName: 'Y',
          email: 'y@gmail.com',
          phone: '0944445555',
          password: 'Matkhau123',
        )),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', AuthStrings.usernameTaken)),
      );
    });

    test('trùng email hoặc số điện thoại đã xác thực thì báo lỗi', () async {
      expect(
        () => repo.register(const RegisterRequest(
          username: 'xuser1',
          fullName: 'X',
          email: 'player@sportnexus.vn',
          phone: '0999888777',
          password: 'Matkhau123',
        )),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', AuthStrings.emailTaken)),
      );
      expect(
        () => repo.register(const RegisterRequest(
          username: 'xuser2',
          fullName: 'X',
          email: 'moi@gmail.com',
          phone: '+84901234567',
          password: 'Matkhau123',
        )),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', AuthStrings.phoneTaken)),
      );
    });
  });

  group('quên mật khẩu', () {
    test('đặt lại mật khẩu xong thì đăng nhập bằng mật khẩu mới', () async {
      await repo.requestPasswordReset('player@sportnexus.vn');
      final token = await repo.verifyResetOtp('player@sportnexus.vn', MockAuthRepository.mockOtp);
      await repo.resetPassword('player@sportnexus.vn', token, 'MatKhauMoi1');

      expect(() => repo.login('player@sportnexus.vn', 'Player@123'), throwsA(isA<AuthException>()));
      final user = await repo.login('player@sportnexus.vn', 'MatKhauMoi1');
      expect(user.email, 'player@sportnexus.vn');
    });

    test('email chưa đăng ký thì báo lỗi', () async {
      expect(
        () => repo.requestPasswordReset('khongco@gmail.com'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', AuthStrings.emailNotFound)),
      );
    });

    test('token sai thì không cho đặt lại', () async {
      expect(
        () => repo.resetPassword('player@sportnexus.vn', 'token-gia', 'MatKhauMoi1'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('hồ sơ', () {
    setUp(() => repo.login('player@sportnexus.vn', 'Player@123'));

    test('đổi họ tên / ảnh đại diện lưu vào tài khoản và phiên; đăng nhập lại vẫn còn', () async {
      await repo.updateFullName(' Khoa Mới ');
      final user = await repo.uploadAvatar('/tmp/a.jpg');
      expect(user.fullName, 'Khoa Mới');
      expect(user.avatarUrl, '/tmp/a.jpg');
      expect((await repo.getCurrentUser())!.fullName, 'Khoa Mới');

      expect((await repo.removeAvatar()).avatarUrl, isNull);
      await repo.logout();
      expect((await repo.login('player1', 'Player@123')).fullName, 'Khoa Mới');
    });

    test('đổi mật khẩu: sai mật khẩu cũ / trùng mật khẩu cũ thì báo lỗi; thành công thì đăng xuất', () async {
      expect(
        () => repo.changePassword(oldPassword: 'sai', newPassword: 'MatKhau9', confirmPassword: 'MatKhau9'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', ProfileStrings.wrongOldPassword)),
      );
      expect(
        () => repo.changePassword(oldPassword: 'Player@123', newPassword: 'Player@123', confirmPassword: 'Player@123'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', ProfileStrings.samePassword)),
      );
      await repo.changePassword(oldPassword: 'Player@123', newPassword: 'MatKhau9', confirmPassword: 'MatKhau9');
      expect(await repo.getCurrentUser(), isNull);
      expect((await repo.login('player1', 'MatKhau9')).id, 'u-player-001');
    });

    test('xóa tài khoản: sai mật khẩu thì báo lỗi; xóa xong thì đăng xuất, không đăng nhập được nữa', () async {
      await repo.logout();
      await repo.register(const RegisterRequest(
        username: 'xoa.tk',
        fullName: 'Xóa Thử',
        email: 'xoa@gmail.com',
        phone: '0911111111',
        password: 'MatKhau9',
      ));
      await repo.verifyRegisterOtp('xoa@gmail.com', MockAuthRepository.mockOtp);
      await repo.login('xoa.tk', 'MatKhau9');

      expect(
        () => repo.deleteAccount(password: 'sai'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', ProfileStrings.wrongDeletePassword)),
      );
      await repo.deleteAccount(password: 'MatKhau9', reason: 'thử');
      expect(await repo.getCurrentUser(), isNull);
      expect(() => repo.login('xoa.tk', 'MatKhau9'), throwsA(isA<AuthException>()));
    });
  });
}
