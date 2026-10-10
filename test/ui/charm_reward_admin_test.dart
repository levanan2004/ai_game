import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/charm_payout.dart';
import 'package:ai_game/logic/charm_rewards.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/charm_reward_admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'charm_board_screen_test.dart' show loadFonts;

final _economy = loadTestData().economy;
final _end = _economy.charmBoard.seasonEnd!;

/// A board of [n] players on season-1. Player 1 (rank 2) claims more Mị lực
/// than the save backs; player 3 (rank 4) has no readable save.
Future<(MemoryCharmBoard, MemoryCharmRewardStore)> board(
  WidgetTester tester, {
  int n = 14,
  Map<String, GameState> extraSaves = const {},
}) async {
  var clock = DateTime.utc(2026, 10, 20, 8);
  final b = MemoryCharmBoard(now: () => clock);
  final saves = <String, GameState>{};
  await tester.runAsync(() async {
    for (var i = 0; i < n; i++) {
      clock = clock.add(const Duration(minutes: 1));
      final save = newSession().state;
      save.addPet('kim_long', fedDay: 1);
      save.ownedPet('kim_long')!.stage = 2;
      save.ownedPet('kim_long')!.worn['neck'] = 'no_co_vai';
      save.petCharm = 'kim_long';
      if (i != 3) saves['p$i'] = save;
      await b.publish(
        period: 'season-1',
        entry: CharmBoardEntry.forPlayer(
          uid: 'p$i',
          displayName: 'Tiệm Hoa Số ${i + 1}',
          charm: i == 1 ? 340 : 305,
          petId: 'kim_long',
          stage: 2,
          worn: const {'neck': 'no_co_vai'},
        ),
      );
    }
  });
  saves.addAll(extraSaves);
  return (b, MemoryCharmRewardStore(saves: saves));
}

/// What the payout would have written for a small season.
MemoryCharmPayoutStore ran({
  DateTime? endsAt,
  bool auto = true,
  String status = 'done',
}) => MemoryCharmPayoutStore(
  auto: auto,
  metas: {
    'season-1': PayoutMeta(
      status: status,
      endsAt: endsAt ?? _end,
      sent: 2,
      held: 2,
      skipped: 1,
    ),
  },
  lines: {
    'season-1': const [
      PayoutLine(
        uid: 'p0',
        status: PayoutStatus.sent,
        displayName: 'Tiệm Hoa Số 1',
        rank: 1,
        stored: 305,
        recomputed: 305,
      ),
      PayoutLine(
        uid: 'p2',
        status: PayoutStatus.sent,
        displayName: 'Tiệm Hoa Số 3',
        rank: 2,
        stored: 305,
        recomputed: 305,
      ),
      PayoutLine(
        uid: 'p1',
        status: PayoutStatus.held,
        displayName: 'Tiệm Hoa Số 2',
        rank: 3,
        stored: 340,
        recomputed: 305,
        flags: ['mismatch'],
        petId: 'kim_long',
        stage: 2,
      ),
      PayoutLine(
        uid: 'p9',
        status: PayoutStatus.held,
        displayName: 'Tiệm Mới',
        rank: 7,
        stored: 305,
        recomputed: 305,
        flags: ['new_account', 'over_cap'],
        petId: 'kim_long',
        stage: 2,
      ),
      PayoutLine(
        uid: 'p3',
        status: PayoutStatus.skipped,
        displayName: 'Tiệm Hoa Số 4',
        stored: 305,
        reason: 'no_save',
      ),
    ],
  },
);

