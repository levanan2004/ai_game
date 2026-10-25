import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> _mount(WidgetTester tester, ShopSession s) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: SummaryScreen(session: s)));
  await tester.pump(const Duration(seconds: 1));
}

ShopSession _summary(List<StockBatch> stock, {bool unlocked = true}) {
  final s = newSession();
  stockAndOpen(s);
  s.state.pendingArrivals.clear();
  s.closeEarly();
  s.state.stock
    ..clear()
    ..addAll(stock);
  s.state.dryingUnlocked = unlocked;
  s.screen = Screen.summary;
  return s;
}

void main() {
  testWidgets('no sheet when drying is locked', (tester) async {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1),
    ], unlocked: false);
    await _mount(tester, s);
    expect(find.byKey(const Key('dry-pick-sheet')), findsNothing);
  });

  testWidgets('pick, Phơi khô sends the stems; peony is greyed', (
    tester,
  ) async {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1),
      StockBatch(flowerId: 'peony', count: 2, freshnessLeft: 1),
    ]);
    final t = s.data.wilting.text;
    final d = s.data.wilting.drying;
    await _mount(tester, s);
    expect(find.byKey(const Key('dry-pick-sheet')), findsOneWidget);
    expect(find.text(t.get('dried', 'pickTitle')), findsOneWidget);
    expect(
      find.text(
        t.get('dried', 'storageCounter', {'dang': 0, 'toiDa': d.storageCap}),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('dry-cell-peony')),
        matching: find.byType(Opacity),
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(const Key('dry-cell-rose')));
    await tester.pump();
    expect(find.byKey(const Key('dry-pick-count')), findsOneWidget);
    expect(
      find.text(t.get('dried', 'pickYield', {'n': dryYield(s, 'rose', 4)})),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('dry-go')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('dry-pick-sheet')), findsNothing);
    expect(s.state.drying.single.flowerId, 'rose');
    expect(s.state.metrics.driedSent, 4);
    expect(
      find.text(t.get('summary', 'driedSentLine', {'n': 4})),
      findsOneWidget,
    );
  });

  testWidgets('Để sau closes without drying', (tester) async {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1),
    ]);
    await _mount(tester, s);
    await tester.tap(find.byKey(const Key('dry-skip')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('dry-pick-sheet')), findsNothing);
    expect(s.state.drying, isEmpty);
  });

  testWidgets('hold ~400ms: -/+ bar picks a stem count', (tester) async {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1),
    ]);
    await _mount(tester, s);
    final cell = find.byKey(const Key('dry-cell-rose'));
    final g = await tester.startGesture(tester.getCenter(cell));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('dry-stepper-rose')), findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    await g.up();
    await tester.pump();
    expect(find.byKey(const Key('dry-stepper-rose')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dry-step-rose--')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dry-step-rose--')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('dry-picked-rose')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    // + stops at the candidates, - at one stem.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('dry-step-rose--')));
      await tester.pump();
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('dry-picked-rose')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('dry-step-rose-+')));
      await tester.pump();
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('dry-picked-rose')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('dry-step-rose--')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dry-go')));
    await tester.pump(const Duration(seconds: 1));
    expect(s.state.metrics.driedSent, 3);
  });

  testWidgets('"Phơi khô" fits at 360dp', (tester) async {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1),
    ]);
    await _mount(tester, s);
    final t = s.data.wilting.text;
    final label = tester.getRect(find.text(t.get('dried', 'dryButton')));
    final button = tester.getRect(find.byKey(const Key('dry-go')));
    expect(label.width, lessThanOrEqualTo(button.width));
    expect(tester.takeException(), isNull);
  });
}
