import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/api_strings.dart';
import '../../core/strings/auth_strings.dart';
import '../../core/strings/profile_strings.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../repositories/auth_repository.dart';
import '../session_store.dart';

/// Bản giả lập [AuthRepository] khi chưa nối API.
///
/// Tài khoản demo (Admin chỉ dùng Web Portal nên không có ở đây):
/// - player@sportnexus.vn     / 0901234567 / Player@123
/// - restricted@sportnexus.vn / 0908888888 / Player@123  (Fair Play 25: bị chặn LFG)
/// - owner@sportnexus.vn      / 0907654321 / Owner@123
///
/// Mã OTP luôn là [mockOtp]. Tài khoản đăng ký mới được lưu vào SharedPreferences.
class MockAuthRepository implements AuthRepository {
  static const String mockOtp = '123456';

  // Key phiên đăng nhập. 3 key đầu được các màn hình cũ đọc trực tiếp, giữ nguyên tên.
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserName = 'user_name';
  static const String keyUserRole = 'user_role';
  static const String keyCurrentUser = 'current_user';
  static const String keyRememberMe = 'remember_me';
  static const String keyAccounts = 'mock_accounts';

  /// Giả lập độ trễ mạng; test truyền `Duration.zero`.
  final Duration latency;

  MockAuthRepository({this.latency = const Duration(milliseconds: 800)});

  final Map<String, String> _resetTokens = {};
  List<_MockAccount>? _accounts;

  /// Tài khoản demo có Fair Play dưới 30 để thử chặn LFG.
  static const String restrictedPlayerId = 'u-player-002';

  /// Tài khoản Chủ sân demo, sở hữu các cơ sở trong MockOwnerRepository.
  static const String ownerId = 'u-owner-001';

  static final List<_MockAccount> _seedAccounts = [
    _MockAccount(
      user: const AppUser(
        id: 'u-player-001',
        username: 'player1',
        fullName: 'Khoa Cao',
        email: 'player@sportnexus.vn',
        phone: '0901234567',
        role: UserRole.player,
        fairPlayScore: 93,
      ),
      password: 'Player@123',
      verified: true,
    ),
    _MockAccount(
      user: const AppUser(
        id: restrictedPlayerId,
        username: 'player2',
        fullName: 'Trần Văn Bình',
        email: 'restricted@sportnexus.vn',
        phone: '0908888888',
        role: UserRole.player,
        fairPlayScore: 25,
      ),
      password: 'Player@123',
      verified: true,
    ),
    _MockAccount(
      user: const AppUser(
        id: ownerId,
        username: 'owner1',
        fullName: 'Chủ Sân Demo',
        email: 'owner@sportnexus.vn',
        phone: '0907654321',
        role: UserRole.courtOwner,
      ),
      password: 'Owner@123',
      verified: true,
    ),
  ];

  @override
  bool get supportsOtp => true;

  @override
  Future<AppUser> login(String identifier, String password, {bool rememberMe = true}) async {
    await _delay();
    final account = _findByIdentifier(await _loadAccounts(), identifier);
    if (account == null || account.password != password) {
      throw const AuthException(AuthStrings.wrongCredentials);
    }
    if (!account.verified) {
      throw const AuthException(AuthStrings.accountNotVerified, needsVerification: true);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsLoggedIn, true);
    await prefs.setString(keyUserName, account.user.fullName);
    await prefs.setString(keyUserRole, account.user.role.apiValue);
    await prefs.setString(keyCurrentUser, jsonEncode(account.user.toJson()));
    await prefs.setBool(keyRememberMe, rememberMe);
    return account.user;
  }

  /// Tạo tài khoản chưa xác thực; mã OTP luôn là [mockOtp] nên không trả devOtp.
  @override
  Future<String?> register(RegisterRequest request) async {
    await _delay();
    final accounts = await _loadAccounts();
    final email = _normalizeEmail(request.email);
    final phone = _normalizePhone(request.phone);

    // Tài khoản chưa xác thực được phép đăng ký lại (ghi đè).
    accounts.removeWhere((a) => !a.verified && (a.user.email == email || a.user.phone == phone));
    if (accounts.any((a) => a.user.email == email)) {
      throw const AuthException(AuthStrings.emailTaken);
    }
    if (accounts.any((a) => a.user.phone == phone)) {
      throw const AuthException(AuthStrings.phoneTaken);
    }
    if (accounts.any((a) => a.user.username == request.username.trim())) {
      throw const AuthException(AuthStrings.usernameTaken);
    }

    accounts.add(_MockAccount(
      user: AppUser(
        id: 'u-${DateTime.now().millisecondsSinceEpoch}',
        username: request.username.trim(),
        fullName: request.fullName.trim(),
        email: email,
        phone: phone,
        role: request.role,
      ),
      password: request.password,
      verified: false,
    ));
    await _saveAccounts();
    return null;
  }

  @override
  Future<void> verifyRegisterOtp(String phone, String otp) async {
    await _delay();
    final account = _findByPhone(await _loadAccounts(), phone);
    if (account == null) throw const AuthException(AuthStrings.phoneNotFound);
    if (otp != mockOtp) throw const AuthException(AuthStrings.wrongOtp);
    account.verified = true;
    await _saveAccounts();
  }

  @override
  Future<String?> requestPasswordReset(String phone) async {
    await _delay();
    final account = _findByPhone(await _loadAccounts(), phone);
    if (account == null || !account.verified) {
      throw const AuthException(AuthStrings.phoneNotFound);
    }
    return null;
  }

  @override
  Future<String> verifyResetOtp(String phone, String otp) async {
    await _delay();
    if (otp != mockOtp) throw const AuthException(AuthStrings.wrongOtp);
    final token = 'reset-${DateTime.now().millisecondsSinceEpoch}';
    _resetTokens[_normalizePhone(phone)] = token;
    return token;
  }

