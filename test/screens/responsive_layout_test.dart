// Kiểm bố cục các màn người chơi trên nhiều cỡ máy + cỡ chữ phóng to: không được tràn chữ (RenderFlex overflow).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/survey_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_facility_repository.dart';
import 'package:test1/data/mock/mock_lfg_repository.dart';
import 'package:test1/data/mock/mock_player_profile_repository.dart';
import 'package:test1/data/mock/mock_player_tournament_repository.dart';
import 'package:test1/data/mock/mock_rating_repository.dart';
import 'package:test1/data/mock/mock_review_repository.dart';
import 'package:test1/data/mock/mock_team_repository.dart';
import 'package:test1/data/mock/mock_wallet_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/models/ai_chat.dart';
import 'package:test1/models/lfg_match.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/sport_rating.dart';
import 'package:test1/models/tournament_listing.dart';
import 'package:test1/screens/lfg/create_lfg_match_screen.dart';
import 'package:test1/screens/lfg/lfg_match_detail_screen.dart';
import 'package:test1/screens/lfg/lfg_screen.dart';
import 'package:test1/screens/profile/change_phone_screen.dart';
import 'package:test1/screens/profile/edit_profile_screen.dart';
import 'package:test1/screens/profile/player_survey_screen.dart';
import 'package:test1/screens/profile/profile_screen.dart';
import 'package:test1/screens/rating/leaderboard_screen.dart';
import 'package:test1/screens/rating/my_elo_screen.dart';
import 'package:test1/screens/rating/skill_assessment_screen.dart';
import 'package:test1/screens/review/submit_review_screen.dart';
import 'package:test1/screens/team/team_detail_screen.dart';
import 'package:test1/screens/team/team_form_screen.dart';
import 'package:test1/screens/tournament/tournament_bracket_screen.dart';
import 'package:test1/screens/tournament/tournament_invitations_screen.dart';
import 'package:test1/screens/tournament/tournament_match_feedback_screen.dart';
import 'package:test1/widgets/ai_chat/ai_suggestion_cards.dart';

import '../helpers/layout_check.dart';

const _longName = 'Nguyễn Hoàng Minh Khôi Đại Nghĩa Trường Sơn';

/// Elo / bảng xếp hạng có tên rất dài.
class _LongRatings extends MockRatingRepository {
  @override
  Future<List<SportRating>> getMyRatings() async => const [
    SportRating(
      type: RatingType.personal,
      ownerId: 'u-player-001',
      ownerName: _longName,
      sportCategoryId: 'mock-badminton',
      sport: Sport.badminton,
      rating: 1488,
      rank: 'Bạch kim',
      ratedMatches: 128,
      isProvisional: true,
    ),
    SportRating(
      type: RatingType.team,
      ownerId: 'team-pickle-q7',
      ownerName: 'Câu Lạc Bộ Pickleball Quận 7 Mở Rộng Phú Mỹ Hưng',
      sportCategoryId: 'mock-pickleball',
      sport: Sport.pickleball,
      rating: 1755,
      rank: 'Kim cương',
      ratedMatches: 9,
    ),
  ];

  @override
  Future<LeaderboardPage> getLeaderboard(Sport sport, {RatingType type = RatingType.personal, int page = 1}) async =>
      LeaderboardPage(
        items: [
          for (var i = 0; i < 12; i++)
            SportRating(
              type: type,
              ownerId: 'x$i',
              ownerName: '$_longName $i',
              sportCategoryId: 'mock-${sport.name}',
              sport: sport,
              rating: 1999 - i,
              rank: 'Kim cương',
              ratedMatches: 999,
            ),
        ],
        page: page,
        pageSize: 20,
        hasMore: false,
      );
}

