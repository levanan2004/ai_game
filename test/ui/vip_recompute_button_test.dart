import 'package:ai_game/data/vip_recompute.dart';
import 'package:ai_game/ui/vip_recompute_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements VipRecompute {
  int calls = 0;
  Object? error;

  @override
  Future<VipRecomputeResult> recomputeAll() async {
    calls++;
    if (error != null) throw error!;
    return (count: 42, changed: 3);
  }
}

Future<void> _mount(WidgetTester tester, _Fake f) => tester.pumpWidget(
  MaterialApp(
    home: Material(
      child: Center(child: VipRecomputeButton(recompute: f)),
    ),
  ),
);

void main() {
  test('reads the vipRecompute answer', () {
    expect(readVipRecompute({'count': 5, 'changed': 2, 'results': {}}), (
      count: 5,
      changed: 2,
    ));
    expect(readVipRecompute(null), (count: 0, changed: 0));
  });

  testWidgets('Tính lại VIP: confirm, then the count', (tester) async {
    final f = _Fake();
    await _mount(tester, f);
    expect(find.text(VipRecomputeButton.label), findsOneWidget);
    // Cancel: nothing is called.
    await tester.tap(find.byKey(const Key('admin-vip-recompute')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-vip-recompute-confirm')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('admin-vip-recompute-cancel')));
    await tester.pumpAndSettle();
    expect(f.calls, 0);
    // Confirm: one call, the result count shows.
    await tester.tap(find.byKey(const Key('admin-vip-recompute')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-vip-recompute-go')));
    await tester.pumpAndSettle();
    expect(f.calls, 1);
    expect(find.text(VipRecomputeButton.done(42)), findsOneWidget);
  });

  testWidgets('Tính lại VIP: a refusal (not admin) is shown', (tester) async {
    final f = _Fake()..error = StateError('not-admin');
    await _mount(tester, f);
    await tester.tap(find.byKey(const Key('admin-vip-recompute')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-vip-recompute-go')));
    await tester.pumpAndSettle();
    expect(find.text(VipRecomputeButton.failed('not-admin')), findsOneWidget);
    // The button is back for another try.
    expect(find.byKey(const Key('admin-vip-recompute')), findsOneWidget);
  });
}
