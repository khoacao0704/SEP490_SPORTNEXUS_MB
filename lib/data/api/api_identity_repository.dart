import 'dart:io';

import '../../core/constants/identity_rules.dart';
import '../../core/strings/identity_strings.dart';
import '../../models/identity_verification.dart';
import '../repositories/identity_repository.dart';
import 'api_client.dart';

/// eKYC theo BE (AI đọc code BE 22/11/2026), dùng chung Owner và Player:
/// - GET  /api/v1/me/verification → hồ sơ gần nhất, `data = null` khi chưa gửi.
/// - POST /api/v1/me/verification/images (multipart `file`, JPG/PNG/WEBP ≤5MB) → url; kho riêng tư, KHÔNG dùng /uploads/images.
/// - POST /api/v1/me/verification {fullName, idNumber (12 số), dateOfBirth (≥18 tuổi), address?,
///   idFrontImageUrl, idBackImageUrl, selfieImageUrl}. Đang PENDING gửi lại → 400. Admin duyệt tay.
class ApiIdentityRepository implements IdentityRepository {
  final ApiClient _api;

  ApiIdentityRepository({required this._api});

  static const String verificationPath = '/api/v1/me/verification';
  static const String imagesPath = '/api/v1/me/verification/images';

  @override
  Future<IdentityVerification?> getMyVerification() async {
    final data = await _call(() => _api.get(verificationPath));
    return data is Map ? fromApi(Map<String, dynamic>.from(data)) : null;
  }

  @override
  Future<String> uploadImage(String filePath) async {
    final int size;
    try {
      size = await File(filePath).length();
    } on FileSystemException {
      throw const IdentityException(IdentityStrings.pickError);
    }
    if (size > IdentityRules.maxImageBytes) throw const IdentityException(IdentityStrings.uploadError);
    final data = await _call(() => _api.upload(imagesPath, filePath: filePath));
    final url = (data is Map ? data['url'] ?? data['imageUrl'] ?? data['secureUrl'] : data)?.toString().trim() ?? '';
    if (url.isEmpty) throw const IdentityException(IdentityStrings.uploadError);
    return url;
  }

  @override
  Future<IdentityVerification> submit(IdentitySubmission s) async {
    final data = await _call(() => _api.post(verificationPath, body: {
          'fullName': s.fullName.trim(),
          'idNumber': s.idNumber.trim(),
          'dateOfBirth': _date(s.dateOfBirth),
          if (s.address.trim().isNotEmpty) 'address': s.address.trim(),
          'idFrontImageUrl': s.idFrontImageUrl,
          'idBackImageUrl': s.idBackImageUrl,
          'selfieImageUrl': s.selfieImageUrl,
        }));
    final parsed = data is Map ? fromApi(Map<String, dynamic>.from(data)) : null;
    // BE không trả hồ sơ thì coi như vừa gửi, đang chờ duyệt.
    return parsed ??
        IdentityVerification(
          status: IdentityStatus.pending,
          fullName: s.fullName.trim(),
          idNumber: s.idNumber.trim(),
          dateOfBirth: s.dateOfBirth,
          address: s.address.trim(),
          submittedAt: DateTime.now(),
        );
  }

  static IdentityVerification? fromApi(Map<String, dynamic> json) {
    final status = IdentityStatus.fromApi(json['status'] ?? json['verificationStatus']);
    if (status == null) return null;
    return IdentityVerification(
      status: status,
      fullName: (json['fullName'] ?? '').toString(),
      idNumber: (json['idNumber'] ?? '').toString(),
      dateOfBirth: _parse(json['dateOfBirth']),
      address: (json['address'] ?? '').toString(),
      rejectReason: json['rejectReason']?.toString(),
      submittedAt: _parse(json['createdAt'] ?? json['submittedAt']),
      reviewedAt: _parse(json['reviewedAt']),
    );
  }

  static DateTime? _parse(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw IdentityException(e.message);
    }
  }
}
