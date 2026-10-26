import 'package:ai_game/logic/platform_flags.dart' show phaLeTopUpOverride;
// Pha lê shop: the top-bar pill opens it. The corner tray is Hộp thư, Phúc
// lợi, Cài đặt (Tin thế giới is on the bottom nav).
import 'package:ai_game/logic/inbox.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/welfare.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/corner_menu.dart';
import 'package:ai_game/ui/game_root.dart' show menuEntries;
import 'package:ai_game/ui/phale_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import '../logic/phale_shop_test.dart' show phaleEconomy;

ShopSession _session({bool open = true}) {
  final s = newSession(
    data: loadTestData(economy: phaleEconomy(open: open)),
    worldChat: MemoryWorldChat(),
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
                  left: CornerMenu.shopHudLeft,
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
  // The top-up shop is closed in the build (platform_flags.dart); these tests
  // cover the code kept behind the flag.
  setUp(() => phaLeTopUpOverride = true);
  tearDown(() => phaLeTopUpOverride = null);
  setUpAll(loadTestFonts);

  for (final size in const [Size(360, 640), Size(390, 844), Size(390, 680)]) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets('basket: 40 dp art, 48 dp tap area ($tag)', (tester) async {
      final s = _session();
      await _menu(tester, s, size: size);
      final art = tester.getRect(find.byKey(const Key('corner-menu')));
      expect(art.size, const Size(40, 40));
      final hit = tester.getRect(find.byKey(const Key('corner-menu-hit')));
      expect(hit.size, const Size(48, 48));
      // Clear of the TopBar pill row (it stops 6 dp left of the art).
      expect(hit.left, greaterThan(CornerMenu.shopHudLeft - 6));
      // 3 dp outside the art still opens the tray.
      await tester.tapAt(art.bottomLeft + const Offset(-3, 3));
      await tester.pump();
      expect(find.byKey(const Key('corner-menu-tray')), findsOneWidget);
    });

    testWidgets('tray: mail, gift, settings ($tag)', (tester) async {
      final s = _session();
      await _menu(tester, s, size: size);
      await tester.tap(find.byKey(const Key('corner-menu')));
      await tester.pump();
      final tray = tester.getRect(find.byKey(const Key('corner-menu-tray')));
      final mail = tester.getRect(find.byKey(const Key('corner-menu-mailbox')));
      final gift = tester.getRect(find.byKey(const Key('corner-menu-welfare')));
      final settings =
          tester.getRect(find.byKey(const Key('corner-menu-settings')));
      expect(mail.top, lessThan(gift.top));
      expect(gift.top, lessThan(settings.top));
      expect(tray.height, CornerMenu.trayHeight(3));
      expect(find.byKey(const Key('corner-menu-phale')), findsNothing);
      expect(find.byKey(const Key('corner-menu-world_chat')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tray: settings toggles pause', (tester) async {
    final s = _session();
    await _menu(tester, s);
    expect(s.pauseMenuOpen, isFalse);
    await openSettingsFromCornerMenu(tester);
    expect(s.pauseMenuOpen, isTrue);
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
      expect(hit.top, greaterThanOrEqualTo(0));
      expect(hit.bottom, lessThanOrEqualTo(56));
    });

    for (final (name, key, dy) in const [
      ('the amount', Key('topbar-pha-le-amount'), 0.0),
      ('the +', Key('topbar-pha-le-plus'), 0.0),
      ('the icon side of the pill', Key('topbar-pha-le'), 0.0),
    ]) {
      testWidgets('tapping $name opens the shop', (tester) async {
        final s = await bar(tester);
        await tester.tapAt(tester.getCenter(find.byKey(key)) + Offset(0, dy));
        await tester.pump();
        expect(s.phaleShopOpen, isTrue);
      });
    }
  });
}
