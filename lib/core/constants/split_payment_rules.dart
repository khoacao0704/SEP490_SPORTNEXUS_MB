/// Quy tắc chia tiền đặt sân đã chốt.
class SplitPaymentRules {
  SplitPaymentRules._();

  /// Người đặt chọn chia 2 hoặc 4 phần (tối đa 4, là bội của 2).
  static const List<int> allowedParts = [2, 4];

  /// Thời gian để những người nhận link trả phần của mình; khung giờ được giữ suốt thời gian này.
  /// Hết giờ mà chưa đủ thì hủy đặt sân và hoàn đủ cho những người đã trả.
  static const Duration window = Duration(minutes: 30);

  /// Phần của mỗi người nhận link: tiền sân chia đều, làm tròn lên 1.000đ.
  static int shareAmount(int total, int parts) => ((total / parts) / 1000).ceil() * 1000;

  /// Phần người đặt trả trước (cọc): phần còn lại sau khi trừ phần của những người khác,
  /// để tổng các phần đúng bằng tiền sân.
  static int bookerAmount(int total, int parts) => total - shareAmount(total, parts) * (parts - 1);
}
