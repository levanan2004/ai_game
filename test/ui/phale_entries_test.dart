// Two ways in to the Pha le shop beside the settings gear / top bar:
//  - a third entry in the corner menu tray, under the gift box (Hop thu, Phuc
//    loi, Cua hang Pha le), icon from the Pha le art, label for screen readers;
//  - the whole Pha le pill of the top bar (amount, icon and +) opens the shop,
//    with a tap area of 44 dp.
// The shop itself says "Sap mo" until config/phaleShop is open.
import 'package:ai_game/logic/inbox.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/welfare.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/corner_menu.dart';
import 'package:ai_game/ui/game_root.dart' show menuEntries;
import 'package:ai_game/ui/phale_shop_screen.dart';
import 'package:ai_game/ui/phale_text.dart';
import 'package:ai_game/ui/reward_bundle_view.dart' show PhaLeIcon;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import '../logic/phale_shop_test.dart' show phaleEconomy;

ShopSession _session({bool open = true}) {
  final s = newSession(
    data: loadTestData(economy: phaleEconomy(open: open)),
  );
  s.accountUid = 'me';
  s.state.phaLe = 250;
  s.phaleAutoPoll = false;
  return s;
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The menu as game_root builds it: basket beside the gear, over the shop.
Future<({Inbox inbox, WelfareFeed welfare})> _menu(
  WidgetTester tester,
  ShopSession s, {
  Size size = const Size(360, 640),
}) async {
  _size(tester, size);
  final mail = MailboxFeed(service: null);
  final welfare = WelfareFeed(service: null);
  final inbox = Inbox(mail: mail);
  addTearDown(inbox.dispose);
  addTearDown(mail.dispose);
  addTearDown(welfare.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: CornerMenu(
                  left: 272,
                  top: 4,
                  listenable: Listenable.merge([inbox, welfare, s]),
                  entries: menuEntries(
                    inbox: inbox,
                    welfare: welfare,
                    session: s,
                  ),
                ),
              ),
              if (s.phaleShopOpen)
                Positioned.fill(child: PhaleShopHost(session: s)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  addTearDown(s.phaleShop.leave);
  return (inbox: inbox, welfare: welfare);
}

void main() {
  setUpAll(loadTestFonts);

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets('tray: Pha le sits under the gift box, >= 44 dp ($tag)', (
      tester,
    ) async {
      final s = _session();
      await _menu(tester, s, size: size);
      await tester.tap(find.byKey(const Key('corner-menu')));
      await tester.pump();
      final tray = tester.getRect(find.byKey(const Key('corner-menu-tray')));
      final mail = tester.getRect(find.byKey(const Key('corner-menu-mailbox')));
      final gift = tester.getRect(find.byKey(const Key('corner-menu-welfare')));
      final pha = tester.getRect(find.byKey(const Key('corner-menu-phale')));
      // top to bottom, equal 48 dp pitch, inside the (168 dp) tray
      expect(mail.top, lessThan(gift.top));
      expect(gift.top, lessThan(pha.top));
      expect(gift.top - mail.top, 48);
      expect(pha.top - gift.top, 48);
      expect(tray.height, CornerMenu.trayHeight(3));
      expect(tray.contains(pha.topLeft), isTrue);
      expect(tray.contains(pha.bottomRight), isTrue);
      for (final r in [mail, gift, pha]) {
        expect(r.width, greaterThanOrEqualTo(44));
        expect(r.height, greaterThanOrEqualTo(44));
      }
      // the three rows do not overlap and the circle keeps its 40 dp
      expect(mail.bottom, lessThanOrEqualTo(gift.top));
      expect(gift.bottom, lessThanOrEqualTo(pha.top));
      expect(
        tester.getSize(find.byKey(const Key('corner-menu-circle-phale'))),
        const Size(40, 40),
      );
      // the tray ends inside the screen
      expect(tray.bottom, lessThan(size.height));
      expect(find.byType(PhaLeIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tray: a11y label and the tap opens the shop (even closed)', (
    tester,
  ) async {
    final s = _session(open: false);
    await _menu(tester, s);
    await tester.tap(find.byKey(const Key('corner-menu')));
    await tester.pump();
    expect(find.bySemanticsLabel(PhaleText.title), findsOneWidget);
    expect(PhaleText.title, 'Cửa hàng Pha lê');
    await tester.tap(find.byKey(const Key('corner-menu-phale')));
    await tester.pump();
    expect(s.phaleShopOpen, isTrue);
    expect(find.byKey(const Key('phale-shop')), findsOneWidget);
    // the tray closed itself
    expect(find.byKey(const Key('corner-menu-tray')), findsNothing);
  });

  testWidgets('tray: no red dot is added by the Pha le entry', (tester) async {
    final s = _session();
    await _menu(tester, s);
    expect(find.byKey(const Key('corner-menu-dot')), findsNothing);
    await tester.tap(find.byKey(const Key('corner-menu')));
    await tester.pump();
    expect(find.byKey(const Key('corner-menu-dot-phale')), findsNothing);
  });

  testWidgets('without a session the tray has no Pha le entry', (tester) async {
    _size(tester, const Size(360, 640));
    final inbox = Inbox(mail: MailboxFeed(service: null));
    addTearDown(inbox.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CornerMenu(
            left: 272,
            top: 4,
            listenable: inbox,
            entries: menuEntries(inbox: inbox),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('corner-menu')));
    await tester.pump();
    expect(find.byKey(const Key('corner-menu-phale')), findsNothing);
    expect(find.byKey(const Key('corner-menu-mailbox')), findsOneWidget);
  });

  group('top bar Pha le pill', () {
    Future<ShopSession> bar(
      WidgetTester tester, {
      bool showRating = true,
      int phaLe = 250,
    }) async {
      final s = _session()..state.phaLe = phaLe;
      _size(tester, const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: TopBar(
                      session: s,
                      showRating: showRating,
                      showDay: false,
                      showPhaLe: true,
                    ),
                  ),
                  if (s.phaleShopOpen)
                    Positioned.fill(child: PhaleShopHost(session: s)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      addTearDown(s.phaleShop.leave);
      return s;
    }

    testWidgets('the tap area is 44 dp high around the 30 dp pill', (
      tester,
    ) async {
      await bar(tester);
      final pill = tester.getRect(find.byKey(const Key('topbar-pha-le')));
      final hit = tester.getRect(find.byKey(const Key('topbar-pha-le-hit')));
      expect(pill.height, 30);
      expect(hit.height, 44);
      expect(hit.width, greaterThanOrEqualTo(44));
      expect(hit.left, pill.left);
      expect(hit.width, pill.width);
      expect(hit.center.dy, closeTo(pill.center.dy, 0.01));
      // inside the 56 dp bar, clear of the corner basket at 272
      expect(hit.top, greaterThanOrEqualTo(0));
      expect(hit.bottom, lessThanOrEqualTo(56));
      expect(hit.right, lessThanOrEqualTo(272));
    });

    for (final (name, key, dy) in const [
      ('the amount', Key('topbar-pha-le-amount'), 0.0),
      ('the +', Key('topbar-pha-le-plus'), 0.0),
      ('the icon side of the pill', Key('topbar-pha-le'), 0.0),
      ('just above the pill (inside the 44 dp)', Key('topbar-pha-le'), -19.0),
      ('just below the pill (inside the 44 dp)', Key('topbar-pha-le'), 19.0),
    ]) {
      testWidgets('tapping $name opens the shop', (tester) async {
        final s = await bar(tester);
        await tester.tapAt(tester.getCenter(find.byKey(key)) + Offset(0, dy));
        await tester.pump();
        expect(s.phaleShopOpen, isTrue);
      });
    }

    testWidgets('a tap 25 dp above the pill misses it', (tester) async {
      final s = await bar(tester);
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('topbar-pha-le'))) +
            const Offset(0, -26),
      );
      await tester.pump();
      expect(s.phaleShopOpen, isFalse);
    });

    testWidgets('a long balance without the star: still the whole pill', (
      tester,
    ) async {
      final s = await bar(tester, showRating: false, phaLe: 12345);
      await tester.tap(find.byKey(const Key('topbar-pha-le-amount')));
      await tester.pump();
      expect(s.phaleShopOpen, isTrue);
    });
  });
}
