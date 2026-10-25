import 'package:ai_game/logic/goals.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Open shop, no walk-ins, stock = [batches] only.
ShopSession _open(List<StockBatch> batches, {int seed = 1}) {
  final s = newSession(seed: seed);
  stockAndOpen(s);
  s.state.pendingArrivals.clear();
  s.state.stock
    ..clear()
    ..addAll(batches);
  return s;
}

double _hour(ShopSession s, int h) => (h - s.e.openHour) * s.e.secondsPerHour;

/// Runs the clearance clock to closing time in 1 s steps.
void _runToClose(ShopSession s) {
  while (s.state.elapsed < s.e.dayRealSeconds - 0.5) {
    s.state.elapsed += 1;
    tickClearance(s);
  }
}

void main() {
  test('basket = stems on the last fresh day only, from startHour', () {
    final s = _open([
      StockBatch(flowerId: 'rose', count: 5, freshnessLeft: 1),
      StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 3),
    ]);
    final c = s.data.wilting.clearance;
    expect(clearanceBasket(s), {'rose': 5});
    s.state.elapsed = _hour(s, c.startHour) - 1;
    expect(clearanceHours(s), isFalse);
    s.state.elapsed = _hour(s, c.startHour);
    expect(clearanceHours(s), isTrue);
    expect(
      clearancePrice(s, 'rose'),
      (s.e.flower('rose').sellPrice * (1 - c.discountPercent) / 1000).floor() *
          1000,
    );
  });

  test('buyers sell basket stems at the basket price, capped per day', () {
    var sawSale = false;
    for (var seed = 1; seed <= 20; seed++) {
      final s = _open([
        StockBatch(flowerId: 'rose', count: 30, freshnessLeft: 1),
        StockBatch(flowerId: 'daisy', count: 6, freshnessLeft: 2),
      ], seed: seed);
      final c = s.data.wilting.clearance;
      final money = s.state.money;
      s.state.elapsed = _hour(s, c.startHour) - 1;
      _runToClose(s);
      final m = s.state.metrics;
      expect(m.clearanceStems, lessThanOrEqualTo(c.maxStemsSoldPerDay));
      expect(m.clearanceIncome, m.clearanceStems * clearancePrice(s, 'rose'));
      expect(s.state.money - money, m.clearanceIncome);
      expect(s.stockCount('rose'), 30 - m.clearanceStems);
      expect(s.stockCount('daisy'), 6);
      if (m.clearanceStems > 0) sawSale = true;
    }
    expect(sawSale, isTrue);
  });

  test('an empty basket rolls no buyers', () {
    final s = _open([StockBatch(flowerId: 'rose', count: 5, freshnessLeft: 3)]);
    s.state.elapsed = _hour(s, s.data.wilting.clearance.startHour) - 1;
    _runToClose(s);
    expect(s.state.metrics.clearanceStems, 0);
  });

  test('clearance money counts in the day income', () {
    final m = DayMetrics()..clearanceIncome = 4000;
    expect(m.income, 4000);
    expect(DayMetrics.fromJson(m.toJson()).clearanceIncome, 4000);
  });
}
