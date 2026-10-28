import '../../models/court_session.dart';
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_review.dart';
import '../../models/owner_facility.dart';
import '../../models/owner_finance.dart';
import '../../models/sport.dart';

/// Lỗi nghiệp vụ phía Chủ sân; [message] sẵn sàng để hiển thị.
class OwnerException implements Exception {
  final String message;

  const OwnerException(this.message);

  @override
  String toString() => 'OwnerException: $message';
}

abstract class OwnerRepository {
  /// Các cơ sở thuộc tài khoản Chủ sân đang đăng nhập.
  Future<List<Facility>> getMyFacilities();

  /// Lượt sân bắt đầu trong ngày [day] (theo giờ máy), sắp theo giờ bắt đầu.
  /// Bỏ trống [facilityId] thì lấy tất cả cơ sở.
  Future<List<CourtSession>> getSessions({required DateTime day, String? facilityId});

  Future<CourtSession> getSession(String sessionId);

  /// Tra mã QR người chơi xuất trình. Lỗi nếu mã sai hoặc không thuộc cơ sở của Chủ sân.
  Future<TicketLookup> lookupTicket(String code);


  /// Check-in một người vào đúng sân con người chơi đã chọn lúc đặt ([CourtSession.assignedCourt]).
  Future<CourtSession> checkIn({required String sessionId, required String userId});

  /// Check-out cả lượt sân: xác nhận đã nhận đủ tiền sân, giải ngân phần escrow cho Chủ sân.
  Future<CourtSession> checkOut(String sessionId);

  // ---------------- Quản lý cơ sở & sân ----------------

  /// Tất cả cơ sở của Chủ sân, gồm cả hồ sơ chờ duyệt / bị từ chối.
  /// ([getMyFacilities] chỉ trả cơ sở đã duyệt.)
  Future<List<OwnerFacility>> getOwnerFacilities();

  Future<OwnerFacility> getOwnerFacility(String facilityId);

  Future<List<Map<String, dynamic>>> getAmenities();
  /// Đăng cơ sở mới: đủ thông tin + giấy phép, chờ Admin duyệt.
  Future<OwnerFacility> submitFacility(FacilitySubmission submission);

  /// Sửa và nộp lại hồ sơ bị từ chối.
  Future<OwnerFacility> resubmitFacility(String facilityId, FacilitySubmission submission);

  /// Cơ sở đã duyệt đổi tên / địa chỉ / giấy phép: chờ Admin duyệt lại, trong lúc chờ vẫn chạy thông tin cũ.
  Future<OwnerFacility> requestProfileChange(String facilityId, FacilityProfile profile);

  /// Giờ mở cửa, SĐT, mô tả, tiện ích, nội quy, ảnh sân: sửa tự do sau khi được duyệt.
  Future<OwnerFacility> updateOperations(String facilityId, FacilityOperations operations);

  /// Thêm loại sân mới hoặc cập nhật số sân con, giá & khung giờ (chỉ khi đã duyệt).
  Future<OwnerFacility> saveCourt(String facilityId, CourtConfig court);

  /// Khóa một loại sân (thay cho xóa; như tạm đóng chưa biết ngày mở). Lỗi nếu còn lượt đặt chưa xong.
  Future<OwnerFacility> lockCourt(String facilityId, Sport sport, CourtType courtType);

  /// Mở khóa loại sân để nhận đặt lại.
  Future<OwnerFacility> unlockCourt(String facilityId, Sport sport, CourtType courtType);

  /// Tạm đóng cả cơ sở ([sport] `null`) hoặc một loại sân. Lỗi nếu khoảng ngày đã có lượt đặt.
  Future<OwnerFacility> addClosure(
    String facilityId, {
    Sport? sport,
    CourtType? courtType,
    required DateTime from,
    required DateTime to,
    required String reason,
  });

  Future<OwnerFacility> removeClosure(String facilityId, String closureId);

  // ---------------- Doanh thu & phí duy trì ----------------
  // Ví Chủ sân (số dư, giao dịch, rút tiền) dùng WalletRepository: BE trả ví theo tài khoản đăng nhập.

  /// Doanh thu tháng chứa [month]; bỏ trống [facilityId] thì gộp tất cả cơ sở.
  Future<MonthlyRevenue> getMonthlyRevenue(DateTime month, {String? facilityId});

  /// Hóa đơn phí duy trì các tháng đã chốt, mới nhất trước.
  Future<List<ListingFeeBill>> getListingFees();

  /// Trả phí bằng số dư ví Chủ sân. (Trả bằng VietQR: nạp đúng số tiền vào ví rồi gọi hàm này.)
  /// Trả xong hóa đơn quá hạn cuối cùng thì các cơ sở hiện lại ngay.
  Future<ListingFeeBill> payListingFee(String billId);

  // ---------------- Đánh giá ----------------

  /// Đánh giá (ẩn danh) của các cơ sở đã duyệt, mới nhất trước. Gồm cả đánh giá Admin đã ẩn.
  Future<List<FacilityReview>> getFacilityReviews({String? facilityId});

  /// Đăng hoặc sửa câu trả lời công khai (mỗi đánh giá một câu).
  Future<FacilityReview> replyToReview(String reviewId, String text);

  /// Báo cáo đánh giá vi phạm lên Admin (mỗi đánh giá một lần). Chủ sân không tự xóa được.
  Future<FacilityReview> reportReview(String reviewId, ReportReason reason, {String note = ''});
}
