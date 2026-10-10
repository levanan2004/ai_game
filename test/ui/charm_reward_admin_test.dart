import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/charm_rewards.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/charm_reward_admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'charm_board_screen_test.dart' show loadFonts;

final _economy = loadTestData().economy;

/// A board of [n] players on season-1. Player 1 (rank 1) claims more Mị lực
/// than the save backs; player 3 has no readable save.
Future<(MemoryCharmBoard, MemoryCharmRewardStore)> board(
  WidgetTester tester, {
  int n = 14,
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
  return (b, MemoryCharmRewardStore(saves: saves));
}

Future<void> mount(
  WidgetTester tester,
  MemoryCharmBoard b,
  MemoryCharmRewardStore store, {
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
        economy: _economy,
        onClose: () {},
        now: () => now ?? DateTime.utc(2026, 11, 10),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  testWidgets(
    'top 10 big, the rest compact, recomputed Mị lực beside the stored one',
    (tester) async {
      final (b, store) = await board(tester);
      await mount(tester, b, store);
      expect(find.text('Xếp hạng Mị lực'), findsOneWidget);
      for (var r = 1; r <= 10; r++) {
        expect(find.byKey(Key('cra-top-$r')), findsOneWidget);
      }
      expect(find.byKey(const Key('cra-top-11')), findsNothing);
      expect(find.byKey(const Key('cra-row-11')), findsOneWidget);
      expect(find.text('Tiệm Hoa Số 1'), findsOneWidget);
      // Rank 1 (p1 is stored 340 > the others) shows the mismatch, p3 no save.
      expect(
        find.descendant(
          of: find.byKey(const Key('cra-top-1')),
          matching: find.textContaining('Tính lại 305, bảng ghi 340'),
        ),
        findsOneWidget,
      );
      expect(find.text('Không đọc được save'), findsOneWidget);
      expect(find.byKey(const Key('cra-summary')), findsOneWidget);
      expect(find.text('Duyệt thưởng (14 người)'), findsOneWidget);
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
    },
  );

  testWidgets(
    'Duyệt thưởng asks first, writes once, then has nothing left to approve',
    (tester) async {
      final (b, store) = await board(tester);
      await mount(tester, b, store);

      // Leave rank 2 out.
      await tester.tap(find.byKey(const Key('cra-skip-p0')));
      await tester.pump();
      expect(find.text('Duyệt thưởng (13 người)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cra-approve')));
      await tester.pump();
      expect(find.byKey(const Key('cra-confirm')), findsOneWidget);
      // "Để xem lại" writes nothing.
      await tester.tap(find.byKey(const Key('cra-confirm-no')));
      await tester.pumpAndSettle();
      expect(store.mails, isEmpty);

      await tester.tap(find.byKey(const Key('cra-approve')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cra-confirm-yes')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(store.mails.length, 13);
      expect(store.mails.containsKey('bxh_season-1_p0'), isFalse);
      expect(find.text('đã gửi 13'), findsOneWidget);
      expect(find.text('Không còn ai để duyệt'), findsOneWidget);
      expect(find.byKey(const Key('cra-paid-1')), findsOneWidget);
      // The skipped player is still waiting.
      expect(find.byKey(const Key('cra-skip-p0')), findsOneWidget);
    },
  );

  testWidgets('a reload after approval shows Đã duyệt and cannot pay again', (
    tester,
  ) async {
    final (b, store) = await board(tester, n: 4);
    await mount(tester, b, store);
    await tester.tap(find.byKey(const Key('cra-approve')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cra-confirm-yes')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(store.mails.length, 4);

    await tester.tap(find.byKey(const Key('cra-load')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    for (var r = 1; r <= 4; r++) {
      expect(find.byKey(Key('cra-paid-$r')), findsOneWidget);
    }
    expect(find.text('Không còn ai để duyệt'), findsOneWidget);
    expect(store.mails.length, 4);
  });

  testWidgets('a season still running is flagged, an empty board says so', (
    tester,
  ) async {
    final (b, store) = await board(tester, n: 0);
    await mount(tester, b, store, now: DateTime.utc(2026, 10, 20));
    expect(find.textContaining('Mùa này chưa kết thúc'), findsOneWidget);
    expect(find.text('Mùa này chưa có ai trên bảng.'), findsOneWidget);
    expect(find.byKey(const Key('cra-approve')), findsOneWidget);
  });

  testWidgets('a period key that is not valid shows the error', (tester) async {
    final (b, store) = await board(tester, n: 2);
    await mount(tester, b, store);
    await tester.enterText(find.byKey(const Key('cra-period')), 'Bad Key');
    await tester.tap(find.byKey(const Key('cra-load')));
    await tester.pump();
    expect(find.textContaining('Chưa tải được bảng'), findsOneWidget);
  });
}
