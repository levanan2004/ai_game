import 'package:ai_game/data/skins.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/map_popup.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> _mount(
  WidgetTester tester,
  ShopSession s,
  Widget child, {
  double width = 360,
  double height = 640,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ListenableBuilder(listenable: s, builder: (_, _) => child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('brush on the main screen only while the shop is closed', (
    tester,
  ) async {
    final s = newSession(worldChat: MemoryWorldChat());
    s.state.potShopHintShown = true;
    s.buyAndGoToShop();
    await _mount(tester, s, MainShopOverlay(session: s));
    expect(s.state.phase, DayPhase.preparing);
    await tester.tap(find.byKey(const Key('main-decorate')));
    await tester.pump();
    expect(s.decorateGroup, skinGroupShop);
    s.state.phase = DayPhase.open;
    s.closeDecorate();
    await _mount(tester, s, MainShopOverlay(session: s));
    expect(find.byKey(const Key('main-decorate')), findsNothing);
  });

  testWidgets('map row opens Tiệm Trang Trí and closes the map', (
    tester,
  ) async {
    final s = newSession();
    s.state.phase = DayPhase.preparing;
    var closed = false;
    await _mount(
      tester,
      s,
      Stack(
        children: [
          Builder(
            builder: (context) => MapPopup(
              session: s,
              onClose: () => closed = true,
              extraRows: [mapDecorateRow(context, s, () => closed = true)],
            ),
          ),
        ],
      ),
    );
    expect(find.text('Tiệm Trang Trí'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('map-decorate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-decorate')));
    await tester.pump();
    expect(s.decorateGroup, skinGroupShop);
    expect(closed, isTrue);
  });

  testWidgets('pet room has a Trang trí phòng button', (tester) async {
    final s = newSession();
    s.state.hasCat = true;
    await _mount(tester, s, PetScreen(session: s));
    await tester.tap(find.byKey(const Key('pet-open-decorate')));
    await tester.pump();
    expect(s.decorateGroup, skinGroupRoom);
  });

  for (final (w, h) in const [(360.0, 640.0), (360.0, 480.0), (420.0, 800.0)]) {
    testWidgets('Trang trí button at ${w.toInt()}x${h.toInt()}: 56dp wooden '
        'box with the brush icon', (tester) async {
      final s = newSession();
      s.state.hasCat = true;
      await _mount(
        tester,
        s,
        PetScreen(session: s),
        width: w,
        height: h,
      );
      final button = find.byKey(const Key('pet-open-decorate'));
      final b = tester.getRect(button);
      expect(b.width, greaterThanOrEqualTo(56));
      expect(b.height, greaterThanOrEqualTo(56));
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.brush)),
        findsOneWidget,
      );
    });
  }
}