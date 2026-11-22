/// Chuỗi hiển thị cho ví: nạp Điểm VietQR, đổi Điểm ra tiền, lịch sử giao dịch.
class WalletStrings {
  WalletStrings._();

  static const String walletName = 'Ví điểm';
  static const String availableBalance = 'Số dư khả dụng';
  static String pendingWithdrawal(String amount) => 'Đang chờ đổi ra tiền: $amount';
  static String frozenBalance(String amount) => 'Đang tạm giữ: $amount';
  static const String featureInDevelopment = 'Chức năng đang được phát triển. Vui lòng thử lại sau.';
  static const String playerWalletNote = 'Điểm trong Ví điểm dùng để đổi khi đặt sân, vào kèo, đăng ký giải trong SportNexus; không đổi ra tiền.';

  // Lịch sử giao dịch
  static const String historyTitle = 'Lịch Sử Giao Dịch';
  static const String historyLink = 'Lịch sử giao dịch';
  static const String filterAll = 'Tất cả';
  static const String filterIn = 'Điểm vào';
  static const String filterOut = 'Điểm ra';
  static const String filterPending = 'Đang xử lý';
  static const String noTransactions = 'Chưa có giao dịch nào';
  static const String today = 'Hôm nay';
  static const String yesterday = 'Hôm qua';
  static const String transactionDetail = 'Chi tiết giao dịch';
  static const String transactionId = 'Mã giao dịch';
  static const String time = 'Thời gian';
  static const String type = 'Loại giao dịch';
  static const String status = 'Trạng thái';
  static const String content = 'Nội dung';
  static const String reference = 'Tham chiếu';

  // Trạng thái
  static const String statusPendingTopUp = 'Chờ thanh toán';
  static const String statusPendingWithdrawal = 'Đang xử lý';
  static const String statusSuccess = 'Thành công';
  static const String statusFailed = 'Thất bại';
  static const String statusExpired = 'Hết hạn';
  static const String statusCancelled = 'Đã hủy';
  static const String statusNotRefunded = 'Không được hoàn';

  // Nạp Điểm VietQR
  static const String vietQrTitle = 'Chuyển Khoản VietQR';
  static const String scanToPay = 'Quét mã bằng ứng dụng ngân hàng để thanh toán';
  static const String orTransferManually = 'Hoặc chuyển khoản thủ công theo thông tin';
  static const String bank = 'Ngân hàng';
  static const String accountNumber = 'Số tài khoản';
  static const String accountName = 'Chủ tài khoản';
  static const String amount = 'Số tiền';
  static const String transferContent = 'Nội dung CK';
  static const String transferContentWarning =
      'Nhập ĐÚNG nội dung chuyển khoản để hệ thống tự cộng Điểm vào Ví điểm (1 đ = 1 Điểm).';
  static String expiresIn(String mmss) => 'Lệnh nạp hết hạn sau $mmss';
  static const String waitingForPayment = 'Đang chờ xác nhận thanh toán...';
  static const String copied = 'Đã sao chép';
  static const String simulatePaid = 'Giả lập đã chuyển khoản';
  static const String sandboxNote = 'Môi trường thử nghiệm (Sandbox) — không chuyển tiền thật.';
  static const String cancelTopUp = 'Hủy giao dịch';
  static const String cancelTopUpConfirm = 'Bạn có chắc muốn hủy lệnh nạp Điểm này?';
  static const String keepWaiting = 'Tiếp tục chờ';
  static const String topUpSuccessTitle = 'Nạp Điểm thành công!';
  static String topUpSuccessMessage(String amount) => 'Đã cộng $amount vào Ví điểm của bạn.';
  static const String topUpExpiredTitle = 'Lệnh nạp đã hết hạn';
  static const String topUpExpiredMessage =
      'Hệ thống chưa nhận được tiền. Nếu bạn đã chuyển khoản, vui lòng liên hệ hỗ trợ kèm mã giao dịch.';
  static const String done = 'Hoàn tất';
  static const String understood = 'Đã hiểu';
  static const String onlyVietQr = 'Hiện tại chỉ hỗ trợ nạp Điểm qua VietQR';
  static const String openCheckout = 'Mở trang thanh toán PayOS';
  static const String cannotOpenCheckout = 'Không mở được trang thanh toán. Vui lòng quét mã QR.';
  static const String topUpFailedTitle = 'Nạp Điểm không thành công';
  static const String topUpFailedMessage = 'Lệnh nạp đã bị hủy hoặc thanh toán thất bại. Ví điểm của bạn không bị trừ Điểm.';
  static const String minTopUpError = 'Số Điểm nạp tối thiểu là';
  static const String maxTopUpError = 'Số Điểm nạp tối đa là';

