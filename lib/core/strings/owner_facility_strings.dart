import '../utils/formatters.dart';

/// Chuỗi hiển thị cho quản lý cơ sở & sân của Chủ sân.
class OwnerFacilityStrings {
  OwnerFacilityStrings._();

  // Danh sách
  static const String title = 'Cơ Sở Của Tôi';
  static const String addFacility = 'Đăng cơ sở mới';
  static const String empty = 'Bạn chưa có cơ sở nào';
  static const String emptyHint = 'Đăng cơ sở kèm giấy phép kinh doanh để Admin duyệt.';
  static const String statusApproved = 'Đang hoạt động';
  static const String statusPending = 'Chờ Admin duyệt';
  static const String statusRejected = 'Bị từ chối';
  static const String statusChangePending = 'Có thay đổi chờ duyệt';
  static const String statusClosedToday = 'Tạm đóng hôm nay';
  static const String statusSuspended = 'Tạm ngưng nhận đặt';

  /// Hệ thống tự tạm ngưng khi chủ sân quá 48h chưa phản hồi khiếu nại; chỉ Admin mở lại.
  static const String suspendedBanner =
      'Cơ sở đang bị tạm ngưng nhận đặt sân vì có khiếu nại quá 48 giờ chưa được phản hồi. '
      'Người chơi vẫn thấy cơ sở nhưng không đặt sân mới được, và bạn tạm thời không đổi Điểm ra tiền được. '
      'Cơ sở chỉ được mở lại sau khi Admin xử lý xong khiếu nại.';
  static const String needsPricing = 'Chưa cài giá & khung giờ';
  static String courtsSummary(int types, int courts) => '$types loại sân • $courts sân con';

  // Chi tiết
  static const String detailTitle = 'Quản Lý Cơ Sở';
  static const String pendingBanner =
      'Hồ sơ đang chờ Admin duyệt. Sau khi được duyệt bạn mới cài giá, khung giờ và nhận đặt sân.';
  static String rejectedBanner(String reason) => 'Admin đã từ chối hồ sơ: $reason';
  static const String resubmit = 'Sửa & nộp lại';
  static const String changePendingBanner =
      'Yêu cầu đổi tên / địa chỉ / giấy phép đang chờ duyệt. Cơ sở vẫn hoạt động với thông tin hiện tại.';
  static String changeRejectedBanner(String reason) => 'Admin từ chối yêu cầu đổi thông tin: $reason';
  static const String sectionProfile = 'Thông tin cần duyệt';
  static const String sectionProfileHint = 'Đổi tên, địa chỉ hoặc giấy phép sẽ cần Admin duyệt lại.';
  static const String requestChange = 'Yêu cầu đổi';
  static const String sectionOperations = 'Thông tin vận hành';
  static const String sectionCourts = 'Loại sân, giá & khung giờ';

  // Giảm giá gói cố định hằng tuần
  static const String sectionDiscount = 'Giảm giá gói định kỳ';
  static const String discountHint =
      'Khách đặt cố định hằng tuần (từ 4 buổi) được giảm theo % này, bạn chịu phần giảm. Nhập 0 = không giảm.';
  static String discountCurrent(int percent) => percent > 0 ? 'Đang áp dụng: giảm $percent%' : 'Đang áp dụng: không giảm';
  static const String discountLabel = 'Mức giảm (0–50)';
  static const String discountOutOfRange = 'Mức giảm gói định kỳ phải từ 0 đến 50%.';
  static const String discountInvalid = 'Nhập số nguyên từ 0 đến 50.';
  static const String discountSave = 'Lưu';
  static String discountSaved(int percent) =>
      percent > 0 ? 'Đã lưu: giảm $percent% cho gói định kỳ.' : 'Đã lưu: không giảm cho gói định kỳ.';
  static const String discountRejectedTitle = 'Cơ sở sẽ chờ duyệt lại';
  static const String discountRejectedWarning =
      'Cơ sở đang bị từ chối. Lưu bất kỳ thay đổi nào (kể cả mức giảm) sẽ chuyển hồ sơ về "Chờ Admin duyệt" lại.';
  static const String discountRejectedConfirm = 'Vẫn lưu';
  static const String addCourtType = 'Thêm loại sân';
  static const String sectionClosures = 'Tạm đóng';
  static const String addClosure = 'Tạm đóng sân';
  static const String noClosures = 'Không có lịch tạm đóng.';
  static const String edit = 'Sửa';
  static const String licenseNumber = 'Số giấy phép KD';
  static const String location = 'Vị trí';
  static String openHours(String open, String close) => '$open - $close';
  static const String phone = 'Số điện thoại';
  static const String noPricing = 'Chưa cài giá';
  static String courtLine(String label, int count) => '$label • $count sân';
  static String slotLength(int minutes) => 'Khung $minutes phút';
  static String priceRange(int low, int high) =>
      low == high ? Formatters.vnd(low) : '${Formatters.vnd(low)} - ${Formatters.vnd(high)}';
  static const String lockedUntilApproved = 'Được cài sau khi Admin duyệt cơ sở.';

