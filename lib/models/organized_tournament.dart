import 'tournament_listing.dart';

/// Thể thức thi đấu, chốt khi tạo giải (không đổi được). [minCount]/[maxCount] là giới hạn cứng của BE.
enum BracketFormat {
  knockout('KNOCKOUT', 'Loại trực tiếp', 2, null),
  roundRobin('ROUND_ROBIN', 'Vòng tròn', 3, 8),
  groupKnockout('GROUP_KNOCKOUT', 'Vòng bảng + loại trực tiếp', 6, null);

  const BracketFormat(this.apiValue, this.label, this.minCount, this.maxCount);

  final String apiValue;
  final String label;
  final int minCount;
  final int? maxCount;

  /// BE trả 'Knockout' / 'RoundRobin' / 'GROUP_KNOCKOUT'…
  static BracketFormat? fromApi(Object? value) {
    final key = '${value ?? ''}'
        .trim()
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toUpperCase();
    for (final f in values) {
      if (f.apiValue == key) return f;
    }
    return null;
  }
}

/// Buổi trong lịch sân BTC yêu cầu.
enum CourtSession {
  morning('MORNING', 'Sáng (06:00–12:00)'),
  afternoon('AFTERNOON', 'Chiều (12:00–18:00)'),
  evening('EVENING', 'Tối (18:00–22:00)'),
  fullDay('FULL_DAY', 'Cả ngày (06:00–22:00)');

  const CourtSession(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CourtSession? fromApi(Object? value) {
    final key = '${value ?? ''}'.toUpperCase();
    for (final s in values) {
      if (s.apiValue == key) return s;
    }
    return null;
  }
}

/// Một dòng lịch sân: ngày, buổi, số sân. Chỉ để xem (BE chưa tự khóa ca).
class CourtScheduleRequest {
  final DateTime? date;
  final CourtSession session;
  final int courtCount;

  /// Giờ cụ thể (nếu BE trả về thay cho buổi).
  final String? startTime;
  final String? endTime;

  const CourtScheduleRequest({
    this.date,
    this.session = CourtSession.morning,
    this.courtCount = 1,
    this.startTime,
    this.endTime,
  });

  CourtScheduleRequest copyWith({DateTime? date, CourtSession? session, int? courtCount}) => CourtScheduleRequest(
    date: date ?? this.date,
    session: session ?? this.session,
    courtCount: courtCount ?? this.courtCount,
  );

  Map<String, dynamic> toJson() => {'date': dateParam(date!), 'session': session.apiValue, 'courtCount': courtCount};
}

/// File PDF đã tải lên (gửi Admin duyệt).
class TournamentDocument {
  final String url;
  final String name;

  const TournamentDocument({required this.url, required this.name});
}

/// Giải thưởng chỉ để hiển thị (BTC tự trao ngoài hệ thống).
class OrganizerPrize {
  final String position;
  final int amount;

  const OrganizerPrize({required this.position, required this.amount});
}

/// Cơ sở để chọn khi người chơi tạo giải.
class FacilityOption {
  final String id;
  final String name;
  final String address;

  const FacilityOption({required this.id, required this.name, this.address = ''});
}

/// Ngày trơn gửi BE: 'YYYY-MM-DD'.
String dateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Hình thức đăng ký → mã số BE (0 đơn, 1 đội, 2 đôi bốc thăm).
int categoryTypeCode(DivisionType type) => switch (type) {
  DivisionType.singles => 0,
  DivisionType.premadeTeams => 1,
  DivisionType.randomDoubles => 2,
};

DivisionType divisionTypeFromApi(Object? value) {
  if (value is num) {
    return switch (value.toInt()) {
      1 => DivisionType.premadeTeams,
      2 => DivisionType.randomDoubles,
      _ => DivisionType.singles,
    };
  }
  final key = '${value ?? ''}'
      .trim()
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}')
      .toUpperCase();
  for (final t in DivisionType.values) {
    if (t.apiValue == key) return t;
  }
  return DivisionType.singles;
}

/// Bản nháp tạo giải (POST /tournaments). Người chơi và chủ sân dùng chung.
class NewTournament {
  final String facilityId;
  final String categoryId;
  final String name;
  final DateTime start;
  final DateTime end;
  final DateTime? deadline;
  final String description;
  final TournamentTier tier;
  final TournamentPurpose purpose;
  final int? minRating;
  final int? maxRating;
  final int? minRatedMatches;
  final BracketFormat format;
  final DivisionType type;
  final int maxParticipants;
  final int entryFee;
  final List<OrganizerPrize> prizes;
  final List<TournamentDocument> rulesFiles;
  final TournamentDocument? contract;
  final List<CourtScheduleRequest> schedule;

