import 'package:ai_game/logic/market_prices.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = loadTestData().economy;
  final f = e.dailyFluctuation;

  test('daily factor: steps within ±range, stable, mean about 1', () {
    final steps = <double>{};
    var sum = 0.0;
    var n = 0;
    for (var seed = 1; seed <= 40; seed++) {
      for (var day = 1; day <= 42; day++) {
        for (final fl in e.flowers) {
          final x = dailyPriceFactor(e, seed, day, fl.id);
          expect(x, dailyPriceFactor(e, seed, day, fl.id));
          expect(x, inInclusiveRange(1 - f.range, 1 + f.range + 1e-9));
          final k = x / f.step;
          expect((k - k.round()).abs(), lessThan(1e-6));
          steps.add(x);
          sum += x;
          n++;
        }
      }
    }
    expect(steps, {0.9, 0.95, 1.0, 1.05, 1.1});
    expect(sum / n, closeTo(1, 0.01));
  });

  test('different saves, days and flowers get different prices', () {
    final a = [for (final fl in e.flowers) dailyPriceFactor(e, 1, 5, fl.id)];
    final b = [for (final fl in e.flowers) dailyPriceFactor(e, 2, 5, fl.id)];
    final c = [for (final fl in e.flowers) dailyPriceFactor(e, 1, 6, fl.id)];
    expect(a, isNot(b));
    expect(a, isNot(c));
    expect(a.toSet().length, greaterThan(1));
  });

  test('bundle price = buyPrice × daily × ramp, rounded to 100', () {
    final v = e.holidays.firstWhere((h) => h.id == 'valentine');
    final rose = e.flower('rose');
    final daisy = e.flower('daisy');
    for (var seed = 1; seed < 30; seed++) {
      for (final day in [3, v.days.first - 2, v.days.first]) {
        for (final fl in [rose, daisy]) {
          final d = dailyPriceFactor(e, seed, day, fl.id);
          final ramp = e.holidayPriceFactor(fl, day);
          final stem = ((fl.buyPrice * d * ramp) / 100).round() * 100;
          expect(marketBundlePrice(e, fl, day, seed), stem * fl.bundleSize);
          expect(stem % 100, 0);
        }
      }
    }
    // Daisy is not a Valentine flower: no ramp.
    expect(e.holidayPriceFactor(daisy, v.days.first), 1);
  });

  test('session: same save, same prices after reload; sellPrice fixed', () {
    final s = newSession(saveSeed: 99);
    final rose = s.e.flower('rose');
    final p = s.bundlePrice(rose);
    expect(p, marketBundlePrice(s.e, rose, s.state.day, 99));
    final reloaded = newSession(saved: s.state, saveSeed: 5);
    expect(reloaded.bundlePrice(rose), p);
    expect(rose.sellPrice, e.flower('rose').sellPrice);
  });

  test('% vs yesterday: up, down, same; none on day 1', () {
    final rose = e.flower('rose');
    expect(priceChangeFromYesterday(e, rose, 1, 7), isNull);
    final seen = <PriceTrend>{};
    for (var seed = 1; seed < 20; seed++) {
      for (var day = 2; day < 30; day++) {
        final c = priceChangeFromYesterday(e, rose, day, seed)!;
        final t = marketBundlePrice(e, rose, day, seed);
        final y = marketBundlePrice(e, rose, day - 1, seed);
        seen.add(c.trend);
        if (t == y) {
          expect(c, const PriceChange(PriceTrend.same, 0));
        } else {
          expect(c.trend, t > y ? PriceTrend.up : PriceTrend.down);
          expect(c.percent, ((t - y).abs() * 100 / y).round());
        }
      }
    }
    expect(seen, PriceTrend.values.toSet());
  });

  test('session priceChange matches the helper', () {
    final s = newSession(saveSeed: 31);
    final rose = s.e.flower('rose');
    expect(s.priceChange(rose), isNull);
    s.state.day = 5;
    expect(s.priceChange(rose), priceChangeFromYesterday(e, rose, 5, 31));
  });
}
