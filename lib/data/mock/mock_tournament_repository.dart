import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/tournament_strings.dart';
import '../../models/user_role.dart';
import '../../models/sport.dart';
import '../../models/tournament.dart';
import '../../models/wallet_transaction.dart';
import '../repositories/tournament_repository.dart';
import '../repositories/wallet_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_facility_data.dart';
import 'mock_wallet_repository.dart';

/// Bản giả lập [TournamentRepository].
///
/// - Giải mẫu có ngày tính theo hôm nay để luôn đủ các trạng thái: mở đăng ký, sắp diễn ra,
///   đang diễn ra, đã kết thúc. Giải nào có thay đổi (đăng ký / rút / hủy) thì lưu lại nguyên bản.
/// - Lệ phí trừ/hoàn qua ví giả lập; ghi lại khoản đã trả theo từng đơn để biết hoàn bao nhiêu.
class MockTournamentRepository implements TournamentRepository, SandboxTournamentSimulator {
  static const String keyTournaments = 'tournaments';

  /// tournamentId -> {entryId: lệ phí đã trả qua ví}.
  static const String keyPayments = 'tournament_payments';

  final Duration latency;
  final DateTime Function() _now;
  final MockWalletRepository _wallet;
  int _counter = 0;

  MockTournamentRepository({
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? now,
    MockWalletRepository? wallet,
  })  : _now = now ?? DateTime.now,
        _wallet = wallet ?? MockWalletRepository(latency: Duration.zero);

  @override
  Future<List<Tournament>> getTournaments(TournamentQuery query) async {
    await _delay();
    final now = _now();
    final items = (await _all())
        .where((t) => t.city == query.city)
        .where((t) => query.sport == null || t.sport == query.sport)
        .where((t) => query.status == null || t.status(now) == query.status)
        .toList()
      ..sort((a, b) {
        final byStatus = a.status(now).index.compareTo(b.status(now).index);
        if (byStatus != 0) return byStatus;
        final ended = a.status(now).index >= TournamentStatus.finished.index;
        return ended ? b.startDate.compareTo(a.startDate) : a.startDate.compareTo(b.startDate);
      });
    return items;
  }

  @override
  Future<Tournament> getTournament(String tournamentId) async {
    await _delay();
    return _find(tournamentId);
  }

  @override
  Future<List<Tournament>> getMyTournaments() async {
    await _delay();
    final me = await _requireUser();
    final now = _now();
    bool isPast(Tournament t) => t.status(now).index >= TournamentStatus.finished.index;

    final mine = (await _all()).where((t) => t.entryOf(me.id) != null).toList();
    final active = mine.where((t) => !isPast(t)).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = mine.where(isPast).toList()..sort((a, b) => b.startDate.compareTo(a.startDate));
    return [...active, ...past];
  }

  @override
  Future<TournamentMember> findPlayer(String emailOrPhone) async {
    await _delay();
    final key = emailOrPhone.trim().toLowerCase();
    final user = await MockAuthRepository(latency: Duration.zero).findUser(key);
    if (user != null) {
      if (user.role != UserRole.player) throw const TournamentException(TournamentStrings.notAPlayer);
      return TournamentMember(userId: user.id, name: user.fullName);
    }
    final demo = _demoPlayers.where((p) => p.email == key || p.phone == key).firstOrNull;
    if (demo == null) throw const TournamentException(TournamentStrings.playerNotFound);
    return TournamentMember(userId: demo.id, name: demo.name);
  }