Future<void> mount(
  WidgetTester tester,
  MemoryCharmBoard b,
  MemoryCharmRewardStore store,
  MemoryCharmPayoutStore payout, {
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(420, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: CharmRewardAdminPanel(
        board: b,
        store: store,
        payout: payout,
        economy: _economy,
        onClose: () {},
        now: () => now ?? _end.add(const Duration(hours: 1)),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  group('before the payout has run: a preview, nothing to approve', () {
    testWidgets(
      'top 10 big, the rest compact, recomputed Mị lực beside the stored one',
      (tester) async {
        final (b, store) = await board(tester);
        await mount(tester, b, store, MemoryCharmPayoutStore());
        expect(find.text('Xếp hạng Mị lực'), findsOneWidget);
        expect(find.byKey(const Key('cra-not-yet')), findsOneWidget);
        for (var r = 1; r <= 10; r++) {
          expect(find.byKey(Key('cra-top-$r')), findsOneWidget);
        }
        expect(find.byKey(const Key('cra-top-11')), findsNothing);
        expect(find.byKey(const Key('cra-row-11')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('cra-top-1')),
            matching: find.textContaining('Tính lại 305, bảng ghi 340'),
          ),
          findsOneWidget,
        );
        expect(find.text('Không đọc được save'), findsOneWidget);
        // The top line says what rank 1 gets.
        expect(
          find.descendant(
            of: find.byKey(const Key('cra-top-1')),
            matching: find.text(
              '100 Pha lê · 20 Giọt hoa · đồ huyền thoại ngẫu nhiên',
            ),
          ),
          findsOneWidget,
        );
        // No bulk approval any more, and no tick boxes.
        expect(find.byKey(const Key('cra-approve')), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
      },
    );

    testWidgets('rows that will be dropped or held are flagged and counted', (
      tester,
    ) async {
      final (b, store) = await board(tester, n: 6);
      // p4 has no pet in the Mị lực slot any more.
      final empty = newSession().state..petCharm = null;
      final saves = await store.saves(['p0', 'p1', 'p2', 'p5']);
      final custom = MemoryCharmRewardStore(saves: {...saves, 'p4': empty});
      await mount(tester, b, custom, MemoryCharmPayoutStore());
      // rank 4 (p3, no save) and rank 5 (p4, no pet): dropped; p1 differs.
      for (final rank in [4, 5]) {
        expect(
          find.descendant(
            of: find.byKey(Key('cra-top-$rank')),
            matching: find.text('Sẽ bị bỏ qua'),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('cra-top-1')),
          matching: find.text('Sẽ bị giữ lại chờ duyệt'),
        ),
        findsOneWidget,
      );
      final summary = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('cra-summary')),
          matching: find.byType(Text),
        ),
      );
      expect(summary.data, contains('sẽ bị bỏ qua 2'));
      expect(summary.data, contains('sẽ bị giữ lại chờ duyệt 1'));
    });

    testWidgets('a season still running is flagged, an empty board says so', (
      tester,
    ) async {
      final (b, store) = await board(tester, n: 0);
      await mount(
        tester,
        b,
        store,
        MemoryCharmPayoutStore(),
        now: _end.subtract(const Duration(days: 3)),
      );
      expect(find.byKey(const Key('cra-season-warn')), findsOneWidget);
      expect(find.textContaining('Mùa này chưa kết thúc'), findsOneWidget);
      expect(find.text('Mùa này chưa có ai trên bảng.'), findsOneWidget);
    });

    testWidgets('a period key that is not valid shows the error', (
      tester,
    ) async {
      final (b, store) = await board(tester, n: 2);
      await mount(tester, b, store, MemoryCharmPayoutStore());
      await tester.enterText(find.byKey(const Key('cra-period')), 'Bad Key');
      await tester.tap(find.byKey(const Key('cra-load')));
      await settle(tester);
      expect(find.textContaining('Chưa tải được bảng'), findsOneWidget);
    });
  });

  group('after the payout: sent, skipped, held', () {
    testWidgets('lists what it did, held rows carry their flags', (
      tester,
    ) async {
      final (b, store) = await board(tester);
      await mount(tester, b, store, ran());
      final summary = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('cra-payout-summary')),
          matching: find.byType(Text),
        ),
      );
      expect(summary.data, contains('đã gửi 2'));
      expect(summary.data, contains('giữ lại chờ duyệt 2'));
      expect(summary.data, contains('bỏ qua 1'));
      expect(find.byKey(const Key('cra-sent-p0')), findsOneWidget);
      expect(find.byKey(const Key('cra-sent-p2')), findsOneWidget);
      expect(find.byKey(const Key('cra-held-p1')), findsOneWidget);
      expect(find.byKey(const Key('cra-flag-p1-mismatch')), findsOneWidget);
      expect(find.byKey(const Key('cra-flag-p9-new_account')), findsOneWidget);
      expect(find.byKey(const Key('cra-flag-p9-over_cap')), findsOneWidget);
      expect(find.text('Bảng ghi cao hơn Mị lực tính lại'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('cra-skipped-p3')),
          matching: find.text('Không đọc được save'),
        ),
        findsOneWidget,
      );
      // The preview is gone and "Duyệt thưởng" exists only on held rows.
      expect(find.byKey(const Key('cra-not-yet')), findsNothing);
      expect(find.byKey(const Key('cra-approve')), findsNothing);
      expect(find.byKey(const Key('cra-release-p1')), findsOneWidget);
      expect(find.byKey(const Key('cra-release-p9')), findsOneWidget);
      expect(find.byKey(const Key('cra-release-p0')), findsNothing);
      expect(find.byKey(const Key('cra-release-p3')), findsNothing);
    });

    testWidgets('releasing a held row asks first, writes once, moves it', (
      tester,
    ) async {
      final (b, store) = await board(tester);
      final payout = ran();
      await mount(tester, b, store, payout);

      await tester.tap(find.byKey(const Key('cra-release-p1')));
      await tester.pump();
      expect(find.byKey(const Key('cra-confirm')), findsOneWidget);
      // The season is over long ago: no warning.
      expect(find.byKey(const Key('cra-confirm-warn')), findsNothing);
      await tester.tap(find.byKey(const Key('cra-confirm-no')));
      await tester.pumpAndSettle();
      expect(store.mails, isEmpty);

      await tester.tap(find.byKey(const Key('cra-release-p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cra-confirm-yes')));
      await settle(tester);
      // Rank 3 of the table, written once, with the id the player claims by.
      expect(store.mails.keys, ['bxh_season-1_p1']);
      final mail = store.mails['bxh_season-1_p1']!;
      expect(mail.target, 'p1');
      expect(charmMailRank(mail), 3);
      expect(payout.released, [('season-1', 'p1')]);
      expect(find.byKey(const Key('cra-held-p1')), findsNothing);
      expect(find.byKey(const Key('cra-sent-p1')), findsOneWidget);
      expect(find.text('Admin đã duyệt'), findsOneWidget);
      // The other held row is untouched.
      expect(find.byKey(const Key('cra-held-p9')), findsOneWidget);
      expect(store.mails.length, 1);
    });

    testWidgets('a failed release leaves the row held to try again', (
      tester,
    ) async {
      final (b, store) = await board(tester);
      store.failFor.add('p1');
      await mount(tester, b, store, ran());
      await tester.tap(find.byKey(const Key('cra-release-p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cra-confirm-yes')));
      await settle(tester);
      expect(find.byKey(const Key('cra-held-p1')), findsOneWidget);
      expect(store.mails, isEmpty);
    });
  });

  group('releasing warns, never blocks, around the season end', () {
    Future<void> release(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('cra-release-p1')));
      await tester.pump();
    }

    testWidgets('before the end: warning on the page and in the dialog', (
      tester,
    ) async {
      final (b, store) = await board(tester, n: 3);
      await mount(
        tester,
        b,
        store,
        ran(),
        now: _end.subtract(const Duration(hours: 1)),
      );
      expect(find.byKey(const Key('cra-season-warn')), findsOneWidget);
      await release(tester);
      expect(find.byKey(const Key('cra-confirm-warn')), findsOneWidget);
      // Not blocked: confirming still writes.
      await tester.tap(find.byKey(const Key('cra-confirm-yes')));
      await settle(tester);
      expect(store.mails.length, 1);
    });

    testWidgets('inside the 5 minute grace it still warns', (tester) async {
      final (b, store) = await board(tester, n: 3);
      await mount(
        tester,
        b,
        store,
        ran(),
        now: _end.add(const Duration(minutes: 4)),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('cra-season-warn')),
          matching: find.textContaining('5 phút'),
        ),
        findsOneWidget,
      );
      await release(tester);
      expect(find.byKey(const Key('cra-confirm-warn')), findsOneWidget);
    });

    testWidgets('after the grace there is no warning', (tester) async {
      final (b, store) = await board(tester, n: 3);
      await mount(
        tester,
        b,
        store,
        ran(),
        now: _end.add(const Duration(minutes: 5)),
      );
      expect(find.byKey(const Key('cra-season-warn')), findsNothing);
      await release(tester);
      expect(find.byKey(const Key('cra-confirm')), findsOneWidget);
      expect(find.byKey(const Key('cra-confirm-warn')), findsNothing);
    });

    testWidgets('the edited endsAt of the meta doc is the one that counts', (
      tester,
    ) async {
      final (b, store) = await board(tester, n: 3);
      // An admin moved the end 3 days later: it is still running.
      await mount(
        tester,
        b,
        store,
        ran(endsAt: _end.add(const Duration(days: 3))),
        now: _end.add(const Duration(hours: 1)),
      );
      expect(find.byKey(const Key('cra-season-warn')), findsOneWidget);
    });
  });

  group('the kill switch', () {
    testWidgets('shows the state and writes the toggle', (tester) async {
      final (b, store) = await board(tester, n: 3);
      final payout = ran();
      await mount(tester, b, store, payout);
      expect(
        tester.widget<Switch>(find.byKey(const Key('cra-auto'))).value,
        isTrue,
      );
      expect(find.textContaining('Bật'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cra-auto')));
      await settle(tester);
      expect(payout.auto, isFalse);
      expect(
        tester.widget<Switch>(find.byKey(const Key('cra-auto'))).value,
        isFalse,
      );
      expect(find.textContaining('không ai được trả thưởng'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cra-auto')));
      await settle(tester);
      expect(payout.auto, isTrue);
    });

    testWidgets('starts off when the doc says off', (tester) async {
      final (b, store) = await board(tester, n: 3);
      await mount(tester, b, store, ran(auto: false));
      expect(
        tester.widget<Switch>(find.byKey(const Key('cra-auto'))).value,
        isFalse,
      );
    });
  });
}