/// Giải có vòng bảng + bảng xếp hạng, tên đội dài, lời mời giải nội bộ.
class _GroupStageTournaments extends MockPlayerTournamentRepository {
  _GroupStageTournaments(MockTeamRepository teams) : super(teams: teams, latency: Duration.zero) {
    invitations.add(
      const TournamentInvitation(
        id: 'inv',
        divisionId: 'pd-pickle-singles',
        divisionName: 'Đơn nam mở rộng hạng A',
        tournamentName: 'Giải Pickleball Mở Rộng Quận 7 Mùa Đông Năm 2026',
        type: DivisionType.premadeTeams,
        entryFee: 1250000,
        teamName: 'Câu Lạc Bộ Pickleball Quận 7 Mở Rộng',
        invitedByName: 'Ban Tổ Chức Giải Phong Trào Thành Phố',
        message: 'Mời đội tham gia giải nội bộ cuối năm, hạn xác nhận trước ngày 10/12.',
      ),
    );
  }

  @override
  Future<List<BracketMatch>> getBracket(String divisionId) async => [
    for (var i = 0; i < 3; i++)
      BracketMatch(
        id: 'g$i',
        index: i,
        roundName: 'Lượt $i',
        stage: MatchStage.group,
        groupName: 'A',
        resultType: i == 0 ? MatchResultType.draw : MatchResultType.walkover,
        status: 'FINISHED',
        start: DateTime(2026, 12, 1, 18),
        courtName: 'Sân số 12 (sân trong nhà có mái che)',
        sideA: 'Câu Lạc Bộ Bóng Đá Phú Mỹ Hưng',
        sideB: 'Đội Bóng Văn Phòng Công Ty Cổ Phần ABC',
        winner: i == 0 ? null : 'Câu Lạc Bộ Bóng Đá Phú Mỹ Hưng',
      ),
  ];

  @override
  Future<List<StandingGroup>> getStandings(String divisionId) async => const [
    StandingGroup(
      name: 'A',
      rows: [
        StandingRow(position: 1, name: 'Câu Lạc Bộ Bóng Đá Phú Mỹ Hưng', played: 10, won: 9, drawn: 1, points: 28, difference: 127),
        StandingRow(position: 2, name: 'Đội Bóng Văn Phòng Công Ty ABC', played: 10, lost: 10, difference: -127),
      ],
    ),
  ];

  @override
  Future<List<MatchPlayer>> getMatchPlayers(String matchId) async => const [
    MatchPlayer(userId: 'u2', name: _longName, sideName: 'Câu Lạc Bộ Bóng Đá Phú Mỹ Hưng', isTeammate: true),
    MatchPlayer(userId: 'u3', name: 'Trần B', sideName: 'Đội Bóng Văn Phòng Công Ty Cổ Phần ABC'),
  ];
}

