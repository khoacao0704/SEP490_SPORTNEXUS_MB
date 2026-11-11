import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/survey_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/onboarding_gate.dart';
import 'package:test1/data/repositories/player_profile_repository.dart';
import 'package:test1/data/session_store.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/models/player_survey.dart';
import 'package:test1/models/sport.dart';
import 'package:test1/models/user_role.dart';
import 'package:test1/screens/profile/player_survey_screen.dart';

class _FakeProfiles implements PlayerProfileRepository {
  PlayerSurvey current;
  PlayerSurvey? saved;
  int gets = 0;
  bool fail = false;

  _FakeProfiles(this.current);

  @override
  Future<PlayerSurvey> getSurvey() async {
    gets++;
    if (fail) throw const PlayerProfileException('mất mạng');
    return current;
  }

  @override
  Future<PlayerSurvey> saveSurvey(PlayerSurvey survey) async {
    saved = survey;
    current = survey.copyWith(isCompleted: true);
    return current;
  }
}

const _player = AppUser(id: 'p1', fullName: 'Khoa', email: 'k@x.com', phone: '0978809952', role: UserRole.player);

/// Đợi SnackBar báo lỗi tắt hẳn (nó che các nút bên dưới).
Future<void> settleSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeProfiles profiles;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.save(_player, rememberMe: true);
    profiles = _FakeProfiles(const PlayerSurvey());
    AppRepositories.playerProfile = profiles;
  });

  testWidgets('khảo sát bắt buộc: chặn bước thiếu thông tin, đi đủ 4 bước rồi lưu và báo hoàn thành', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSurveyScreen(mandatory: true, onCompleted: (_) => completed = true, onLogout: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(SurveyStrings.logout), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    // Bước 1: môn + trình độ.
    await tester.tap(find.text(SurveyStrings.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(SurveyStrings.needSport), findsOneWidget);
    await settleSnack(tester);
    await tester.tap(find.widgetWithText(FilterChip, Sport.badminton.label));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, SkillLevel.advanced.label));
    await tester.ensureVisible(find.widgetWithText(FilterChip, PlayFormat.doubles.label));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, PlayFormat.doubles.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SurveyStrings.next));
    await tester.pumpAndSettle();

    // Bước 2: lịch rảnh.
    expect(find.text(SurveyStrings.availabilityTitle), findsOneWidget);
    await tester.tap(find.text(SurveyStrings.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(SurveyStrings.needWindow), findsOneWidget);
    await settleSnack(tester);
    await tester.tap(find.text(SurveyStrings.addWindow));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SurveyStrings.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(SurveyStrings.needDay), findsOneWidget);
    await settleSnack(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'T2'));
    await tester.tap(find.widgetWithText(FilterChip, 'T4'));
    await tester.pump();
    await tester.tap(find.text(SurveyStrings.add));
    await tester.pumpAndSettle();
    expect(find.text('T2 18:00–21:00'), findsOneWidget);
    expect(find.text('T4 18:00–21:00'), findsOneWidget);
    await tester.tap(find.text(SurveyStrings.next));
    await tester.pumpAndSettle();

    // Bước 3: khu vực (bỏ qua) → bước 4.
    expect(find.text(SurveyStrings.areaTitle), findsOneWidget);
    await tester.tap(find.text(SurveyStrings.next));
    await tester.pumpAndSettle();

    await tester.tap(find.text(SurveyStrings.finish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(SurveyStrings.needGoal), findsOneWidget);
    await settleSnack(tester);
    for (final label in [PlayGoal.competition.label, PlayFrequency.weekly12.label]) {
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, label));
    }
    await tester.pump();
    await tester.tap(find.text(SurveyStrings.finish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(completed, isTrue);
    final saved = profiles.saved!;
    expect(saved.sports.single.sport, Sport.badminton);
    expect(saved.sports.single.level, SkillLevel.advanced);
    expect(saved.sports.single.formats, ['DOUBLES']);
    expect(saved.availability.map((w) => w.dayOfWeek), [1, 3]);
    expect(saved.goal, PlayGoal.competition);
    expect(saved.frequency, PlayFrequency.weekly12);
    expect(await OnboardingGate.needsSurvey(_player), isFalse);
  });

  test('cổng khảo sát: chưa làm thì phải làm; đã xong thì nhớ trên máy, không hỏi lại; lỗi mạng thì cho vào', () async {
    expect(await OnboardingGate.needsSurvey(_player), isTrue);
    expect(profiles.gets, 1);

    profiles.current = const PlayerSurvey(isCompleted: true);
    expect(await OnboardingGate.needsSurvey(_player), isFalse);
    expect(await OnboardingGate.needsSurvey(_player), isFalse);
    expect(profiles.gets, 2);

    // BE báo chưa khảo sát → xoá dấu nhớ, lần sau hỏi lại.
    await OnboardingGate.clear();
    profiles.fail = true;
    expect(await OnboardingGate.needsSurvey(_player), isFalse);
    expect(profiles.gets, 3);

    // Chủ sân không cần khảo sát.
    const owner = AppUser(id: 'o1', fullName: 'O', email: 'o@x.com', phone: '09', role: UserRole.courtOwner);
    expect(await OnboardingGate.needsSurvey(owner), isFalse);
    expect(profiles.gets, 3);
  });

  testWidgets('sửa từ Hồ sơ: hiện dữ liệu cũ, lưu thì đóng màn', (tester) async {
    profiles.current = PlayerSurvey(
      isCompleted: true,
      sports: const [SurveySport(sport: Sport.football, level: SkillLevel.beginner, formats: ['7'])],
      availability: [AvailabilityWindow(dayOfWeek: 0, start: DayTime.hm(7, 0), end: DayTime.hm(9, 0))],
      goal: PlayGoal.exchange,
      frequency: PlayFrequency.rarely,
    );
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const PlayerSurveyScreen()),
            ),
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text(SurveyStrings.editTitle), findsOneWidget);
    expect(find.text(SurveyStrings.logout), findsNothing);
    expect(find.text('Sân 7'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(SurveyStrings.next));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(SurveyStrings.save));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(profiles.saved!.availability.single.label, 'CN 07:00–09:00');
  });
}
