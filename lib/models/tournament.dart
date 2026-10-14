import 'sport.dart';

/// Đơn vị đăng ký giải: cá nhân, cặp đôi hoặc đội.
enum TournamentEntryType {
  single('Single', 'Đơn (cá nhân)'),
  pair('Pair', 'Đôi'),
  team('Team', 'Đội');

  const TournamentEntryType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TournamentEntryType fromApi(String value) => values.firstWhere((t) => t.apiValue == value);
}

enum TournamentStatus {
  /// Còn nhận đăng ký tới hạn chót.
  registrationOpen,

  /// Đã qua hạn đăng ký, chờ khai mạc (BTC bốc thăm, xếp lịch).
  upcoming,
  ongoing,
  finished,

  /// BTC hủy giải: hoàn 100% lệ phí.
  cancelled,
}

class TournamentMember {
  final String userId;
  final String name;

  const TournamentMember({required this.userId, required this.name});

  factory TournamentMember.fromJson(Map<String, dynamic> json) =>
      TournamentMember(userId: json['userId'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'userId': userId, 'name': name};
}

/// Một đơn đăng ký (người chơi / cặp / đội). Người đăng ký là đội trưởng, đứng đầu [members].
class TournamentEntry {
  final String id;

  /// Tên đội; với giải đơn/đôi là tên người chơi ("A / B").
  final String name;
  final String captainId;
  final List<TournamentMember> members;
  final DateTime registeredAt;

  /// Rút sau hạn đăng ký: vẫn nằm trong sơ đồ, đối thủ được xử thắng.
  final bool withdrawn;

  const TournamentEntry({
    required this.id,
    required this.name,
    required this.captainId,
    required this.members,
    required this.registeredAt,
    this.withdrawn = false,
  });

  bool hasMember(String userId) => members.any((m) => m.userId == userId);

  TournamentEntry copyWith({bool? withdrawn}) => TournamentEntry(
        id: id,
        name: name,
        captainId: captainId,
        members: members,
        registeredAt: registeredAt,
        withdrawn: withdrawn ?? this.withdrawn,
      );

  factory TournamentEntry.fromJson(Map<String, dynamic> json) => TournamentEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        captainId: json['captainId'] as String,
        members: (json['members'] as List).map((e) => TournamentMember.fromJson(e as Map<String, dynamic>)).toList(),
        registeredAt: DateTime.parse(json['registeredAt'] as String),
        withdrawn: json['withdrawn'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'captainId': captainId,
        'members': members.map((m) => m.toJson()).toList(),
        'registeredAt': registeredAt.toIso8601String(),
        'withdrawn': withdrawn,
      };
}

/// Một trận trong sơ đồ loại trực tiếp. BTC xếp lịch và nhập kết quả trên Web.
class TournamentMatch {
  final String id;

  /// Vòng, bắt đầu từ 1 (vòng đầu tiên).
  final int round;

  /// Vị trí trong vòng, bắt đầu từ 0; trận [index] của vòng sau nhận người thắng trận 2·index và 2·index+1.
  final int index;

  /// `null` khi chưa xác định (chờ thắng trận trước).
  final String? entryAId;
  final String? entryBId;
  final DateTime? scheduledAt;

  /// "Sân 2"...
  final String court;

  /// Tỉ số do BTC nhập, vd. "21-18, 21-15" hoặc "3 - 1".
  final String? score;
  final String? winnerId;

  const TournamentMatch({
    required this.id,
    required this.round,
    required this.index,
    this.entryAId,
    this.entryBId,
    this.scheduledAt,
    this.court = '',
    this.score,
    this.winnerId,
  });

  bool get isFinished => winnerId != null;

