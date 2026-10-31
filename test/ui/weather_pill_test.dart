import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../logic/weather_test.dart';

void main() {
  testWidgets('weather pill: top-left, 8 dp from the edge, 6 dp under the '
      'resource bar (Phú 31/10)', (tester) async {
    final s = newSession(data: weatherData(), saveSeed: 77);
    var day = 1;
    while (s.weatherOn(day) == null || s.weatherOn(day)!.isNormal) {
      day++;
      expect(day, lessThan(400), reason: 'no weather day in the rules');
    }
    s.state.day = day;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: s,
            builder: (_, _) => MainShopOverlay(session: s),
          ),
        ),
      ),
    );
    await tester.pump();
    final pill = find.byKey(const Key('weather-pill'));
    expect(pill, findsOneWidget);
    expect(tester.getTopLeft(pill), const Offset(8, 56 + 6.0));
    await tester.pumpWidget(const SizedBox());
  });
}
