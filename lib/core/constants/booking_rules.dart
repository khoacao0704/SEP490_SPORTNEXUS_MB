/// Quy tắc đặt sân thường đã chốt. Đặt sân thường KHÔNG có cọc: trả 100% hoặc chia tiền nhóm.
class BookingRules {
  BookingRules._();

  /// Hủy trước giờ chơi ít nhất chừng này thì được hoàn 100%; hủy trong khoảng này thì mất 100%
  /// (không hoàn cho ai, kể cả người góp tiền nhóm — chủ sân nhận hết).
  static const Duration freeCancelBeforeStart = Duration(hours: 24);
}
