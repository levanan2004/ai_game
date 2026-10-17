import 'dart:io';

import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/account_prefs.dart';
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/charm_board_controller.dart';
import 'package:ai_game/logic/preset_avatars.dart';
import 'package:ai_game/logic/profile_report.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/pet_slots_screen.dart';
import 'package:ai_game/ui/rating_board_view.dart' show RatingText;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _pets = [
  'kim_long',
  'phuong_hoang',
  'ky_lan',
  'bach_ho',
  'hac',
  'ca_chep',
];

/// A board with [n] other players, Mị lực from 600 downwards, and a session
/// for the player under test.
Future<({ShopSession s, MemoryCharmBoard board, DateTime Function() now})> rig(
  WidgetTester tester, {
  int n = 12,
  bool signedIn = true,
  String? pet = 'kim_long',
  int stage = 1,
  DateTime? at,
  ProfileReports? reports,
  AvatarFrameSource? frames,
  AccountPrefsSource? accountPrefs,
}) async {
  var clock = at ?? DateTime.utc(2026, 10, 20, 8);
  final board = MemoryCharmBoard(now: () => clock);
  final s = newSession(
    charmBoard: board,
    now: () => clock,
    reports: reports,
    avatarFrames: frames,
    accountPrefs: accountPrefs,
  );
  await tester.runAsync(() async {
    for (var i = 0; i < n; i++) {
      clock = clock.add(const Duration(minutes: 1));
      await board.publish(
        period: s.e.charmBoard.periodKey,
        entry: CharmBoardEntry.forPlayer(
          uid: 'p$i',
          displayName: 'Tiệm Hoa Số ${i + 1}',
          avatar: presetAvatarIds[i % presetAvatarIds.length],
          charm: 600 - i * 5,
          petId: _pets[i % _pets.length],
          stage: i % 3,
          worn: i.isEven
              ? const {'neck': 'no_co_vai', 'head': 'mu_rom'}
              : const {},
        ),
      );
    }
  });
  clock = clock.add(const Duration(hours: 1));
  if (signedIn) s.accountUid = 'me';
  s.state.shopName = 'Tiệm Hoa Sớm Mai';
  s.state.day = 8;
  if (pet != null) {
    s.state.addPet(pet, fedDay: 1);
    s.state.ownedPet(pet)!.stage = stage;
    s.state.petCharm = pet;
  }
  return (s: s, board: board, now: () => clock);
}

