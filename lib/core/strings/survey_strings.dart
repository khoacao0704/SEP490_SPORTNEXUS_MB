/// Chuỗi hiển thị cho khảo sát người chơi (hồ sơ thể thao).
class SurveyStrings {
  SurveyStrings._();

  static const String title = 'Khảo sát người chơi';
  static const String editTitle = 'Hồ sơ thể thao';
  static const String profileMenu = 'Hồ sơ thể thao';
  static const String intro =
      'Cho SportNexus biết bạn chơi môn gì, trình độ và lịch rảnh để gợi ý kèo, đồng đội phù hợp. '
      'Bạn cần hoàn thành khảo sát trước khi dùng app.';
  static const String requiredNote = 'Cần hoàn thành khảo sát để tiếp tục';
  static const String loading = 'Đang tải hồ sơ thể thao…';
  static const String loadError = 'Không tải được khảo sát. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
  static const String logout = 'Đăng xuất';

  static String step(int current, int total) => 'Bước $current/$total';
  static const String next = 'TIẾP TỤC';
  static const String back = 'Quay lại';
  static const String finish = 'HOÀN THÀNH';
  static const String save = 'LƯU';
  static const String saved = 'Đã lưu hồ sơ thể thao';
  static const String completed = 'Cảm ơn bạn đã hoàn thành khảo sát!';

  // Bước 1: môn
  static const String sportsTitle = 'Bạn chơi môn nào?';
  static const String sportsHint = 'Chọn ít nhất 1 môn, rồi chọn trình độ của bạn ở từng môn.';
  static const String level = 'Trình độ';
  static const String formats = 'Nội dung hay chơi (không bắt buộc)';
  static const String needSport = 'Vui lòng chọn ít nhất 1 môn';
  static String sportUnavailable(String sport) => 'Môn $sport chưa có trên hệ thống. Vui lòng bỏ chọn môn này.';

  // Bước 2: lịch rảnh
  static const String availabilityTitle = 'Bạn thường rảnh lúc nào?';
  static const String availabilityHint = 'Thêm các khung giờ trong tuần bạn có thể chơi (ít nhất 1 khung).';
  static const String addWindow = 'Thêm khung giờ';
  static const String days = 'Ngày trong tuần';
  static const String from = 'Từ';
  static const String to = 'Đến';
  static const String add = 'Thêm';
  static const String cancel = 'Huỷ';
  static const String needWindow = 'Vui lòng thêm ít nhất 1 khung giờ rảnh';
  static const String needDay = 'Chọn ít nhất 1 ngày';
  static const String endAfterStart = 'Giờ kết thúc phải sau giờ bắt đầu';
  static const String windowOverlap = 'Khung giờ bị trùng với khung đã có';
  static String tooManyWindows(int max) => 'Tối đa $max khung giờ';
  static const String noWindows = 'Chưa có khung giờ nào';

  // Bước 3: khu vực & giá
  static const String areaTitle = 'Khu vực & mức giá';
  static const String areaHint = 'Dùng để gợi ý sân và kèo gần bạn (không bắt buộc).';
  static const String useLocation = 'Dùng vị trí hiện tại';
  static const String locating = 'Đang lấy vị trí…';
  static const String locationSet = 'Đã lưu vị trí của bạn';
  static const String clearLocation = 'Bỏ vị trí';
  static const String locationFailed = 'Không lấy được vị trí. Bạn có thể bỏ qua bước này.';
  static String radius(int km) => 'Bán kính tìm: $km km';
  static const String maxPrice = 'Giá sân tối đa mỗi giờ';
  static const String noPriceLimit = 'Không giới hạn';

  // Bước 4: mục tiêu
  static const String goalTitle = 'Mục tiêu & thói quen';
  static const String goal = 'Mục tiêu chơi';
  static const String frequency = 'Tần suất chơi';
  static const String gender = 'Giới tính (không bắt buộc)';
  static const String needGoal = 'Vui lòng chọn mục tiêu và tần suất chơi';
}