  @override
  Future<Tournament> register(TournamentRegistration registration) async {
    await _delay();
    final me = await _requireUser();
    final now = _now();
    final t = await _find(registration.tournamentId);

    if (t.status(now) != TournamentStatus.registrationOpen) throw const TournamentException(TournamentStrings.closed);
    if (t.slotsLeft <= 0) throw const TournamentException(TournamentStrings.noSlots);
    if (t.entryOf(me.id) != null) throw const TournamentException(TournamentStrings.alreadyRegistered);

    final mates = registration.teammates;
    final ids = {me.id, ...mates.map((m) => m.userId)};
    if (ids.length != mates.length + 1) throw const TournamentException(TournamentStrings.duplicateMember);
    if (ids.length < t.minMembers || ids.length > t.maxMembers) {
      throw const TournamentException(TournamentStrings.wrongMemberCount);
    }
    for (final mate in mates) {
      if (t.entryOf(mate.userId) != null) throw TournamentException(TournamentStrings.memberTaken(mate.name));
    }
    final teamName = registration.teamName.trim();
    if (t.entryType == TournamentEntryType.team && teamName.isEmpty) {
      throw const TournamentException(TournamentStrings.teamNameRequired);
    }

    final members = [TournamentMember(userId: me.id, name: me.name), ...mates];
    final entry = TournamentEntry(
      id: '${t.id}-u${now.millisecondsSinceEpoch}-${++_counter}',
      name: t.entryType == TournamentEntryType.team ? teamName : members.map((m) => m.name).join(' / '),
      captainId: me.id,
      members: members,
      registeredAt: now,
    );

    try {
      await _wallet.pay(
        amount: t.entryFee,
        type: TransactionType.tournamentFee,
        description: 'Lệ phí ${t.name}',
        reference: t.id,
      );
    } on WalletException catch (e) {
      throw TournamentException(e.message);
    }

    final updated = t.copyWith(entries: [...t.entries, entry]);
    await _save(updated);
    final payments = await _payments();
    payments.putIfAbsent(t.id, () => {})[entry.id] = t.entryFee;
    await _savePayments(payments);
    return updated;
  }

  @override
  Future<int> withdraw(String tournamentId) async {
    await _delay();
    final me = await _requireUser();
    final now = _now();
    final t = await _find(tournamentId);
    final entry = t.entryOf(me.id);
    if (entry == null) throw const TournamentException(TournamentStrings.notRegistered);
    if (entry.captainId != me.id) throw const TournamentException(TournamentStrings.notCaptain);
    if (entry.withdrawn) throw const TournamentException(TournamentStrings.alreadyWithdrawn);
    final status = t.status(now);
    if (status != TournamentStatus.registrationOpen && status != TournamentStatus.upcoming) {
      throw const TournamentException(TournamentStrings.alreadyStarted);
    }

    final payments = await _payments();
    final paid = payments[t.id]?.remove(entry.id);
    await _savePayments(payments);

    if (t.refundableOnWithdraw(now)) {
      final refund = paid ?? t.entryFee;
      await _wallet.creditRefund(amount: refund, description: 'Hoàn 100% lệ phí • rút khỏi ${t.name}', reference: t.id);
      await _save(t.copyWith(entries: t.entries.where((e) => e.id != entry.id).toList()));
      return refund;
    }
    // Sau hạn: vẫn giữ trong sơ đồ, BE xử thua các trận còn lại.
    await _save(t.copyWith(entries: [for (final e in t.entries) e.id == entry.id ? e.copyWith(withdrawn: true) : e]));
    return 0;
  }

  @override
  Future<Tournament> simulateOrganizerCancelled(String tournamentId) async {
    final t = await _find(tournamentId);
    if (t.cancelled) return t;
    final payments = await _payments();
    final paid = payments.remove(t.id) ?? {};
    // Đơn mẫu không có bản ghi thanh toán: vẫn hoàn cho đơn của người dùng hiện tại (nếu là đội trưởng).
    final me = await _requireUser();
    final myEntry = t.entryOf(me.id);
    if (myEntry != null && myEntry.captainId == me.id && !myEntry.withdrawn) {
      paid.putIfAbsent(myEntry.id, () => t.entryFee);
    }
    for (final amount in paid.values) {
      await _wallet.creditRefund(amount: amount, description: 'Hoàn 100% lệ phí • BTC hủy ${t.name}', reference: t.id);
    }
    await _savePayments(payments);
    final updated = t.copyWith(cancelled: true);
    await _save(updated);
    return updated;
  }

