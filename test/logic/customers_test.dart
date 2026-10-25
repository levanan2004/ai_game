import 'dart:math';

import 'package:ai_game/logic/customers.dart';
import 'package:ai_game/logic/delivery.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final data = loadTestData();
  final e = data.economy;
  final owned = {
    ...e.unlockedFlowers,
    ...e.unlockedPapers,
    ...e.unlockedRibbons,
  };

  test('walk-ins skip a sold-out species and stay within the shelf', () {
    const shelf = {'rose': 2, 'daisy': 0, 'baby': 1};
    for (var seed = 0; seed < 40; seed++) {
      final r = requestForShelf(
        e,
        owned: owned,
        shelf: shelf,
        rng: Random(seed),
      );
      expect(r, isNotNull);
      expect(r!.stems.keys, {'rose'});
      expect(r.total, inInclusiveRange(1, 2));
      if (r.fillerId != null) {
        expect(r.fillerId, 'baby');
        expect(r.fillerCount, inInclusiveRange(1, 1));
      }
      for (final need in stemNeeds(r).entries) {
        expect(need.value, lessThanOrEqualTo(shelf[need.key]!));
      }
    }
  });

  test('walk-ins arrive early and keep a steady gap', () {
    final e = loadTestData().economy;
    // 4-star day 1 is 20 guests over 240s: about 12s between entrances.
    final times = scheduleArrivals(e, 20, Random(3));
    expect(times, hasLength(20));
    expect(times.first, lessThan(8));
    final gaps = [
      for (var i = 1; i < times.length; i++) times[i] - times[i - 1],
    ];
    final average = gaps.reduce((a, b) => a + b) / gaps.length;
    expect(average, closeTo(e.dayRealSeconds / 20, 1.5));
    // 10:58 in-game is almost 60 real seconds after opening.
    expect(times.first, lessThan(20));
  });

  test('rush hours: 17-18h busier than 12-14h, count unchanged', () {
    final e = loadTestData().economy;
    final perHour = e.dayRealSeconds / (e.closeHour - e.openHour);
    int inHours(List<double> t, int from, int to) => t
        .where(
          (x) =>
              x >= (from - e.openHour) * perHour &&
              x < (to - e.openHour) * perHour,
        )
        .length;
    var evening = 0;
    var lunch = 0;
    for (var seed = 0; seed < 30; seed++) {
      for (final n in [9, 20, 28]) {
        final t = scheduleArrivals(e, n, Random(seed));
        expect(t, hasLength(n));
        expect(t, orderedEquals([...t]..sort()));
        expect(t.first, greaterThanOrEqualTo(0.4));
        expect(t.last, lessThanOrEqualTo(e.dayRealSeconds - 1));
        evening += inHours(t, 17, 19);
        lunch += inHours(t, 12, 14);
      }
    }
    expect(evening, greaterThan(lunch * 2));
  });

  test('arrivalTimeAt follows the hourly weights', () {
    final e = loadTestData().economy;
    final perHour = e.dayRealSeconds / (e.closeHour - e.openHour);
    expect(arrivalTimeAt(e, 0), 0);
    expect(arrivalTimeAt(e, 1), closeTo(e.dayRealSeconds, 1e-9));
    final total = e.arrivalWeightsByHour.values.fold(0.0, (a, b) => a + b);
    final w8 = e.arrivalWeightsByHour[8]!;
    expect(arrivalTimeAt(e, w8 / total), closeTo(perHour, 1e-9));
  });

  test(
    'a new flower is ordered once owned, and any owned filler can be asked',
    () {
      final owned = {'gerbera', 'statice', 'kraft', 'twine'};
      var sawGerbera = false;
      var sawStatice = false;
      for (var seed = 0; seed < 80; seed++) {
        final r = generateRequest(e, owned: owned, rng: Random(seed));
        sawGerbera = sawGerbera || r.stems.containsKey('gerbera');
        sawStatice = sawStatice || r.fillerId == 'statice';
        expect(r.fillerId, anyOf(isNull, 'statice'));
      }
      expect(sawGerbera, isTrue);
      expect(sawStatice, isTrue);
    },
  );

  test('a shelf with only filler does not spawn a request', () {
    expect(
      requestForShelf(e, owned: owned, shelf: {'baby': 8}, rng: Random(1)),
      isNull,
    );
    expect(requestForShelf(e, owned: owned, shelf: {}, rng: Random(1)), isNull);
  });

  test('an empty shelf drops the scheduled visit', () {
    final s = newSession();
    s.buyAndGoToShop();
    s.openShop();
    s.state.stock.clear();
    s.state.pendingArrivals
      ..clear()
      ..add(0);
    s.tick(0.05);
    expect(s.queue, isEmpty);
    expect(s.state.pendingArrivals, isEmpty);
  });

  test('a walk-in can be filled from what is left on the shelf', () {
    final s = newSession(seed: 4);
    s.buyAndGoToShop();
    s.openShop();
    s.state.stock
      ..clear()
      ..add(StockBatch(flowerId: 'daisy', count: 2, freshnessLeft: 3));
    s.state.pendingArrivals
      ..clear()
      ..add(0);
    s.tick(0.05);
    final c = s.queue.single;
    for (final need in stemNeeds(c.request).entries) {
      expect(need.key, isNot('rose'));
      expect(s.stockAvailable(need.key), greaterThanOrEqualTo(need.value));
    }
    s.openTable();
    expect(s.cannotFillCustomer, isFalse);
  });
}