  // Đổi Điểm ra tiền
  static const String withdrawTitle = 'Đổi Điểm Ra Tiền';
  static const String withdrawAmountLabel = 'SỐ ĐIỂM MUỐN ĐỔI RA TIỀN (1 Điểm = 1 đ)';
  static const String withdrawAll = 'Tất cả';
  static const String receiveAccount = 'TÀI KHOẢN NHẬN TIỀN';
  static const String addBankAccount = 'Thêm tài khoản ngân hàng';
  static const String noBankAccount = 'Chưa có tài khoản nhận tiền';
  static String minWithdrawalNote(String min, String fee) => 'Tối thiểu $min • Phí đổi: $fee';
  static const String free = 'Miễn phí';
  static const String withdrawProcessingNote = 'Lệnh đổi ra tiền được xử lý trong vòng 24 giờ làm việc.';
  static const String withdrawButton = 'ĐỔI ĐIỂM RA TIỀN';
  static const String confirmWithdrawTitle = 'Xác nhận đổi Điểm ra tiền';
  static String confirmWithdrawMessage(String amount, String account) =>
      'Đổi $amount ra tiền, chuyển về tài khoản $account?';
  static const String confirm = 'Xác nhận';
  static const String cancel = 'Hủy';
  static const String withdrawSubmittedTitle = 'Đã gửi lệnh đổi Điểm ra tiền';
  static String withdrawSubmittedMessage(String amount) =>
      'Lệnh đổi $amount ra tiền đang được xử lý. Tiền sẽ về tài khoản trong vòng 24 giờ làm việc.';
  static const String removeAccount = 'Xóa tài khoản';
  static const String removeAccountConfirm = 'Xóa tài khoản ngân hàng này khỏi danh sách?';

  // Thêm tài khoản ngân hàng
  static const String addAccountTitle = 'Thêm Tài Khoản Ngân Hàng';
  static const String chooseBank = 'Chọn ngân hàng';
  static const String accountNumberHint = 'Nhập số tài khoản';
  static const String accountHolderHint = 'VD: NGUYEN VAN A';
  static const String accountHolderNote = 'In hoa, không dấu, trùng với tên chủ tài khoản ngân hàng.';
  static const String saveAccount = 'LƯU TÀI KHOẢN';
  static const String bankRequired = 'Vui lòng chọn ngân hàng';
  static const String invalidAccountNumber = 'Số tài khoản gồm 6–20 chữ số';
  static const String changeBankAccount = 'Đổi tài khoản ngân hàng';
  static String withdrawTo(String bankName) => 'Đổi Điểm ra tiền về $bankName';
  static const String invalidAccountHolder = 'Chỉ gồm chữ cái in hoa không dấu và khoảng trắng';

  // Lỗi
  static const String insufficientBalance = 'Không đủ Điểm. Vui lòng nạp thêm Điểm hoặc chọn phương thức khác.';
  static String belowMinWithdrawal(String min) => 'Số Điểm đổi tối thiểu là $min';
  static const String invalidAmount = 'Vui lòng nhập số Điểm hợp lệ';
  static const String accountExists = 'Tài khoản ngân hàng này đã được lưu';
  static const String transactionNotFound = 'Không tìm thấy giao dịch';
  static const String note = 'Ghi chú';
  static const String cancelWithdrawal = 'Hủy yêu cầu đổi';
  static const String cancelWithdrawalConfirm =
      'Hủy yêu cầu đổi Điểm ra tiền này? Số Điểm sẽ được trả lại vào Ví điểm của bạn.';
  static const String withdrawalCancelled = 'Đã hủy yêu cầu đổi Điểm ra tiền, Điểm đã trả lại Ví điểm.';
  static const String noPendingWithdrawal = 'Yêu cầu đổi Điểm ra tiền không còn ở trạng thái chờ xử lý.';
  static const String keep = 'Giữ lại';
  static const String topUpNotPending = 'Lệnh nạp không còn ở trạng thái chờ thanh toán';
  static const String loadError = 'Không tải được dữ liệu ví. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