  // Form đăng ký
  static const String registerTitle = 'Đăng Cơ Sở Mới';
  static const String resubmitTitle = 'Sửa & Nộp Lại Hồ Sơ';
  static const String changeTitle = 'Yêu Cầu Đổi Thông Tin';
  static const String formBasic = 'Thông tin cơ sở';
  static const String name = 'Tên cơ sở';
  static const String city = 'Tỉnh / Thành phố';
  static const String ward = 'Phường / Xã';
  static const String address = 'Số nhà, tên đường';
  static const String pickLocation = 'Ghim vị trí trên bản đồ';
  static const String locationPicked = 'Đã ghim vị trí';
  static const String openTime = 'Giờ mở cửa';
  static const String closeTime = 'Giờ đóng cửa';
  static const String description = 'Mô tả (không bắt buộc)';
  static const String formCourts = 'Loại sân & số sân con';
  static const String formCourtsHint = 'Giá và khung giờ cài sau khi Admin duyệt.';
  static const String sport = 'Môn';
  static const String courtType = 'Loại sân';
  static const String courtCount = 'Số sân con';
  static const String formPhotos = 'Ảnh sân';
  static const String formLicense = 'Giấy phép kinh doanh';
  static const String licenseHint = 'Chụp rõ toàn bộ giấy phép, có thể thêm nhiều ảnh (mặt trước, mặt sau).';
  static const String addPhoto = 'Thêm ảnh';
  static const String takePhoto = 'Chụp ảnh';
  static const String fromGallery = 'Chọn từ thư viện';
  static const String pickPhotoError = 'Không mở được camera / thư viện ảnh. Hãy cấp quyền trong Cài đặt.';
  static const String submit = 'Gửi hồ sơ cho Admin duyệt';
  static const String submitChange = 'Gửi yêu cầu đổi';
  static const String submitted = 'Đã gửi hồ sơ. Admin sẽ duyệt trong thời gian sớm nhất.';
  static const String changeSubmitted = 'Đã gửi yêu cầu đổi thông tin cho Admin duyệt.';
  static const String required = 'Bắt buộc';
  static const String invalidPhone = 'Số điện thoại không hợp lệ';

  // Lỗi hồ sơ
  static const String missingLocation = 'Hãy ghim vị trí cơ sở trên bản đồ.';
  static const String missingLicenseImage = 'Hãy thêm ít nhất một ảnh giấy phép kinh doanh.';
  static const String missingPhoto = 'Hãy thêm ít nhất một ảnh sân.';
  static const String missingCourt = 'Hãy thêm ít nhất một loại sân.';
  static const String duplicateCourt = 'Loại sân này đã có trong danh sách.';
  static const String invalidHours = 'Giờ đóng cửa phải sau giờ mở cửa.';
  static const String missingInfo = 'Vui lòng nhập đủ thông tin bắt buộc.';
  static const String notApproved = 'Cơ sở chưa được duyệt nên chưa thể thay đổi mục này.';
  static const String notRejected = 'Chỉ hồ sơ bị từ chối mới được nộp lại.';
  static const String changeAlreadyPending = 'Đang có một yêu cầu đổi thông tin chờ duyệt.';
  static const String notFound = 'Không tìm thấy cơ sở.';

  // Bản đồ chọn vị trí
  static const String pickerTitle = 'Ghim Vị Trí Cơ Sở';
  static const String pickerHint = 'Chạm vào bản đồ để đặt ghim đúng cổng vào cơ sở.';
  static const String useMyLocation = 'Vị trí hiện tại';
  static const String confirmLocation = 'Xác nhận vị trí';
  static const String locationUnavailable = 'Không lấy được vị trí hiện tại.';

  // Thông tin vận hành
  static const String operationsTitle = 'Thông Tin Vận Hành';
  static const String amenities = 'Tiện ích';
  static const String addAmenity = 'Thêm tiện ích';
  static const String rules = 'Nội quy';
  static const String addRule = 'Thêm nội quy';
  static const String save = 'Lưu';
  static const String saved = 'Đã lưu thay đổi.';
  static const String add = 'Thêm';
  static const String cancel = 'Hủy';

