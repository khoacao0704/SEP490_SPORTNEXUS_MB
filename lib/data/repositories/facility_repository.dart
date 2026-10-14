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
  Future<List<FacilitySearchResult>> searchFacilities(FacilitySearchQuery query);

  /// Các quận/huyện trong [city] đang có cơ sở hoạt động (dùng cho bộ lọc).
  Future<List<String>> getDistricts(String city);

  Future<Facility> getFacility(String facilityId);

  /// Các khung giờ chủ sân đã cấu hình cho [sport] trong ngày [date], kèm số sân còn trống.
  Future<List<TimeSlot>> getTimeSlots(String facilityId, Sport sport, DateTime date);

  /// Giữ 1 sân trong khung giờ [slot] tối đa 10 phút để thanh toán.
  /// Ném [FacilityException] nếu khung giờ vừa hết sân.
  Future<SlotHold> holdSlot(TimeSlot slot);

  /// Nhả chỗ đang giữ (người dùng quay lại hoặc hết giờ).
  Future<void> releaseHold(String holdId);
}