Future<void> mount(WidgetTester tester, ShopSession s) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 360,
          height: 640,
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => Stack(
              children: [
                Positioned.fill(child: PetSlotsScreen(session: s)),
                if (s.charmBoardOpen)
                  Positioned.fill(child: CharmBoardScreen(session: s)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> open(WidgetTester tester, ShopSession s) async {
  s.openCharmBoard();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The real Nunito and Baloo 2, so a line that is too long here is too long
/// in the game (the default test font is far wider).
Future<void> loadFonts() async {
  const fonts = {
    AppFonts.body: 'assets/fonts/nunito/Nunito-VariableFont_wght.ttf',
    AppFonts.display: 'assets/fonts/baloo2/Baloo2-VariableFont_wght.ttf',
  };
  for (final e in fonts.entries) {
    final bytes = File(e.value).readAsBytesSync();
    await (FontLoader(
      e.key,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

void main() {
  setUpAll(loadFonts);

  group('entry and states', () {
    testWidgets('the round button in the title row opens the board', (
      tester,
    ) async {
      final r = await rig(tester);
      r.s.openPetSlots();
      await mount(tester, r.s);
      expect(find.byKey(const Key('bxh-entry')), findsOneWidget);
      expect(
        find.byKey(const Key('bxh-entry-rank')),
        findsNothing,
        reason: 'no rank yet',
      );
      await tester.tap(find.byKey(const Key('bxh-entry')));
      await tester.pump();
      expect(r.s.charmBoardOpen, isTrue);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('bxh-screen')), findsOneWidget);
      // With Bảng Đánh giá in economy.json the ribbon is the shared title
      // and the Mị lực tab is chosen.
      expect(find.text(RatingText.boardTitle), findsOneWidget);
      expect(find.byKey(const Key('board-tabs')), findsOneWidget);
      // Back returns to the slot picker.
      await tester.tap(find.byKey(const Key('bxh-back')));
      await tester.pump();
      expect(r.s.charmBoardOpen, isFalse);
      expect(r.s.petSlotsOpen, isTrue);
    });

    testWidgets('ranked: card with rank badge, podium, rows, refresh note', (
      tester,
    ) async {
      final r = await rig(tester, n: 20, pet: 'kim_long', stage: 2);
      r.s.openPetSlots();
      await mount(tester, r.s);
      // Publish the player's row first so the card has a rank.
      await tester.runAsync(() => r.s.board.publishIfDue());
      await open(tester, r.s);
      await tester.runAsync(() => r.s.board.refresh(force: true));
      await tester.pump();
      expect(r.s.board.me, BoardMe.ranked);
      expect(find.byKey(const Key('bxh-card')), findsOneWidget);
      expect(find.text(Bxh.you), findsOneWidget);
      for (final k in ['bxh-podium-1', 'bxh-podium-2', 'bxh-podium-3']) {
        expect(find.byKey(Key(k)), findsOneWidget);
      }
      expect(find.byKey(const Key('bxh-row-4')), findsOneWidget);
      expect(find.text(Bxh.refreshNote(15)), findsOneWidget);
      expect(find.byKey(const Key('bxh-season')), findsOneWidget);
      expect(find.text(Bxh.rewardsBtn), findsOneWidget);
      // The entry chip carries the rank once it is known.
      expect(r.s.board.myRank, isNotNull);
    });

    testWidgets('no pet in the Mị lực slot: Chưa xếp hạng, hint, Chọn thú', (
      tester,
    ) async {
      final r = await rig(tester, pet: null);
      await mount(tester, r.s);
      await open(tester, r.s);
      expect(find.byKey(const Key('bxh-unranked')), findsOneWidget);
      expect(find.text(Bxh.noPetHint), findsOneWidget);
      expect(find.byKey(const Key('bxh-podium-1')), findsOneWidget);
      expect(find.text(Bxh.refreshNote(15)), findsOneWidget);
      await tester.tap(find.byKey(const Key('bxh-pick-pet')));
      await tester.pump();
      expect(r.s.charmBoardOpen, isFalse);
      expect(r.s.petSlotsOpen, isTrue);
      expect(r.s.petSlotSelected, 'charm');
    });

    testWidgets('under 20 Mị lực: hint with the minimum from the config', (
      tester,
    ) async {
      final r = await rig(tester, pet: 'ca_chep', stage: 0);
      await mount(tester, r.s);
      await open(tester, r.s);
      expect(r.s.board.me, BoardMe.underMin);
      expect(find.text(Bxh.minHint(20)), findsOneWidget);
      expect(find.byKey(const Key('bxh-unranked')), findsOneWidget);
      expect(find.text(Bxh.refreshNote(15)), findsOneWidget);
    });

    testWidgets('guest: sign-in prompt, no board, no refresh note', (
      tester,
    ) async {
      final r = await rig(tester, signedIn: false);
      await mount(tester, r.s);
      await open(tester, r.s);
      expect(find.byKey(const Key('bxh-guest-title')), findsOneWidget);
      expect(find.text(Bxh.guestBtn), findsOneWidget);
      expect(find.byKey(const Key('bxh-podium-1')), findsNothing);
      expect(find.byKey(const Key('bxh-refresh-note')), findsNothing);
    });

    testWidgets('network error: message, retry brings the board back', (
      tester,
    ) async {
      final r = await rig(tester);
      final flaky = _Offline(r.board);
      final s = newSession(charmBoard: flaky, now: r.now)
        ..accountUid = 'me'
        ..state.day = 8
        ..state.addPet('kim_long', fedDay: 1)
        ..state.petCharm = 'kim_long';
      await mount(tester, s);
      await open(tester, s);
      expect(find.byKey(const Key('bxh-error')), findsOneWidget);
      expect(find.text(Bxh.errorSub), findsOneWidget);
      expect(find.byKey(const Key('bxh-refresh-note')), findsNothing);
      flaky.down = false;
      await tester.tap(find.byKey(const Key('bxh-retry')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.byKey(const Key('bxh-error')), findsNothing);
      expect(find.byKey(const Key('bxh-podium-1')), findsOneWidget);
    });

    testWidgets('outside the top 100: 100+ and how much is missing', (
      tester,
    ) async {
      final r = await rig(tester, n: 100, pet: 'kim_long', stage: 0);
      await mount(tester, r.s);
      await open(tester, r.s);
      expect(r.s.board.me, BoardMe.outside);
      expect(find.byKey(const Key('bxh-badge-100+')), findsOneWidget);
      expect(find.text(Bxh.outHint(r.s.board.outsideNeed)), findsOneWidget);
    });

    testWidgets(
      'an ended season is frozen: Đang chốt bảng until the reward mail exists',
      (tester) async {
        final r = await rig(tester, at: DateTime.utc(2026, 11, 20));
        await mount(tester, r.s);
        await open(tester, r.s);
        expect(r.s.board.seasonEnded, isTrue);
        expect(find.textContaining(Bxh.seasonEnded), findsOneWidget);
        expect(find.textContaining(Bxh.seasonPending), findsOneWidget);
        expect(Bxh.seasonPending, 'Đang chốt bảng');
        expect(Bxh.claimPending, 'Đang chốt bảng');
      },
    );
  });

  group('report a profile', () {
    testWidgets('another player: Báo cáo, a reason, Gửi báo cáo, toast', (
      tester,
    ) async {
      final reports = MemoryProfileReports();
      final r = await rig(tester, reports: reports);
      await mount(tester, r.s);
      await open(tester, r.s);
      final other = r.s.board.rows.firstWhere((row) => row.entry.uid == 'p3');
      r.s.board.openProfile(other);
      await tester.pump();
      expect(find.byKey(const Key('bxh-report')), findsOneWidget);
      // The 96 dp avatar (spec 6.1) puts it under the fold of the sheet.
      await tester.ensureVisible(find.byKey(const Key('bxh-report')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bxh-report')));
      await tester.pump();
      expect(find.byKey(const Key('bxh-report-sheet')), findsOneWidget);
      expect(find.text(Bxh.reportTitle), findsOneWidget);
      for (final reason in ReportReason.values) {
        expect(find.text(reason.label), findsOneWidget);
      }
      // Nothing picked yet: Gửi báo cáo does nothing.
      await tester.tap(find.byKey(const Key('bxh-report-send')));
      await tester.pump();
      expect(reports.sent, isEmpty);
      await tester.tap(find.byKey(const Key('bxh-report-impersonation')));
      await tester.enterText(
        find.byKey(const Key('bxh-report-note')),
        'Giả tên tiệm mình',
      );
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('bxh-report-send')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      final sent = reports.sent['me_p3']!;
      expect(sent.reporterUid, 'me');
      expect(sent.targetName, 'Tiệm Hoa Số 4');
      expect(sent.reason, ReportReason.impersonation);
      expect(sent.note, 'Giả tên tiệm mình');
      expect(find.text(Bxh.reportSent), findsOneWidget);
      expect(find.byKey(const Key('bxh-report-sheet')), findsNothing);
      expect(find.byKey(const Key('bxh-profile')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Ẩn người chơi này: confirm, row keeps its rank masked, '
        'the Người chơi đã ẩn list offers Bỏ ẩn', (tester) async {
      final r = await rig(tester, reports: MemoryProfileReports());
      final store = ProgressStore.memory({});
      await tester.runAsync(() => r.s.board.useHiddenPlayers(store));
      await mount(tester, r.s);
      await open(tester, r.s);
      expect(find.byKey(const Key('bxh-hidden-list-open')), findsNothing);
      final other = r.s.board.rows.firstWhere((row) => row.entry.uid == 'p3');
      r.s.board.openProfile(other);
      r.s.board.openReport();
      await tester.pump();
      expect(find.text(Bxh.hide), findsOneWidget);
      await tester.tap(find.byKey(const Key('bxh-hide')));
      await tester.pump();
      // Confirm; Thôi goes back to the form.
      expect(find.text(Bxh.hideConfirmTitle('Tiệm Hoa Số 4')), findsOneWidget);
      expect(find.text(Bxh.hideConfirmBody), findsOneWidget);
      await tester.tap(find.byKey(const Key('bxh-hide-cancel')));
      await tester.pump();
      expect(find.byKey(const Key('bxh-hide-confirm')), findsNothing);
      expect(r.s.board.isHidden('p3'), isFalse);
      await tester.tap(find.byKey(const Key('bxh-hide')));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('bxh-hide-ok')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(r.s.board.isHidden('p3'), isTrue);
      expect(r.s.board.hidden['p3'], 'Tiệm Hoa Số 4');
      expect(find.text(Bxh.hidden('Tiệm Hoa Số 4')), findsOneWidget);
      expect(find.byKey(const Key('bxh-report-sheet')), findsNothing);
      expect(find.byKey(const Key('bxh-profile')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      // Same rank, masked.
      final row = find.byKey(Key('bxh-row-${other.rank}'));
      expect(
        find.descendant(of: row, matching: find.text(Bxh.hiddenName)),
        findsOneWidget,
      );
      expect(find.text('Tiệm Hoa Số 4'), findsNothing);
      // Tap: no profile, the list.
      await tester.tap(row);
      await tester.pump();
      expect(find.byKey(const Key('bxh-profile')), findsNothing);
      expect(find.byKey(const Key('bxh-hidden-list')), findsOneWidget);
      expect(find.text(Bxh.hiddenListNote), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('bxh-hidden-list')),
          matching: find.text('Tiệm Hoa Số 4'),
        ),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('bxh-unhide-p3')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(r.s.board.isHidden('p3'), isFalse);
      expect(await tester.runAsync(store.loadHiddenPlayers), isEmpty);
      expect(find.text(Bxh.unhidden('Tiệm Hoa Số 4')), findsOneWidget);
      expect(find.text(Bxh.hiddenListEmpty), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      r.s.board.closeHiddenList();
      await tester.pump();
      expect(find.byKey(const Key('bxh-hidden-list')), findsNothing);
      expect(find.text('Tiệm Hoa Số 4'), findsWidgets);
    });

    testWidgets('signed in, the list note says it is kept per account', (
      tester,
    ) async {
      final r = await rig(tester, accountPrefs: MemoryAccountPrefs());
      await tester.runAsync(() async {
        r.s.accountUid = 'me';
        await r.s.prefs.switchTo('me');
        await r.s.board.hidePlayer('p3', 'Tiệm Hoa Số 4');
      });
      expect(r.s.prefs.onServer, isTrue);
      await mount(tester, r.s);
      await open(tester, r.s);
      r.s.board.openHiddenList();
      await tester.pump();
      expect(find.text(Bxh.hiddenListNoteAccount), findsOneWidget);
      expect(find.text(Bxh.hiddenListNote), findsNothing);
    });

    testWidgets('the board links to Người chơi đã ẩn once someone is hidden', (
      tester,
    ) async {
      final r = await rig(tester, reports: MemoryProfileReports());
      final store = ProgressStore.memory({});
      await tester.runAsync(
        () => store.saveHiddenPlayers({'gone': 'Tiệm Xa Lắm'}),
      );
      await tester.runAsync(() => r.s.board.useHiddenPlayers(store));
      await mount(tester, r.s);
      await open(tester, r.s);
      final link = find.byKey(const Key('bxh-hidden-list-open'));
      await tester.scrollUntilVisible(
        link,
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('bxh-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(link);
      await tester.pump();
      expect(find.byKey(const Key('bxh-hidden-gone')), findsOneWidget);
      expect(find.text('Tiệm Xa Lắm'), findsOneWidget);
    });

    testWidgets('your own row has no Báo cáo', (tester) async {
      final r = await rig(tester, reports: MemoryProfileReports());
      await mount(tester, r.s);
      await tester.runAsync(() => r.s.board.publishIfDue());
      await open(tester, r.s);
      await tester.runAsync(() => r.s.board.refresh(force: true));
      await tester.pump();
      final mine = r.s.board.rows.firstWhere((row) => row.entry.uid == 'me');
      r.s.board.openProfile(mine);
      await tester.pump();
      expect(find.byKey(const Key('bxh-profile')), findsOneWidget);
      expect(find.byKey(const Key('bxh-report')), findsNothing);
    });
  });
}

/// Fails reads until [down] is false.
class _Offline extends MemoryCharmBoard {
  _Offline(this.inner) : super();

  final MemoryCharmBoard inner;
  bool down = true;

  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) async {
    if (down) throw StateError('offline');
    return inner.top(period: period, limit: limit);
  }
}
