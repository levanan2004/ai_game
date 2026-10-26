import 'package:ai_game/ui/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('Thu chi amounts end on one right-aligned column', (
    tester,
  ) async {
    final s = newSession();
    stockAndOpen(s);
    s.state.pendingArrivals.clear();
    s.closeEarly();
    s.state.stock.clear();
    s.state.dryingUnlocked = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SummaryScreen(session: s)));
    await tester.pump(const Duration(seconds: 2));
    final card = find
        .ancestor(of: find.text('Thu chi'), matching: find.byType(Stack))
        .first;
    final amounts = find.descendant(
      of: card,
      matching: find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^[+\-\u2212]').hasMatch(w.data ?? ''),
      ),
    );
    expect(amounts, findsAtLeastNWidgets(2));
    final rights = {
      for (final e in amounts.evaluate())
        tester.getTopRight(find.byWidget(e.widget)).dx.roundToDouble(),
    };
    expect(rights, hasLength(1), reason: 'right edges: $rights');
  });
}
