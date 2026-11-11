import 'sport.dart';

/// Trình độ tự khai theo môn (khảo sát người chơi, thẻ trình độ kèo LFG).
enum SkillLevel {
  beginner('BEGINNER', 'Mới chơi'),
  intermediate('INTERMEDIATE', 'Trung bình'),
  advanced('ADVANCED', 'Khá'),
  professional('PROFESSIONAL', 'Giỏi / bán chuyên');

  const SkillLevel(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SkillLevel? fromApi(Object? value) =>
      values.where((l) => l.apiValue == value?.toString().toUpperCase()).firstOrNull;
}

enum Gender {
  male('MALE', 'Nam'),
  female('FEMALE', 'Nữ');

  const Gender(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static Gender? fromApi(Object? value) => values.where((g) => g.apiValue == value?.toString().toUpperCase()).firstOrNull;
}

enum PlayGoal {
  exchange('EXCHANGE', 'Giao lưu'),
  training('TRAINING', 'Rèn luyện sức khoẻ, nâng trình'),
  competition('COMPETITION', 'Thi đấu');

  const PlayGoal(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PlayGoal? fromApi(Object? value) =>
      values.where((g) => g.apiValue == value?.toString().toUpperCase()).firstOrNull;
}

enum PlayFrequency {
  rarely('RARELY', 'Thỉnh thoảng'),
  weekly12('WEEKLY_1_2', '1–2 buổi / tuần'),
  weekly3Plus('WEEKLY_3_PLUS', 'Từ 3 buổi / tuần');

  const PlayFrequency(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PlayFrequency? fromApi(Object? value) =>
      values.where((f) => f.apiValue == value?.toString().toUpperCase()).firstOrNull;
}

/// Nội dung thi đấu ưa thích của một môn: môn vợt là đơn / đôi, môn đồng đội là số người mỗi đội.
class PlayFormat {
  /// Giá trị gửi BE: "SINGLES", "DOUBLES" hoặc số người mỗi đội ("5", "7"…).
  final String apiValue;
  final String label;

  const PlayFormat(this.apiValue, this.label);

  static const singles = PlayFormat('SINGLES', 'Đơn');
  static const doubles = PlayFormat('DOUBLES', 'Đôi');

  /// Các nội dung chọn được của từng môn (theo SportTeamFormats của BE).
  static List<PlayFormat> optionsFor(Sport sport) => switch (sport) {
    Sport.badminton || Sport.tennis || Sport.pickleball => const [singles, doubles],
    Sport.football => const [PlayFormat('5', 'Sân 5'), PlayFormat('7', 'Sân 7'), PlayFormat('11', 'Sân 11')],
    Sport.basketball => const [PlayFormat('3', '3x3'), PlayFormat('5', '5x5')],
  };

  @override
  bool operator ==(Object other) => other is PlayFormat && other.apiValue == apiValue;

  @override
  int get hashCode => apiValue.hashCode;
}

/// Một môn trong hồ sơ người chơi.
class SurveySport {
  final Sport sport;
  final SkillLevel level;
  final List<String> formats;

  const SurveySport({required this.sport, required this.level, this.formats = const []});

  SurveySport copyWith({SkillLevel? level, List<String>? formats}) =>
      SurveySport(sport: sport, level: level ?? this.level, formats: formats ?? this.formats);
}

/// Giờ trong ngày dạng phút từ 00:00 (giờ Việt Nam).
class DayTime implements Comparable<DayTime> {
  final int minutes;

  const DayTime(this.minutes);

  DayTime.hm(int hour, int minute) : minutes = hour * 60 + minute;

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  /// "HH:mm" như BE nhận / trả.
  String get hhmm => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static DayTime? parse(Object? value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value?.toString() ?? '');
    if (match == null) return null;
    return DayTime.hm(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  @override
  int compareTo(DayTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) => other is DayTime && other.minutes == minutes;

  @override
  int get hashCode => minutes;
}

/// Khung giờ rảnh hàng tuần. [dayOfWeek]: 0 = Chủ nhật … 6 = Thứ bảy (như BE).
class AvailabilityWindow {
  final int dayOfWeek;
  final DayTime start;
  final DayTime end;

  const AvailabilityWindow({required this.dayOfWeek, required this.start, required this.end});

  /// Tên thứ: "T2" … "T7", "CN".
  static String dayLabel(int dayOfWeek) => dayOfWeek == 0 ? 'CN' : 'T${dayOfWeek + 1}';

  /// Thứ tự hiển thị: Thứ 2 trước, Chủ nhật cuối.
  static const List<int> weekOrder = [1, 2, 3, 4, 5, 6, 0];

  String get label => '${dayLabel(dayOfWeek)} ${start.hhmm}–${end.hhmm}';

  int get sortKey => weekOrder.indexOf(dayOfWeek) * 24 * 60 + start.minutes;

  bool overlaps(AvailabilityWindow other) =>
      other.dayOfWeek == dayOfWeek && start.minutes < other.end.minutes && other.start.minutes < end.minutes;
}

/// Khảo sát người chơi (bắt buộc với người chơi trước khi dùng app): môn + trình độ, lịch rảnh, khu vực,
/// mức giá, mục tiêu, tần suất. Dùng để gợi ý kèo / người chơi.
class PlayerSurvey {
  static const int maxSports = 10;
  static const int maxWindows = 28;
  static const int minRadiusKm = 1;
  static const int maxRadiusKm = 50;
  static const int defaultRadiusKm = 10;

  final bool isCompleted;
  final Gender? gender;
  final List<SurveySport> sports;
  final List<AvailabilityWindow> availability;
  final double? latitude;
  final double? longitude;
  final int radiusKm;

  /// Giá sân tối đa mỗi giờ; `null` = không giới hạn.
  final int? maxPricePerHour;
  final PlayGoal? goal;
  final PlayFrequency? frequency;

  const PlayerSurvey({
    this.isCompleted = false,
    this.gender,
    this.sports = const [],
    this.availability = const [],
    this.latitude,
    this.longitude,
    this.radiusKm = defaultRadiusKm,
    this.maxPricePerHour,
    this.goal,
    this.frequency,
  });

  bool get hasLocation => latitude != null && longitude != null;

  /// Đủ các mục bắt buộc để gửi.
  bool get isValid => sports.isNotEmpty && availability.isNotEmpty && goal != null && frequency != null;

  PlayerSurvey copyWith({
    bool? isCompleted,
    Gender? gender,
    bool clearGender = false,
    List<SurveySport>? sports,
    List<AvailabilityWindow>? availability,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    int? radiusKm,
    int? maxPricePerHour,
    bool clearMaxPrice = false,
    PlayGoal? goal,
    PlayFrequency? frequency,
  }) => PlayerSurvey(
    isCompleted: isCompleted ?? this.isCompleted,
    gender: clearGender ? null : gender ?? this.gender,
    sports: sports ?? this.sports,
    availability: availability ?? this.availability,
    latitude: clearLocation ? null : latitude ?? this.latitude,
    longitude: clearLocation ? null : longitude ?? this.longitude,
    radiusKm: radiusKm ?? this.radiusKm,
    maxPricePerHour: clearMaxPrice ? null : maxPricePerHour ?? this.maxPricePerHour,
    goal: goal ?? this.goal,
    frequency: frequency ?? this.frequency,
  );
}