  // Cài giá & khung giờ
  static const String pricingTitle = 'Giá & Khung Giờ';
  static const String newCourtTitle = 'Thêm Loại Sân';
  static const String slotDuration = 'Độ dài mỗi khung giờ';
  static String minutes(int m) => '$m phút';
  static const String peakHours = 'Giờ cao điểm';
  static const String peakFrom = 'Từ';
  static const String peakTo = 'Đến';
  static const String weekday = 'Thứ 2 - Thứ 6';
  static const String weekend = 'Thứ 7 - Chủ nhật';
  static const String normalPrice = 'Giá thường';
  static const String peakPrice = 'Giá cao điểm';
  static const String preview = 'Xem trước khung giờ';
  static const String previewWeekday = 'Ngày thường';
  static const String previewWeekend = 'Cuối tuần';
  static const String noSlots = 'Giờ mở cửa ngắn hơn một khung giờ.';
  static const String invalidPrice = 'Giá phải lớn hơn 0';
  static const String invalidPeak = 'Giờ cao điểm phải nằm trong giờ mở cửa và kết thúc sau khi bắt đầu.';
  static const String invalidCourtCount = 'Số sân con phải từ 1 trở lên.';
  static const String lockCourt = 'Khóa loại sân';
  static const String lockTitle = 'Khóa loại sân này?';
  static String lockMessage(String label) =>
      '$label sẽ ngừng nhận đặt cho tới khi bạn mở khóa. Dùng khi sân bỏ, chuyển mục đích khác hoặc chưa biết ngày mở lại.';
  static const String locked = 'Đã khóa';
  static const String lockedDone = 'Đã khóa loại sân.';
  static const String courtLocked = 'Loại sân này đang khóa. Hãy mở khóa trước khi chỉnh sửa.';
  static const String unlock = 'Mở khóa';
  static const String unlocked = 'Đã mở khóa loại sân.';
  static const String notLocked = 'Loại sân này không bị khóa.';
  static String lockBlocked(int n) =>
      'Còn $n lượt đặt sắp tới của loại sân này nên chưa khóa được. Hãy khóa sau khi các lượt đó kết thúc.';
  static const String courtInUse = 'Không giảm được số sân con: đang có lượt sân dùng sân con số cao hơn.';

  // Tạm đóng
  static const String closureTitle = 'Tạm Đóng Sân';
  static const String closureScope = 'Phạm vi';
  static const String wholeFacility = 'Cả cơ sở';
  static const String closureDates = 'Khoảng ngày';
  static const String chooseDates = 'Chọn ngày';
  static const String closureReason = 'Lý do (vd. bảo trì, nghỉ lễ)';
  static const String confirmClosure = 'Tạm đóng';
  static const String closureAdded = 'Đã tạm đóng sân.';
  static const String closureRemoved = 'Đã mở lại sân.';
  static const String reopen = 'Mở lại';
  static String closureBlocked(int n) =>
      'Đã có $n lượt đặt trong khoảng này nên không thể tạm đóng. Hãy chọn khoảng ngày khác.';
  static String closureRange(String from, String to) => from == to ? from : '$from - $to';

  // ---------------- Cơ sở của tôi theo Web (đợt 3) ----------------
  static const String createTitle = 'Tạo cơ sở mới';
  static const String createHint =
      'Cần hồ sơ xác minh chủ sân đã được duyệt. Cơ sở mới sẽ chờ Admin duyệt trước khi hiện với người chơi.';
  static const String editTitle = 'Sửa thông tin';
  static const String fName = 'Tên cơ sở *';
  static const String fProvince = 'Tỉnh / thành phố *';
  static const String fWard = 'Phường / xã *';
  static const String fStreet = 'Số nhà, tên đường *';
  static const String fPhone = 'Số điện thoại';
  static const String fMap = 'Vị trí sân trên bản đồ';
  static const String fMapHint = 'Bấm lên bản đồ hoặc kéo ghim để cắm cờ chọn đúng tọa độ sân.';
  static const String fPickOnMap = 'Chọn trên bản đồ';
  static const String fClearPin = 'Xóa ghim';
  static const String fLat = 'Vĩ độ';
  static const String fLng = 'Kinh độ';
  static const String fOpen = 'Giờ mở cửa';
  static const String fClose = 'Giờ đóng cửa';
  static const String fDescription = 'Giới thiệu';
  static const String fRules = 'Nội quy sân';
  static const String fAutoSlots = 'Tự sinh ca hằng ngày theo giờ mở cửa';
  static const String fDiscount = 'Giảm giá gói đặt định kỳ (%)';
  static const String fDiscountHint =
      'Từ 0 đến 50%, gợi ý 10%. Nhập 0 = không giảm. Áp dụng khi người chơi đặt cùng ca, cùng sân, cùng thứ từ 4 tuần '
      'liên tiếp. Phần giảm do chủ sân chịu, phí nền tảng tính trên số tiền sau giảm.';
  static const String fAmenities = 'Tiện ích';
  static const String createSubmit = 'Tạo cơ sở';
  static const String saveInfo = 'Lưu thông tin';
  static const String created = 'Đã tạo cơ sở, đang chờ Admin duyệt. Bạn có thể thêm ảnh và sân ngay.';
  static const String infoSaved = 'Đã lưu thông tin cơ sở.';
  static const String errName = 'Vui lòng nhập tên cơ sở.';
  static const String errAddress = 'Vui lòng chọn tỉnh / thành, phường / xã và nhập số nhà, tên đường.';
  static const String errLatLng = 'Vui lòng chọn đầy đủ cả Vĩ độ và Kinh độ, hoặc xóa tọa độ.';
  static const String errLatLngRange = 'Vĩ độ phải trong khoảng -90..90 và kinh độ trong khoảng -180..180.';
  static const String errHours = 'Giờ đóng cửa phải sau giờ mở cửa.';
  static const String errDiscount = 'Mức giảm gói định kỳ phải là số nguyên từ 0 đến 50 (%).';

