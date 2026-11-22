import '../../core/constants/identity_rules.dart';
import '../../core/strings/identity_strings.dart';
import '../../models/identity_verification.dart';
import '../repositories/identity_repository.dart';

/// eKYC giả lập (trong bộ nhớ). Gửi xong là chờ duyệt; test dùng [approve] / [reject] thay Admin.
class MockIdentityRepository implements IdentityRepository {
  final Duration latency;
  IdentityVerification? _current;
  int _uploads = 0;

  MockIdentityRepository({this.latency = const Duration(milliseconds: 300), IdentityVerification? initial})
      : _current = initial;

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  @override
  Future<IdentityVerification?> getMyVerification() async {
    await _delay();
    return _current;
  }

  @override
  Future<String> uploadImage(String filePath) async {
    await _delay();
    return 'https://mock.sportnexus.vn/ekyc/${++_uploads}.jpg';
  }

  @override
  Future<IdentityVerification> submit(IdentitySubmission s) async {
    await _delay();
    if (_current?.status == IdentityStatus.pending) throw const IdentityException(IdentityStrings.pendingNote);
    if (!IdentityRules.isValidIdNumber(s.idNumber)) throw const IdentityException(IdentityStrings.invalidIdNumber);
    if (!IdentityRules.isAdult(s.dateOfBirth, DateTime.now())) throw const IdentityException(IdentityStrings.underAge);
    return _current = IdentityVerification(
      status: IdentityStatus.pending,
      fullName: s.fullName.trim(),
      idNumber: s.idNumber.trim(),
      dateOfBirth: s.dateOfBirth,
      address: s.address.trim(),
      submittedAt: DateTime.now(),
    );
  }

  void approve() => _current = _copy(IdentityStatus.approved);

  void reject(String reason) => _current = _copy(IdentityStatus.rejected, reason: reason);

  IdentityVerification _copy(IdentityStatus status, {String? reason}) {
    final c = _current;
    return IdentityVerification(
      status: status,
      fullName: c?.fullName ?? '',
      idNumber: c?.idNumber ?? '',
      dateOfBirth: c?.dateOfBirth,
      address: c?.address ?? '',
      rejectReason: reason,
      submittedAt: c?.submittedAt,
      reviewedAt: DateTime.now(),
    );
  }
}