  bool involves(String entryId) => entryAId == entryId || entryBId == entryId;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) => TournamentMatch(
        id: json['id'] as String,
        round: (json['round'] as num).toInt(),
        index: (json['index'] as num).toInt(),
        entryAId: json['entryAId'] as String?,
        entryBId: json['entryBId'] as String?,
        scheduledAt: json['scheduledAt'] == null ? null : DateTime.parse(json['scheduledAt'] as String),
        court: json['court'] as String? ?? '',
        score: json['score'] as String?,
        winnerId: json['winnerId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'round': round,
        'index': index,
        'entryAId': entryAId,
        'entryBId': entryBId,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'court': court,
        'score': score,
        'winnerId': winnerId,
      };
}

class TournamentPrize {
  /// "Vô địch", "Á quân", "Đồng hạng ba"...
  final String title;
  final int amount;

  /// Hiện vật kèm theo (cúp, huy chương...).
  final String extra;

  const TournamentPrize({required this.title, required this.amount, this.extra = ''});

  factory TournamentPrize.fromJson(Map<String, dynamic> json) => TournamentPrize(
        title: json['title'] as String,
        amount: (json['amount'] as num).toInt(),
        extra: json['extra'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'title': title, 'amount': amount, 'extra': extra};
}

/// Giải đấu do chủ sân / Admin tạo trên Web. Thể thức loại trực tiếp.
class Tournament {
  final String id;
  final String name;
  final String organizer;
  final String facilityId;
  final String facilityName;
  final String city;
  final String district;
  final Sport sport;
  final TournamentEntryType entryType;

  /// Số người mỗi đội (kể cả đội trưởng); đơn = 1, đôi = 2.
  final int minMembers;
  final int maxMembers;

  /// Số suất tối đa (8, 16, 32...): cũng là kích thước sơ đồ nhánh.
  final int maxEntries;

  /// Lệ phí mỗi đơn đăng ký (đội trưởng trả cho cả đội).
  final int entryFee;
  final DateTime registrationDeadline;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final List<TournamentPrize> prizes;

  /// Điều lệ, mỗi dòng một điều.
  final List<String> rules;
  final List<TournamentEntry> entries;

  /// Rỗng cho tới khi BTC bốc thăm (sau hạn đăng ký).
  final List<TournamentMatch> matches;
  final bool cancelled;

  const Tournament({
    required this.id,
    required this.name,
    required this.organizer,
    required this.facilityId,
    required this.facilityName,
    required this.city,
    required this.district,
    required this.sport,
    required this.entryType,
    required this.minMembers,
    required this.maxMembers,
    required this.maxEntries,
    required this.entryFee,
    required this.registrationDeadline,
    required this.startDate,
    required this.endDate,
    this.description = '',
    this.prizes = const [],
    this.rules = const [],
    this.entries = const [],
    this.matches = const [],
    this.cancelled = false,
  });

  int get totalPrize => prizes.fold(0, (sum, p) => sum + p.amount);

  /// Số suất đã đăng ký (kể cả đội rút sau hạn, vì vẫn giữ chỗ trong sơ đồ).
  int get entryCount => entries.length;

  int get slotsLeft => (maxEntries - entryCount).clamp(0, maxEntries);

  TournamentStatus status(DateTime now) {
    if (cancelled) return TournamentStatus.cancelled;
    if (!endDate.isAfter(now)) return TournamentStatus.finished;
    if (!startDate.isAfter(now)) return TournamentStatus.ongoing;
    if (now.isBefore(registrationDeadline)) return TournamentStatus.registrationOpen;
    return TournamentStatus.upcoming;
  }

  bool canRegister(DateTime now) => status(now) == TournamentStatus.registrationOpen && slotsLeft > 0;

  /// Rút trước hạn đăng ký thì hoàn 100% lệ phí.
  bool refundableOnWithdraw(DateTime now) => now.isBefore(registrationDeadline);

  TournamentEntry? entryOf(String userId) =>
      entries.where((e) => e.hasMember(userId)).firstOrNull;

  TournamentEntry? entryById(String? id) => id == null ? null : entries.where((e) => e.id == id).firstOrNull;

