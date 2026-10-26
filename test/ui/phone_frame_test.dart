import 'package:ai_game/ui/frame_metrics.dart';
import 'package:ai_game/ui/game_root.dart' show GameFrame;
import 'package:ai_game/ui/market_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> _frame(
  WidgetTester tester,
  Size size, {
  EdgeInsets viewPadding = EdgeInsets.zero,
  Widget? child,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, viewPadding: viewPadding),
        child: GameFrame(child: child ?? const _Probe()),
      ),
    ),
  );
  await tester.pump();
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    final m = FrameMetrics.maybeOf(context);
    return Text(
      '${m?.stageGapTop ?? -1} ${m?.edgeTop ?? -1}',
      key: const Key('probe'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a 360x640 phone keeps the design frame', (tester) async {
    await _frame(tester, const Size(360, 640));
    expect(
      tester.getSize(find.byKey(const Key('probe'))),
      const Size(360, 640),
    );
    expect(tester.widget<Text>(find.byKey(const Key('probe'))).data, '0.0 0.0');
  });

  testWidgets('a tall phone grows the frame instead of letterboxing', (
    tester,
  ) async {
    await _frame(tester, const Size(390, 844));
    final probe = tester.getSize(find.byKey(const Key('probe')));
    // 844 / (390/360) — the window aspect, not the old 640.
    expect(probe.width, 360);
    expect(probe.height, closeTo(844 * 360 / 390, 0.05));
    final gap = double.parse(
      tester
          .widget<Text>(find.byKey(const Key('probe')))
          .data!
          .split(' ')
          .first,
    );
    // The stage sits under the safe area (none here), not centred: no band
    // above the header (An 26/10).
    expect(gap, 0);
  });

  testWidgets('market header and footer meet the screen on a tall phone', (
    tester,
  ) async {
    await _frame(
      tester,
      const Size(390, 844),
      viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      child: MarketScreen(session: newSession()),
    );
    final frame = tester.getRect(find.byType(GameFrame));
    final money = tester.getRect(find.byKey(const Key('topbar-money')));
    final buy = tester.getRect(find.byKey(const Key('market-buy')));
    // Status icons sit in the green header; the pill stays below them.
    expect(money.top, greaterThan(47));
    expect(money.top, lessThan(80));
    // The buy button clears the gesture bar and is not floating mid-screen.
    expect(frame.bottom - buy.bottom, greaterThan(34));
    expect(frame.bottom - buy.bottom, lessThan(70));
    expect(tester.takeException(), isNull);
  });
}
