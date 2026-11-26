import '../../models/booking.dart' show CancelReason;
import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_review.dart';
import '../../models/owner_booking.dart';
import '../../models/owner_court.dart';
import '../../models/owner_facility.dart';
import '../../models/owner_finance.dart';
import '../../models/sport.dart';

/// Lỗi nghiệp vụ phía Chủ sân; [message] sẵn sàng để hiển thị.
class OwnerException implements Exception {
  final String message;

  /// BE chưa có API này (404 / 405): màn hiện "đang chờ hệ thống cập nhật" thay vì báo lỗi.
  final bool unavailable;

  const OwnerException(this.message, {this.unavailable = false});

  @override
  String toString() => 'OwnerException: $message';
}

abstract class OwnerRepository {
  /// Các cơ sở thuộc tài khoản Chủ sân đang đăng nhập.
  Future<List<Facility>> getMyFacilities();

  // ---------------- Vận hành: đơn, lịch, check-in (giống Web) ----------------

  /// GET /bookings/owner: lọc theo ngày ([date]) hoặc khoảng ngày, trạng thái, tên / SĐT khách.
  Future<OwnerBookingPage> getBookings({
    required String facilityId,
    DateTime? date,
    DateTime? from,
    DateTime? to,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 15,
  });

  Future<OwnerBooking> getBooking(String bookingId);

  /// Lưới lịch một ngày: mọi sân con và ca của cơ sở.
  Future<FacilityDaySchedule> getDaySchedule(String facilityId, DateTime date);

  /// Nhận khách vãng lai tại quầy.
  Future<void> createWalkIn(WalkInRequest request);

  /// Check-in thủ công cả nhóm của đơn (khách quên vé QR).
  Future<void> checkInBooking(String bookingId);

  /// Kết thúc ca sớm: check-out mọi người chơi đang trong sân, không hoàn tiền phần còn lại.
  Future<void> endBooking(String bookingId);

  /// Khóa (bảo trì) hoặc mở lại một ca trống.
  Future<void> setSlotLocked(String slotId, {required bool locked});

  /// Đổi giá một ca trống (tối thiểu 1.000 Điểm).
  Future<void> setSlotPrice(String slotId, int price);

  /// Quét mã QR vé tại cơ sở: quét là check-in luôn.
  Future<ScanResult> scanQr({required String facilityId, required String qrCode});

  /// Lý do hủy đơn (dùng chung danh sách với người chơi, như Web).
  Future<List<CancelReason>> getCancelReasons();

  /// Chủ sân hủy đơn của khách (xem [OwnerCancelRules]).
  /// [lockSlot]: true thì ca sân chuyển sang Bảo trì, false thì mở lại cho người khác đặt.
  Future<OwnerCancelResult> cancelBooking(String bookingId, {int? reasonCode, String? reason, bool lockSlot = false});

  // ---------------- Quản lý cơ sở & sân ----------------

  /// Tất cả cơ sở của Chủ sân, gồm cả hồ sơ chờ duyệt / bị từ chối.
  /// ([getMyFacilities] chỉ trả cơ sở đã duyệt.)
  Future<List<OwnerFacility>> getOwnerFacilities();

  Future<OwnerFacility> getOwnerFacility(String facilityId);

  /// Danh mục tiện ích (master-data/amenities).
  Future<List<FacilityAmenity>> getAmenities();

  /// Tỉnh / thành và phường / xã để chọn địa chỉ (lưu bằng mã).
  Future<List<AreaOption>> getProvinces();

  Future<List<AreaOption>> getWards(String provinceCode);

  // ---------------- Cơ sở của tôi (giống Web) ----------------

  /// Tạo cơ sở mới: chờ Admin duyệt; thêm ảnh và sân ngay được.
  Future<OwnerFacility> createFacility(FacilityInput input);

  /// Lưu thông tin cơ sở (tiện ích, ảnh sửa riêng).
  Future<OwnerFacility> updateFacility(String facilityId, FacilityInput input);

