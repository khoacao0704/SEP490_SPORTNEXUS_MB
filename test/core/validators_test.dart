import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/strings/auth_strings.dart';
import 'package:test1/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('chấp nhận email hợp lệ', () {
      expect(Validators.email('player@sportnexus.vn'), isNull);
      expect(Validators.email('  a.b+c@fpt.edu.vn  '), isNull);
    });

    test('từ chối email sai định dạng hoặc rỗng', () {
      expect(Validators.email(''), AuthStrings.requiredField);
      expect(Validators.email('player@'), AuthStrings.invalidEmail);
      expect(Validators.email('player.sportnexus.vn'), AuthStrings.invalidEmail);
    });
  });

  group('Validators.phone', () {
    test('chấp nhận số di động Việt Nam', () {
      expect(Validators.phone('0901234567'), isNull);
      expect(Validators.phone('+84901234567'), isNull);
      expect(Validators.phone('0381234567'), isNull);
    });

    test('từ chối số sai đầu số hoặc sai độ dài', () {
      expect(Validators.phone('0101234567'), AuthStrings.invalidPhone);
      expect(Validators.phone('090123456'), AuthStrings.invalidPhone);
      expect(Validators.phone('09012345678'), AuthStrings.invalidPhone);
    });
  });

  test('Validators.emailOrPhone chấp nhận cả hai loại', () {
    expect(Validators.emailOrPhone('player@sportnexus.vn'), isNull);
    expect(Validators.emailOrPhone('0901234567'), isNull);
    expect(Validators.emailOrPhone('khoa'), AuthStrings.invalidIdentifier);
  });

  group('Validators.password', () {
    test('yêu cầu tối thiểu 8 ký tự, có chữ và số', () {
      expect(Validators.password('Player@123'), isNull);
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.password('abc123'), AuthStrings.invalidPassword);
      expect(Validators.password('abcdefgh'), AuthStrings.invalidPassword);
      expect(Validators.password('12345678'), AuthStrings.invalidPassword);
    });
  });

  test('Validators.confirmPassword so khớp với mật khẩu gốc', () {
    final validator = Validators.confirmPassword(() => 'Player@123');
    expect(validator('Player@123'), isNull);
    expect(validator('Player@124'), AuthStrings.passwordMismatch);
    expect(validator(''), AuthStrings.requiredField);
  });
}
