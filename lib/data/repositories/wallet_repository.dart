import '../../models/bank_account.dart';
import '../../models/wallet_transaction.dart';

/// Lỗi nghiệp vụ của ví; [message] sẵn sàng để hiển thị.
class WalletException implements Exception {
  final String message;

  const WalletException(this.message);

  @override
  String toString() => 'WalletException: $message';
}

abstract class WalletRepository {
  /// false: nạp tiền chưa dùng được (UI báo "đang phát triển").
  bool get supportsTopUp;

  /// false: rút tiền / tài khoản ngân hàng chưa dùng được (UI báo "đang phát triển").
  bool get supportsWithdrawal;

  /// true: chỉ lưu MỘT tài khoản ngân hàng nhận tiền (thêm mới = thay thế, không xóa được).
  bool get singleBankAccount;

  /// Số dư khả dụng (đã trừ các lệnh rút đang chờ xử lý).
  Future<int> getBalance();

  /// Tiền đang tạm giữ, tách khỏi số dư khả dụng (cọc kèo LFG, lệ phí giải đấu).
  Future<int> getFrozenBalance();

  /// Tổng tiền của các lệnh rút đang chờ xử lý.
  Future<int> getPendingWithdrawalAmount();

  /// Lịch sử giao dịch, mới nhất trước.
  Future<List<WalletTransaction>> getTransactions();

  /// Trừ tiền ví cho một khoản thanh toán (đặt sân, cọc LFG, Flash Claim).
  /// Ném [WalletException] nếu số dư không đủ.
  Future<WalletTransaction> pay({
    required int amount,
    required TransactionType type,
    required String description,
    String? reference,
  });

  // ---------- Nạp tiền VietQR ----------

  /// Tạo lệnh nạp ở trạng thái chờ; ví chỉ được cộng khi BE xác nhận đã nhận tiền.
  Future<TopUpOrder> createTopUp(int amount);

  /// Hỏi lại trạng thái lệnh nạp [TopUpOrder.transactionId] (UI gọi định kỳ trong lúc chờ).
  Future<TransactionStatus> getTopUpStatus(String orderId);

  /// Chi tiết một giao dịch trong lịch sử.
  Future<WalletTransaction> getTransaction(String transactionId);

  /// Hủy lệnh nạp đang chờ; lệnh đã xong (đã nhận tiền / đã hủy) thì bỏ qua.
  Future<void> cancelTopUp(String transactionId);

  // ---------- Rút tiền ----------

  Future<List<BankAccount>> getBankAccounts();

  Future<BankAccount> addBankAccount({
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  });

  Future<void> removeBankAccount(String accountId);

  /// Gửi lệnh rút: trừ số dư ngay, trạng thái chờ xử lý. Nếu bị từ chối, BE hoàn lại tiền.
  Future<WalletTransaction> requestWithdrawal({required int amount, required BankAccount account});
}

/// Chỉ bản giả lập cài đặt: dùng cho nút "Giả lập đã chuyển khoản" khi demo.
abstract class SandboxPaymentSimulator {
  Future<void> simulateTopUpReceived(String transactionId);

  Future<void> simulateWithdrawalProcessed(String transactionId, {required bool approved});
}
