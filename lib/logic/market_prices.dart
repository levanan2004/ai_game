// Giá chợ dao động (market.dailyFluctuation): each morning every flower has
// its own price factor from hash(saveSeed, day, flower id), so a reload shows
// the same prices. Paper, ribbon and delivery fee never move.

import '../data/economy.dart';
import 'stable_hash.dart';

/// The day's market factor for [flowerId]: `1 + range × u`, u in [-1, 1]
/// from FNV-1a of (saveSeed, day, flower), rounded to `step`. 1 when the
/// fluctuation is off.
double dailyPriceFactor(Economy e, int saveSeed, int day, String flowerId) {
  final f = e.dailyFluctuation;
  if (!f.active) return 1;
  final h = fnv1a32('$saveSeed|$day|$flowerId');
  final u = h / 0xffffffff * 2 - 1;
  var x = 1 + f.range * u;
  if (f.step > 0) x = (x / f.step).round() * f.step;
  x = x.clamp(1 - f.range, 1 + f.range);
  // 0.95 stays 0.95, not 0.9500000000000001.
  return (x * 100).round() / 100;
}

/// Bundle price of [f] on [day] for this save: daily factor × holiday ramp.
int marketBundlePrice(Economy e, FlowerDef f, int day, int saveSeed) =>
    e.bundlePrice(f, day, daily: dailyPriceFactor(e, saveSeed, day, f.id));

enum PriceTrend { up, down, same }

/// Today's bundle price against yesterday's ([percent] is whole %, at least
/// 1 when the price moved).
class PriceChange {
  const PriceChange(this.trend, this.percent);

  final PriceTrend trend;
  final int percent;

  @override
  bool operator ==(Object other) =>
      other is PriceChange && other.trend == trend && other.percent == percent;

  @override
  int get hashCode => Object.hash(trend, percent);

  @override
  String toString() => 'PriceChange($trend, $percent%)';
}

/// [f]'s market price on [day] vs [day] - 1 for this save. Null on day 1
/// (nothing to compare: "Mới mở chợ").
PriceChange? priceChangeFromYesterday(
  Economy e,
  FlowerDef f,
  int day,
  int saveSeed,
) {
  if (day <= 1) return null;
  final today = marketBundlePrice(e, f, day, saveSeed);
  final before = marketBundlePrice(e, f, day - 1, saveSeed);
  if (today == before || before <= 0)
    return const PriceChange(PriceTrend.same, 0);
  final pct = ((today - before).abs() * 100 / before).round();
  return PriceChange(
    today > before ? PriceTrend.up : PriceTrend.down,
    pct < 1 ? 1 : pct,
  );
}
