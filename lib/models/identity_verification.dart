/// Trạng thái hồ sơ xác minh danh tính (eKYC). Chưa gửi = không có hồ sơ (`null`).
enum IdentityStatus {
  /// Đã gửi, chờ Admin duyệt tay. Đang chờ thì không gửi lại được.
  pending,
  approved,

  /// Bị từ chối (có lý do), gửi lại được.
  rejected;

  static IdentityStatus? fromApi(Object? value) => switch (value?.toString().toUpperCase()) {
        'PENDING' => pending,
        'APPROVED' => approved,
        'REJECTED' => rejected,
        _ => null,
      };
}

/// Hồ sơ eKYC gần nhất của tài khoản (BE: GET /api/v1/owner/verification, dùng chung Owner và Player).
class IdentityVerification {
  final IdentityStatus status;
  final String fullName;
  final String idNumber;
  final DateTime? dateOfBirth;
  final String address;
  final String? rejectReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  const IdentityVerification({
    required this.status,
    this.fullName = '',
    this.idNumber = '',
    this.dateOfBirth,
    this.address = '',
    this.rejectReason,
    this.submittedAt,
    this.reviewedAt,
  });

  bool get isApproved => status == IdentityStatus.approved;
  bool get canResubmit => status == IdentityStatus.rejected;

  /// "0790••••1234" để hiện lại mà không lộ đủ số CCCD.
  String get maskedIdNumber =>
      idNumber.length < 8 ? idNumber : '${idNumber.substring(0, 4)}••••${idNumber.substring(idNumber.length - 4)}';
}

/// Hồ sơ gửi đi: 3 ảnh đã tải lên (URL do BE trả).
class IdentitySubmission {
  final String fullName;
  final String idNumber;
  final DateTime dateOfBirth;
  final String address;
  final String idFrontImageUrl;
  final String idBackImageUrl;
  final String selfieImageUrl;

  const IdentitySubmission({
    required this.fullName,
    required this.idNumber,
    required this.dateOfBirth,
    this.address = '',
    required this.idFrontImageUrl,
    required this.idBackImageUrl,
    required this.selfieImageUrl,
  });
}
