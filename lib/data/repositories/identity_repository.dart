import '../../models/identity_verification.dart';

class IdentityException implements Exception {
  final String message;

  const IdentityException(this.message);

  @override
  String toString() => message;
}

/// Xác minh danh tính (eKYC), dùng chung Owner và Player. Admin duyệt tay.
abstract class IdentityRepository {
  /// Hồ sơ gần nhất; `null` = chưa gửi.
  Future<IdentityVerification?> getMyVerification();

  /// Tải một ảnh (JPG/PNG/WEBP ≤5MB) lên kho riêng tư, trả URL để gửi kèm hồ sơ.
  Future<String> uploadImage(String filePath);

  /// Gửi (hoặc gửi lại khi bị từ chối) hồ sơ. Đang chờ duyệt thì BE trả lỗi.
  Future<IdentityVerification> submit(IdentitySubmission submission);
}
