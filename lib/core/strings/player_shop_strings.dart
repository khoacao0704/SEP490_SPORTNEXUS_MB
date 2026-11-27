import '../utils/formatters.dart';

/// Chuỗi hiển thị cho shop tại sân phía người chơi + lịch sử check-in (theo Web).
class PlayerShopStrings {
  PlayerShopStrings._();

  // Mục shop ở chi tiết sân
  static const String sectionTitle = 'Shop tại sân';
  static const String sectionNote = 'Đặt trước nước, phụ kiện… nhận và trả tiền tại quầy, không trừ ví.';
  static const String myOrders = 'Đơn mua của tôi';
  static const String order = 'Đặt';
  static const String outOfStock = 'Hết hàng';
  static const String openShop = 'Đặt đồ tại sân';
  static const String shopEmpty = 'Cơ sở chưa bán sản phẩm nào.';

  // Form đặt
  static String orderTitle(String name) => 'Đặt $name';
  static String orderSubtitle(int price, int stock) =>
      '${Formatters.vnd(price)} / sản phẩm · còn $stock. Trả tiền tại quầy khi nhận hàng.';
  static const String quantity = 'Số lượng';
  static const String note = 'Ghi chú (không bắt buộc)';
  static const String noteHint = 'VD: lấy lúc 19h, sân 2';
  static String subtotal(int amount) => 'Tạm tính: ${Formatters.vnd(amount)}';
  static const String cancel = 'Hủy';
  static const String submit = 'Đặt trước';
  static const String submitting = 'Đang đặt…';
  static String ordered(int qty, String name) => 'Đã đặt $qty × $name. Nhận hàng và thanh toán tại quầy.';
  static const String orderError = 'Không đặt được sản phẩm.';

  // Đơn mua tại sân
  static const String ordersTitle = 'Đơn mua tại sân';
  static const String ordersSubtitle =
      'Sản phẩm đặt trước ở shop của cơ sở. Nhận hàng và trả tiền tại quầy, không trừ ví.';
  static const String ordersEmpty = 'Bạn chưa đặt sản phẩm nào.';
  static const String ordersEmptyHint = 'Shop mở trong chi tiết sân khi bạn có đơn đặt sân ở cơ sở đó, trước khi check-in.';
  static const String findCourt = 'Tìm sân';
  static String cancelConfirm(int qty, String name) => 'Hủy đơn $qty × $name?';
  static const String keep = 'Không';
  static const String cancelled = 'Đã hủy đơn.';
  static const String cancelError = 'Không hủy được đơn.';
  static const String loadError = 'Không tải được danh sách đơn. Vui lòng thử lại.';
  static const String retry = 'Thử lại';

  // Lỗi bản giả lập
  static const String productNotFound = 'Sản phẩm không còn bán.';
  static String quantityRange(int max) => 'Số lượng từ 1 đến $max.';
  static const String cannotCancel = 'Đơn này không còn hủy được.';

  // Lịch sử check-in
  static String historyTab(int n) => 'Lịch sử check-in ($n)';
  static const String historyTabShort = 'Lịch sử check-in';
  static const String historyEmpty = 'Bạn chưa check-in lần nào';
  static const String historyEmptyHint = 'Mỗi lần chủ sân quét vé QR của bạn sẽ được ghi lại ở đây.';
  static String historyCount(int n) => '$n lượt check-in';
  static const String late = 'Trễ';
  static String slot(String from, String to) => 'Ca $from - $to';
  static const String tournamentFallback = 'Giải đấu';
  static const String historyError = 'Không tải được lịch sử check-in.';
}
