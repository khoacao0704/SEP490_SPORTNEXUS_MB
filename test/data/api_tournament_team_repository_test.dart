import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/data/api/api_client.dart';
import 'package:test1/data/api/api_facility_repository.dart';
import 'package:test1/data/api/api_player_tournament_repository.dart';
import 'package:test1/data/api/api_team_repository.dart';
import 'package:test1/data/api/token_store.dart';
import 'package:test1/data/repositories/player_tournament_repository.dart';
import 'package:test1/data/repositories/team_repository.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/team.dart';
import 'package:test1/models/tournament_listing.dart';

/// Giả lập server: trả JSON theo "METHOD path", ghi lại request đã gửi. Không gọi mạng.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) return ResponseBody.fromString('', 404);
    final (status, body) = route;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _ok(Object? data) => {'statusCode': 200, 'message': 'OK', 'data': data};

void main() {
  late _FakeServer server;
  late ApiPlayerTournamentRepository tournaments;
  late ApiTeamRepository teams;

  setUp(() async {
    server = _FakeServer();
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final dio = Dio(BaseOptions(baseUrl: 'https://be.test', validateStatus: (_) => true))..httpClientAdapter = server;
    final api = ApiClient(tokens: tokens, dio: dio);
    tournaments = ApiPlayerTournamentRepository(api: api, facility: ApiFacilityRepository(api: api));
    teams = ApiTeamRepository(api: api);
  });

  group('giải đấu', () {
    test('tìm giải: gửi môn theo categoryId / bộ lọc / sắp xếp, đọc giải và còn trang sau', () async {
      server.routes['GET ${ApiFacilityRepository.sportsPath}'] = (
        200,
        _ok([
          {'id': 'cat-cl', 'name': 'Cầu lông'},
        ]),
      );
      server.routes['GET ${ApiPlayerTournamentRepository.searchPath}'] = (
        200,
        _ok({
          'page': 1,
          'pageSize': 10,
          'totalItems': 11,
          'totalPages': 2,
          'items': [
            {
              'id': 't-1',
              'name': 'Giải A',
              'status': 'OPEN',
              'isPromoted': true,
              'facilityId': 'f-1',
              'facilityName': 'Sân A',
              'categoryName': 'Cầu lông',
              'totalSubTournaments': 2,
              'startDate': '2026-11-10T00:00:00Z',
              'registrationDeadline': '2026-11-05T15:00:00Z',
              'isRegistrationOpen': true,
            },
          ],
        }),
      );

      final page = await tournaments.search(
        const TournamentSearchQuery(
          keyword: ' cup ',
          sport: Sport.badminton,
          registrationOpenOnly: true,
          sort: TournamentSort.deadline,
        ),
      );

      final q = server.requests.last.queryParameters;
      expect(q['Keyword'], 'cup');
      expect(q['CategoryId'], 'cat-cl');
      expect(q['RegistrationOpen'], true);
      expect(q['SortBy'], 'deadline');
      expect(q.containsKey('Status'), isFalse);
      expect(page.hasMore, isTrue);
      final t = page.items.single;
      expect(t.sport, Sport.badminton);
      expect(t.phase, TournamentPhase.open);
      expect(t.isPromoted, isTrue);
      expect(t.divisionCount, 2);
      expect(t.registrationDeadline, DateTime.utc(2026, 11, 5, 15).toLocal());
    });

    test('chi tiết: bảng con, loại đăng ký, giải thưởng; giải không chia bảng con thì chính nó là nội dung', () async {
      server.routes['GET ${ApiPlayerTournamentRepository.detailPath('t-1')}'] = (
        200,
        _ok({
          'id': 't-1',
          'name': 'Giải A',
          'status': 'OPEN',
          'rules': 'Điều lệ',
          'sportRulesDescription': 'Luật',
          'prizes': [
            {'id': 'p2', 'position': 2, 'rewardAmount': 500000},
            {'id': 'p1', 'position': 1, 'rewardAmount': 1000000},
          ],
          'children': [
            {
              'id': 'd-1',
              'name': 'Đôi',
              'categoryType': 'PREMADE_TEAMS',
              'categoryTypeName': 'Đôi cố định',
              'maxParticipants': 8,
              'minTeamSize': 2,
              'maxTeamSize': 2,
              'entryFee': 300000.0,
              'status': 'OPEN',
              'isRegistrationOpen': true,
            },
          ],
        }),
      );
      server.routes['GET ${ApiPlayerTournamentRepository.detailPath('t-2')}'] = (
        200,
        _ok({'id': 't-2', 'name': 'Giải đơn', 'status': 'OPEN', 'categoryType': 'SINGLES', 'entryFee': 0, 'children': []}),
      );

      final d = await tournaments.getDetails('t-1');
      expect(d.rules, 'Điều lệ');
      expect(d.prizes.map((p) => p.position), [1, 2]);
      final division = d.divisions.single;
      expect(division.type, DivisionType.premadeTeams);
      expect(division.typeLabel, 'Đôi cố định');
      expect(division.entryFee, 300000);
      expect(division.maxTeamSize, 2);

      final single = await tournaments.getDetails('t-2');
      expect(single.divisions.single.id, 't-2');
      expect(single.divisions.single.type, DivisionType.singles);
    });

    test('người tham gia gom theo đội; sơ đồ sắp theo thứ tự trận, bên chưa rõ là TBD', () async {
      server.routes['GET ${ApiPlayerTournamentRepository.participantsPath('t-1')}'] = (
        200,
        _ok([
          {'participantId': 'p1', 'tournamentId': 'd-1', 'userId': 'u1', 'fullName': 'An', 'teamId': 'tm', 'teamName': 'Đội X'},
          {'participantId': 'p2', 'tournamentId': 'd-1', 'userId': 'u2', 'fullName': 'Bình', 'teamId': 'tm', 'teamName': 'Đội X'},
          {'participantId': 'p3', 'tournamentId': 'd-1', 'userId': 'u3', 'fullName': 'Chi', 'isCheckedIn': true},
        ]),
      );
      server.routes['GET ${ApiPlayerTournamentRepository.bracketPath('d-1')}'] = (
        200,
        _ok([
          {'id': 'm2', 'matchIndex': 2, 'roundName': 'Chung kết', 'p1': 'TBD', 'p2': null},
          {
            'id': 'm1',
            'matchIndex': 1,
            'roundName': 'Bán kết',
            'status': 'COMPLETED',
            'p1': 'Đội X',
            'p2': 'Chi',
            'winner': 'Đội X',
            'courtName': 'Sân 1',
            'scores': [
              {'setNumber': 1, 'scoreP1': 11, 'scoreP2': 7, 'isTiebreak': false},
            ],
          },
        ]),
      );

      final groups = TournamentEntryGroup.group(await tournaments.getParticipants('t-1'));
      expect(groups.map((g) => g.name), ['Đội X', 'Chi']);
      expect(groups.first.members, hasLength(2));
      expect(groups.last.members.single.isCheckedIn, isTrue);

      final bracket = await tournaments.getBracket('d-1');
      expect(bracket.map((m) => m.id), ['m1', 'm2']);
      expect(bracket.first.isFinished, isTrue);
      expect(bracket.first.scores.single.a, 11);
      expect(bracket.last.sideB, BracketMatch.unknownSide);
      expect(bracket.last.isFinished, isFalse);
    });

    test('đã đăng ký: tách bảng con / giải mẹ, vé QR; lịch đấu sắp theo giờ', () async {
      server.routes['GET ${ApiPlayerTournamentRepository.myRegistrationsPath}'] = (
        200,
        _ok([
          {
            'participantId': 'p1',
            'tournamentId': 'd-1',
            'tournamentName': 'Đôi',
            'parentTournamentId': 't-1',
            'parentTournamentName': 'Giải A',
            'categoryType': 'PREMADE_TEAMS',
            'entryFee': 300000,
            'tournamentStatus': 'OPEN',
            'qrCode': 'TN-ABC',
            'teamId': 'tm',
            'teamName': 'Đội X',
            'registrationDeadline': '2099-01-01T00:00:00Z',
          },
        ]),
      );
      server.routes['GET ${ApiPlayerTournamentRepository.myMatchesPath}'] = (
        200,
        _ok([
          {'matchId': 'm2', 'tournamentName': 'Giải A', 'startTime': '2026-11-11T03:00:00Z', 'mySideName': 'Đội X', 'opponentName': null},
          {'matchId': 'm1', 'tournamentName': 'Giải A', 'startTime': '2026-11-10T03:00:00Z', 'mySideName': 'Đội X', 'opponentName': 'Chi'},
        ]),
      );

      final r = (await tournaments.getMyRegistrations()).single;
      expect(r.divisionId, 'd-1');
      expect(r.tournamentId, 't-1');
      expect(r.tournamentName, 'Giải A');
      expect(r.teamName, 'Đội X');
      expect(r.canWithdraw, isTrue);
      expect(r.refundableAt(DateTime(2026)), isTrue);

      final matches = await tournaments.getMyMatches();
      expect(matches.map((m) => m.matchId), ['m1', 'm2']);
      expect(matches.last.opponent, BracketMatch.unknownSide);
    });

    test('đăng ký: chỉ gửi teamId cho bảng đội; lỗi BE thành TournamentException', () async {
      server.routes['POST ${ApiPlayerTournamentRepository.joinPath('d-1')}'] = (200, _ok({'participantId': 'p9'}));
      server.routes['POST ${ApiPlayerTournamentRepository.joinPath('d-2')}'] = (
        400,
        {'statusCode': 400, 'message': 'Số dư ví không đủ', 'data': null},
      );

      await tournaments.join('d-1', teamId: 'tm');
      expect(server.requests.last.queryParameters, {'teamId': 'tm'});
      await expectLater(
        tournaments.join('d-2'),
        throwsA(isA<TournamentException>().having((e) => e.message, 'message', 'Số dư ví không đủ')),
      );
      expect(server.requests.last.queryParameters, isEmpty);
    });
  });

  group('đội', () {
    test('đội của tôi: đội trưởng từ createdById, thành viên; thiếu đội trưởng trong danh sách thì thêm vào', () async {
      server.routes['GET ${ApiTeamRepository.myTeamsPath}'] = (
        200,
        _ok([
          {
            'id': 'tm',
            'name': 'Đội X',
            'createdById': 'u1',
            'createdByName': 'An',
            'createAt': '2026-10-01T00:00:00Z',
            'isLocked': false,
            'totalMembers': 2,
            'members': [
              {'accountId': 'u2', 'fullName': 'Bình', 'phone': '0911', 'joinedAt': '2026-10-02T00:00:00Z'},
            ],
          },
        ]),
      );

      final team = (await teams.getMyTeams()).single;
      expect(team.captainId, 'u1');
      expect(team.isCaptain('u1'), isTrue);
      expect(team.members.map((m) => m.accountId), ['u1', 'u2']);
      expect(team.createdAt, DateTime.utc(2026, 10, 1).toLocal());
    });

    test('tạo đội gửi SĐT mời; lời mời của tôi chỉ lấy PENDING; chuyển đội trưởng gửi newCaptainId', () async {
      server.routes['POST ${ApiTeamRepository.teamsPath}'] = (200, _ok({'id': 'tm', 'name': 'Đội X', 'createdById': 'me'}));
      server.routes['GET ${ApiTeamRepository.myInvitationsPath}'] = (
        200,
        _ok([
          {'id': 'i1', 'teamId': 'tm', 'teamName': 'Đội X', 'status': 'PENDING', 'expiresAt': '2026-11-01T00:00:00Z'},
          {'id': 'i2', 'teamId': 'tm', 'teamName': 'Đội X', 'status': 'EXPIRED'},
        ]),
      );
      server.routes['PUT ${ApiTeamRepository.captainPath('tm')}'] = (200, _ok(null));

      await teams.createTeam(name: ' Đội X ', invitePhones: ['0911', '0922']);
      expect(server.requests.last.data, {
        'name': 'Đội X',
        'memberPhones': ['0911', '0922'],
      });

      final invitations = await teams.getMyInvitations();
      expect(server.requests.last.queryParameters['status'], 'PENDING');
      expect(invitations.map((i) => i.id), ['i1']);
      expect(invitations.single.status, InvitationStatus.pending);

      await teams.transferCaptain('tm', 'u2');
      expect(server.requests.last.data, {'newCaptainId': 'u2'});
    });

    test('lỗi BE (vd. SĐT chưa có tài khoản) thành TeamException', () async {
      server.routes['POST ${ApiTeamRepository.invitationsPath('tm')}'] = (
        404,
        {'statusCode': 404, 'message': 'Không tìm thấy tài khoản với số điện thoại 0999', 'data': null},
      );

      expect(
        () => teams.invite('tm', '0999'),
        throwsA(isA<TeamException>().having((e) => e.message, 'message', contains('0999'))),
      );
    });
  });
}
