import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/main.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/bouquet_table_screen.dart';
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
  await tester.pump();
  await tester.enterText(find.byKey(const Key('shop-name-field')), 'Hoa Ơi');
  await tester.pump();
  await tester.tap(find.byKey(const Key('shop-name-save')));
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

  testWidgets('holiday: day pill shows the short date in pink, no chip', (
    tester,
  ) async {
    final s = newSession();
    final h = s.e.holidays.first;
    BoxDecoration pill() =>
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byKey(const Key('topbar-day')),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    Future<void> pump({required bool market}) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: market
              ? TopBar(
                  session: s,
                  showRating: false,
                  dayLabel: '${dayName(s)} · Sáng',
                )
              : TopBar(session: s, showPause: true),
        ),
      ),
    );

    s.state.day = h.days.first;
    expect(s.holidayToday?.id, h.id);
    await pump(market: true);
    expect(find.text('${h.shortLabel} · Sáng'), findsOneWidget);
    expect(find.textContaining('Ngày'), findsNothing);
    expect(find.text(h.nameVi), findsNothing);
    expect(find.byKey(const Key('topbar-holiday')), findsNothing);
    expect(pill().color, AppColors.headerChip);
    expect(pill().border, isNull);
    await pump(market: false);
    expect(find.text('${h.shortLabel} · ${s.clockText}'), findsOneWidget);
    expect(pill().color, AppColors.headerChip);

    // Ordinary day uses the same chip fill.
    s.state.day = h.days.first - 1;
    expect(s.holidayToday, isNull);
    await pump(market: false);
    expect(find.text('Ngày ${s.state.day} · ${s.clockText}'), findsOneWidget);
    expect(pill().color, AppColors.headerChip);
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

  testWidgets('unlock grid is two columns at 390 and at 360', (tester) async {
    Future<void> openTab(Size size) async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ShopApp(data: loadTestData(), store: ProgressStore.memory({})),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _startAndSkipTutorial(tester);
      await tester.tap(find.byKey(const Key('market-buy')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('nav-1')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('upgrades-tab-1')));
      await tester.pump(const Duration(milliseconds: 300));
    }

    void expectSameRow(String a, String b) {
      final ra = tester.getRect(find.byKey(Key('unlock-$a')));
      final rb = tester.getRect(find.byKey(Key('unlock-$b')));
      expect(
        (ra.top - rb.top).abs(),
        lessThan(1),
        reason: '$a and $b share a row',
      );
      expect((ra.height - rb.height).abs(), lessThan(1));
      expect((ra.width - rb.width).abs(), lessThan(1));
      expect(rb.left, greaterThan(ra.right));
    }

    Future<void> expectHeadings() async {
      expect(find.text('Hoa'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Giấy gói'), 200);
      expect(find.text('Giấy gói'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Nơ'), 200);
      expect(find.text('Nơ'), findsOneWidget);
    }

    await openTab(const Size(390, 844));
    expectSameRow('rose', 'daisy');
    expectSameRow('baby', 'carnation');
    final wide = tester.getRect(find.byKey(const Key('unlock-rose')));
    // 164 logical px, scaled into the 390-wide frame (about 175).
    expect(wide.width, greaterThan(170));
    expect(wide.width, lessThan(190));
    await expectHeadings();

    await openTab(const Size(360, 640));
    expectSameRow('rose', 'daisy');
    final phone = tester.getRect(find.byKey(const Key('unlock-rose')));
    final daisy = tester.getRect(find.byKey(const Key('unlock-daisy')));
    expect(phone.width, closeTo(164, 1));
    expect(daisy.left - phone.right, closeTo(8, 1));
    await expectHeadings();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tutorial steps 1-4 lead the first customer to the table', (
    tester,
  ) async {
    final backing = <String, String>{};
    await _boot(tester, backing);
    await tester.tap(find.byKey(const Key('title-main')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('shop-name-field')), 'Hoa Ơi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('shop-name-save')));
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

  testWidgets('title settings hides the pause line and says Đóng', (
    tester,
  ) async {
    await _boot(tester, {});
    await tester.tap(find.byKey(const Key('topbar-pause')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Game đang tạm dừng'), findsNothing);
    expect(find.text('Đóng'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsNothing);
    await tester.tap(find.byKey(const Key('settings-rename')));
    await tester.pump();
    expect(find.text('Đổi tên tiệm'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(find.text('Lưu tên'), findsOneWidget);
    expect(find.text('Có thể đổi tên sau trong Cài đặt.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings gear pauses and Tiếp tục resumes', (tester) async {
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
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Game đang tạm dừng'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.textContaining('Đăng nhập để lưu tiến độ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-resume')),
      80,
    );
    await tester.tap(find.byKey(const Key('settings-resume')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Cài đặt'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('signed-out avatar pick updates the settings portrait', (
    tester,
  ) async {
    await _boot(tester, {});
    await tester.tap(find.byKey(const Key('topbar-pause')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('settings-avatar')));
    await tester.pump();
    expect(find.byKey(const Key('avatar-picker')), findsOneWidget);
    expect(find.text('Đổi avatar'), findsOneWidget);
    expect(
      find.text(
        'Cần đăng nhập Google. Ảnh được cắt vuông và thu nhỏ trước khi lưu.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('avatar-lan_anh')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('avatar-close')));
    await tester.pump();
    expect(find.byKey(const Key('avatar-picker')), findsNothing);

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('settings-avatar')),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as AssetImage).assetName, contains('lan_anh'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the settings pencil opens the avatar picker', (tester) async {
    await _boot(tester, {});
    await tester.tap(find.byKey(const Key('topbar-pause')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('settings-avatar-edit')));
    await tester.pump();
    expect(find.byKey(const Key('avatar-picker')), findsOneWidget);
    expect(find.text('Đổi avatar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Giấy tab switches tabs and keeps the same customer', (
    tester,
  ) async {
    final s = newSession();
    stockAndOpen(s);
    final c = waitForCustomer(s);
    s.state.pendingArrivals.clear();
    s.openTable();
    expect(s.addStem('rose'), isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: BouquetTableScreen(session: s),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('tray-kraft')), findsNothing);
    await tester.tap(find.byKey(const Key('tab-paper')));
    await tester.pump();
    expect(find.byKey(const Key('tray-kraft')), findsOneWidget);
    expect(s.tableCustomer?.id, c.id);
    expect(s.draft.stems, isNotEmpty);
    expect(s.screen, Screen.table);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