  // Chi tiết
  static const String badgeApproved = 'Đã duyệt';
  static const String badgePending = 'Chờ Admin duyệt';
  static const String badgeRejected = 'Bị từ chối';
  static const String badgeLocked = 'Bị khóa';
  static String rejectReason(String r) => 'Lý do từ chối: $r';
  static String lockReason(String r) => 'Lý do khóa: $r';
  static const String infoHours = 'Giờ mở cửa';
  static const String infoPhone = 'Điện thoại';
  static const String infoArea = 'Khu vực';
  static const String infoRating = 'Đánh giá';
  static String ratingValue(double r, int n) => '${r.toStringAsFixed(1)} ★ ($n)';
  static const String noRating = 'Chưa có';
  static const String infoCourts = 'Sân con';
  static String courtsValue(int n) => '$n sân';
  static const String infoAutoSlots = 'Tự sinh ca';
  static const String on = 'Bật';
  static const String off = 'Tắt';
  static const String infoDiscount = 'Giảm gói định kỳ';
  static const String noDiscount = 'Không giảm';

  // Ảnh
  static const int maxPhotos = 10;
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  static const String photosTitle = 'Ảnh cơ sở';
  static String photosCount(int n) => '$n/$maxPhotos';
  static const String addPhotos = 'Thêm ảnh';
  static const String uploading = 'Đang tải…';
  static const String noPhotos = 'Chưa có ảnh. Ảnh đầu tiên sẽ là ảnh đại diện.';
  static const String thumbnail = 'Ảnh đại diện';
  static const String setThumbnail = 'Đặt đại diện';
  static String tooManyPhotos(int max) => 'Tối đa $max ảnh cho mỗi cơ sở.';
  static const String photoTooBig = 'Mỗi ảnh tối đa 5MB.';
  static String uploaded(int n) => 'Đã tải lên $n ảnh.';
  static const String thumbnailSet = 'Đã đặt ảnh đại diện.';
  static const String deletePhotoConfirm = 'Xóa ảnh này?';
  static const String photoDeleted = 'Đã xóa ảnh.';

  // Tiện ích
  static const String amenitiesTitle = 'Tiện ích';
  static const String undo = 'Hoàn tác';
  static const String saveAmenities = 'Lưu tiện ích';
  static const String amenitiesSaved = 'Đã cập nhật tiện ích.';
  static const String amenitiesLoadError = 'Chưa tải được danh mục tiện ích.';

  // Đóng cơ sở
  static const String closeTitle = 'Đóng cơ sở';
  static const String closeHint = 'Không đóng được khi còn đơn đặt sắp tới hoặc giải đấu chưa kết thúc.';
  static const String closeButton = 'Đóng cơ sở này';
  static String closeConfirm(String name) =>
      'Đóng cơ sở "$name"? Sân con và các ca chưa đặt trong tương lai sẽ bị xóa. Lịch sử đặt sân và đánh giá vẫn được giữ.';
  static const String closed = 'Đã đóng cơ sở.';
  static String closeBlocked(int n) => 'Cơ sở còn $n đơn đặt sắp tới, chưa đóng được.';
  static const String confirm = 'Đồng ý';
}
