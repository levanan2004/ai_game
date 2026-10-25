import 'package:ai_game/logic/format.dart';
import 'package:ai_game/logic/rush_hour_status.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart' show DayPhase;
import 'package:ai_game/ui/gio_cao_diem_text.dart';
import 'package:ai_game/ui/rush_hour_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Giờ cao điểm pill: numbers from economy.json peakWindows /
/// arrivalWeightsByHour, texts from GioCaoDiemText.
ShopSession _open() {
  final s = newSession(seed: 4);
  s.buyAndGoToShop();
  s.state.phase = DayPhase.open;
  return s;
}

/// Puts the clock at [hour]:[minute].
void _at(ShopSession s, int hour, [int minute = 0]) {
  final e = s.e;
  s.state.elapsed =
      ((hour - e.openHour) * 60 + minute) / 60 * e.secondsPerHour + 0.01;
}

void main() {
  test('peak, lunch, upcoming and normal hours', () {
    final s = _open();
    final w = s.e.peakWindows;
    final evening = w.peaks.last;
    _at(s, evening.start);
    final peak = rushStatusOf(s)!;
    expect(peak.kind, RushKind.peak);
    expect(peak.labelKey, evening.labelKey);
    final weight = s.e.arrivalWeightsByHour[evening.start]!;
    expect(peak.multiplier, (weight * 10).round() / 10);

    _at(s, w.lunchQuiet!.start);
    expect(rushStatusOf(s)!.kind, RushKind.lunch);

    _at(s, evening.start - 1, 60 - w.warnBeforeMinutes ~/ 2);
    final soon = rushStatusOf(s)!;
    expect(soon.kind, RushKind.upcoming);
    expect(soon.minutesLeft, w.warnBeforeMinutes - w.warnBeforeMinutes ~/ 2);

    _at(s, evening.start - 1, 59 - w.warnBeforeMinutes);
    expect(rushStatusOf(s), isNull, reason: 'normal hour: hidden');

    s.state.phase = DayPhase.preparing;
    expect(rushStatusOf(s), isNull);
  });

  testWidgets('pill texts, opacity, start toast', (tester) async {
    final s = _open();
    final w = s.e.peakWindows;
    final evening = w.peaks.last;
    _at(s, evening.start - 1, 60 - w.warnBeforeMinutes);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(width: 230, child: RushHourPill(session: s)),
          ),
        ),
      ),
    );
    final name = GioCaoDiemText.peakName(evening.labelKey);
    expect(
      find.text(
        '${GioCaoDiemText.upcoming(name, formatClock(evening.start, 0))}'
        ' · ${GioCaoDiemText.countdown(w.warnBeforeMinutes)}',
      ),
      findsOneWidget,
    );
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.6);
    expect(
      tester.getSize(find.byKey(const Key('rush-pill-upcoming'))).height,
      24,
    );

    _at(s, evening.start);
    s.tick(0.1);
    await tester.pump();
    final weight = s.e.arrivalWeightsByHour[evening.start]!;
    expect(find.text('$name ×${formatMultiplier(weight)}'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(
      find.text('${GioCaoDiemText.peakLabel}\n${GioCaoDiemText.peakSub}'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 150));
    final mid = tester.widget<ScaleTransition>(find.byType(ScaleTransition));
    expect(mid.scale.value, greaterThan(1.05));
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.text('${GioCaoDiemText.peakLabel}\n${GioCaoDiemText.peakSub}'),
      findsNothing,
    );

    _at(s, evening.end);
    s.tick(0.1);
    await tester.pump();
    expect(find.byKey(const Key('rush-pill-none')), findsOneWidget);

    _at(s, w.lunchQuiet!.start);
    s.tick(0.1);
    await tester.pump();
    expect(find.text(GioCaoDiemText.lunchPill), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
