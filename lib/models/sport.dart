enum Sport {
  badminton('Badminton', 'Cầu Lông'),
  pickleball('Pickleball', 'Pickleball'),
  football('Football', 'Bóng Đá'),
  basketball('Basketball', 'Bóng Rổ'),
  tennis('Tennis', 'Tennis');

  const Sport(this.apiValue, this.label);

  /// Giá trị BE trả về / nhận vào.
  final String apiValue;

  /// Tên hiển thị tiếng Việt.
  final String label;

  static Sport fromApi(String value) {
    return Sport.values.firstWhere(
      (s) => s.apiValue.toLowerCase() == value.toLowerCase(),
      orElse: () => throw ArgumentError('Môn thể thao không hợp lệ: $value'),
    );
  }
}
