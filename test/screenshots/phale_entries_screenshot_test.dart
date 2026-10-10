// Pha le entries: the corner tray with its third row and the shop it opens, at
// 360x640 and 390x844. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/phale_entries_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/inbox.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/welfare.dart';
import 'package:ai_game/ui/corner_menu.dart';
import 'package:ai_game/ui/game_root.dart' show menuEntries;
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/phale_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import '../logic/phale_shop_test.dart' show phaleEconomy;

final _dir = Platform.environment['SHOT_DIR'];
const _frame = Key('shot-frame');

Future<void> _save(WidgetTester tester, String name) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1000)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_frame),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadTestFonts);
  if (_dir == null) {
    test('screenshots skipped (SHOT_DIR not set)', () {}, skip: true);
    return;
  }

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    for (final open in [true, false]) {
      final state = open ? 'mo' : 'sap_mo';
      testWidgets('pha le entry $state $tag', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = newSession(
          data: loadTestData(economy: phaleEconomy(open: open)),
          seed: 4,
        );
        s.buyAndGoToShop();
        s.state.day = 20;
        s.state.phaLe = 250;
        s.state.potShopHintShown = true; // no pot-shop reminder over the shots
        s.state.potShopSeenIds = [for (final p in s.e.pots) p.id];
        s.accountUid = 'me';
        s.phaleAutoPoll = false;
        final inbox = Inbox(mail: MailboxFeed(service: null));
        final welfare = WelfareFeed(service: null);
        addTearDown(inbox.dispose);
        addTearDown(welfare.dispose);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: _frame,
              child: Material(
                child: ListenableBuilder(
                  listenable: s,
                  builder: (context, _) => Stack(
                    children: [
                      Positioned.fill(child: MainShopOverlay(session: s)),
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
          ),
        );
        await tester.pump();
        addTearDown(s.phaleShop.leave);
        if (open) await _save(tester, 'phale_vao_01_man_chinh_$tag');
        await tester.tap(find.byKey(const Key('corner-menu')));
        await tester.pump(const Duration(milliseconds: 300));
        if (open) await _save(tester, 'phale_vao_02_khay_3_muc_$tag');
        await tester.tap(find.byKey(const Key('corner-menu-phale')));
        await tester.pump(const Duration(milliseconds: 500));
        await _save(tester, 'phale_vao_03_cua_hang_${state}_$tag');
        if (open) {
          s.closePhaleShop();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byKey(const Key('topbar-pha-le-amount')));
          await tester.pump(const Duration(milliseconds: 500));
          await _save(tester, 'phale_vao_04_cham_so_du_$tag');
          expect(s.phaleShopOpen, isTrue);
        }
      });
    }
  }
}
