// Thời tiết in play: the day's tallies for the end-of-day lines, the effect
// words, the customer line and the night wilt (thoi_tiet_block `apply`).
import 'dart:math';

import '../data/weather.dart';
import 'price_format.dart';

/// What the weather did today ({soKhach}, {xu}, {soCanh}). Mid-day state is
/// never saved, like DayMetrics' replay rule: a reload replays the morning.
class WeatherDay {
  /// Customers who came in today (walk-ins and regulars).
  int customers = 0;

  /// Tip xu earned on top of what the same bouquets pay without weather.
  int tipExtra = 0;

  /// Stems of today's favoured flowers sold.
  int demandSold = 0;

  /// Weather lines said today, and whether the last customer said one.
  int linesShown = 0;
  bool lastHadLine = false;

  /// The day's banner has shown (`bannerMoiNgay`).
  int bannersShown = 0;
}

/// Tonight's freshness change (`apply.wiltSpeed`).
class NightWilt {
  const NightWilt({this.extra = 0, this.skip = false, this.debt = 0});

  /// Extra freshness points every batch loses tonight.
  final int extra;

  /// Wilt below 1: no batch loses a point tonight.
  final bool skip;

  /// freshnessDebt to carry to tomorrow.
  final double debt;
}

/// Above 1 the fraction piles into [debt]; a whole point costs one more
/// freshness. Below 1 a (1 − wilt) chance, rolled from (seed, day), spares
/// the night. Same inputs, same answer, so the summary can predict it.
NightWilt nightWilt(double wilt, double debt, int seed, int day) {
  if (wilt > 1) {
    final d = ((debt + wilt - 1) * 1e6).round() / 1e6;
    final whole = d.floor();
    return NightWilt(extra: whole, debt: d - whole);
  }
  if (wilt < 1) {
    final skip = WeatherRules.roll(seed, day, 'weatherFresh') < 1 - wilt;
    return NightWilt(skip: skip, debt: debt);
  }
  return NightWilt(debt: debt);
}

/// `{phanTram}`: |factor − 1| × 100, rounded.
int weatherPercent(double factor) => ((factor - 1).abs() * 100).round();

/// Favoured flowers the player can sell, by Vietnamese name.
List<String> favouredNames(
  WeatherType t,
  Set<String> owned,
  String Function(String id) name,
) => [
  for (final id in t.boostFlowers)
    if (owned.contains(id)) name(id),
];

/// Effect lines for [t] (weather_effect_*), one per factor that moves, then
/// the demand line. binh_thuong: weather_binh_thuong_effect.
List<(String text, String tooltipKey)> weatherEffectLines(
  WeatherRules r,
  WeatherType t,
  Set<String> owned,
  String Function(String id) name,
) {
  if (t.isNormal) {
    return [(r.t('weather_binh_thuong_effect'), 'weather_tooltip_pill')];
  }
  final out = <(String, String)>[];
  void add(String factorKey, String stem, String tip) {
    final f = r.factor(t, factorKey);
    final p = weatherPercent(f);
    if (p == 0) return;
    final up = f > 1;
    final key = switch (stem) {
      'wilt' => up ? 'weather_effect_wilt_up' : 'weather_effect_wilt_down',
      _ => 'weather_effect_${stem}_${up ? 'up' : 'down'}',
    };
    out.add((r.t(key, {'phanTram': p}), tip));
  }

  add(WeatherFactor.customer, 'customer', 'weather_tooltip_customer');
  add(WeatherFactor.wilt, 'wilt', 'weather_tooltip_wilt');
  add(WeatherFactor.market, 'market', 'weather_tooltip_market');
  add(WeatherFactor.tip, 'tip', 'weather_tooltip_tip');
  final names = favouredNames(t, owned, name);
  if (names.isNotEmpty) {
    out.add((
      r.t('weather_effect_demand', {'hoaChuong': names.join(', ')}),
      'weather_tooltip_demand',
    ));
  }
  return out;
}

/// `{anhHuong}`: the effect lines joined by weather_effect_join.
String weatherEffectText(
  WeatherRules r,
  WeatherType t,
  Set<String> owned,
  String Function(String id) name,
) => [
  for (final l in weatherEffectLines(r, t, owned, name)) l.$1,
].join(r.t('weather_effect_join'));

/// End-of-day lines (weather_summary_*), numbers with thousands dots.
List<String> weatherSummaryLines(
  WeatherRules r,
  WeatherType t,
  WeatherDay d, {
  required NightWilt night,
  required int stemsInStock,
  required Set<String> owned,
  required String Function(String id) name,
}) {
  final tenThoiTiet = r.t(t.nameKey);
  if (t.isNormal) {
    return [
      r.t('weather_summary_line', {
        'tenThoiTiet': tenThoiTiet,
        'soKhach': coinFull(d.customers),
      }),
      r.t('weather_summary_binh_thuong'),
    ];
  }
  final out = [
    r.t('weather_summary_line', {
      'tenThoiTiet': tenThoiTiet,
      'soKhach': coinFull(d.customers),
    }),
  ];
  if (d.tipExtra > 0) {
    out.add(r.t('weather_summary_tip', {'xu': coinFull(d.tipExtra)}));
  }
  if (night.extra > 0 && stemsInStock > 0) {
    out.add(r.t('weather_summary_wilt', {'soCanh': coinFull(stemsInStock)}));
  } else if (night.skip && stemsInStock > 0) {
    out.add(r.t('weather_summary_fresh', {'soCanh': coinFull(stemsInStock)}));
  }
  final names = favouredNames(t, owned, name);
  if (d.demandSold > 0 && names.isNotEmpty) {
    out.add(
      r.t('weather_summary_demand', {
        'soCanh': coinFull(d.demandSold),
        'hoaChuong': names.join(', '),
      }),
    );
  }
  return out;
}

/// A walk-in's weather line (`hienThi.cauKhach*`), or null. Asking for a
/// favoured flower says weather_customer_demand; otherwise one of the
/// type's own lines. Updates [d]'s counters either way.
String? pickWeatherLine(
  WeatherRules r,
  WeatherType? t,
  WeatherDay d,
  Random rng, {
  required Iterable<String> requested,
  required String Function(String id) name,
}) {
  final h = r.display;
  if (t == null || t.isNormal) {
    d.lastHadLine = false;
    return null;
  }
  final blocked =
      d.linesShown >= h.lineMaxPerDay ||
      (h.lineNotConsecutive && d.lastHadLine);
  if (blocked || rng.nextDouble() >= h.lineChance) {
    d.lastHadLine = false;
    return null;
  }
  String? line;
  final wanted = [
    for (final id in requested)
      if (t.boostFlowers.contains(id)) id,
  ];
  if (wanted.isNotEmpty) {
    line = r.t('weather_customer_demand', {'tenHoa': name(wanted.first)});
  } else {
    final own = [
      for (var i = 1; r.text.containsKey('weather_customer_${t.id}_$i'); i++)
        r.t('weather_customer_${t.id}_$i'),
    ];
    if (own.isNotEmpty) line = own[rng.nextInt(own.length)];
  }
  if (line == null || line.isEmpty) {
    d.lastHadLine = false;
    return null;
  }
  d.linesShown++;
  d.lastHadLine = true;
  return line;
}
