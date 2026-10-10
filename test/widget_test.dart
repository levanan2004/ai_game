import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/logic/bouquet.dart';
import 'package:ai_game/logic/delivery.dart';
import 'package:ai_game/logic/payment.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/main.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/bouquet_table_screen.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/donors_screen.dart';
import 'package:ai_game/ui/garden_screen.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/price_screen.dart';
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
    ShopApp(
      data: loadTestData(),
      store: ProgressStore.memory(withTerms(backing)),
    ),
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

  testWidgets('holiday: day pill shows the short date, no chip', (
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
      ShopApp(
        data: loadTestData(),
        store: ProgressStore.memory(withTerms(backing)),
      ),
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
    expect(find.byKey(const Key('end-day')), findsOneWidget);

    final game = tester
        .widget<GameWidget<ShopGame>>(find.byType(GameWidget<ShopGame>))
        .game!;
    expect(game.camera.viewport.virtualSize.x, ShopGame.logicalWidth);

    // In the shop no tab is open, so no tab label is in the active colour.
    for (var i = 0; i < 5; i++) {
      final labels = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(Key('nav-$i')),
          matching: find.byType(Text),
        ),
      );
      for (final t in labels) {
        expect(t.style?.color, isNot(AppColors.navActiveLabel));
      }
    }

    // Kho hoa lists what is already in the shop.
    await tester.tap(find.byKey(const Key('nav-0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Kho hoa'), findsOneWidget);
    expect(find.text('Hoa hồng'), findsOneWidget);
    await tester.tap(find.byKey(const Key('stock-back')));
    await tester.pump(const Duration(milliseconds: 100));

    // Star pill opens the Reviews screen.
    await tester.tap(find.byKey(const Key('nav-2')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đánh giá của khách'), findsOneWidget);
    expect(find.text('Chưa có nhận xét nào'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reviews-back')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('donors: board first, Ủng hộ opens the QR card', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(home: DonorsScreen(session: newSession())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('donors-board')), findsOneWidget);
    expect(find.byKey(const Key('donors-ask-admin')), findsOneWidget);
    expect(find.byKey(const Key('donors-card')), findsNothing);

    await tester.tap(find.byKey(const Key('donate-open')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('donors-card')), findsOneWidget);
    expect(
      find.text('Trời có mắt, người tốt sẽ được đền đáp vào bản cập nhật sau.'),
      findsOneWidget,
    );
    expect(find.textContaining('số điện thoại'), findsWidgets);

    // Tapping inside the card keeps it; the close button dismisses it.
    await tester.tap(find.text('Ủng hộ Tiệm Hoa Sớm Mai'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('donors-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('donate-close')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('donors-card')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('upgrades: buy a level through the confirm popup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final backing = <String, String>{};
    await tester.pumpWidget(
      ShopApp(
        data: loadTestData(),
        store: ProgressStore.memory(withTerms(backing)),
      ),
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
    expect(find.text('Nâng cấp'), findsOneWidget);
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
        ShopApp(data: loadTestData(), store: ProgressStore.memory(withTerms())),
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

    Future<void> expectGroups() async {
      expect(find.byKey(const Key('unlock-rose')), findsOneWidget);
      expect(find.byKey(const Key('unlock-kraft')), findsNothing);
      await tester.tap(find.byKey(const Key('unlock-kind-1')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Giấy'), findsWidgets);
      expect(find.byKey(const Key('unlock-kraft')), findsOneWidget);
      expect(find.byKey(const Key('unlock-rose')), findsNothing);
      await tester.tap(find.byKey(const Key('unlock-kind-2')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('unlock-twine')), findsOneWidget);
      expect(find.byKey(const Key('unlock-kraft')), findsNothing);
    }

    await openTab(const Size(390, 844));
    expectSameRow('rose', 'daisy');
    expectSameRow('baby', 'carnation');
    final wide = tester.getRect(find.byKey(const Key('unlock-rose')));
    // 164 logical px, scaled into the 390-wide frame (about 175).
    expect(wide.width, greaterThan(170));
    expect(wide.width, lessThan(190));
    await expectGroups();

    await openTab(const Size(360, 640));
    expectSameRow('rose', 'daisy');
    final phone = tester.getRect(find.byKey(const Key('unlock-rose')));
    final daisy = tester.getRect(find.byKey(const Key('unlock-daisy')));
    expect(phone.width, closeTo(164, 1));
    expect(daisy.left - phone.right, closeTo(8, 1));
    await expectGroups();
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
    expect(find.text('1 bông'), findsOneWidget);
    expect(find.byKey(const Key('picked-rose')), findsOneWidget);
    expect(find.byKey(const Key('tray-kraft')), findsNothing);
    await tester.tap(find.byKey(const Key('tab-paper')));
    await tester.pump();
    expect(find.byKey(const Key('tray-kraft')), findsOneWidget);
    expect(s.tableCustomer?.id, c.id);
    expect(s.draft.stems, isNotEmpty);
    expect(s.screen, Screen.table);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the right theme card adds a tip', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession(seed: 3);
    stockAndOpen(s);
    final c = waitForCustomer(s);
    s.state.pendingArrivals.clear();
    s.openTable();
    final flower = c.request.stems.keys.first;
    expect(s.addStem(flower), isTrue);
    s.selectPaper(
      s.owned.contains(c.request.paperId) ? c.request.paperId : 'kraft',
    );
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
    await tester.tap(find.byKey(const Key('deliver-button')));
    await tester.pump();
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('wrap-hold'))),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await hold.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('card-suggest-0')), findsOneWidget);
    expect(find.byKey(const Key('card-suggest-3')), findsOneWidget);
    // The finish step only offers the four cards, never a typed wish.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(
      find.text('Đúng chủ đề thì boa thêm 3k. Không chọn vẫn giao được.'),
      findsOneWidget,
    );
    final theme = s.e.occasion(c.request.occasionId).nameVi;
    Finder? chip;
    for (var i = 0; i < 4; i++) {
      final key = find.byKey(Key('card-suggest-$i'));
      final label = tester.widget<Text>(
        find.descendant(of: key, matching: find.byType(Text)),
      );
      if (label.data == theme) chip = key;
    }
    expect(chip, isNotNull);
    await tester.tap(chip!);
    await tester.pump();
    expect(s.cardNote, cardLineFor(s.e, c.request.occasionId));
    await tester.tap(find.byKey(const Key('admire-deliver')));
    await tester.pump();
    expect(s.lastDelivery?.payment.noteBonus, s.e.cardNoteTip);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an online ticket shows the occasion theme', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession(seed: 5);
    stockAndOpen(s);
    s.tableOrder = OnlineOrder(
      id: 1,
      kind: OrderKind.sameday,
      customerName: 'An',
      avatarId: 'lan_anh',
      request: const BouquetRequest(
        occasionId: 'thanks',
        stems: {'rose': 3},
        paperId: 'kraft',
        ribbonId: 'twine',
      ),
      line: '3 hoa hồng',
      speech: 'Giao giúp mình trước giờ đóng cửa nhé!',
      deadline: 120,
      spawnAt: 0,
      acceptLeft: 20,
    );
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
    expect(find.textContaining('Cảm ơn / thăm'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Bản đồ opens the market and keeps the later rooms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession(seed: 4);
    s.buyAndGoToShop();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: MainShopOverlay(session: s),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('prices-ledge')));
    await tester.pump();
    expect(find.text('Mở vào ngày 10'), findsOneWidget);
    expect(s.screen, isNot(Screen.prices));
    expect(find.text('Bản đồ'), findsOneWidget);
    await tester.tap(find.text('Bản đồ'));
    await tester.pump();
    expect(find.byKey(const Key('map-market')), findsOneWidget);
    expect(find.byKey(const Key('map-pets')), findsOneWidget);
    expect(find.byKey(const Key('map-garden')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-pets')));
    await tester.pump();
    expect(find.text('Mở vào ngày 5'), findsWidgets);
    expect(s.screen, isNot(Screen.pets));
    await tester.tap(find.byKey(const Key('map-garden')));
    await tester.pump();
    expect(find.text('Mở vào ngày 20'), findsWidgets);
    expect(s.screen, isNot(Screen.garden));
    await tester.tap(find.byKey(const Key('map-market')));
    await tester.pump();
    expect(s.screen, Screen.market);
    expect(s.state.phase, DayPhase.market);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Vườn nhà opens from the map and plants a seed', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession(seed: 5);
    s.state.day = 20;
    s.state.potShopHintShown = true; // no Tiệm Chậu Hoa hint over the nav
    s.buyAndGoToShop();
    expect(s.buyShovel(), isTrue);
    expect(s.tillPlot(0), isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: MainShopOverlay(session: s),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Bản đồ'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-garden')));
    await tester.pump();
    expect(s.screen, Screen.garden);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: ListenableBuilder(
              listenable: s,
              builder: (_, _) => GardenScreen(session: s),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('garden-plot-0')), findsOneWidget);
    expect(find.byKey(const Key('garden-plot-3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('garden-shop')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('garden-buy-daisy')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('garden-shop')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('garden-plant-daisy')));
    await tester.pump();
    expect(find.textContaining('đang lớn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the third early day cannot end before closing time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession(seed: 7);
    stockAndOpen(s);
    s.state.earlyClosesInARow = 2;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: ListenableBuilder(
              listenable: s,
              builder: (_, _) => MainShopOverlay(session: s),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('end-day')));
    await tester.pump();
    expect(find.text(ShopSession.playUntilCloseHint), findsOneWidget);
    expect(find.byKey(const Key('end-day-confirm')), findsNothing);
    expect(s.state.phase, DayPhase.open);

    s.state.stock.clear();
    s.tick(0.1);
    await tester.pump();
    await tester.tap(find.byKey(const Key('close-early')));
    await tester.pump();
    expect(find.byKey(const Key('end-day-confirm')), findsNothing);
    expect(s.state.phase, DayPhase.open);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Giá bán steps the walk-in price before the doors open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession(seed: 6);
    s.buyAndGoToShop();
    s.state.day = 10;
    s.openPrices();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: ListenableBuilder(
              listenable: s,
              builder: (_, _) => PriceScreen(session: s),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1×'), findsOneWidget);
    await tester.tap(find.byKey(const Key('price-up')));
    await tester.pump();
    expect(s.priceMultiplier, 1.1);
    expect(find.text('1,1×'), findsOneWidget);
    expect(find.text('Khoảng 92%'), findsOneWidget);
    s.openShop();
    await tester.pump();
    await tester.tap(find.byKey(const Key('price-up')));
    await tester.pump();
    expect(s.priceMultiplier, 1.1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
