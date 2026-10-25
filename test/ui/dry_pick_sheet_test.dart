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
}