void main() {
  late MockLfgRepository lfg;
  late MockReviewRepository review;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final wallet = MockWalletRepository(latency: Duration.zero);
    review = MockReviewRepository(latency: Duration.zero);
    final teams = MockTeamRepository(latency: Duration.zero);
    lfg = MockLfgRepository(latency: Duration.zero, wallet: wallet, review: review);
    AppRepositories.auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.wallet = AppRepositories.paymentWallet = AppRepositories.bookingWallet = wallet;
    AppRepositories.review = review;
    AppRepositories.lfg = lfg;
    AppRepositories.team = teams;
    AppRepositories.facility = AppRepositories.lfgFacility = MockFacilityRepository(latency: Duration.zero);
    AppRepositories.rating = _LongRatings();
    AppRepositories.playerProfile = MockPlayerProfileRepository();
    AppRepositories.playerTournament = _GroupStageTournaments(teams);
    AppRepositories.sportOfCategory = AppRepositories.mockSportOfCategory;
    await MockAuthRepository(latency: Duration.zero).login('player@sportnexus.vn', 'Player@123');
  });

  Future<void> check(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Future<void> Function(WidgetTester tester)? interact,
  }) => expectNoOverflow(tester, name, build, interact: interact);

  Future<void> settle(WidgetTester tester) => settleFrames(tester);

  testWidgets('Hồ sơ, sửa hồ sơ, đổi SĐT', (tester) async {
    final user = (await tester.runAsync(SessionStore.readUser))!;
    await check(tester, 'Hồ sơ', () => const ProfileScreen());
    await check(tester, 'Sửa hồ sơ', () => EditProfileScreen(user: user));
    await check(tester, 'Đổi SĐT', () => const ChangePhoneScreen(currentPhone: '0901234567'));
  });

  testWidgets('Khảo sát người chơi: đủ 4 bước', (tester) async {
    await check(
      tester,
      'Khảo sát',
      () => PlayerSurveyScreen(mandatory: true, onCompleted: (_) {}, onLogout: (_) {}),
      interact: (tester) async {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text(SurveyStrings.next));
          await settle(tester);
        }
      },
    );
  });

  testWidgets('Elo, bảng xếp hạng, khảo sát trình độ', (tester) async {
    await check(tester, 'Elo', () => const MyEloScreen());
    await check(tester, 'Bảng xếp hạng', () => const LeaderboardScreen(highlightIds: {'x1'}));
    await check(tester, 'Khảo sát trình độ', () => const SkillAssessmentScreen(sport: Sport.tennis));
  });

  testWidgets('Đội: tạo đội, chi tiết đội', (tester) async {
    await check(tester, 'Tạo đội', () => const TeamFormScreen());
    await check(tester, 'Chi tiết đội', () => const TeamDetailScreen(teamId: 'team-pickle-q7'));
  });

  testWidgets('LFG: bảng tin, gợi ý, bộ lọc, tạo kèo, chi tiết kèo', (tester) async {
    await check(
      tester,
      'Bảng tin LFG',
      () => const LfgScreen(),
      interact: (tester) async {
        await tester.tap(find.text('Gợi ý cho bạn'));
        await settle(tester);
      },
    );
    await check(tester, 'Tạo kèo', () => const CreateLfgMatchScreen());
    final match = (await tester.runAsync(() => lfg.getFeed(const LfgFeedQuery(city: 'Hồ Chí Minh'))))!.first.match;
    await check(tester, 'Chi tiết kèo', () => LfgMatchDetailScreen(matchId: match.id));
  });

  testWidgets('Chấm điểm sau trận (có nhận xét trình độ)', (tester) async {
    final pending = (await tester.runAsync(review.getPendingReviews))!.first;
    await check(tester, 'Chấm điểm', () => SubmitReviewScreen(session: pending));
  });

  testWidgets('Giải đấu: sơ đồ vòng bảng + bảng xếp hạng, lời mời, nhận xét trình độ', (tester) async {
    await check(
      tester,
      'Sơ đồ',
      () => const TournamentBracketScreen(divisionId: 'd', title: 'Giải Bóng Đá Phong Trào Mùa Đông'),
      interact: (tester) async {
        await tester.tap(find.text('Bảng xếp hạng'));
        await settle(tester);
      },
    );
    await check(tester, 'Lời mời giải', () => const TournamentInvitationsScreen());
    await check(
      tester,
      'Nhận xét trận giải',
      () => const TournamentMatchFeedbackScreen(
        match: MyTournamentMatch(
          matchId: 'm',
          tournamentName: 'Giải Bóng Đá Phong Trào Mùa Đông',
          mySide: 'Câu Lạc Bộ Bóng Đá Phú Mỹ Hưng',
          opponent: 'Đội Bóng Văn Phòng Công Ty Cổ Phần ABC',
          status: 'FINISHED',
        ),
      ),
    );
  });

  testWidgets('Thẻ gợi ý của AI (giải đấu)', (tester) async {
    await check(
      tester,
      'Thẻ AI',
      () => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AiTournamentCard(
              tournament: AiTournamentSuggestion(
                tournamentId: 't',
                name: 'Giải Cầu Lông Mở Rộng Toàn Thành Phố Hồ Chí Minh Lần Thứ Mười',
                sport: Sport.badminton,
                facilityName: 'Trung Tâm Thể Thao Phú Thọ Quận 11',
                startDate: DateTime(2026, 12, 20),
                registrationDeadline: DateTime(2026, 12, 10),
                tier: 'SEMI_PRO',
                minEntryFee: 1500000,
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  });
}
