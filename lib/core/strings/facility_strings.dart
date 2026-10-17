/// Chuỗi hiển thị cho tìm sân, bản đồ và chi tiết cơ sở.
class FacilityStrings {
  FacilityStrings._();

  // Tìm sân
  static const String searchTitle = 'Tìm Sân';
  static const String searchHint = 'Tìm theo tên sân, địa chỉ...';
  static const String allSports = 'Tất cả';
  static const String allDistricts = 'Tất cả quận/huyện';
  static const String listView = 'Danh sách';
  static const String mapView = 'Bản đồ';
  static const String filterTitle = 'Bộ lọc';
  static const String sortBy = 'Sắp xếp theo';
  static const String sortDistance = 'Gần nhất';
  static const String sortPrice = 'Giá thấp nhất';
  static const String sortRating = 'Đánh giá cao';
  static const String district = 'Quận / Huyện';
  static const String applyFilter = 'ÁP DỤNG';
  static const String resetFilter = 'Đặt lại';
  static const String chooseCity = 'Chọn Tỉnh / Thành phố';
  static String resultCount(int n) => '$n cơ sở phù hợp';
  static const String noResults = 'Không tìm thấy sân phù hợp';
  static const String noResultsHint = 'Thử đổi môn thể thao, khu vực hoặc từ khóa khác';
  static String priceFrom(String price) => 'Từ $price';
  static const String retry = 'Thử lại';

  // Vị trí
  static const String locating = 'Đang xác định vị trí của bạn...';
  static const String locationDenied = 'Bật quyền vị trí để xem khoảng cách và sân gần bạn';
  static const String locationServiceOff = 'GPS đang tắt. Bật GPS để xem sân gần bạn';
  static const String locationUnavailable = 'Không lấy được vị trí hiện tại';
  static const String enableLocation = 'Bật';
  static const String openSettings = 'Cài đặt';
  static const String myLocation = 'Vị trí của tôi';

  // Chi tiết cơ sở
  static const String reviews = 'đánh giá';
  static const String chooseSport = 'Chọn môn';
  static const String chooseCourtType = 'Loại sân';
  static const String holdExpired = 'Đã hết thời gian giữ chỗ. Vui lòng chọn lại khung giờ.';
  static String courtCount(int n) => '$n sân';
  static const String chooseDate = 'Chọn ngày';
  static const String chooseSlot = 'Chọn khung giờ';
  static const String noSlots = 'Không có khung giờ nào trong ngày này';
  static const String chooseCourt = 'Chọn sân';
  static String courtName(int number) => 'Sân $number';
  static String freeSlotCount(int n) => n == 0 ? 'Kín lịch' : 'Trống $n khung';
  static const String available = 'Còn trống';
  static const String full = 'Đã đặt';
  static const String passed = 'Đã qua';
  static const String today = 'Hôm nay';
  static const String openingHours = 'Giờ mở cửa';
  static const String amenities = 'Tiện ích';
  static const String rules = 'Quy định của sân';
  static const String contact = 'Liên hệ';
  static const String about = 'Giới thiệu';
  static const String location = 'Vị trí';
  static const String sameCourtsNote =
      'Bạn đặt đúng sân con đã chọn. Khi check-in, chủ sân xếp bạn vào đúng sân này.';
  static const String totalLabel = 'TỔNG TIỀN TẠM TÍNH';
  static const String selectSlotFirst = 'Chọn khung giờ để đặt sân';
  static const String multiSlotHint = 'Có thể chọn nhiều khung giờ, kể cả ở các ngày khác nhau.';
  static String selectedSlotCount(int n) => 'Đã chọn $n khung giờ';
  static const String viewSelected = 'Xem';
  static const String selectedSlotsTitle = 'Khung giờ đã chọn';
  static const String clearSelection = 'Bỏ chọn tất cả';
  static const String bookNow = 'ĐẶT SÂN';

  // Lỗi
  static const String facilityNotFound = 'Không tìm thấy cơ sở';
  static String slotJustFull(String slot) => '$slot vừa có người đặt. Vui lòng bỏ chọn khung này.';
  static String slotStarted(String slot) => 'Khung giờ $slot đã bắt đầu. Vui lòng bỏ chọn khung này.';
  static const String noSlotSelected = 'Vui lòng chọn ít nhất 1 khung giờ';
  static const String loadError = 'Không tải được dữ liệu. Vui lòng thử lại.';
  static const String featureInDevelopment = 'Chức năng đang được phát triển. Vui lòng thử lại sau.';
}