  @override
  Future<void> resetPassword(String phone, String resetToken, String newPassword) async {
    await _delay();
    final key = _normalizePhone(phone);
    final account = _findByPhone(await _loadAccounts(), key);
    if (account == null || _resetTokens[key] != resetToken) {
      throw const AuthException(AuthStrings.sessionExpired);
    }
    account.password = newPassword;
    _resetTokens.remove(key);
    await _saveAccounts();
  }

  @override
  Future<String?> resendOtp(String phone, OtpPurpose purpose) async {
    await _delay();
    return null;
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(keyIsLoggedIn) ?? false;
    final rememberMe = prefs.getBool(keyRememberMe) ?? true;
    final raw = prefs.getString(keyCurrentUser);

    if (!isLoggedIn || raw == null) return null;
    if (!rememberMe) {
      await logout();
      return null;
    }
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await logout();
      return null;
    }
  }

  @override
  Future<void> logout({bool revoke = true}) async {
    // Chỉ xóa dữ liệu phiên; giữ lại ví, lịch đặt và tài khoản giả lập.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyIsLoggedIn);
    await prefs.remove(keyUserName);
    await prefs.remove(keyUserRole);
    await prefs.remove(keyCurrentUser);
    await prefs.remove(keyRememberMe);
  }

  // ---------------- Hồ sơ ----------------

  /// Tài khoản của phiên đang đăng nhập.
  Future<_MockAccount> _me() async {
    final current = await SessionStore.readUser();
    final account = current == null
        ? null
        : (await _loadAccounts()).where((a) => a.user.id == current.id).firstOrNull;
    if (account == null) throw const AuthException(ApiStrings.sessionExpired);
    return account;
  }

  Future<AppUser> _update(AppUser Function(AppUser) change) async {
    await _delay();
    final account = await _me();
    account.user = change(account.user);
    await _saveAccounts();
    await SessionStore.save(account.user, rememberMe: await SessionStore.rememberMe());
    return account.user;
  }

  @override
  Future<AppUser> getProfile() => _update((u) => u);

  @override
  Future<AppUser> updateFullName(String fullName) {
    final name = fullName.trim();
    if (name.isEmpty) throw const AuthException(AuthStrings.requiredField);
    return _update((u) => u.copyWith(fullName: name));
  }

  /// Bản giả lập lưu đường dẫn ảnh trong máy thay cho URL Cloudinary.
  @override
  Future<AppUser> uploadAvatar(String filePath) => _update((u) => u.copyWith(avatarUrl: filePath));

  @override
  Future<AppUser> removeAvatar() => _update((u) => u.copyWith(clearAvatar: true));

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _delay();
    final account = await _me();
    if (account.password != oldPassword) throw const AuthException(ProfileStrings.wrongOldPassword);
    if (newPassword != confirmPassword) throw const AuthException(ProfileStrings.confirmMismatch);
    if (newPassword == oldPassword) throw const AuthException(ProfileStrings.samePassword);
    account.password = newPassword;
    await _saveAccounts();
    await logout();
  }

  @override
  Future<void> deleteAccount({required String password, String? reason}) async {
    await _delay();
    final account = await _me();
    if (account.password != password) throw const AuthException(ProfileStrings.wrongDeletePassword);
    _accounts!.remove(account);
    await _saveAccounts();
    await logout();
  }

  /// Tra cứu tài khoản theo email / số điện thoại (giả lập tìm đồng đội khi đăng ký giải).
  Future<AppUser?> findUser(String identifier) async => _findByIdentifier(await _loadAccounts(), identifier)?.user;

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<List<_MockAccount>> _loadAccounts() async {
    if (_accounts != null) return _accounts!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyAccounts);
    if (raw == null) {
      _accounts = _seedAccounts.map((a) => a.copy()).toList();
    } else {
      _accounts = (jsonDecode(raw) as List)
          .map((e) => _MockAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      // Bổ sung tài khoản demo mới thêm sau lần chạy trước.
      final ids = _accounts!.map((a) => a.user.id).toSet();
      _accounts!.addAll(_seedAccounts.where((s) => !ids.contains(s.user.id)).map((s) => s.copy()));
    }
    return _accounts!;
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAccounts, jsonEncode(_accounts!.map((a) => a.toJson()).toList()));
  }

  _MockAccount? _findByIdentifier(List<_MockAccount> accounts, String identifier) {
    final email = _normalizeEmail(identifier);
    final phone = _normalizePhone(identifier);
    final username = identifier.trim();
    for (final a in accounts) {
      if (a.user.email == email || a.user.phone == phone || (a.user.username.isNotEmpty && a.user.username == username)) {
        return a;
      }
    }
    return null;
  }

  _MockAccount? _findByPhone(List<_MockAccount> accounts, String phone) {
    final key = _normalizePhone(phone);
    for (final a in accounts) {
      if (a.user.phone == key) return a;
    }
    return null;
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Đưa "+84xxxxxxxxx" về dạng "0xxxxxxxxx".
  static String _normalizePhone(String phone) {
    final p = phone.trim();
    return p.startsWith('+84') ? '0${p.substring(3)}' : p;
  }
}

class _MockAccount {
  AppUser user;
  String password;
  bool verified;

  _MockAccount({required this.user, required this.password, required this.verified});

  _MockAccount copy() => _MockAccount(user: user, password: password, verified: verified);

  factory _MockAccount.fromJson(Map<String, dynamic> json) => _MockAccount(
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
        password: json['password'] as String,
        verified: json['verified'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'password': password,
        'verified': verified,
      };
}
