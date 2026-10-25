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
            child: SizedBox(width: 800, child: RushHourPill(session: s)),
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
      28,
    );

    _at(s, evening.start);
    s.tick(0.1);
    await tester.pump();
    final weight = s.e.arrivalWeightsByHour[evening.start]!;
    expect(
      find.text(
        '${GioCaoDiemText.peakCountdown((evening.end - evening.start) * 60)}'
        ' ×${formatMultiplier(weight)}',
      ),
      findsOneWidget,
    );
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
    final lunch = w.lunchQuiet!;
    expect(
      find.text(GioCaoDiemText.lunchCountdown((lunch.end - lunch.start) * 60)),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  test('countdown strings (Nhất 23:58)', () {
    expect(GioCaoDiemText.peakCountdown(42), 'Giờ cao điểm · còn 42 phút');
    expect(GioCaoDiemText.lunchCountdown(5), 'Giờ vắng · còn 5 phút');
    expect(GioCaoDiemText.peakCountdown(0), 'Giờ cao điểm · sắp hết');
    expect(GioCaoDiemText.lunchCountdown(0), 'Giờ vắng · sắp hết');
    expect(GioCaoDiemText.compactCountdown(7), ' · 7′');
  });

  test('minutes left round up; under one minute is 0', () {
    final s = _open();
    final evening = s.e.peakWindows.peaks.last;
    final perMin = s.e.secondsPerHour / 60;
    s.state.elapsed = ((evening.end - s.e.openHour) * 60 - 41.5) * perMin;
    expect(rushStatusOf(s)!.minutesLeft, 42);
    s.state.elapsed = ((evening.end - s.e.openHour) * 60 - 0.5) * perMin;
    expect(rushStatusOf(s)!.minutesLeft, 0);
  });

  testWidgets('narrow: icon + ×N + countdown, no text', (tester) async {
    final s = _open();
    final evening = s.e.peakWindows.peaks.last;
    _at(s, evening.end - 1, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(width: 90, child: RushHourPill(session: s)),
          ),
        ),
      ),
    );
    final weight = s.e.arrivalWeightsByHour[evening.end - 1]!;
    expect(find.byKey(const Key('rush-pill-compact')), findsOneWidget);
    expect(
      find.text(
        '×${formatMultiplier((weight * 10).round() / 10)}'
        '${GioCaoDiemText.compactCountdown(30)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('morning rush toast 1 s after opening, on the game clock', (
    tester,
  ) async {
    final s = _open();
    s.state.elapsed = 0;
    expect(rushStatusOf(s)!.kind, RushKind.peak);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(width: 800, child: RushHourPill(session: s)),
          ),
        ),
      ),
    );
    const toast = '${GioCaoDiemText.peakLabel}\n${GioCaoDiemText.peakSub}';
    s.tick(0.5);
    await tester.pump();
    expect(find.text(toast), findsNothing);
    s.tick(0.6);
    await tester.pump();
    expect(find.text(toast), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(toast), findsNothing);
    s.tick(0.5);
    await tester.pump();
    expect(find.text(toast), findsNothing, reason: 'once');
  });
}
