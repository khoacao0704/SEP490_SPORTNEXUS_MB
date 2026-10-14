import 'sport.dart';

/// Loại sân trong một môn. Môn vợt chỉ có sân tiêu chuẩn; bóng đá / bóng rổ chia theo số người mỗi đội.
/// Mỗi loại có số sân (tồn kho) và bảng giá riêng.
enum CourtType {
  standard('Standard', null, 'Sân tiêu chuẩn', 0),
  football5('Football5', Sport.football, 'Sân 5 người', 5),
  football7('Football7', Sport.football, 'Sân 7 người', 7),
  football11('Football11', Sport.football, 'Sân 11 người', 11),
  basketballHalf('BasketballHalf', Sport.basketball, 'Nửa sân 3x3', 3),
  basketballFull('BasketballFull', Sport.basketball, 'Sân đầy đủ 5x5', 5);

  const CourtType(this.apiValue, this.sport, this.label, this.playersPerTeam);

  final String apiValue;

  /// `null` với [standard] (dùng cho mọi môn vợt).
  final Sport? sport;
  final String label;

  /// Số người mỗi đội khi đá/đấu Team vs Team; 0 với sân tiêu chuẩn.
  final int playersPerTeam;

  /// "5 vs 5"
  String get matchup => '$playersPerTeam vs $playersPerTeam';

  bool get isStandard => this == CourtType.standard;

  /// Các loại sân có thể có của môn: bóng đá 5/7/11, bóng rổ 3x3/5x5, môn khác chỉ sân tiêu chuẩn.
  static List<CourtType> forSport(Sport sport) {
    final typed = values.where((t) => t.sport == sport).toList();
    return typed.isEmpty ? const [CourtType.standard] : typed;
  }

  static CourtType fromApi(String? value) =>
      values.firstWhere((t) => t.apiValue == value, orElse: () => CourtType.standard);
}