  // ---------------- Nội bộ ----------------

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Future<({String id, String name})> _requireUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MockAuthRepository.keyCurrentUser);
    if (raw == null) throw const TournamentException(TournamentStrings.loginRequired);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (id: json['id'] as String, name: json['fullName'] as String);
  }

  Future<Tournament> _find(String id) async {
    final t = (await _all()).where((t) => t.id == id).firstOrNull;
    return t ?? (throw const TournamentException(TournamentStrings.notFound));
  }

  Future<List<Tournament>> _all() async {
    final stored = await _stored();
    return {for (final t in _seedTournaments()) t.id: t, ...stored}.values.toList();
  }

  Future<Map<String, Tournament>> _stored() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyTournaments);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((id, json) => MapEntry(id, Tournament.fromJson(json as Map<String, dynamic>)));
  }

  Future<void> _save(Tournament t) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = await _stored();
    stored[t.id] = t;
    await prefs.setString(keyTournaments, jsonEncode(stored.map((id, t) => MapEntry(id, t.toJson()))));
  }

  Future<Map<String, Map<String, int>>> _payments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyPayments);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((tid, byEntry) => MapEntry(tid, Map<String, int>.from(byEntry as Map)));
  }

  Future<void> _savePayments(Map<String, Map<String, int>> payments) async {
    final prefs = await SharedPreferences.getInstance();
    payments.removeWhere((_, byEntry) => byEntry.isEmpty);
    await prefs.setString(keyPayments, jsonEncode(payments));
  }

  // ---------------- Dữ liệu mẫu ----------------

  /// Người chơi có thể thêm vào đội khi demo (ngoài các tài khoản đăng nhập được).
  static const _demoPlayers = [
    (id: 'u-guest-1', name: 'Phương Linh', email: 'phuonglinh@sportnexus.vn', phone: '0911000001'),
    (id: 'u-guest-2', name: 'Tuấn Kiệt', email: 'tuankiet@sportnexus.vn', phone: '0911000002'),
    (id: 'u-guest-3', name: 'Bảo Ngọc', email: 'baongoc@sportnexus.vn', phone: '0911000003'),
    (id: 'u-guest-4', name: 'Gia Huy', email: 'giahuy@sportnexus.vn', phone: '0911000004'),
    (id: 'u-hoangnam', name: 'Hoàng Nam', email: 'hoangnam@sportnexus.vn', phone: '0911000005'),
    (id: 'u-minhtuan', name: 'Minh Tuấn', email: 'minhtuan@sportnexus.vn', phone: '0911000006'),
  ];

  static const _names = [
    'Anh Khoa', 'Bích Ngọc', 'Công Danh', 'Diệu Linh', 'Đức Anh', 'Gia Bảo', 'Hải Đăng', 'Hồng Nhung',
    'Khánh Vy', 'Lâm Phong', 'Mai Anh', 'Nhật Minh', 'Phúc Thịnh', 'Quang Huy', 'Thanh Tâm', 'Thùy Dung',
    'Trung Kiên', 'Tú Anh', 'Văn Long', 'Xuân Mai', 'Yến Nhi', 'Bảo Long', 'Cẩm Tú', 'Đăng Khoa',
  ];

  static const _teams = [
    'FC Sài Gòn', 'Kiệt FC', 'Huy United', 'Bình Thạnh Ballers', 'Q7 Warriors', 'Thủ Đức Stars',
    'Gò Vấp Tigers', 'Hoa Lư Legends', 'Ngọc Team', 'Phú Nhuận Eagles',
  ];

  List<Tournament> _seedTournaments() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset, [int hour = 0, int minute = 0]) => today.add(Duration(days: offset, hours: hour, minutes: minute));
    final facilities = {for (final f in MockFacilityData.facilities) f.id: f};
    final created = day(-20);

    TournamentEntry entry(String tid, int n, String name, List<String> memberNames, {String? captainId, List<String>? ids}) {
      final members = [
        for (var i = 0; i < memberNames.length; i++)
          TournamentMember(userId: ids?[i] ?? 'u-$tid-$n-$i', name: memberNames[i]),
      ];
      return TournamentEntry(
        id: '$tid-e$n',
        name: name,
        captainId: captainId ?? members.first.userId,
        members: members,
        registeredAt: created.add(Duration(hours: n * 5)),
      );
    }

    String person(int i) => _names[i % _names.length];
    TournamentEntry single(String tid, int n) => entry(tid, n, person(n), [person(n)]);
    TournamentEntry pair(String tid, int n) {
      final a = person(n * 2), b = person(n * 2 + 1);
      return entry(tid, n, '$a / $b', [a, b]);
    }
    TournamentEntry team(String tid, int n, int size) =>
        entry(tid, n, _teams[n % _teams.length], [for (var i = 0; i < size; i++) person(n * 3 + i)]);

    Tournament make({
      required String id,
      required String name,
      required String facilityId,
      required Sport sport,
      required TournamentEntryType type,
      required int minMembers,
      required int maxMembers,
      required int maxEntries,
      required int fee,
      required DateTime deadline,
      required DateTime start,
      required DateTime end,
      required String description,
      required List<TournamentPrize> prizes,
      required List<TournamentEntry> entries,
      List<TournamentMatch> matches = const [],
      List<String> extraRules = const [],
    }) {
      final f = facilities[facilityId]!;
      return Tournament(
        id: id,
        name: name,
        organizer: f.name,
        facilityId: f.id,
        facilityName: f.name,
        city: f.city,
        district: f.district,
        sport: sport,
        entryType: type,
        minMembers: minMembers,
        maxMembers: maxMembers,
        maxEntries: maxEntries,
        entryFee: fee,
        registrationDeadline: deadline,
        startDate: start,
        endDate: end,
        description: description,
        prizes: prizes,
        rules: [
          'Thể thức loại trực tiếp, bốc thăm chia nhánh sau khi hết hạn đăng ký.',
          'Có mặt trước giờ thi đấu 30 phút để check-in với ban tổ chức.',
          'Trễ quá 15 phút so với giờ thi đấu bị xử thua.',
          ...extraRules,
          'Quyết định của trọng tài và ban tổ chức là quyết định cuối cùng.',
        ],
        entries: entries,
        matches: matches,
      );
    }

    // 1. Cầu lông đôi – đang mở đăng ký.
    const t1 = 't-hcm-caulong-doi-mua-thu';
    // 2. Bóng đá 5 người – đang mở đăng ký.
    const t2 = 't-hcm-sportnexus-cup';
    // 3. Bóng rổ 3x3 – hết hạn đăng ký, đã bốc thăm, có Khoa Cao làm đội trưởng.
    const t3 = 't-hcm-bongro-3x3';
    final t3Entries = [
      entry(t3, 0, 'Khoa Cao 3x3', ['Khoa Cao', 'Tuấn Kiệt', 'Gia Huy'],
          ids: ['u-player-001', 'u-guest-2', 'u-guest-4']),
      for (var n = 1; n < 8; n++) team(t3, n, 3),
    ];
    // 4. Pickleball đơn – đang diễn ra, Khoa Cao vào bán kết.
    const t4 = 't-hcm-pickleball-open-q7';
    final t4Entries = [
      for (var n = 0; n < 8; n++)
        n == 2 ? entry(t4, n, 'Khoa Cao', ['Khoa Cao'], ids: ['u-player-001']) : single(t4, n + 10),
    ];
    // 5. Tennis đơn – đã kết thúc, Khoa Cao dừng ở bán kết.
    const t5 = 't-hcm-tennis-he';
    final t5Entries = [
      for (var n = 0; n < 8; n++)
        n == 5 ? entry(t5, n, 'Khoa Cao', ['Khoa Cao'], ids: ['u-player-001']) : single(t5, n + 3),
    ];

    return [
      make(
        id: t1,
        name: 'Giải Cầu Lông Đôi Mùa Thu 2026',
        facilityId: 'f-hcm-thientrieu',
        sport: Sport.badminton,
        type: TournamentEntryType.pair,
        minMembers: 2,
        maxMembers: 2,
        maxEntries: 16,
        fee: 300000,
        deadline: day(6, 23, 59),
        start: day(9, 7),
        end: day(10, 18),
        description: 'Giải phong trào đôi nam/nữ/nam nữ, trình độ trung bình – khá. Thi đấu 2 ngày cuối tuần.',
        prizes: const [
          TournamentPrize(title: 'Vô địch', amount: 5000000, extra: 'Cúp + huy chương vàng'),
          TournamentPrize(title: 'Á quân', amount: 3000000, extra: 'Huy chương bạc'),
          TournamentPrize(title: 'Đồng hạng ba (2 đôi)', amount: 1000000, extra: 'Huy chương đồng'),
        ],
        entries: [for (var n = 0; n < 11; n++) pair(t1, n)],
        extraRules: const ['Mỗi trận 3 ván, ván 21 điểm. Cầu do ban tổ chức cung cấp.'],
      ),
      make(
        id: t2,
        name: 'SportNexus Cup – Bóng Đá 5 Người',
        facilityId: 'f-hcm-hoalu',
        sport: Sport.football,
        type: TournamentEntryType.team,
        minMembers: 5,
        maxMembers: 10,
        maxEntries: 8,
        fee: 1500000,
        deadline: day(4, 23, 59),
        start: day(7, 8),
        end: day(7, 18),
        description: 'Giải bóng đá phủi 5 người, đá trong 1 ngày. Mỗi đội 5–10 cầu thủ.',
        prizes: const [
          TournamentPrize(title: 'Vô địch', amount: 8000000, extra: 'Cúp + 10 áo đấu'),
          TournamentPrize(title: 'Á quân', amount: 4000000),
          TournamentPrize(title: 'Vua phá lưới', amount: 500000),
        ],
        entries: [for (var n = 0; n < 5; n++) team(t2, n, 6)],
        extraRules: const ['Mỗi trận 2 hiệp × 20 phút. Hòa thì đá luân lưu 5 quả.', 'Đi giày đinh dăm, không đi giày đinh sắt.'],
      ),
      make(
        id: t3,
        name: 'Giải Bóng Rổ 3x3 Bình Thạnh',
        facilityId: 'f-hcm-chuvanan',
        sport: Sport.basketball,
        type: TournamentEntryType.team,
        minMembers: 3,
        maxMembers: 4,
        maxEntries: 8,
        fee: 600000,
        deadline: day(-1, 23, 59),
        start: day(2, 8),
        end: day(2, 17),
        description: 'Bóng rổ đường phố 3x3, mỗi đội 3–4 người.',
        prizes: const [
          TournamentPrize(title: 'Vô địch', amount: 3000000, extra: 'Cúp'),
          TournamentPrize(title: 'Á quân', amount: 1500000),
        ],
        entries: t3Entries,
        matches: _bracket(t3, t3Entries, roundStarts: [day(2, 8), day(2, 13), day(2, 16)]),
        extraRules: const ['Trận đấu 10 phút hoặc tới 21 điểm.'],
      ),
      make(
        id: t4,
        name: 'Pickleball Open Quận 7',
        facilityId: 'f-hcm-eco-q7',
        sport: Sport.pickleball,
        type: TournamentEntryType.single,
        minMembers: 1,
        maxMembers: 1,
        maxEntries: 8,
        fee: 250000,
        deadline: day(-5, 23, 59),
        start: day(-1, 8),
        end: day(1, 18),
        description: 'Giải đơn mở rộng cho mọi trình độ.',
        prizes: const [
          TournamentPrize(title: 'Vô địch', amount: 2000000, extra: 'Vợt Joola'),
          TournamentPrize(title: 'Á quân', amount: 1000000),
        ],
        entries: t4Entries,
        matches: _bracket(t4, t4Entries, roundStarts: [
          day(-1, 8),
          day(1, 9),
          day(1, 15),
        ], results: [
          [(0, '11-7, 11-9'), (0, '8-11, 11-6, 11-9'), (0, '11-5, 11-8'), (1, '9-11, 11-9, 7-11')],
        ]),
      ),
      make(
        id: t5,
        name: 'Giải Tennis Đơn Mùa Hè',
        facilityId: 'f-hcm-kyhoa',
        sport: Sport.tennis,
        type: TournamentEntryType.single,
        minMembers: 1,
        maxMembers: 1,
        maxEntries: 8,
        fee: 400000,
        deadline: day(-16, 23, 59),
        start: day(-12, 7),
        end: day(-11, 18),
        description: 'Giải đơn nam nữ chung, 2 ngày.',
        prizes: const [
          TournamentPrize(title: 'Vô địch', amount: 4000000, extra: 'Cúp'),
          TournamentPrize(title: 'Á quân', amount: 2000000),
        ],
        entries: t5Entries,
        matches: _bracket(t5, t5Entries, roundStarts: [
          day(-12, 7),
          day(-12, 15),
          day(-11, 16),
        ], results: [
          [(0, '6-3, 6-4'), (1, '4-6, 3-6'), (1, '6-7, 4-6'), (0, '6-2, 6-1')],
          [(1, '3-6, 2-6'), (1, '5-7, 4-6')],
          [(1, '4-6, 6-3, 5-7')],
        ]),
      ),
      make(
        id: 't-hn-caulong-mo-rong',
        name: 'Giải Cầu Lông Hà Nội Mở Rộng',
        facilityId: 'f-hn-caugiay',
        sport: Sport.badminton,
        type: TournamentEntryType.single,
        minMembers: 1,
        maxMembers: 1,
        maxEntries: 32,
        fee: 200000,
        deadline: day(10, 23, 59),
        start: day(14, 7),
        end: day(15, 18),
        description: 'Giải đơn nam, đơn nữ chung nhánh cho người chơi phong trào.',
        prizes: const [
          TournamentPrize(title: 'Vô địch', amount: 3000000),
          TournamentPrize(title: 'Á quân', amount: 1500000),
        ],
        entries: [for (var n = 0; n < 20; n++) single('t-hn-caulong-mo-rong', n)],
      ),
    ];
  }

  /// Sơ đồ loại trực tiếp từ danh sách đơn theo thứ tự bốc thăm.
  /// [results] theo từng vòng: (0 = đơn A thắng / 1 = đơn B thắng, tỉ số).
  static List<TournamentMatch> _bracket(
    String tid,
    List<TournamentEntry> entries, {
    required List<DateTime> roundStarts,
    List<List<(int, String)>> results = const [],
  }) {
    final matches = <TournamentMatch>[];
    List<String?> current = entries.map((e) => e.id).toList();
    for (var round = 1; current.length > 1; round++) {
      final next = <String?>[];
      for (var i = 0; i < current.length ~/ 2; i++) {
        final a = current[2 * i], b = current[2 * i + 1];
        final roundResults = results.length >= round ? results[round - 1] : const <(int, String)>[];
        final result = i < roundResults.length ? roundResults[i] : null;
        final winner = result == null ? null : (result.$1 == 0 ? a : b);
        matches.add(TournamentMatch(
          id: '$tid-r$round-m$i',
          round: round,
          index: i,
          entryAId: a,
          entryBId: b,
          scheduledAt: roundStarts[round - 1].add(Duration(minutes: 45 * (i ~/ 2))),
          court: 'Sân ${i % 2 + 1}',
          score: result?.$2,
          winnerId: winner,
        ));
        next.add(winner);
      }
      current = next;
    }
    return matches;
  }
}