  const NewTournament({
    required this.facilityId,
    required this.categoryId,
    required this.name,
    required this.start,
    required this.end,
    this.deadline,
    this.description = '',
    this.tier = TournamentTier.amateur,
    this.purpose = TournamentPurpose.exchange,
    this.minRating,
    this.maxRating,
    this.minRatedMatches,
    this.format = BracketFormat.knockout,
    this.type = DivisionType.singles,
    this.maxParticipants = 8,
    this.entryFee = 0,
    this.prizes = const [],
    this.rulesFiles = const [],
    this.contract,
    this.schedule = const [],
  });

  bool get _rated => tier != TournamentTier.amateur;

  Map<String, dynamic> toJson() => {
    'facilityId': facilityId,
    'categoryId': categoryId,
    'name': name.trim(),
    'startDate': dateParam(start),
    'endDate': dateParam(end),
    'registrationDeadline': deadline == null ? null : dateParam(deadline!),
    'rules': description.trim().isEmpty ? null : description.trim(),
    'tier': tier.apiValue,
    'purpose': purpose.apiValue,
    'minRating': _rated ? minRating : null,
    'maxRating': _rated ? maxRating : null,
    'minRatedMatches': _rated ? minRatedMatches : null,
    'defaultBracketFormat': format.apiValue,
    'rulesFileUrls': [for (final f in rulesFiles) f.url],
    'rulesFileUrl': rulesFiles.isEmpty ? null : rulesFiles.first.url,
    'contractFileUrl': contract?.url,
    'requestedSchedule': schedule.isEmpty ? null : [for (final r in schedule) r.toJson()],
    'categoryType': categoryTypeCode(type),
    'maxParticipants': maxParticipants,
    'minParticipants': 4,
    'entryFee': entryFee,
    'prizes': [
      for (final p in prizes)
        if (p.position.trim().isNotEmpty && p.amount > 0) {'position': p.position.trim(), 'rewardAmount': p.amount},
    ],
  };
}

/// Sửa thông tin giải (PUT /tournaments/{id}); null = giữ nguyên.
class TournamentInfoUpdate {
  final String? name;
  final DateTime? start;
  final DateTime? end;
  final DateTime? deadline;
  final String? imageUrl;
  final String? description;
  final int? entryFee;

  const TournamentInfoUpdate({
    this.name,
    this.start,
    this.end,
    this.deadline,
    this.imageUrl,
    this.description,
    this.entryFee,
  });

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name!.trim(),
    if (start != null) 'startDate': dateParam(start!),
    if (end != null) 'endDate': dateParam(end!),
    if (deadline != null) 'registrationDeadline': dateParam(deadline!),
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (description != null) 'rules': description!.trim(),
    if (entryFee != null) 'entryFee': entryFee,
  };
}

/// Trạng thái duyệt của Admin.
enum ApprovalStatus { pending, approved, rejected, unknown }

/// Nhóm lọc ở "Giải tôi tổ chức" (như Web).
enum OrganizedGroup {
  inProgress('Đang thi đấu'),
  open('Đang nhận đăng ký'),
  pending('Chờ duyệt'),
  finished('Đã kết thúc'),
  cancelled('Đã hủy');

  const OrganizedGroup(this.label);

  final String label;
}

/// Giải tôi tổ chức (danh sách + chi tiết).
class OrganizedTournament {
  final String id;
  final String name;
  final String status;
  final ApprovalStatus approval;
  final String approvalNote;
  final String sportName;

  /// Mã bộ môn (lọc đội khi mời).
  final String categoryId;

  /// Mã cơ sở (xếp ca sân cho trận).
  final String facilityId;

  final String organizerName;
  final String facilityName;
  final String facilityAddress;
  final DateTime? start;
  final DateTime? end;
  final DateTime? deadline;
  final TournamentTier? tier;
  final TournamentPurpose? purpose;
  final DivisionType type;
  final BracketFormat? format;
  final int maxParticipants;
  final int registeredCount;
  final int entryFee;
  final List<OrganizerPrize> prizes;
  final String description;
  final String imageUrl;
  final int? minRating;
  final int? maxRating;
  final int? minRatedMatches;
  final List<TournamentDocument> documents;
  final List<CourtScheduleRequest> requestedSchedule;
  final String cancellationReason;

  /// false khi là giải người khác tổ chức tại cơ sở của tôi (chủ sân).
  final bool isOrganizer;

