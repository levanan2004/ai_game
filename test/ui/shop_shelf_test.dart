import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/shop_shelf.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> _pump(WidgetTester tester, ShopSession s) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => MainShopOverlay(session: s),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Finder _petImages() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('shelf-pet-'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('Pha lê pill sits after the star, clear of the menu', (
    tester,
  ) async {
    final s = newSession();
    s.state.phaLe = 1250;
    await _pump(tester, s);
    expect(_text(tester, 'topbar-pha-le-amount'), '1,2k');
    final pill = tester.getRect(find.byKey(const Key('topbar-pha-le')));
    final money = tester.getRect(find.byKey(const Key('topbar-money')));
    // Same row as xu and star, ends before the menu basket (x 272).
    expect(pill.top, closeTo(money.top - (money.height - 30) / 2, 30));
    expect(pill.right - pill.left, 58);
    final origin = tester.getTopLeft(find.byType(MainShopOverlay));
    expect(pill.right - origin.dx, lessThanOrEqualTo(266));
  });

  testWidgets('main shop header has no day/time box; the ledge plaque does', (
    tester,
  ) async {
    final s = newSession();
    await _pump(tester, s);
    expect(find.byKey(const Key('topbar-day')), findsNothing);
    expect(find.byKey(const Key('topbar-money')), findsOneWidget);
    expect(find.byKey(const Key('topbar-pause')), findsOneWidget);
    expect(_text(tester, 'shelf-day'), 'Ngày ${s.state.day}');
    expect(_text(tester, 'shelf-time'), '08:00');
    expect(find.byKey(const Key('shelf-clock')), findsOneWidget);

    // Other screens keep their header box.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: TopBar(session: s, showPause: true, noticeSlot: true),
        ),
      ),
    );
    expect(find.byKey(const Key('topbar-day')), findsOneWidget);
  });

  testWidgets('plaque follows the in-game clock as it runs', (tester) async {
    final s = newSession();
    s.state.day = 12;
    s.state.phase = DayPhase.open;
    s.state.elapsed = 0;
    await _pump(tester, s);
    expect(_text(tester, 'shelf-day'), 'Ngày 12');
    expect(_text(tester, 'shelf-time'), '08:00');

    // Session ticks notify listeners; the plaque rebuilds from them.
    s.state.elapsed = s.e.secondsPerHour * 9.5;
    s.tick(0.2);
    await tester.pump();
    final shown = _text(tester, 'shelf-time');
    expect(shown, s.clockText);
    expect(shown, startsWith('17:3'));

    // Last hour: line 2 turns warning amber.
    s.state.elapsed = s.e.secondsPerHour * (s.e.closeHour - s.e.openHour - 0.5);
    await _pump(tester, s);
    expect(
      tester.widget<Text>(find.byKey(const Key('shelf-time'))).style!.color,
      AppColors.statusWarning,
    );
    expect(shelfClosingSoon(s), isTrue);

    s.state.elapsed = s.e.secondsPerHour * (s.e.closeHour - s.e.openHour + 1);
    await _pump(tester, s);
    expect(_text(tester, 'shelf-time'), 'Đóng cửa');
  });

  testWidgets('holiday keeps its short date on the plaque', (tester) async {
    final s = newSession();
    final h = s.e.holidays.first;
    s.state.day = h.days.first;
    await _pump(tester, s);
    expect(_text(tester, 'shelf-day'), h.shortLabel);
    expect(
      tester.widget<Text>(find.byKey(const Key('shelf-day'))).style!.color,
      AppColors.primaryPressed,
    );
  });

  testWidgets('tapping the clock shows the closing-time tip for 2 s', (
    tester,
  ) async {
    final heard = <String>[];
    final s = newSession(sounds: Sounds(heard: heard));
    s.state.phase = DayPhase.open;
    s.state.elapsed = 0;
    await _pump(tester, s);
    final taps = shelfTapsOf(s);
    expect(taps.tap(taps.clockArea!.center), isTrue);
    await tester.pump();
    expect(
      _text(tester, 'shelf-clock-tip'),
      'Ngày 1 · 08:00 · còn 12 giờ nữa đóng cửa',
    );
    expect(heard, contains('ui_tap.mp3'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const Key('shelf-clock-tip')), findsNothing);
    // Empty ledge passes through.
    expect(taps.tap(const Offset(180, 270)), isFalse);
  });

  test('clock tip wording across the day', () {
    final s = newSession();
    expect(shelfClockTip(s), 'Ngày 1 · 08:00 · tiệm chưa mở cửa');
    s.state.phase = DayPhase.open;
    s.state.elapsed = s.e.secondsPerHour * 11.5;
    expect(shelfClockTip(s), 'Ngày 1 · 19:30 · còn 30 phút nữa đóng cửa');
    s.state.elapsed = s.e.secondsPerHour * 2.5;
    expect(shelfClockTip(s), 'Ngày 1 · 10:30 · còn 9 giờ 30 phút nữa đóng cửa');
    s.state.elapsed = s.e.secondsPerHour * 13;
    expect(shelfClockTip(s), 'Ngày 1 · tiệm đã đóng cửa');
  });

  testWidgets('brought cat sits on the ledge, picture by stage', (
    tester,
  ) async {
    final s = newSession();
    s.state.hasCat = true;
    for (final (stage, asset, height) in const [
      (0, 'meo_au_ngoi', 42.0),
      (1, 'meo_lon_ngoi', 50.0),
      (2, 'meo_truong_ngoi', 56.0),
    ]) {
      s.state.petStage = stage;
      await _pump(tester, s);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(Key('shelf-pet-$asset')), findsOneWidget);
      expect(_petImages(), findsOneWidget);
      final pet = shelfPet(s.state)!;
      final ink = ShelfGeometry.petRect(pet);
      expect(ink.height, height);
      expect(ink.bottom, ShelfGeometry.ledgeTop + 1);
      expect(ink.right, lessThanOrEqualTo(356));
      expect(shelfTapsOf(s).petArea, ink);
      final box = tester.getRect(find.byKey(Key('shelf-pet-$asset')));
      final want = ShelfGeometry.petImageBox(pet);
      expect(box.left, closeTo(want.left, 0.5));
      expect(box.bottom, closeTo(want.bottom, 0.5));
    }
  });

  testWidgets('no cat brought: no cat, no shadow target; clock stays', (
    tester,
  ) async {
    final s = newSession();
    s.state.hasCat = false;
    await _pump(tester, s);
    expect(_petImages(), findsNothing);
    expect(shelfTapsOf(s).petArea, isNull);
    expect(find.byKey(const Key('shelf-clock')), findsOneWidget);
    expect(find.byKey(const Key('shelf-plaque')), findsOneWidget);
  });

  testWidgets('cat: tap hops with a heart, a second tap opens the room', (
    tester,
  ) async {
    final s = newSession();
    s.state.hasCat = true;
    s.state.day = 6;
    s.screen = Screen.shop;
    await _pump(tester, s);
    final taps = shelfTapsOf(s);
    final at = taps.petArea!.center;
    expect(taps.tap(at), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('shelf-heart')), findsOneWidget);
    expect(s.screen, Screen.shop);
    expect(taps.tap(at), isTrue);
    await tester.pump();
    expect(s.screen, Screen.pets);

    s.closePets();
    await _pump(tester, s);
    expect(taps.hold(taps.petArea!.center), isTrue);
    expect(s.screen, Screen.pets);
  });

  testWidgets('the shelf never takes a pointer itself', (tester) async {
    final s = newSession();
    s.state.hasCat = true;
    await _pump(tester, s);
    expect(
      find.ancestor(
        of: find.byKey(const Key('shop-shelf')),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    final ignore = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const Key('shop-shelf')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue);
  });

  test('ledge geometry matches the spec', () {
    final clock = ShelfGeometry.clockRect();
    expect(clock.left, 6);
    expect(clock.height, 39);
    expect(clock.bottom, ShelfGeometry.ledgeTop);
    expect(clock.width, closeTo(42.4, 0.1));
    final small = ShelfGeometry.plaqueRect(10);
    expect(small.width, closeTo(46, 0.001));
    expect(small.height, 32);
    expect(small.left, clock.right - 3);
    expect(small.bottom, ShelfGeometry.ledgeTop);
    expect(ShelfGeometry.plaqueRect(50).width, closeTo(62, 0.001));
    final s = newSession();
    s.state.hasCat = true;
    s.state.petStage = 2;
    final big = ShelfGeometry.petRect(shelfPet(s.state)!);
    expect(big.center.dx, closeTo(311, 0.5));
    expect(big.right, lessThanOrEqualTo(356));
    // Clear of the notice, mailbox and Phúc lợi buttons (x 276+, y < 160).
    expect(big.top, greaterThan(160));
    expect(clock.top, greaterThan(160));
  });
}