  /// Đóng cơ sở: sân con và ca chưa đặt trong tương lai bị xóa; lịch sử đặt và đánh giá giữ lại.
  Future<void> deleteFacility(String facilityId);

  /// Tải ảnh (đường dẫn trong máy) lên cơ sở.
  Future<void> uploadFacilityPhotos(String facilityId, List<String> filePaths);

  Future<void> deleteFacilityPhoto(String facilityId, String photoId);

  Future<void> setFacilityThumbnail(String facilityId, String photoId);

  Future<void> updateFacilityAmenities(String facilityId, List<String> amenityIds);

  /// % giảm gói cố định hằng tuần (0–50, 0 = không giảm). Cơ sở đang bị từ chối: lưu xong BE tự chuyển về chờ duyệt lại.
  Future<OwnerFacility> updateRecurringDiscount(String facilityId, int percent);

  // ---------------- Sân & giá, Ca sân (giống Web) ----------------

  /// Môn thể thao để chọn khi thêm sân.
  Future<List<SportCategory>> getSports();

  Future<List<OwnerCourt>> getCourts(String facilityId);

  /// Chi tiết sân: thêm số ca trống 7 ngày tới, khoảng giá sắp tới.
  Future<OwnerCourt> getCourt(String facilityId, String courtId);

  Future<void> createCourt(String facilityId, CourtInput input);

  /// [previous] để gửi "" / 0 / clearIsIndoor khi xóa giá trị cũ (như Web).
  Future<void> updateCourt(String facilityId, OwnerCourt previous, CourtInput input);

  /// Xóa sân và các ca tương lai chưa có người đặt; trả số ca đã xóa.
  Future<int> deleteCourt(String facilityId, String courtId);

  /// Xóa ca trống từ ngày mai rồi sinh lại theo cấu hình mới của sân (ca có khách giữ nguyên).
  Future<void> regenerateCourtSlots(String courtId);

  /// Giờ mở / đóng cửa của cơ sở ("HH:mm").
  Future<void> updateOpenHours(String facilityId, {required String openTime, required String closeTime});

  /// Lịch 7 ngày (hoặc khoảng ngày bất kỳ).
  Future<SlotsRange> getSlotsRange(String facilityId, {required DateTime from, required DateTime to});

  /// Số ca khách đặt được hôm nay.
  Future<FacilityAvailability> getAvailability(String facilityId, DateTime date);

  /// Sinh ca hàng loạt; một sân thì gọi theo sân, nhiều sân / tất cả thì theo cơ sở.
  Future<List<GenerateResultRow>> generateSlots(String facilityId, GenerateSlotsRequest request, {Map<String, String> courtNames});

  Future<BulkSlotResult> bulkSlots(String facilityId, BulkSlotRequest request);

  Future<void> deleteSlot(String slotId);

  /// Đợt giá đặc biệt từ [from] trở đi. BE chưa có API thì ném [OwnerException.unavailable].
  Future<List<PricePeriod>> getPricePeriods(String facilityId, {DateTime? from, DateTime? to});

  Future<PricePeriodResult> savePricePeriod(String facilityId, PricePeriod period);

  Future<void> deletePricePeriod(String facilityId, String periodId);

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
  // Ví Chủ sân (số dư, giao dịch, đổi Điểm ra tiền) dùng WalletRepository: BE trả ví theo tài khoản đăng nhập.

  /// Doanh thu tháng chứa [month]; bỏ trống [facilityId] thì gộp tất cả cơ sở.
  Future<MonthlyRevenue> getMonthlyRevenue(DateTime month, {String? facilityId});

  /// Hóa đơn phí duy trì các tháng đã chốt, mới nhất trước.
  Future<List<ListingFeeBill>> getListingFees();

  /// Trả phí bằng số dư ví Chủ sân. (Trả bằng VietQR: nạp đúng số tiền vào Ví điểm rồi gọi hàm này.)
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
