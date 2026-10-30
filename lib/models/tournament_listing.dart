import 'sport.dart';

/// Model giải đấu phía người chơi, theo cấu trúc BE: giải mẹ gồm nhiều bảng con (hạng mục thi đấu).
/// (Model [Tournament] trong tournament.dart là của phần Chủ sân, dữ liệu giả lập.)

enum TournamentPhase {
  open('OPEN', 'Đang mở đăng ký'),
  inProgress('IN_PROGRESS', 'Đang diễn ra'),
  finished('FINISHED', 'Đã kết thúc'),
  cancelled('CANCELLED', 'Đã hủy');

  const TournamentPhase(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TournamentPhase fromApi(String? value) =>
      values.where((s) => s.apiValue == value?.toUpperCase()).firstOrNull ?? TournamentPhase.open;
}

/// Hình thức đăng ký của một bảng con.
enum DivisionType {
  singles('SINGLES', 'Đơn'),

  /// Đội / đôi lập sẵn: đăng ký bằng một đội.
  premadeTeams('PREMADE_TEAMS', 'Đội / đôi cố định'),

  /// Đăng ký cá nhân, ban tổ chức ghép cặp sau.
  randomDoubles('RANDOM_DOUBLES', 'Ghép đôi ngẫu nhiên');

  const DivisionType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  bool get needsTeam => this == premadeTeams;

  static DivisionType fromApi(String? value) =>
      values.where((t) => t.apiValue == value?.toUpperCase()).firstOrNull ?? DivisionType.singles;
}

enum TournamentSort {
  newest('newest', 'Mới nhất'),
  upcoming('upcoming', 'Sắp diễn ra'),
  deadline('deadline', 'Sắp hết hạn đăng ký');

  const TournamentSort(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Một giải (giải mẹ) trong danh sách.
class TournamentListItem {
  final String id;
  final String name;
  final String? imageUrl;
  final TournamentPhase phase;
  final bool isPromoted;
  final String facilityId;
  final String facilityName;
  final String facilityAddress;
  final Sport? sport;
  final String sportName;
  final int divisionCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? registrationDeadline;

  /// Có ít nhất một bảng con đang mở và chưa quá hạn đăng ký.
  final bool isRegistrationOpen;

  const TournamentListItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.phase,
    this.isPromoted = false,
    required this.facilityId,
    required this.facilityName,
    this.facilityAddress = '',
    this.sport,
    this.sportName = '',
    this.divisionCount = 0,
    this.startDate,
    this.endDate,
    this.registrationDeadline,
    this.isRegistrationOpen = false,
  });

  String get sportLabel => sport?.label ?? sportName;
}

class TournamentPrizeItem {
  /// Hạng (1 = vô địch).
  final int position;
  final int amount;

  const TournamentPrizeItem({required this.position, required this.amount});
}

/// Một bảng con (hạng mục) của giải: nơi người chơi thực sự đăng ký.
class TournamentDivision {
  final String id;
  final String name;
  final DivisionType type;
  final String typeName;

  /// Hướng dẫn đăng ký do ban tổ chức viết.
  final String guide;

  /// Số suất tối đa (số đội với bảng đội, số người với bảng cá nhân).
  final int maxEntries;
  final int minTeamSize;
  final int maxTeamSize;
  final int entryFee;
  final TournamentPhase phase;
  final bool isRegistrationOpen;
  final List<TournamentPrizeItem> prizes;

  const TournamentDivision({
    required this.id,
    required this.name,
    required this.type,
    this.typeName = '',
    this.guide = '',
    required this.maxEntries,
    this.minTeamSize = 1,
    this.maxTeamSize = 1,
    required this.entryFee,
    required this.phase,
    required this.isRegistrationOpen,
    this.prizes = const [],
  });

  String get typeLabel => typeName.isNotEmpty ? typeName : type.label;
}

class TournamentDetails {
  final TournamentListItem info;

  /// Điều lệ riêng của giải.
  final String rules;

  /// Luật chung của môn.
  final String sportRules;
  final List<TournamentPrizeItem> prizes;
  final List<TournamentDivision> divisions;

  const TournamentDetails({
    required this.info,
    this.rules = '',
    this.sportRules = '',
    this.prizes = const [],
    this.divisions = const [],
  });
}

/// Một người trong danh sách tham gia (giải đội: mỗi thành viên một dòng).
class TournamentParticipant {
  final String participantId;
  final String divisionId;
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? teamId;
  final String? teamName;
  final bool isCheckedIn;

  const TournamentParticipant({
    required this.participantId,
    required this.divisionId,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.teamId,
    this.teamName,
    this.isCheckedIn = false,
  });
}

/// Một suất đã đăng ký của bảng con: một đội (gom các thành viên) hoặc một người.
class TournamentEntryGroup {
  final String key;
  final String name;
  final List<TournamentParticipant> members;

