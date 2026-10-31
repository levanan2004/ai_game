// Thời tiết (Hà Phương thoi_tiet_block.json, Nhất thoi_tiet_strings.json,
// Phú spec_phu_and_notes.md). Every number comes from the block; every word
// from the strings file.
import 'dart:convert';

import '../logic/stable_hash.dart';

/// One weather type of `weather.types[]`.
class WeatherType {
  const WeatherType({
    required this.id,
    required this.weight,
    required this.nameKey,
    required this.descKey,
    required this.overlay,
    required this.multipliers,
    required this.boostFlowers,
    required this.speciesWeight,
  });

  /// The id with no overlay, no pill, no banner (Phú addendum).
  static const normalId = 'binh_thuong';

  final String id;
  final double weight;
  final String nameKey;
  final String descKey;
  final String? overlay;

  /// customerArrival, wiltSpeed, marketPrice, tip (raw, before the clamp).
  final Map<String, double> multipliers;
  final List<String> boostFlowers;
  final double speciesWeight;

  bool get isNormal => id == normalId;

  factory WeatherType.fromJson(Map<String, dynamic> j) {
    final m = (j['multipliers'] as Map?) ?? const {};
    final d = (j['demandBoost'] as Map?) ?? const {};
    return WeatherType(
      id: j['id'] as String,
      weight: (j['weight'] as num).toDouble(),
      nameKey: j['nameKey'] as String? ?? 'weather_${j['id']}_name',
      descKey: j['descKey'] as String? ?? 'weather_${j['id']}_desc',
      overlay: j['overlay'] as String?,
      multipliers: {
        for (final e in m.entries) '${e.key}': (e.value as num).toDouble(),
      },
      boostFlowers: [for (final f in (d['flowers'] as List?) ?? const []) '$f'],
      speciesWeight: (d['occasionSpeciesWeight'] as num?)?.toDouble() ?? 1,
    );
  }
}

/// `hienThi` of the block: banner and customer-line rules.
class WeatherDisplay {
  const WeatherDisplay({
    this.bannerPerDay = 0,
    this.bannerSeconds = 0,
    this.hideOnNormal = true,
    this.lineChance = 0,
    this.lineMaxPerDay = 0,
    this.lineNotConsecutive = true,
  });

  final int bannerPerDay;
  final double bannerSeconds;
  final bool hideOnNormal;
  final double lineChance;
  final int lineMaxPerDay;
  final bool lineNotConsecutive;

  factory WeatherDisplay.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const WeatherDisplay();
    return WeatherDisplay(
      bannerPerDay: (j['bannerMoiNgay'] as num?)?.toInt() ?? 0,
      bannerSeconds: (j['bannerAnSauGiay'] as num?)?.toDouble() ?? 0,
      hideOnNormal: j['anKhiBinhThuong'] != false,
      lineChance: (j['cauKhachTiLe'] as num?)?.toDouble() ?? 0,
      lineMaxPerDay: (j['cauKhachToiDaMoiNgay'] as num?)?.toInt() ?? 0,
      lineNotConsecutive: j['cauKhachKhongLienTiep'] != false,
    );
  }
}

/// Multiplier keys of the block.
abstract final class WeatherFactor {
  static const customer = 'customerArrival';
  static const wilt = 'wiltSpeed';
  static const market = 'marketPrice';
  static const tip = 'tip';
}

class WeatherRules {
  const WeatherRules({
    required this.enabled,
    required this.types,
    required this.clampMin,
    required this.clampMax,
    required this.display,
    required this.text,
  });

  static const asset = 'assets/data/thoi_tiet_block.json';
  static const textAsset = 'assets/data/thoi_tiet_strings.json';

  static const empty = WeatherRules(
    enabled: false,
    types: [],
    clampMin: 1,
    clampMax: 1,
    display: WeatherDisplay(),
    text: {},
  );

  final bool enabled;
  final List<WeatherType> types;
  final double clampMin;
  final double clampMax;
  final WeatherDisplay display;
  final Map<String, String> text;

  bool get active => enabled && types.isNotEmpty;

  static WeatherRules parse(String? block, {String? text}) {
    if (block == null) return empty;
    final root = jsonDecode(block) as Map<String, dynamic>;
    final w = root['weather'] as Map<String, dynamic>?;
    if (w == null) return empty;
    final clamp = (w['effectClamp'] as Map?) ?? const {};
    final words = <String, String>{};
    if (text != null) {
      final t = jsonDecode(text) as Map<String, dynamic>;
      for (final e in t.entries) {
        if (e.value is String && !e.key.startsWith('_')) {
          words[e.key] = e.value as String;
        }
      }
    }
    return WeatherRules(
      enabled: w['enabled'] != false,
      types: [
        for (final t in (w['types'] as List?) ?? const [])
          WeatherType.fromJson(t as Map<String, dynamic>),
      ],
      clampMin: (clamp['min'] as num?)?.toDouble() ?? 1,
      clampMax: (clamp['max'] as num?)?.toDouble() ?? 1,
      display: WeatherDisplay.fromJson(
        root['hienThi'] as Map<String, dynamic>?,
      ),
      text: words,
    );
  }

  /// Uniform in [0, 1) from hash(seed, gameDay, 'weather'): same save and
  /// day always give the same value, so a reload never re-rolls.
  static double roll(int seed, int day, [String salt = 'weather']) =>
      fnv1a32('$seed|$day|$salt') / 4294967296.0;

  /// `pick`: walk `types[]` in order with cumulative weights.
  WeatherType? pick(int seed, int day) {
    if (!active) return null;
    final total = types.fold<double>(0, (a, t) => a + t.weight);
    if (total <= 0) return null;
    final u = roll(seed, day) * total;
    var acc = 0.0;
    for (final t in types) {
      acc += t.weight;
      if (u < acc) return t;
    }
    return types.last;
  }

  /// The type's [key] multiplier inside `effectClamp`; 1 when [t] is null.
  double factor(WeatherType? t, String key) {
    if (t == null) return 1;
    final v = t.multipliers[key] ?? 1;
    return v.clamp(clampMin, clampMax).toDouble();
  }

  /// [key] with each `{slot}` replaced; '' when missing.
  String t(String key, [Map<String, Object> vars = const {}]) {
    var s = text[key] ?? '';
    for (final v in vars.entries) {
      s = s.replaceAll('{${v.key}}', '${v.value}');
    }
    return s;
  }
}
