import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/core/strings/organizer_strings.dart';
import 'package:test1/data/app_repositories.dart';
import 'package:test1/data/mock/mock_auth_repository.dart';
import 'package:test1/data/mock/mock_host_tournament_repository.dart';
import 'package:test1/data/mock/mock_identity_repository.dart';
import 'package:test1/models/identity_verification.dart';
import 'package:test1/models/organized_tournament.dart';
import 'package:test1/models/tournament_listing.dart';
import 'package:test1/screens/tournament/create_tournament_screen.dart';
import 'package:test1/screens/tournament/organized_tournament_screen.dart';
import 'package:test1/screens/tournament/organized_tournaments_tab.dart';

import '../helpers/layout_check.dart';

/// Giải đấu đợt 2: Giải tôi tổ chức + tạo / sửa / hủy / xóa giải.
class _Host extends MockHostTournamentRepository {
  NewTournament? lastDraft;
  final List<String> uploaded = [];

  _Host() : super(latency: Duration.zero);

  @override
  Future<ApprovalStatus> create(NewTournament draft) {
    lastDraft = draft;
    return super.create(draft);
  }

  @override
  Future<String> uploadDocument(String filePath) {
    uploaded.add(filePath);
    return super.uploadDocument(filePath);
  }
}

void main() {
  late _Host host;

  Future<void> login(String email) async {
    final auth = MockAuthRepository(latency: Duration.zero);
    AppRepositories.auth = auth;
    await auth.login(email, 'Player@123');
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = _Host();
    AppRepositories.hostTournament = host;
    AppRepositories.identity = MockIdentityRepository(
      latency: Duration.zero,
      initial: const IdentityVerification(status: IdentityStatus.approved),
    );
    await login('player@sportnexus.vn');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1600, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: Scaffold(body: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Mở [screen] từ một màn khác để màn tự đóng (pop) được và còn chỗ hiện thông báo.
  Future<void> pumpPushed(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1600, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  group('Giải tôi tổ chức', () {
    testWidgets('đủ điều kiện: nút tạo mở; lọc nhóm có số đếm; giải bị từ chối hiện lý do', (tester) async {
      await pump(tester, const OrganizedTournamentsTab());
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, OrganizerStrings.createNew));
      expect(button.onPressed, isNotNull);
      expect(find.text('${OrganizerStrings.all} (3)'), findsOneWidget);
      expect(find.text('${OrganizedGroup.pending.label} (1)'), findsOneWidget);
      expect(find.text(OrganizerStrings.rejectedBanner('Thiếu hợp đồng thuê sân.')), findsOneWidget);
      await tester.tap(find.text('${OrganizedGroup.pending.label} (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Giải Pickleball Giao lưu Quận 7'), findsNothing);
      expect(find.text('Giải Cầu Lông Bán chuyên'), findsOneWidget);
    });

    testWidgets('Fair Play < 90: khóa nút tạo, báo lý do', (tester) async {
      await login('restricted@sportnexus.vn');
      await pump(tester, const OrganizedTournamentsTab());
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, OrganizerStrings.createNew));
      expect(button.onPressed, isNull);
      expect(find.textContaining('Fair Play từ 90'), findsOneWidget);
      expect(find.textContaining(OrganizerStrings.stillManage), findsOneWidget);
    });

    testWidgets('CCCD chưa nộp: khóa + nút Xác minh ngay; đang chờ duyệt: không có nút', (tester) async {
      AppRepositories.identity = MockIdentityRepository(latency: Duration.zero);
      await pump(tester, const OrganizedTournamentsTab());
      expect(find.textContaining(OrganizerStrings.kycRequired), findsOneWidget);
      expect(find.text(OrganizerStrings.verifyNow), findsOneWidget);

      AppRepositories.identity = MockIdentityRepository(
        latency: Duration.zero,
        initial: const IdentityVerification(status: IdentityStatus.pending),
      );
      await pump(tester, const OrganizedTournamentsTab());
      expect(find.textContaining(OrganizerStrings.kycPending), findsOneWidget);
      expect(find.text(OrganizerStrings.verifyNow), findsNothing);
    });
  });

  group('Tạo giải', () {
    testWidgets('thiếu tên / cơ sở thì báo; đủ thì gửi, giải chờ Admin duyệt', (tester) async {
      await pumpPushed(
        tester,
        CreateTournamentScreen(
          pickPdf: ({required bool multiple}) async =>
              multiple ? ['/tmp/luat.pdf', '/tmp/nhansu.pdf'] : ['/tmp/hd.pdf'],
        ),
      );
      await tester.tap(find.text(OrganizerStrings.submit));
      await tester.pump();
      expect(find.text(OrganizerStrings.nameRequired), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), 'Giải Pickleball Mùa Đông');
      await tester.tap(find.text(OrganizerStrings.submit));
      await tester.pump();
      expect(find.text(OrganizerStrings.facilityRequired), findsOneWidget);

      // Gõ không dấu rồi chọn cơ sở.
      await tester.enterText(find.byType(TextField).first, 'sunrise quan 7');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sân Pickleball Sunrise'));
      await tester.pumpAndSettle();

      // Ngày bắt đầu (sớm nhất) → hạn đăng ký tự điền; ngày kết thúc = ngày bắt đầu.
      await tester.tap(find.text(OrganizerStrings.pickDate).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.pickDate), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.pickDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(OrganizerStrings.uploadPdf).first);
      await tester.pumpAndSettle();
      expect(find.text('luat.pdf'), findsOneWidget);
      expect(find.text('nhansu.pdf'), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.uploadPdf));
      await tester.pumpAndSettle();
      expect(find.text('hd.pdf'), findsOneWidget);

      await tester.tap(find.text(OrganizerStrings.submit));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.submitted), findsOneWidget);
      final d = host.lastDraft!;
      expect(d.facilityId, 'f-sunrise');
      expect(d.format, BracketFormat.knockout); // gợi ý cho 8 người
      expect(d.deadline, d.start.subtract(const Duration(days: 2)));
      expect(d.rulesFiles.length, 2);
      expect(d.contract?.name, 'hd.pdf');
      expect((await host.getMine()).first.isPendingApproval, isTrue);
    });

    testWidgets('Bán chuyên bắt buộc Elo; Phát triển chuyên môn khóa ở Phong trào; vòng tròn > 8 bị chặn', (
      tester,
    ) async {
      await pump(
        tester,
        const CreateTournamentScreen(
          fixedFacility: FacilityOption(id: 'f-sunrise', name: 'Sân Sunrise'),
        ),
      );
      // Chủ sân: cơ sở cố định, không có ô hợp đồng.
      expect(find.text(OrganizerStrings.contract), findsNothing);
      expect(find.text(OrganizerStrings.change), findsNothing);
      expect(find.text(OrganizerStrings.minRating), findsNothing);

      await tester.tap(find.text(TournamentTier.amateur.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TournamentTier.semiPro.label).last);
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.minRating), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(4), '9');
      await tester.pump();
      expect(find.text('${BracketFormat.groupKnockout.label}${OrganizerStrings.suggested}'), findsOneWidget);
      await tester.tap(find.text('${BracketFormat.groupKnockout.label}${OrganizerStrings.suggested}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(BracketFormat.roundRobin.label).last);
      await tester.pumpAndSettle();
      expect(find.text('Vòng tròn chỉ cho tối đa 8 đấu thủ.'), findsOneWidget);
    });
  });

  group('Quản lý giải', () {
    testWidgets('giải còn mở, đã có người: sửa thông tin + hủy (nhập lý do); không có nút xóa / sửa lệ phí', (
      tester,
    ) async {
      await pump(tester, const OrganizedTournamentScreen(tournamentId: 'ht-1'));
      expect(find.text(OrganizerStrings.delete), findsNothing);
      expect(find.text(OrganizerStrings.editFee), findsNothing);
      await tester.tap(find.text(OrganizerStrings.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OrganizerStrings.cancelConfirm));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.cancelReasonRequired), findsOneWidget);
      await tester.tap(find.text(OrganizerStrings.cancel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Sân sửa chữa');
      await tester.tap(find.text(OrganizerStrings.cancelConfirm));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.cancelled), findsOneWidget);
      expect(find.text(OrganizerStrings.cancelledBanner('Sân sửa chữa')), findsOneWidget);
      // Đã hủy: xóa được.
      await tester.tap(find.text(OrganizerStrings.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OrganizerStrings.delete).last);
      await tester.pumpAndSettle();
      expect((await host.getMine()).any((t) => t.id == 'ht-1'), isFalse);
    });

    testWidgets('gần hạn đăng ký: Hủy giải bị khóa kèm lý do; chưa ai đăng ký: sửa lệ phí', (tester) async {
      final seed = (await host.getMine()).firstWhere((t) => t.id == 'ht-2');
      await pump(
        tester,
        OrganizedTournamentScreen(tournamentId: 'ht-2', now: () => seed.deadline!.subtract(const Duration(hours: 3))),
      );
      expect(find.text(OrganizerStrings.cancelLocked), findsOneWidget);
      expect(find.text(OrganizerStrings.cancelLockedReason), findsOneWidget);
      expect(find.text(OrganizerStrings.rejectedBanner('Thiếu hợp đồng thuê sân.')), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '50000');
      await tester.tap(find.text(OrganizerStrings.saveFee));
      await tester.pumpAndSettle();
      expect(find.text(OrganizerStrings.feeSaved), findsOneWidget);
      expect((await host.getDetail('ht-2')).entryFee, 50000);
    });

    testWidgets('sửa thông tin: đổi tên lưu được', (tester) async {
      final t = await host.getDetail('ht-1');
      await pump(tester, EditTournamentInfoScreen(tournament: t));
      await tester.enterText(find.byType(TextField).first, 'Giải Pickleball Mùa Xuân');
      await tester.tap(find.text(OrganizerStrings.save));
      await tester.pumpAndSettle();
      expect((await host.getDetail('ht-1')).name, 'Giải Pickleball Mùa Xuân');
    });
  });

  testWidgets('bố cục: danh sách, form tạo (Bán chuyên + lịch sân), quản lý giải', (tester) async {
    Future<void> scrollToEnd(WidgetTester t) async {
      for (var i = 0; i < 12; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -400), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    await expectNoOverflow(
      tester,
      'Giải tôi tổ chức',
      () => const Scaffold(body: OrganizedTournamentsTab()),
      interact: scrollToEnd,
    );
    await expectNoOverflow(
      tester,
      'Tạo giải',
      () => const CreateTournamentScreen(),
      interact: (t) async {
        Future<void> tapVisible(Finder f) async {
          await t.ensureVisible(f);
          await settleFrames(t);
          await t.tap(f);
          await settleFrames(t);
        }

        await tapVisible(find.text(OrganizerStrings.pickDate).first);
        await t.tap(find.text('OK'));
        await settleFrames(t);
        await tapVisible(find.text(TournamentTier.amateur.label));
        await t.tap(find.text(TournamentTier.semiPro.label).last);
        await settleFrames(t);
        await tapVisible(find.text(OrganizerStrings.addScheduleRow));
        expect(find.text(OrganizerStrings.courtCount), findsOneWidget);
        expect(find.text(OrganizerStrings.minRating), findsOneWidget);
        await scrollToEnd(t);
      },
    );
    await expectNoOverflow(
      tester,
      'Quản lý giải',
      () => const OrganizedTournamentScreen(tournamentId: 'ht-2'),
      interact: scrollToEnd,
    );
  });
}
