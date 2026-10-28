import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../core/strings/api_strings.dart';
import '../../core/strings/auth_strings.dart';
import '../repositories/auth_repository.dart';
import '../repositories/phone_verifier.dart';

/// [PhoneVerifier] dùng Firebase Phone Auth. Chỉ mượn Firebase để lấy ID token chứng minh SĐT:
/// đăng nhập Firebase xong lấy token rồi đăng xuất ngay, phiên của app vẫn do BE quản lý.
class FirebasePhoneVerifier implements PhoneVerifier {
  /// BE từ chối token xác thực quá 10 phút; chừa 1 phút cho người dùng gửi form.
  static const Duration tokenLifetime = Duration(minutes: 9);

  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? _phone;
  String? _verificationId;
  int? _resendToken;
  ({String phone, String idToken, DateTime at})? _verified;
  final _events = StreamController<String>.broadcast();

  @override
  Stream<String> get verifiedPhones => _events.stream;

  @override
  bool isVerified(String phone) {
    final v = _verified;
    return v != null && v.phone == phone && DateTime.now().difference(v.at) < tokenLifetime;
  }

  @override
  Future<void> sendCode(String phone) async {
    final resendToken = phone == _phone ? _resendToken : null;
    _phone = phone;
    _verificationId = null;
    final sent = Completer<void>();
    void done([Object? error]) {
      if (sent.isCompleted) return;
      error == null ? sent.complete() : sent.completeError(error);
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _toE164(phone),
        forceResendingToken: resendToken,
        verificationCompleted: (credential) async {
          // Android tự đọc SMS / tự xác thực: lỗi thì người dùng vẫn nhập mã bằng tay.
          try {
            await _signIn(phone, credential);
          } catch (_) {}
          done();
        },
        verificationFailed: (e) => done(_error(e)),
        codeSent: (verificationId, token) {
          _verificationId = verificationId;
          _resendToken = token;
          done();
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      done(_error(e));
    }
    return sent.future;
  }

  @override
  Future<String> verifyCode(String phone, String code) async {
    final v = _verified;
    if (v != null && isVerified(phone)) return v.idToken;
    final verificationId = _verificationId;
    if (verificationId == null || phone != _phone) throw const AuthException(AuthStrings.otpExpired);
    return _signIn(phone, PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code));
  }

  @override
  void clear() {
    _verified = null;
    _verificationId = null;
  }

  Future<String> _signIn(String phone, PhoneAuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken();
      if (idToken == null) throw const AuthException(AuthStrings.phoneVerifyFailed);
      _verified = (phone: phone, idToken: idToken, at: DateTime.now());
      _events.add(phone);
      return idToken;
    } on FirebaseAuthException catch (e) {
      throw _error(e);
    } finally {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  /// 0901234567 → +84901234567.
  static String _toE164(String phone) => phone.startsWith('0') ? '+84${phone.substring(1)}' : phone;

  static AuthException _error(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return const AuthException(AuthStrings.wrongOtp);
      case 'session-expired':
      case 'code-expired':
      case 'invalid-verification-id':
        return const AuthException(AuthStrings.otpExpired);
      case 'invalid-phone-number':
        return const AuthException(AuthStrings.invalidPhone);
      case 'too-many-requests':
        return const AuthException(AuthStrings.otpTooManyRequests);
      // operation-not-allowed: chưa bật Phone / chưa cho phép khu vực VN ở "SMS region policy" của Firebase.
      case 'operation-not-allowed':
      case 'quota-exceeded':
      case 'billing-not-enabled':
        return const AuthException(AuthStrings.smsUnavailable);
      case 'network-request-failed':
        return const AuthException(ApiStrings.noConnection);
      default:
        return const AuthException(AuthStrings.phoneVerifyFailed);
    }
  }
}
