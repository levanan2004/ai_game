import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_game/data/game_data.dart';
import 'package:ai_game/data/weather.dart';
import 'package:ai_game/logic/market_prices.dart';
import 'package:ai_game/logic/weather.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _blockText = File(WeatherRules.asset).readAsStringSync();
final _wordsText = File(WeatherRules.textAsset).readAsStringSync();
final _block = jsonDecode(_blockText) as Map<String, dynamic>;
final _words = jsonDecode(_wordsText) as Map<String, dynamic>;
final rules = WeatherRules.parse(_blockText, text: _wordsText);

GameData weatherData() {
  final d = loadTestData();
  return GameData(
    economy: d.economy,
    reviews: d.reviews,
    orders: d.orders,
    cosmetics: d.cosmetics,
    words: d.words,
    skinCatalog: d.skinCatalog,
    shareText: d.shareText,
    regularsCatalog: d.regularsCatalog,
    wiltingRules: d.wiltingRules,
    seasonPassText: d.seasonPassText,
    weatherRules: rules,
  );
}

String name(String id) => 'N:$id';

void main() {
  final types = (_block['weather']['types'] as List).cast<Map>();
  final hien = _block['hienThi'] as Map;

  test('block parses every type and the hienThi rules', () {
    expect(rules.active, isTrue);
    expect(rules.types.map((t) => t.id), [for (final t in types) t['id']]);
    expect(rules.display.bannerPerDay, hien['bannerMoiNgay']);
    expect(rules.display.bannerSeconds, hien['bannerAnSauGiay']);
    expect(rules.display.lineChance, hien['cauKhachTiLe']);
    expect(rules.display.lineMaxPerDay, hien['cauKhachToiDaMoiNgay']);
    expect(rules.display.lineNotConsecutive, hien['cauKhachKhongLienTiep']);
    expect(rules.display.hideOnNormal, hien['anKhiBinhThuong']);
  });

  test('every weather key Nhất delivered is present; each type has words', () {
    final keys = RegExp(r'^- `(weather_[a-z_0-9]+)`', multiLine: true)
        .allMatches(
          File('test/fixtures/thoi_tiet_keys.txt').existsSync()
              ? File('test/fixtures/thoi_tiet_keys.txt').readAsStringSync()
              : '',
        )
        .map((m) => m.group(1)!);
    for (final k in keys) {
      expect(rules.text[k], isNotNull, reason: k);
    }
    for (final t in rules.types) {
      expect(rules.t(t.nameKey), isNotEmpty, reason: t.nameKey);
      expect(rules.t(t.descKey), isNotEmpty, reason: t.descKey);
      if (!t.isNormal) {
        expect(rules.t('weather_banner_${t.id}'), isNotEmpty);
        expect(rules.t('weather_customer_${t.id}_1'), isNotEmpty);
      }
    }
    expect(
      rules.text.length,
      _words.keys.where((k) => !k.startsWith('_')).length,
    );
  });

  test('roll is fixed per (seed, day) and follows the weights', () {
    expect(rules.pick(7, 3)!.id, rules.pick(7, 3)!.id);
    final count = <String, int>{};
    const n = 40000;
    for (var d = 1; d <= n; d++) {
      final id = rules.pick(12345, d)!.id;
      count[id] = (count[id] ?? 0) + 1;
    }
    final total = types.fold<double>(0, (a, t) => a + (t['weight'] as num));
    for (final t in types) {
      final want = (t['weight'] as num) / total;
      expect(count[t['id']]! / n, closeTo(want, 0.015), reason: '${t['id']}');
    }
  });

  test('factors stay inside effectClamp', () {
    final c = _block['weather']['effectClamp'] as Map;
    for (final t in rules.types) {
      for (final k in t.multipliers.keys) {
        final f = rules.factor(t, k);
        expect(f, inInclusiveRange(c['min'], c['max']));
      }
    }
    expect(rules.factor(null, WeatherFactor.tip), 1);
  });

  test('effect lines: one per moving factor, demand only for owned', () {
    for (final t in rules.types.where((t) => !t.isNormal)) {
      final owned = t.boostFlowers.take(1).toSet();
      final lines = weatherEffectLines(rules, t, owned, name);
      final moving = [
        WeatherFactor.customer,
        WeatherFactor.wilt,
        WeatherFactor.market,
        WeatherFactor.tip,
      ].where((k) => weatherPercent(rules.factor(t, k)) != 0).length;
      expect(lines.length, moving + (owned.isEmpty ? 0 : 1));
      for (final (text, tip) in lines) {
        expect(text, isNot(contains('{')));
        expect(rules.t(tip), isNotEmpty);
      }
      if (owned.isNotEmpty) {
        expect(lines.last.$1, contains(name(owned.first)));
      }
      expect(
        weatherEffectLines(rules, t, {}, name).length,
        moving,
        reason: 'no demand line without the flower',
      );
    }
    final normal = rules.types.firstWhere((t) => t.isNormal);
    expect(
      weatherEffectText(rules, normal, {}, name),
      rules.t('weather_binh_thuong_effect'),
    );
  });

  test('night wilt: fraction piles up, below 1 can spare the night', () {
    var debt = 0.0;
    var extra = 0;
    const w = 1.2;
    for (var d = 1; d <= 5; d++) {
      final n = nightWilt(w, debt, 1, d);
      debt = n.debt;
      extra += n.extra;
    }
    expect(extra, 1);
    expect(debt, closeTo(0, 1e-6));
    var spared = 0;
    for (var d = 1; d <= 4000; d++) {
      if (nightWilt(0.9, 0, 3, d).skip) spared++;
    }
    expect(spared / 4000, closeTo(0.1, 0.02));
    expect(nightWilt(0.9, 0, 3, 8).skip, nightWilt(0.9, 0, 3, 8).skip);
  });

  test('customer lines: max per day, never two in a row, none on normal', () {
    final rainy = rules.types.firstWhere((t) => !t.isNormal);
    final normal = rules.types.firstWhere((t) => t.isNormal);
    final rng = Random(5);
    final day = WeatherDay();
    var prev = false;
    var said = 0;
    for (var i = 0; i < 300; i++) {
      final l = pickWeatherLine(
        rules,
        rainy,
        day,
        rng,
        requested: const ['zzz'],
        name: name,
      );
      if (l != null) {
        said++;
        expect(prev, isFalse);
        expect(l, isNotEmpty);
      }
      prev = l != null;
    }
    expect(said, rules.display.lineMaxPerDay);
    final d2 = WeatherDay();
    for (var i = 0; i < 100; i++) {
      expect(
        pickWeatherLine(
          rules,
          normal,
          d2,
          rng,
          requested: const [],
          name: name,
        ),
        isNull,
      );
    }
  });

  test('a favoured flower request says weather_customer_demand', () {
    final t = rules.types.firstWhere((t) => t.boostFlowers.isNotEmpty);
    final d = WeatherDay();
    String? l;
    final rng = Random(1);
    while (l == null) {
      d.lastHadLine = false;
      l = pickWeatherLine(
        rules,
        t,
        d,
        rng,
        requested: [t.boostFlowers.first],
        name: name,
      );
    }
    expect(
      l,
      rules.t('weather_customer_demand', {
        'tenHoa': name(t.boostFlowers.first),
      }),
    );
  });

  test('summary fills {soKhach} {xu} {soCanh} with thousand dots', () {
    final t = rules.types.firstWhere(
      (t) => !t.isNormal && t.boostFlowers.isNotEmpty,
    );
    final d = WeatherDay()
      ..customers = 12
      ..tipExtra = 15000
      ..demandSold = 7;
    final lines = weatherSummaryLines(
      rules,
      t,
      d,
      night: const NightWilt(extra: 1),
      stemsInStock: 1200,
      owned: t.boostFlowers.toSet(),
      name: name,
    );
    expect(lines.first, contains('12'));
    expect(lines.any((l) => l.contains('15.000')), isTrue);
    expect(lines.any((l) => l.contains('1.200')), isTrue);
    expect(
      lines.any(
        (l) => l.contains('7') && l.contains(name(t.boostFlowers.first)),
      ),
      isTrue,
    );
    for (final l in lines) {
      expect(l, isNot(contains('{')));
    }
  });

  group('session', () {
    test('market price, customers and tip use today\'s weather', () {
      final s = newSession(data: weatherData(), saveSeed: 77);
      final plain = newSession(saveSeed: 77);
      expect(s.weatherToday!.id, rules.pick(77, s.state.day)!.id);
      final f = s.weatherFactor(WeatherFactor.customer);
      expect(s.expectedCustomers, closeTo(plain.expectedCustomers * f, 1e-9));
      final rose = s.e.flower('rose');
      expect(
        s.bundlePrice(rose),
        marketBundlePrice(
          s.e,
          rose,
          s.state.day,
          77,
          weather: s.weatherFactor(WeatherFactor.market),
        ),
      );
    });

    test('weather is the same after a reload', () {
      final s = newSession(data: weatherData(), saveSeed: 9);
      for (var d = 1; d < 40; d++) {
        s.state.day = d;
        final again = newSession(
          data: weatherData(),
          saved: s.state,
          saveSeed: 1,
        );
        expect(again.weatherToday!.id, s.weatherToday!.id);
      }
    });

    test('without the block nothing changes', () {
      final s = newSession(saveSeed: 9);
      expect(s.weatherToday, isNull);
      expect(s.weatherSummary(), isEmpty);
      expect(s.weatherFactor(WeatherFactor.tip), 1);
    });

    test('freshnessDebt and weatherFxOff are saved', () {
      final s = newSession(data: weatherData());
      s.state.freshnessDebt = 0.45;
      s.state.weatherFxOff = true;
      final back = newSession(data: weatherData(), saved: s.state);
      expect(back.state.freshnessDebt, 0.45);
      expect(back.state.weatherFxOff, isTrue);
    });
  });
}
