import 'package:flutter_test/flutter_test.dart';
import 'package:test1/models/user_role.dart';
import 'package:test1/screens/auth/role_router.dart';

void main() {
  test('app mobile chỉ cho Player và Chủ sân, chặn Admin', () {
    expect(isRoleAllowedOnMobile(UserRole.player), isTrue);
    expect(isRoleAllowedOnMobile(UserRole.courtOwner), isTrue);
    expect(isRoleAllowedOnMobile(UserRole.admin), isFalse);
  });

  test('đọc đúng role từ giá trị BE trả về', () {
    expect(UserRole.fromApi('Admin'), UserRole.admin);
    expect(UserRole.fromApi('courtowner'), UserRole.courtOwner);
    expect(UserRole.fromApi('Player'), UserRole.player);
  });
}
