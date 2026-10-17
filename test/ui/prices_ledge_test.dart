import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/shop_shelf.dart';
import 'package:ai_game/save/game_state.dart' show DayPhase;
import 'package:ai_game/ui/game_root.dart' show GameFrame;
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/prices_ledge_button.dart';
import 'package:ai_game/ui/shop_shelf_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

/// "Giá bán" on the counter ledge, right of the day/time plaque (PA2), and
/// the bottom bar that lost its tab.
Future<void> _pump(
  WidgetTester tester,
  ShopSession s, {
  Size size = const Size(360, 640),
  bool framed = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Widget overlay() => ListenableBuilder(
    listenable: s,
    builder: (context, _) => MainShopOverlay(session: s),
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        child: framed
            ? GameFrame(child: overlay())
            : Align(alignment: Alignment.topLeft, child: overlay()),
      ),
    ),
  );
  await tester.pump();
}

ShopSession _shop({int day = 12}) {
  final s = newSession(seed: 4);
  s.buyAndGoToShop();
  s.state.day = day;
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets(
      'PA2: 78x44 tap area, 8 dp right of the plaque, on the ledge ($tag)',
      (tester) async {
        final s = _shop();
        await _pump(tester, s, size: size);
        final origin = tester.getTopLeft(find.byType(MainShopOverlay));
        final btn = tester.getRect(find.byKey(const Key('prices-ledge')));
        final plaque = tester.getRect(find.byKey(const Key('shelf-plaque')));
        final clock = tester.getRect(find.byKey(const Key('shelf-clock')));
        expect(btn.size, const Size(78, 44));
        expect(btn.width, greaterThanOrEqualTo(44));
        expect(btn.height, greaterThanOrEqualTo(44));
        expect(btn.left - plaque.right, closeTo(8, 0.01));
        expect(btn.bottom - origin.dy, closeTo(ShelfGeometry.ledgeTop, 0.01));
        expect(btn.overlaps(plaque), isFalse);
        expect(btn.overlaps(clock), isFalse);
        // Inside the frame, left of the bar's pet end of the ledge.
        expect(btn.right - origin.dx, lessThan(360 - 100));
        expect(find.byKey(const Key('prices-ledge-icon')), findsOneWidget);
        expect(find.text('Giá bán'), findsOneWidget);
        // The top bar did not get a Giá bán.
        expect(
          find.descendant(
            of: find.byKey(const Key('topbar-money')),
            matching: find.text('Giá bán'),
          ),
          findsNothing,
        );
      },
    );
  }

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    testWidgets(
      'the board is the plaque kind: 32 dp, same face, wood and radius, on the ledge (${size.width.round()})',
      (tester) async {
        final s = _shop();
        await _pump(tester, s, size: size);
        final plaque = tester.getRect(find.byKey(const Key('shelf-plaque')));
        final board = tester.getRect(
          find.byKey(const Key('prices-ledge-board')),
        );
        final hit = tester.getRect(find.byKey(const Key('prices-ledge')));
        expect(board.height, plaque.height);
        expect(board.height, 32);
        expect(board.bottom, closeTo(plaque.bottom, 0.01));
        expect(board.top, closeTo(plaque.top, 0.01));
        expect(board.left, hit.left);
        expect(board.right, hit.right);
        expect(hit.height, 44);
        // The face is built from the same pieces as the plaque.
        final face = tester.widget<DecoratedBox>(
          find.byKey(const Key('prices-ledge-face')),
        );
        final deco = face.decoration as BoxDecoration;
        expect(deco.color, AppColors.bgBase);
        expect(deco.borderRadius, BorderRadius.circular(8));
        final border = deco.border! as Border;
        expect(border.top.color, ShopShelfLayer.wood);
        expect(border.top.width, 1.8);
        // Icon and word sit inside the board, no overflow, one line.
        final icon = tester.getRect(find.byKey(const Key('prices-ledge-icon')));
        final text = tester.getRect(
          find.byKey(const Key('prices-ledge-label')),
        );
        expect(board.contains(icon.topLeft), isTrue);
        expect(board.contains(icon.bottomRight), isTrue);
        expect(board.contains(text.topLeft), isTrue);
        expect(board.contains(text.bottomRight), isTrue);
        expect(icon.right, lessThanOrEqualTo(text.left));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('icon-only flag: the same board, just the icon, 44 dp wide', (
    tester,
  ) async {
    expect(kPricesLedgeIconOnly, isFalse, reason: 'default is icon + text');
    final s = _shop();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: PricesLedgeButton(session: s, iconOnly: true),
          ),
        ),
      ),
    );
    final hit = tester.getRect(find.byKey(const Key('prices-ledge')));
    expect(hit.size, const Size(44, 44));
    expect(
      tester.getSize(find.byKey(const Key('prices-ledge-board'))),
      const Size(44, 32),
    );
    expect(find.byKey(const Key('prices-ledge-icon')), findsOneWidget);
    expect(find.byKey(const Key('prices-ledge-label')), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const Key('prices-ledge'))).label,
      'Giá bán',
    );
    expect(
      ShelfGeometry.pricesRect(
        const Rect.fromLTWH(0, 0, 50, 32),
        iconOnly: true,
      ).width,
      44,
    );
  });

  testWidgets('a longer day text widens the plaque and the button follows', (
    tester,
  ) async {
    final s = _shop(day: 20);
    await _pump(tester, s);
    final short = tester.getRect(find.byKey(const Key('prices-ledge')));
    s.state.day = 1000;
    s.notifyListeners();
    await tester.pump();
    final plaque = tester.getRect(find.byKey(const Key('shelf-plaque')));
    final long = tester.getRect(find.byKey(const Key('prices-ledge')));
    expect(long.left, greaterThan(short.left));
    expect(long.left - plaque.right, closeTo(8, 0.01));
  });

  testWidgets('wide screen: the button stays in the scaled frame', (
    tester,
  ) async {
    final s = _shop();
    await _pump(tester, s, size: const Size(1000, 600), framed: true);
    final frame = tester.getRect(find.byType(MainShopOverlay));
    final btn = tester.getRect(find.byKey(const Key('prices-ledge')));
    expect(frame.contains(btn.topLeft), isTrue);
    expect(frame.contains(btn.bottomRight), isTrue);
    final scale = frame.width / 360;
    expect(btn.width, closeTo(78 * scale, 0.5));
    expect(btn.height, closeTo(44 * scale, 0.5));
    await tester.tap(find.byKey(const Key('prices-ledge')));
    await tester.pump();
    expect(s.screen, Screen.prices);
  });

  testWidgets('before the opening day it is dimmed and says the day', (
    tester,
  ) async {
    final s = _shop(day: 4);
    await _pump(tester, s);
    double opacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byKey(const Key('prices-ledge')),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(opacity(), 0.45);
    await tester.tap(find.byKey(const Key('prices-ledge')));
    await tester.pump();
    expect(find.text('Mở vào ngày ${s.e.pricesOpenDay}'), findsOneWidget);
    expect(s.screen, isNot(Screen.prices));

    s.state.day = s.e.pricesOpenDay;
    s.notifyListeners();
    await tester.pump(const Duration(seconds: 3));
    expect(opacity(), 1);
  });

  testWidgets('from the opening day a tap opens Giá bán, any phase', (
    tester,
  ) async {
    final s = _shop(day: 12);
    await _pump(tester, s);
    await tester.tap(find.byKey(const Key('prices-ledge')));
    await tester.pump();
    expect(s.screen, Screen.prices);
    s.closePrices();
    s.openShop();
    await tester.pump();
    expect(s.state.phase, DayPhase.open);
    await tester.tap(find.byKey(const Key('prices-ledge')));
    await tester.pump();
    expect(s.screen, Screen.prices, reason: 'still opens while selling');
  });

  testWidgets('the drawing of the ledge still ignores the pointer', (
    tester,
  ) async {
    final s = _shop();
    await _pump(tester, s);
    final ignore = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const Key('shop-shelf')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue);
    expect(
      find.ancestor(
        of: find.byKey(const Key('prices-ledge')),
        matching: find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
        ),
      ),
      findsNothing,
      reason: 'the button must be able to take the tap',
    );
  });

  testWidgets('bottom bar: five tabs of 72 dp, no Giá bán tab', (tester) async {
    final s = _shop();
    await _pump(tester, s);
    final origin = tester.getTopLeft(find.byType(MainShopOverlay));
    for (var i = 0; i < 5; i++) {
      final r = tester.getRect(find.byKey(Key('nav-$i')));
      expect(r.width, 72);
      expect(r.left - origin.dx, i * 72.0);
    }
    expect(find.byKey(const Key('nav-5')), findsNothing);
    final labels = [
      for (var i = 0; i < 5; i++)
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(Key('nav-$i')),
                matching: find.byType(Text),
              ),
            )
            .data,
    ];
    expect(labels, ['Kho hoa', 'Nâng cấp', 'Đánh giá', 'Bản đồ', 'Chậu hoa']);
  });
}
