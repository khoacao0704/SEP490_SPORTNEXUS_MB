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

  PlayerSurvey completedSurvey() => PlayerSurvey(
    isCompleted: true,
    sports: const [SurveySport(sport: Sport.football, level: SkillLevel.beginner, formats: ['7'])],
    availability: [AvailabilityWindow(dayOfWeek: 0, start: DayTime.hm(7, 0), end: DayTime.hm(9, 0))],
    goal: PlayGoal.exchange,
    frequency: PlayFrequency.rarely,
  );

  testWidgets('mở từ Hồ sơ: thấy màn xem với lựa chọn cũ; Sửa → 4 bước điền sẵn → Lưu thì về màn xem', (tester) async {
    profiles.current = completedSurvey();
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
    // Màn xem: chỉ đọc, chưa có bước / nút Tiếp.
    expect(find.text(SurveyStrings.viewSports), findsOneWidget);
    expect(find.text(Sport.football.label), findsOneWidget);
    expect(find.textContaining('Sân 7'), findsOneWidget);
    expect(find.text('CN 07:00–09:00'), findsOneWidget);
    expect(find.textContaining(PlayGoal.exchange.label, findRichText: true), findsOneWidget);
    expect(find.textContaining(SurveyStrings.notChosen, findRichText: true), findsOneWidget); // giới tính
    expect(find.text(SurveyStrings.next), findsNothing);
    expect(find.byType(FilterChip), findsNothing);

    await tester.tap(find.text(SurveyStrings.edit));
    await tester.pumpAndSettle();
    expect(find.text(SurveyStrings.step(1, 4)), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Sân 7'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, SkillLevel.advanced.label));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(SurveyStrings.next));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(SurveyStrings.save));
    await tester.pumpAndSettle();
    expect(result, isNull); // vẫn ở màn, về màn xem
    expect(profiles.saved!.availability.single.label, 'CN 07:00–09:00');
    expect(profiles.saved!.sports.single.level, SkillLevel.advanced);
    expect(find.text(SurveyStrings.viewSports), findsOneWidget);
    expect(find.textContaining(SkillLevel.advanced.label), findsOneWidget);
    expect(find.text(SurveyStrings.edit), findsOneWidget);
  });

  testWidgets('đang sửa mà quay lại ở bước 1 thì bỏ thay đổi, về màn xem', (tester) async {
    profiles.current = completedSurvey();
    await tester.pumpWidget(const MaterialApp(home: PlayerSurveyScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SurveyStrings.edit));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, SkillLevel.advanced.label));
    await tester.tap(find.text(SurveyStrings.next));
    await tester.pumpAndSettle();
    // Bước 2 → bước 1 → màn xem.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text(SurveyStrings.step(1, 4)), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text(SurveyStrings.viewSports), findsOneWidget);
    expect(find.textContaining(SkillLevel.beginner.label), findsOneWidget);
    expect(profiles.saved, isNull);
  });

  testWidgets('mở từ Hồ sơ khi chưa làm khảo sát: đi 4 bước như bắt buộc, không có màn xem', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push<bool>(
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
    expect(find.text(SurveyStrings.step(1, 4)), findsOneWidget);
    expect(find.text(SurveyStrings.edit), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, Sport.badminton.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SurveyStrings.next));
    await tester.pumpAndSettle();
    expect(find.text(SurveyStrings.availabilityTitle), findsOneWidget);
  });
}
