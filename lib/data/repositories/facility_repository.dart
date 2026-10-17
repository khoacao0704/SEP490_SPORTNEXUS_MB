import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/facility_search.dart';
import '../../models/sport.dart';
import '../../models/time_slot.dart';

/// Lỗi nghiệp vụ khi tìm sân / giữ chỗ; [message] sẵn sàng để hiển thị.
class FacilityException implements Exception {
  final String message;

  const FacilityException(this.message);

  @override
  String toString() => 'FacilityException: $message';
}

abstract class FacilityRepository {
  /// false: không lọc được theo tỉnh/quận (UI ẩn bộ lọc khu vực, [getDistricts] trả rỗng).
  bool get supportsAreaFilter;

  Future<List<FacilitySearchResult>> searchFacilities(FacilitySearchQuery query);

  /// Các quận/huyện trong [city] đang có cơ sở hoạt động (dùng cho bộ lọc).
  Future<List<String>> getDistricts(String city);

  Future<Facility> getFacility(String facilityId);

  /// Các khung giờ chủ sân đã cấu hình cho loại sân [courtType] của [sport] trong ngày [date],
  /// trên TỪNG sân con (sắp theo sân rồi theo giờ), kèm trạng thái còn trống.
  /// Bỏ trống [courtType] thì dùng loại sân rẻ nhất của môn.
  Future<List<TimeSlot>> getTimeSlots(String facilityId, Sport sport, DateTime date, {CourtType? courtType});

  /// Giữ đúng sân con của mỗi khung giờ trong [slots] tối đa 10 phút để thanh toán.
  /// Giữ theo kiểu "tất cả hoặc không": chỉ cần 1 khung vừa có người đặt / đã bắt đầu
  /// thì không giữ khung nào và ném [FacilityException] nêu rõ khung đó.
  Future<SlotHold> holdSlots(List<TimeSlot> slots);

  /// Nhả toàn bộ chỗ đang giữ của [holdId] (người dùng quay lại hoặc hết giờ).
  Future<void> releaseHold(String holdId);

  /// Chuyển chỗ đang giữ sang một lượt giữ mới tới [until] (vd. chờ nhóm chia tiền 30 phút,
  /// hoặc giữ hẳn khi đặt thành công). Có [slotIds] thì chỉ chuyển các khung đó (mỗi khung một lượt đặt),
  /// các khung còn lại vẫn ở lượt giữ cũ. Các khung đã chuyển không bị ảnh hưởng khi nhả [holdId].
  Future<SlotHold> transferHold(String holdId, {required DateTime until, List<String>? slotIds});
}
