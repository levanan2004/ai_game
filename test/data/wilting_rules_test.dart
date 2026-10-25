import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/wilting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final raw =
      jsonDecode(File(WiltingRules.asset).readAsStringSync())
          as Map<String, dynamic>;
  final data = loadTestData();
  final w = data.wilting;

  test('clearance numbers are read from the block', () {
    final j = raw['clearanceSale'] as Map<String, dynamic>;
    final c = w.clearance;
    expect(c.enabled, j['enabled']);
    expect(c.freshnessThreshold, j['freshnessThreshold']);
    expect(c.startHour, j['startHour']);
    expect(c.discountPercent, j['discountPercent']);
    expect(c.minDiscountPercentGuard, j['minDiscountPercentGuard']);
    expect(c.buyersPerDay, j['demand']['buyersPerDay']);
    expect(c.stemsPerBuyer, j['demand']['stemsPerBuyer']);
    expect(c.maxStemsSoldPerDay, j['demand']['maxStemsSoldPerDay']);
    expect(c.summaryLabel, j['summaryLabelVi']);
  });

  test('dried numbers are read from the block, hydrangea included', () {
    final j = raw['driedFlowers'] as Map<String, dynamic>;
    final d = w.drying;
    expect(d.unlockDay, j['unlock']['day']);
    expect(d.unlockCost, j['unlock']['unlockCost']);
    expect(d.dryingDays, j['dryingDays']);
    expect(d.dryingCostPerStem, j['dryingCostPerStem']);
    expect(d.storageCap, j['storageCap']);
    expect(d.shelfBuyersPerDay, j['shelfSales']['buyersPerDay']);
    expect(d.shelfStemsPerBuyer, j['shelfSales']['stemsPerBuyer']);
    final list = (j['flowers'] as List).cast<Map<String, dynamic>>();
    expect(d.flowers.map((f) => f.id), list.map((f) => f['id']));
    for (final f in list) {
      expect(d.byId(f['id'])!.driedSellPrice, f['driedSellPrice']);
      expect(d.byId(f['id'])!.conversionRatio, f['conversionRatio']);
    }
    expect(d.canDry('hydrangea'), isTrue);
    expect(d.canDry('peony'), isFalse);
  });

  test('golden rule: recovery per stem stays below buyPrice', () {
    final e = data.economy;
    for (final f in w.drying.flowers) {
      final flower = e.flowers.firstWhere((x) => x.id == f.id);
      final back =
          f.conversionRatio * f.driedSellPrice - w.drying.dryingCostPerStem;
      expect(back, lessThan(flower.buyPrice), reason: f.id);
    }
    for (final flower in e.flowers) {
      expect(
        w.clearance.priceFor(flower.sellPrice),
        lessThan(flower.buyPrice),
        reason: flower.id,
      );
    }
  });

  test('discount never goes below the guard; price rounds down to 1000', () {
    final c = ClearanceRules.fromJson({
      'discountPercent': 0.3,
      'minDiscountPercentGuard': 0.45,
    });
    expect(c.discount, 0.45);
    expect(c.priceFor(8000), 4000);
    expect(w.clearance.priceFor(3000), 1000);
  });

  test('missing block leaves the feature off', () {
    expect(WiltingRules.parse(null).clearance.enabled, isFalse);
    expect(WiltingRules.parse(null).drying.flowers, isEmpty);
  });
}