  const OrganizedTournament({
    required this.id,
    required this.name,
    this.status = 'OPEN',
    this.approval = ApprovalStatus.unknown,
    this.approvalNote = '',
    this.sportName = '',
    this.categoryId = '',
    this.facilityId = '',
    this.organizerName = '',
    this.facilityName = '',
    this.facilityAddress = '',
    this.start,
    this.end,
    this.deadline,
    this.tier,
    this.purpose,
    this.type = DivisionType.singles,
    this.format,
    this.maxParticipants = 0,
    this.registeredCount = 0,
    this.entryFee = 0,
    this.prizes = const [],
    this.description = '',
    this.imageUrl = '',
    this.minRating,
    this.maxRating,
    this.minRatedMatches,
    this.documents = const [],
    this.requestedSchedule = const [],
    this.cancellationReason = '',
    this.isOrganizer = true,
  });

  String get _status => status.toUpperCase();
  bool get isCancelled => _status == 'CANCELLED';
  bool get isFinished => _status == 'FINISHED';
  bool get isClosed => isCancelled || isFinished;
  bool get isPendingApproval => approval == ApprovalStatus.pending;
  bool get isRejected => approval == ApprovalStatus.rejected;

  OrganizedGroup get group {
    if (isCancelled) return OrganizedGroup.cancelled;
    if (isFinished) return OrganizedGroup.finished;
    if (isPendingApproval || isRejected) return OrganizedGroup.pending;
    return _status == 'IN_PROGRESS' ? OrganizedGroup.inProgress : OrganizedGroup.open;
  }

  /// Nhãn trạng thái: theo duyệt trước (BE để OPEN cho giải chờ duyệt).
  String get statusLabel {
    if (isCancelled) return 'Đã hủy';
    if (isFinished) return 'Đã kết thúc';
    if (isPendingApproval) return 'Chờ Admin duyệt';
    if (isRejected) return 'Bị từ chối';
    return _status == 'IN_PROGRESS' ? 'Đang thi đấu' : 'Đang nhận đăng ký';
  }

  /// Xóa được khi đã hủy hoặc chưa ai đăng ký (như Web).
  bool get canDelete => isCancelled || registeredCount == 0;

  /// Sửa lệ phí: giải còn mở và chưa ai đăng ký.
  bool get canEditFee => _status == 'OPEN' && registeredCount == 0;

  bool get isOpen => _status == 'OPEN' && !isPendingApproval && !isRejected;

  /// Quá hạn đăng ký mà chưa đủ 4 người / đội: BTC chọn vẫn thi đấu hoặc hủy (như Web).
  bool needsRegistrationDecision(DateTime now) =>
      isOpen && deadline != null && deadline!.isBefore(now) && registeredCount < 4;

