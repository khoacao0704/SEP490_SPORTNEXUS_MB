/// Chuỗi hiển thị cho ví: nạp tiền VietQR, rút tiền, lịch sử giao dịch.
class WalletStrings {
  WalletStrings._();

  static const String walletName = 'Ví SportNexus';
  static const String availableBalance = 'Số dư khả dụng';
  static String pendingWithdrawal(String amount) => 'Đang chờ rút: $amount';
  static String frozenBalance(String amount) => 'Đang tạm giữ: $amount';
  static const String featureInDevelopment = 'Chức năng đang được phát triển. Vui lòng thử lại sau.';

  // Lịch sử giao dịch
  static const String historyTitle = 'Lịch Sử Giao Dịch';
  static const String historyLink = 'Lịch sử giao dịch';
  static const String filterAll = 'Tất cả';
  static const String filterIn = 'Tiền vào';
  static const String filterOut = 'Tiền ra';
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

  // Nạp tiền VietQR
  static const String vietQrTitle = 'Chuyển Khoản VietQR';
  static const String scanToPay = 'Quét mã bằng ứng dụng ngân hàng để thanh toán';
  static const String orTransferManually = 'Hoặc chuyển khoản thủ công theo thông tin';
  static const String bank = 'Ngân hàng';
  static const String accountNumber = 'Số tài khoản';
  static const String accountName = 'Chủ tài khoản';
  static const String amount = 'Số tiền';
  static const String transferContent = 'Nội dung CK';
  static const String transferContentWarning =
      'Nhập ĐÚNG nội dung chuyển khoản để hệ thống tự cộng tiền vào ví.';
  static String expiresIn(String mmss) => 'Lệnh nạp hết hạn sau $mmss';
  static const String waitingForPayment = 'Đang chờ xác nhận thanh toán...';
  static const String copied = 'Đã sao chép';
  static const String simulatePaid = 'Giả lập đã chuyển khoản';
  static const String sandboxNote = 'Môi trường thử nghiệm (Sandbox) — không chuyển tiền thật.';
  static const String cancelTopUp = 'Hủy giao dịch';
  static const String cancelTopUpConfirm = 'Bạn có chắc muốn hủy lệnh nạp tiền này?';
  static const String keepWaiting = 'Tiếp tục chờ';
  static const String topUpSuccessTitle = 'Nạp tiền thành công!';
  static String topUpSuccessMessage(String amount) => 'Đã cộng $amount vào ví SportNexus của bạn.';
  static const String topUpExpiredTitle = 'Lệnh nạp đã hết hạn';
  static const String topUpExpiredMessage =
      'Hệ thống chưa nhận được tiền. Nếu bạn đã chuyển khoản, vui lòng liên hệ hỗ trợ kèm mã giao dịch.';
  static const String done = 'Hoàn tất';
  static const String understood = 'Đã hiểu';
  static const String onlyVietQr = 'Hiện tại chỉ hỗ trợ nạp tiền qua VietQR';
  static const String openCheckout = 'Mở trang thanh toán PayOS';
  static const String cannotOpenCheckout = 'Không mở được trang thanh toán. Vui lòng quét mã QR.';
  static const String topUpFailedTitle = 'Nạp tiền không thành công';
  static const String topUpFailedMessage = 'Lệnh nạp đã bị hủy hoặc thanh toán thất bại. Ví của bạn không bị trừ tiền.';
  static const String minTopUpError = 'Số tiền nạp tối thiểu là';
  static const String maxTopUpError = 'Số tiền nạp tối đa là';

  // Rút tiền
  static const String withdrawTitle = 'Rút Tiền';
  static const String withdrawAmountLabel = 'SỐ TIỀN MUỐN RÚT (VND)';
  static const String withdrawAll = 'Tất cả';
  static const String receiveAccount = 'TÀI KHOẢN NHẬN TIỀN';
  static const String addBankAccount = 'Thêm tài khoản ngân hàng';
  static const String noBankAccount = 'Chưa có tài khoản nhận tiền';
  static String minWithdrawalNote(String min, String fee) => 'Tối thiểu $min • Phí rút: $fee';
  static const String free = 'Miễn phí';
  static const String withdrawProcessingNote = 'Lệnh rút được xử lý trong vòng 24 giờ làm việc.';
  static const String withdrawButton = 'RÚT TIỀN';
  static const String confirmWithdrawTitle = 'Xác nhận rút tiền';
  static String confirmWithdrawMessage(String amount, String account) =>
      'Rút $amount về tài khoản $account?';
  static const String confirm = 'Xác nhận';
  static const String cancel = 'Hủy';
  static const String withdrawSubmittedTitle = 'Đã gửi lệnh rút tiền';
  static String withdrawSubmittedMessage(String amount) =>
      'Lệnh rút $amount đang được xử lý. Tiền sẽ về tài khoản trong vòng 24 giờ làm việc.';
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
  static String withdrawTo(String bankName) => 'Rút tiền về $bankName';
  static const String invalidAccountHolder = 'Chỉ gồm chữ cái in hoa không dấu và khoảng trắng';

  // Lỗi
  static const String insufficientBalance = 'Số dư ví không đủ. Vui lòng nạp thêm tiền hoặc chọn phương thức khác.';
  static String belowMinWithdrawal(String min) => 'Số tiền rút tối thiểu là $min';
  static const String invalidAmount = 'Vui lòng nhập số tiền hợp lệ';
  static const String accountExists = 'Tài khoản ngân hàng này đã được lưu';
  static const String transactionNotFound = 'Không tìm thấy giao dịch';
  static const String topUpNotPending = 'Lệnh nạp không còn ở trạng thái chờ thanh toán';
  static const String loadError = 'Không tải được dữ liệu ví. Vui lòng thử lại.';
  static const String retry = 'Thử lại';
}