  const TournamentEntryGroup({required this.key, required this.name, required this.members});

  bool get isTeam => members.first.teamId != null;

  /// Gom người tham gia của một bảng con thành từng suất (đội theo teamId, cá nhân theo từng người).
  static List<TournamentEntryGroup> group(Iterable<TournamentParticipant> participants) {
    final groups = <String, List<TournamentParticipant>>{};
    for (final p in participants) {
      groups.putIfAbsent(p.teamId ?? 'p:${p.participantId}', () => []).add(p);
    }
    return [
      for (final entry in groups.entries)
        TournamentEntryGroup(
          key: entry.key,
          name: entry.value.first.teamName ?? entry.value.first.name,
          members: entry.value,
        ),
    ];
  }
}

class SetScore {
  final int set;
  final int a;
  final int b;
  final bool isTiebreak;

  const SetScore({required this.set, required this.a, required this.b, this.isTiebreak = false});
}

/// Một trận trong sơ đồ loại trực tiếp. Hai bên chỉ có tên ("TBD" khi chưa xác định).
class BracketMatch {
  final String id;
  final int index;
  final String roundName;
  final String status;
  final DateTime? start;
  final DateTime? end;
  final String courtName;
  final String sideA;
  final String sideB;
  final String? winner;
  final List<SetScore> scores;

  const BracketMatch({
    required this.id,
    required this.index,
    required this.roundName,
    this.status = 'SCHEDULED',
    this.start,
    this.end,
    this.courtName = '',
    required this.sideA,
    required this.sideB,
    this.winner,
    this.scores = const [],
  });

  static const String unknownSide = 'TBD';

  bool get isFinished => winner != null && winner!.isNotEmpty && winner != unknownSide;
}

/// Một lượt đăng ký của tôi (kể cả khi đội của tôi đăng ký).
class TournamentRegistrationItem {
  final String participantId;

  /// Bảng con đã đăng ký (đăng ký / rút / vé đều theo id này).
  final String divisionId;
  final String divisionName;

  /// Giải mẹ (bằng [divisionId] khi giải không có bảng con).
  final String tournamentId;
  final String tournamentName;
  final DivisionType type;
  final String facilityName;
  final int entryFee;
  final String paymentStatus;
  final TournamentPhase phase;
  final String? qrCode;
  final String? teamId;
  final String? teamName;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? registrationDeadline;
  final bool isRegistrationOpen;
  final String? imageUrl;

  const TournamentRegistrationItem({
    required this.participantId,
    required this.divisionId,
    required this.divisionName,
    required this.tournamentId,
    required this.tournamentName,
    required this.type,
    this.facilityName = '',
    required this.entryFee,
    this.paymentStatus = '',
    required this.phase,
    this.qrCode,
    this.teamId,
    this.teamName,
    this.startDate,
    this.endDate,
    this.registrationDeadline,
    this.isRegistrationOpen = false,
    this.imageUrl,
  });

  /// Rút trước hạn đăng ký thì được hoàn 100%, sau hạn thì không.
  bool refundableAt(DateTime now) {
    final deadline = registrationDeadline;
    return deadline == null || now.isBefore(deadline);
  }

  bool get canWithdraw => phase == TournamentPhase.open;
}

/// Một trận sắp tới / đã đấu của tôi.
class MyTournamentMatch {
  final String matchId;
  final String tournamentName;
  final String divisionName;
  final String roundName;
  final String status;
  final DateTime? start;
  final DateTime? end;
  final String courtName;
  final String facilityName;
  final String facilityAddress;
  final String mySide;
  final String opponent;
  final String? winner;

  const MyTournamentMatch({
    required this.matchId,
    required this.tournamentName,
    this.divisionName = '',
    this.roundName = '',
    this.status = '',
    this.start,
    this.end,
    this.courtName = '',
    this.facilityName = '',
    this.facilityAddress = '',
    required this.mySide,
    required this.opponent,
    this.winner,
  });
}

/// Vé QR check-in giải (mã tĩnh, mỗi người một mã).
class TournamentTicket {
  final String tournamentName;
  final String facilityName;
  final String fullName;
  final String? teamName;
  final String qrCode;

  const TournamentTicket({
    required this.tournamentName,
    this.facilityName = '',
    required this.fullName,
    this.teamName,
    required this.qrCode,
  });
}

class TournamentSearchQuery {
  final String keyword;
  final Sport? sport;
  final TournamentPhase? phase;
  final bool registrationOpenOnly;
  final TournamentSort sort;

  const TournamentSearchQuery({
    this.keyword = '',
    this.sport,
    this.phase,
    this.registrationOpenOnly = false,
    this.sort = TournamentSort.newest,
  });
}

class TournamentPage {
  final List<TournamentListItem> items;
  final bool hasMore;

  const TournamentPage({required this.items, required this.hasMore});
}
