import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/main.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/common.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Title screen "Bắt đầu", then "Bỏ qua" on the first tutorial card.
Future<void> _startAndSkipTutorial(WidgetTester tester) async {
  expect(find.text('Bắt đầu'), findsOneWidget);
  expect(find.text('v0.1'), findsOneWidget);
  await tester.tap(find.byKey(const Key('title-main')));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('Chào chủ tiệm mới!'), findsOneWidget);
  await tester.tap(find.byKey(const Key('tutorial-skip')));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byKey(const Key('tutorial-card')), findsNothing);
}

/// The spotlight measures its target after layout, so it needs a frame
/// more than the screen change itself.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _boot(WidgetTester tester, Map<String, String> backing) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ShopApp(data: loadTestData(), store: ProgressStore.memory(backing)),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('holiday chip shows the short date beside the day pill', (
    tester,
  ) async {
    final s = newSession();
    final h = s.e.holidays.first;
    s.state.day = h.days.first;
    expect(s.holidayToday?.id, h.id);
    for (final upgrades in [false, true]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: TopBar(
              session: s,
              showRating: upgrades,
              dayLabel: upgrades ? 'Ngày 7' : 'Ngày 7 · Sáng',
            ),
          ),
        ),
      );
      expect(find.text(h.shortLabel), findsOneWidget);
      expect(find.text(h.nameVi), findsNothing);
      final chip = tester.getRect(find.byKey(const Key('topbar-holiday')));
      // The chip hugs its short text instead of stretching to 140 px.
      expect(chip.width, lessThan(100), reason: 'upgrades: $upgrades');
      expect(chip.top, 10, reason: 'same row as the day pill');
      if (upgrades) {
        final day = tester.getRect(find.text('Ngày 7'));
        expect(chip.right, lessThan(day.left));
      }
    }
  });

  testWidgets('market -> main shop -> open, at phone size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final backing = <String, String>{};
    await tester.pumpWidget(
      ShopApp(data: loadTestData(), store: ProgressStore.memory(backing)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _startAndSkipTutorial(tester);

    expect(find.text('Chợ hoa buổi sáng'), findsOneWidget);
    expect(find.text('Mở cửa luôn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plus-rose')));
    await tester.pump();
    expect(find.text('Mua & mở cửa'), findsOneWidget);
    await tester.tap(find.byKey(const Key('market-buy')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mở cửa'), findsOneWidget);
    expect(find.text('Mục tiêu hôm nay'), findsOneWidget);
    await tester.tap(find.byKey(const Key('main-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đang chờ khách...'), findsOneWidget);

    final game = tester
        .widget<GameWidget<ShopGame>>(find.byType(GameWidget<ShopGame>))
        .game!;
    expect(game.camera.viewport.virtualSize.x, ShopGame.logicalWidth);

    // Star pill opens the Reviews screen.
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đánh giá của khách'), findsOneWidget);
    expect(find.text('Chưa có nhận xét nào'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reviews-back')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('upgrades: buy a level through the confirm popup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final backing = <String, String>{};
    await tester.pumpWidget(
      ShopApp(data: loadTestData(), store: ProgressStore.memory(backing)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _startAndSkipTutorial(tester);
    await tester.tap(find.byKey(const Key('market-buy')));
    await tester.pump(const Duration(milliseconds: 100));

    // Preparing: the Nâng cấp nav button opens the screen.
    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Nâng cấp tiệm'), findsOneWidget);
    expect(find.byKey(const Key('upgrade-cold_storage')), findsOneWidget);

    await tester.tap(find.byKey(const Key('buy-cold_storage')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('upgrade-confirm')), findsOneWidget);
    expect(find.text('Chưa có'), findsWidgets);
    await tester.tap(find.byKey(const Key('confirm-buy')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('upgrade-confirm')), findsNothing);
    expect(find.textContaining('Đang có cấp 1'), findsOneWidget);

    // Second tab: unlock grid with "Đã có" for owned items.
    await tester.tap(find.byKey(const Key('upgrades-tab-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Đã có'), findsWidgets);
    expect(find.byKey(const Key('unlock-rose')), findsOneWidget);

    await tester.tap(find.byKey(const Key('upgrades-back')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Mục tiêu hôm nay'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tutorial steps 1-4 lead the first customer to the table', (
    tester,
  ) async {
    final backing = <String, String>{};
    await _boot(tester, backing);
    await tester.tap(find.byKey(const Key('title-main')));
    await _frames(tester);
    expect(find.text('1/8'), findsOneWidget);

    // Taps outside the spotlight are swallowed.
    await tester.tap(find.byKey(const Key('market-buy')), warnIfMissed: false);
    await _frames(tester);
    expect(find.text('1/8'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plus-rose')));
    await _frames(tester);
    expect(find.text('2/8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('market-buy')));
    await _frames(tester);
    expect(find.text('3/8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('main-button')));
    await _frames(tester);
    expect(find.text('4/8'), findsOneWidget);
    // The clock stands still while the tutorial runs.
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('08:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await _frames(tester);
    expect(find.byKey(const Key('tutorial-card')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pause popup: back to title keeps the morning save', (
    tester,
  ) async {
    final backing = <String, String>{};
    await _boot(tester, backing);
    await _startAndSkipTutorial(tester);
    await tester.tap(find.byKey(const Key('plus-rose')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('market-buy')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('main-button')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('topbar-pause')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tạm dừng'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pause-title')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Chơi tiếp'), findsOneWidget);
    await tester.tap(find.byKey(const Key('title-main')));
    await tester.pump(const Duration(milliseconds: 100));
    // Back at the market of day 1, the bought roses are gone.
    expect(find.text('Chợ hoa buổi sáng'), findsOneWidget);
    expect(find.text('Kho: trống'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