  /// Số vòng của sơ đồ: 8 suất → 3 vòng (tứ kết, bán kết, chung kết).
  int get roundCount {
    var rounds = 0;
    var size = 1;
    while (size < maxEntries) {
      size *= 2;
      rounds++;
    }
    return rounds;
  }

  List<TournamentMatch> matchesInRound(int round) =>
      matches.where((m) => m.round == round).toList()..sort((a, b) => a.index.compareTo(b.index));

  TournamentMatch? get finalMatch => matches.where((m) => m.round == roundCount).firstOrNull;

  TournamentEntry? get champion => entryById(finalMatch?.winnerId);

  Tournament copyWith({List<TournamentEntry>? entries, List<TournamentMatch>? matches, bool? cancelled}) => Tournament(
        id: id,
        name: name,
        organizer: organizer,
        facilityId: facilityId,
        facilityName: facilityName,
        city: city,
        district: district,
        sport: sport,
        entryType: entryType,
        minMembers: minMembers,
        maxMembers: maxMembers,
        maxEntries: maxEntries,
        entryFee: entryFee,
        registrationDeadline: registrationDeadline,
        startDate: startDate,
        endDate: endDate,
        description: description,
        prizes: prizes,
        rules: rules,
        entries: entries ?? this.entries,
        matches: matches ?? this.matches,
        cancelled: cancelled ?? this.cancelled,
      );

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        id: json['id'] as String,
        name: json['name'] as String,
        organizer: json['organizer'] as String,
        facilityId: json['facilityId'] as String,
        facilityName: json['facilityName'] as String,
        city: json['city'] as String,
        district: json['district'] as String,
        sport: Sport.fromApi(json['sport'] as String),
        entryType: TournamentEntryType.fromApi(json['entryType'] as String),
        minMembers: (json['minMembers'] as num).toInt(),
        maxMembers: (json['maxMembers'] as num).toInt(),
        maxEntries: (json['maxEntries'] as num).toInt(),
        entryFee: (json['entryFee'] as num).toInt(),
        registrationDeadline: DateTime.parse(json['registrationDeadline'] as String),
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        description: json['description'] as String? ?? '',
        prizes: (json['prizes'] as List? ?? []).map((e) => TournamentPrize.fromJson(e as Map<String, dynamic>)).toList(),
        rules: (json['rules'] as List? ?? []).cast<String>(),
        entries: (json['entries'] as List? ?? []).map((e) => TournamentEntry.fromJson(e as Map<String, dynamic>)).toList(),
        matches: (json['matches'] as List? ?? []).map((e) => TournamentMatch.fromJson(e as Map<String, dynamic>)).toList(),
        cancelled: json['cancelled'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'organizer': organizer,
        'facilityId': facilityId,
        'facilityName': facilityName,
        'city': city,
        'district': district,
        'sport': sport.apiValue,
        'entryType': entryType.apiValue,
        'minMembers': minMembers,
        'maxMembers': maxMembers,
        'maxEntries': maxEntries,
        'entryFee': entryFee,
        'registrationDeadline': registrationDeadline.toIso8601String(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'description': description,
        'prizes': prizes.map((p) => p.toJson()).toList(),
        'rules': rules,
        'entries': entries.map((e) => e.toJson()).toList(),
        'matches': matches.map((m) => m.toJson()).toList(),
        'cancelled': cancelled,
      };
}

class TournamentQuery {
  final String city;
  final Sport? sport;

  /// `null` là mọi trạng thái.
  final TournamentStatus? status;

  const TournamentQuery({required this.city, this.sport, this.status});
}

/// Thông tin gửi lên khi đăng ký giải.
class TournamentRegistration {
  final String tournamentId;

  /// Tên đội; bỏ trống với giải đơn/đôi (BE ghép từ tên người chơi).
  final String teamName;

  /// Đồng đội (không gồm người đăng ký), đã tra cứu từ email/SĐT.
  final List<TournamentMember> teammates;

  const TournamentRegistration({required this.tournamentId, this.teamName = '', this.teammates = const []});
}
