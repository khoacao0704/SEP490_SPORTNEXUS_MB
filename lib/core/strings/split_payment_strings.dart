import '../utils/formatters.dart';

/// Chuỗi hiển thị cho chia tiền đặt sân.
class SplitPaymentStrings {
  SplitPaymentStrings._();

  // Màn thanh toán đặt sân
  static const String option = 'Chia tiền nhóm';
  static const String optionHint = 'Trả phần của bạn, chia link cho nhóm trả phần còn lại';
  static const String partsTitle = 'Chia làm mấy phần?';
  static String partsLabel(int parts) => '$parts phần';
  static String explain(int parts, int bookerAmount, int share) =>
      'Bạn trả trước ${Formatters.vnd(bookerAmount)} (1/$parts tiền sân). '
      '${parts - 1} người nhận link mỗi người trả ${Formatters.vnd(share)} trong 30 phút. '
      'Khung giờ được giữ trong thời gian này; hết 30 phút chưa đủ thì hủy đặt sân và hoàn đủ cho mọi người.';
  static String payNow(int parts) => 'Phần của bạn (1/$parts tiền sân)';

  // Danh sách & nhập mã
  static const String listTitle = 'Chia Tiền Sân';
  static const String enterCode = 'Nhập mã chia tiền';
  static const String codeHint = 'Mã 6 ký tự trong link bạn nhận được';
  static const String open = 'Mở';
  static const String mine = 'Lượt chia của tôi';
  static const String empty = 'Chưa có lượt chia tiền nào.';

  // Chi tiết
  static const String detailTitle = 'Chia Tiền Đặt Sân';
  static String bookedBy(String name) => '$name đặt sân và chia tiền';
  static String countdown(String t) => 'Còn $t để cả nhóm trả đủ';
  static String progress(int paid, int parts) => 'Đã trả $paid/$parts phần';
  static const String shareLinkTitle = 'Gửi link cho nhóm';
  static const String shareLinkNote = 'Người nhận cần có tài khoản SportNexus. Mở link hoặc nhập mã trong mục Chia Tiền Sân.';
  static const String copyLink = 'Sao chép link';
  static const String copied = 'Đã sao chép link chia tiền.';
  static const String code = 'Mã';
  static String shareRow(int index) => index == 0 ? 'Người đặt' : 'Phần ${index + 1}';
  static const String waiting = 'Chờ thanh toán';
  static const String you = '(Bạn)';
  static const String total = 'Tiền sân';
  static String yourShare(int amount) => 'Phần của bạn: ${Formatters.vnd(amount)}';
  static const String payShare = 'TRẢ PHẦN CỦA TÔI';
  static const String paymentMethod = 'Phương thức thanh toán';
  static const String payWallet = 'Ví SportNexus';
  static String balance(int amount) => 'Số dư: ${Formatters.vnd(amount)}';
  static const String payVietQr = 'Chuyển khoản VietQR';
  static const String payVietQrHint = 'Quét mã bằng app ngân hàng';
  static const String insufficient = 'Số dư ví không đủ. Hãy chọn VietQR hoặc nạp thêm tiền.';
  static const String paid = 'Bạn đã trả phần của mình.';
  static const String statusPending = 'Đang chờ nhóm thanh toán';
  static const String statusCompleted = 'Đã đủ tiền • đặt sân thành công';
  static const String statusExpired = 'Hết 30 phút chưa đủ • đã hủy và hoàn tiền';
  static const String completedNote = 'Đặt sân thành công. Mỗi khung giờ có vé QR riêng trong mục Lịch Đặt & QR.';
  static const String expiredNote = 'Đặt sân đã bị hủy, những người đã trả được hoàn đủ vào ví.';
  static const String simulateFriend = 'Giả lập bạn bè trả 1 phần';
  static const String createdMessage = 'Đã trả phần của bạn. Gửi link cho nhóm để trả nốt trong 30 phút.';
  static const String paidMessage = 'Thanh toán thành công!';

  // Mời bạn góp tiền theo tài khoản (BE thật)
  static const String inviteHint = 'Mời bạn bè bằng số điện thoại; mọi người (gồm bạn) chia đều tiền sân.';
  static const String invitePhoneHint = 'SĐT của bạn bè';
  static const String inviteAdd = 'Thêm';
  static const String inviteByLinkSoon = 'Mời bằng link chia sẻ: đang phát triển.';
  static String inviteExplain(int people, int each, int mine) =>
      'Chia $people người: mỗi bạn góp ${Formatters.vnd(each)}, bạn trả ${Formatters.vnd(mine)} ngay. '
      'Mọi người có 30 phút (không quá giờ chơi) để góp; chưa đủ thì đơn tự hủy và hoàn tiền cho người đã góp.';
  static const String invitePay = 'Phần của bạn (chia tiền nhóm)';
  static const String invitedMessage = 'Đã trả phần của bạn và gửi lời mời góp tiền.';
  static const String playerNotFound = 'Không tìm thấy tài khoản với số điện thoại này.';
  static const String inviteRequired = 'Vui lòng mời ít nhất 1 người.';
  static const String alreadyInvited = 'Người này đã có trong danh sách.';

  // Màn chia tiền của một đơn
  static const String awaiting = 'Chờ góp tiền';
  static String deadlineIn(String t) => 'Hạn góp còn $t';
  static const String deadlinePassed = 'Đã hết hạn góp: đơn sẽ tự hủy và hoàn tiền trong ít phút.';
  static const String hostLabel = 'Người đặt';
  static const String contributed = 'Đã góp';
  static const String notContributed = 'Chưa góp';
  static String payMyShare(int amount) => 'GÓP ${Formatters.vnd(amount)} TỪ VÍ';
  static const String joinedMessage = 'Đã góp phần của bạn.';
  static String payRemaining(int amount) => 'Trả nốt phần còn lại (${Formatters.vnd(amount)})';
  static const String payRemainingConfirm =
      'Bạn trả thay phần của những người chưa góp; họ sẽ bị bỏ khỏi đơn và đơn được xác nhận ngay.';
  static const String payRemainingDone = 'Đã trả nốt, đặt sân thành công.';
  static const String inviteMore = 'Mời thêm bạn';
  static const String inviteMoreNote = 'Chỉ mời thêm được khi chưa ai góp; phần tiền sẽ được chia lại.';
  static const String openSplit = 'Xem chia tiền';
  static const String confirm = 'Xác nhận';
  static const String cancel = 'Để sau';
  static const String fullyPaidNote = 'Đã đủ tiền • đặt sân thành công. Vé QR ở mục Lịch Đặt & QR.';

  // Lỗi
  static const String loginRequired = 'Vui lòng đăng nhập để chia tiền.';
  static const String invalidParts = 'Chỉ chia được 2 hoặc 4 phần.';
  static const String notFound = 'Không tìm thấy lượt chia tiền với mã này.';
  static const String alreadyPaid = 'Bạn đã trả một phần trong lượt chia này rồi.';
  static const String isBooker = 'Bạn là người đặt, phần của bạn đã được trả.';
  static const String fullyPaid = 'Lượt chia này đã đủ tiền.';
  static const String expired = 'Lượt chia đã hết hạn 30 phút, đặt sân đã bị hủy.';
  static const String loadError = 'Không tải được dữ liệu chia tiền. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