  int get prizeTotal => prizes.fold(0, (s, p) => s + p.amount);

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty || s == 'null' ? null : s;
  }

  static int? _intOrNull(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
  static DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

  static Object? _pick(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      Object? cur = j;
      for (final part in k.split('.')) {
        cur = cur is Map ? cur[part] : null;
      }
      if (cur != null && '$cur'.isNotEmpty) return cur;
    }
    return null;
  }

  static ApprovalStatus approvalFromApi(Object? value) {
    final v = '${value ?? ''}'.toUpperCase();
    if (v.startsWith('PENDING')) return ApprovalStatus.pending;
    if (v == 'APPROVED') return ApprovalStatus.approved;
    if (v == 'REJECTED') return ApprovalStatus.rejected;
    return ApprovalStatus.unknown;
  }

  factory OrganizedTournament.fromApi(Map<String, dynamic> j) {
    final rulesUrls = [
      for (final u in (j['rulesFileUrls'] as List? ?? const []))
        if (_str(u) != null) _str(u)!,
    ];
    if (rulesUrls.isEmpty && _str(j['rulesFileUrl']) != null) rulesUrls.add(_str(j['rulesFileUrl'])!);
    final docs = [
      for (var i = 0; i < rulesUrls.length; i++)
        TournamentDocument(url: rulesUrls[i], name: rulesUrls.length > 1 ? 'Tài liệu giải ${i + 1}' : 'Tài liệu giải'),
      if (_str(j['contractFileUrl']) != null)
        TournamentDocument(url: _str(j['contractFileUrl'])!, name: 'Hợp đồng với chủ sân'),
    ];
    String? up(Object? v) => _str(v)?.toUpperCase();
    final tierKey = up(j['tier']);
    final purposeKey = up(j['purpose']);
    return OrganizedTournament(
      id: _str(_pick(j, ['id', 'tournamentId'])) ?? '',
      name: _str(_pick(j, ['name', 'title'])) ?? '—',
      status: _str(_pick(j, ['status', 'tournamentStatus'])) ?? 'OPEN',
      approval: approvalFromApi(j['approvalStatus']),
      approvalNote: _str(_pick(j, ['approvalNote', 'rejectionReason', 'rejectReason'])) ?? '',
      sportName: _str(_pick(j, ['categoryName', 'sportName', 'category.name'])) ?? '',
      categoryId: _str(_pick(j, ['categoryId', 'sportCategoryId', 'category.id'])) ?? '',
      facilityId: _str(_pick(j, ['facilityId', 'facility.id'])) ?? '',
      organizerName: _str(_pick(j, ['organizerName', 'ownerName', 'createdByName', 'hostName'])) ?? '',
      facilityName: _str(_pick(j, ['facilityName', 'facility.name'])) ?? '',
      facilityAddress: _str(_pick(j, ['facilityAddress', 'facility.address'])) ?? '',
      start: _date(_pick(j, ['startDate', 'startTime'])),
      end: _date(_pick(j, ['endDate', 'endTime'])),
      deadline: _date(_pick(j, ['registrationDeadline', 'registrationEndDate'])),
      tier: TournamentTier.values.where((t) => t.apiValue == tierKey).firstOrNull,
      purpose: TournamentPurpose.values.where((p) => p.apiValue == purposeKey).firstOrNull,
      type: divisionTypeFromApi(j['categoryType']),
      format: BracketFormat.fromApi(_pick(j, ['format', 'defaultBracketFormat', 'bracketType'])),
      maxParticipants: _intOrNull(_pick(j, ['maxParticipants', 'capacity'])) ?? 0,
      registeredCount:
          _intOrNull(_pick(j, ['registeredCount', 'currentParticipants', 'participantCount', 'totalParticipants'])) ??
          0,
      entryFee: _intOrNull(_pick(j, ['entryFee', 'fee'])) ?? 0,
      prizes: [
        for (final p in (j['prizes'] as List? ?? const []).whereType<Map>())
          OrganizerPrize(
            position: _str(p['position'] ?? p['rank'] ?? p['name']) ?? '',
            amount: _intOrNull(p['rewardAmount'] ?? p['amount']) ?? 0,
          ),
      ],
      description: _str(_pick(j, ['rules', 'description'])) ?? '',
      imageUrl: _str(_pick(j, ['imageUrl', 'coverImageUrl', 'bannerUrl'])) ?? '',
      minRating: _intOrNull(j['minRating']),
      maxRating: _intOrNull(j['maxRating']),
      minRatedMatches: _intOrNull(j['minRatedMatches']),
      documents: docs,
      requestedSchedule: [
        for (final r in (j['requestedSchedule'] as List? ?? const []).whereType<Map>())
          CourtScheduleRequest(
            date: DateTime.tryParse('${r['date']}'),
            session: CourtSession.fromApi(r['session']) ?? CourtSession.fullDay,
            courtCount: _intOrNull(r['courtCount']) ?? 1,
            startTime: _str(r['startTime']),
            endTime: _str(r['endTime']),
          ),
      ],
      cancellationReason: _str(_pick(j, ['cancellationReason', 'cancelReason'])) ?? '',
      isOrganizer: j['isOrganizer'] != false,
    );
  }

  OrganizedTournament copyWith({
    String? name,
    String? status,
    DateTime? start,
    DateTime? end,
    DateTime? deadline,
    String? description,
    String? imageUrl,
    int? entryFee,
    String? cancellationReason,
    int? registeredCount,
  }) => OrganizedTournament(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    approval: approval,
    approvalNote: approvalNote,
    sportName: sportName,
    categoryId: categoryId,
    facilityId: facilityId,
    organizerName: organizerName,
    facilityName: facilityName,
    facilityAddress: facilityAddress,
    start: start ?? this.start,
    end: end ?? this.end,
    deadline: deadline ?? this.deadline,
    tier: tier,
    purpose: purpose,
    type: type,
    format: format,
    maxParticipants: maxParticipants,
    registeredCount: registeredCount ?? this.registeredCount,
    entryFee: entryFee ?? this.entryFee,
    prizes: prizes,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    minRating: minRating,
    maxRating: maxRating,
    minRatedMatches: minRatedMatches,
    documents: documents,
    requestedSchedule: requestedSchedule,
    cancellationReason: cancellationReason ?? this.cancellationReason,
    isOrganizer: isOrganizer,
  );
}
