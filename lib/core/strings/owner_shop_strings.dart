/// Chuỗi hiển thị cho Quảng bá của Chủ sân (theo Web: OwnerPromotions.jsx). Mobile chỉ làm gói cho cơ sở.
class OwnerPromoStrings {
  OwnerPromoStrings._();

  static const String title = 'Quảng bá';
  static const String subtitle = 'Đẩy cơ sở lên đầu kết quả tìm kiếm của người chơi.';
  static const String packagesTitle = 'Gói đang bán';
  static const String loadingPackages = 'Đang tải gói…';
  static const String noPackages = 'Hiện chưa có gói quảng bá nào cho cơ sở.';
  static String days(int n) => '$n ngày';
  static const String defaultDescription = 'Ưu tiên hiển thị trong kết quả tìm kiếm.';
  static const String buy = 'Mua gói';
  static const String mineTitle = 'Lượt quảng bá đã mua';
  static const String activeOnly = 'Chỉ đang chạy';
  static const String noneBought = 'Bạn chưa mua lượt quảng bá nào.';
  static const String facility = 'Cơ sở';
  static String period(String from, String to) => '$from – $to';
  static String daysLeft(int n) => 'Còn $n ngày';

  // Mua gói
  static String buyTitle(String name) => 'Mua gói $name';
  static String buySub(int days, String price) => '$days ngày • $price • trừ vào số dư ví';
  static const String noTarget = 'Bạn chưa có cơ sở nào để quảng bá.';
  static const String targetLabel = 'Cơ sở được quảng bá';
  static const String extendHint = 'Nếu mục này đang có lượt quảng bá, thời hạn sẽ được cộng nối tiếp.';
  static const String balance = 'Số dư ví hiện tại:';
  static const String notEnough = 'Số dư không đủ. Vui lòng nạp thêm hoặc chờ tiền về ví.';
  static const String cancel = 'Hủy';
  static String pay(String price) => 'Thanh toán $price';
  static String bought(String name) => 'Đã mua gói "$name".';
  static const String pickTarget = 'Vui lòng chọn mục cần quảng bá.';
  static const String packageNotFound = 'Không tìm thấy gói quảng bá.';
}

/// Chuỗi hiển thị cho Shop tại sân (theo Web: OwnerShop.jsx).
class OwnerShopStrings {
  OwnerShopStrings._();

  static const String title = 'Shop tại sân';
  static const String subtitle =
      'Bán nước, phụ kiện, thuê vợt… Khách đặt trước trên app, nhận hàng và trả tiền tại quầy (không qua ví).';
  static const String addProduct = 'Thêm sản phẩm';
  static const String tabOrders = 'Đơn của khách';
  static String tabProducts(int n) => 'Sản phẩm ($n)';
  static const String noFacility = 'Bạn cần có cơ sở đã duyệt để mở shop tại sân.';

  // Đơn
  static const String allStatus = 'Mọi trạng thái';
  static const String statusLabel = 'Trạng thái đơn';
  static const String refresh = 'Làm mới';
  static const String noOrders = 'Chưa có đơn nào.';
  static const String loading = 'Đang tải…';
  static String line(int qty, String product) => '$qty × $product';
  static String note(String n) => 'Ghi chú: $n';
  static const String collect = 'Tiền thu tại quầy';
  static const String cancelOrder = 'Hủy';
  static String cancelConfirm(int qty, String product, String customer) => 'Hủy đơn $qty × $product của $customer?';
  static const String orderUpdated = 'Đã cập nhật đơn.';
  static const String orderCancelled = 'Đã hủy đơn.';

  // Sản phẩm
  static const String noProducts = 'Chưa có sản phẩm. Bấm "Thêm sản phẩm" để bắt đầu bán.';
  static const String hidden = 'Đang ẩn';
  static String inStock(int n) => 'Còn $n';
  static const String edit = 'Sửa';
  static const String delete = 'Xóa';
  static String deleteConfirm(String name) => 'Xóa sản phẩm "$name"?';
  static const String deleted = 'Đã xóa sản phẩm.';

  // Form
  static const String editTitle = 'Sửa sản phẩm';
  static const String fName = 'Tên sản phẩm';
  static const String fNameHint = 'VD: Nước suối 500ml';
  static const String fDescription = 'Mô tả';
  static const String fPrice = 'Giá (đ)';
  static const String fStock = 'Tồn kho';
  static const String fImage = 'Ảnh';
  static const String uploadImage = 'Tải ảnh lên';
  static const String changeImage = 'Đổi ảnh';
  static const String uploading = 'Đang tải…';
  static const String fActive = 'Đang bán (khách thấy và đặt được)';
  static const String save = 'Lưu';
  static const String saving = 'Đang lưu…';
  static const String cancel = 'Hủy';
  static const String created = 'Đã thêm sản phẩm.';
  static const String updated = 'Đã cập nhật sản phẩm.';
  static const String errName = 'Nhập tên sản phẩm.';
  static const String errPrice = 'Giá không hợp lệ.';
  static const String errStock = 'Tồn kho phải là số nguyên ≥ 0.';
  static const String notFound = 'Không tìm thấy sản phẩm.';
  static const String orderNotFound = 'Không tìm thấy đơn.';
  static const String badTransition = 'Đơn này không chuyển sang trạng thái đó được.';
}
