import 'package:ai_game/logic/delivery.dart' show gameHour;
import 'package:ai_game/logic/price_format.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/hoa_sap_heo_view.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> _pump(WidgetTester tester, ShopSession s, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(listenable: s, builder: (_, _) => child),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

/// Open shop at clearance `startHour` with 4 last-day roses.
ShopSession _clearanceSession() {
  final s = newSession();
  stockAndOpen(s);
  s.state.stock
    ..clear()
    ..add(StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1));
  final start = s.data.wilting.clearance.startHour;
  while (gameHour(s.e, s.state.elapsed) < start) {
    s.state.elapsed += 1;
  }
  return s;
}

void main() {
  testWidgets('basket shows from startHour; sheet prices', (tester) async {
    final s = _clearanceSession();
    expect(ClearanceBasket.visible(s), isTrue);
    await _pump(tester, s, MainShopOverlay(session: s));
    expect(find.byKey(const Key('clearance-basket')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('clearance-badge')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('clearance-basket')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('clearance-sheet')), findsOneWidget);
    expect(find.text(vndLabel(clearancePrice(s, 'rose'))), findsOneWidget);
    expect(find.text(vndLabel(s.e.flower('rose').sellPrice)), findsOneWidget);
  });

  testWidgets('basket hidden before startHour', (tester) async {
    final s = newSession();
    stockAndOpen(s);
    s.state.stock
      ..clear()
      ..add(StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1));
    expect(ClearanceBasket.visible(s), isFalse);
    await _pump(tester, s, MainShopOverlay(session: s));
    expect(find.byKey(const Key('clearance-basket')), findsNothing);
  });

  testWidgets('shelf: badge, progress, sheet with block names', (tester) async {
    final s = newSession();
    final d = s.data.wilting.drying;
    s.state.dryingUnlocked = true;
    s.state.drying.add(
      DryingBatch(flowerId: 'rose', stems: 2, daysLeft: d.dryingDays),
    );
    s.state.driedStock['rose'] = 3;
    await _pump(tester, s, MainShopOverlay(session: s));
    expect(find.text('5/${d.storageCap}'), findsOneWidget);
    expect(find.byKey(const Key('dried-progress')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dried-shelf')));
    await tester.pump(const Duration(milliseconds: 500));
    final t = s.data.wilting.text;
    expect(find.text(t.get('dried', 'shelfStock', {'n': 3})), findsOneWidget);
    expect(find.text(d.byId('rose')!.name), findsOneWidget);
    expect(
      find.text(t.get('dried', 'drying', {'ngay': d.dryingDays})),
      findsOneWidget,
    );
  });

  testWidgets('unlock card: locked hint, then popup buys the rack', (
    tester,
  ) async {
    final s = newSession();
    final d = s.data.wilting.drying;
    final t = s.data.wilting.text;
    s.state.day = d.unlockDay - 1;
    var open = false;
    Widget page() => StatefulBuilder(
      builder: (_, set) => Stack(
        children: [
          const SizedBox.expand(),
          DryingUnlockCard(session: s, onBuy: () => set(() => open = true)),
          if (open)
            Positioned.fill(
              child: DryingUnlockPopup(
                session: s,
                onClose: () => set(() => open = false),
              ),
            ),
        ],
      ),
    );
    await _pump(tester, s, page());
    expect(
      find.text(t.get('unlock', 'lockedHint', {'ngay': d.unlockDay})),
      findsOneWidget,
    );
    s.state.day = d.unlockDay;
    s.state.money = d.unlockCost;
    await _pump(tester, s, page());
    await tester.tap(find.byKey(const Key('buy-drying')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('drying-unlock-popup')), findsOneWidget);
    await tester.tap(find.byKey(const Key('drying-unlock-go')));
    await tester.pump(const Duration(seconds: 1));
    expect(s.state.dryingUnlocked, isTrue);
    expect(s.state.money, 0);
  });
}
