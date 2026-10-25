import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// A day ended on the summary with only [batches] in stock.
ShopSession _summary(List<StockBatch> batches, {bool unlocked = true}) {
  final s = newSession();
  stockAndOpen(s);
  s.state.pendingArrivals.clear();
  s.closeEarly();
  s.state.stock
    ..clear()
    ..addAll(batches);
  s.state.dryingUnlocked = unlocked;
  return s;
}

void main() {
  test('unlock waits for unlock.day and costs unlock.unlockCost', () {
    final s = newSession();
    final d = s.data.wilting.drying;
    s.state.day = d.unlockDay - 1;
    expect(unlockDrying(s), isFalse);
    s.state.day = d.unlockDay;
    s.state.money = d.unlockCost - 1;
    expect(unlockDrying(s), isFalse);
    expect(s.state.dryingUnlocked, isFalse);
    s.state.money = d.unlockCost;
    expect(unlockDrying(s), isTrue);
    expect(s.state.money, 0);
    expect(s.state.dryingUnlocked, isTrue);
    expect(unlockDrying(s), isFalse);
  });

  test('candidates: last fresh day, dryable from the block only', () {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1),
      StockBatch(flowerId: 'rose', count: 3, freshnessLeft: 2),
      StockBatch(flowerId: 'hydrangea', count: 2, freshnessLeft: 1),
      StockBatch(flowerId: 'peony', count: 2, freshnessLeft: 1),
    ]);
    expect(dryCandidates(s), {'rose': 4, 'hydrangea': 2});
    expect(dryCandidates(_summary(const [], unlocked: false)), isEmpty);
  });

  test('drying: fee, floor yield, rack days, then the shelf', () {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 5, freshnessLeft: 1),
    ]);
    final d = s.data.wilting.drying;
    final rose = d.byId('rose')!;
    final money = s.state.money;
    s.state.metrics
      ..wiltedByFlower = {'rose': 5}
      ..stemsWilted = 5;
    expect(sendToDry(s, {'rose': 5}), isTrue);
    final out = (5 * rose.conversionRatio).floor();
    expect(s.state.money, money - 5 * d.dryingCostPerStem);
    expect(s.stockCount('rose'), 0);
    expect(s.state.drying.single.stems, out);
    expect(s.state.metrics.driedSent, 5);
    expect(s.state.metrics.stemsWilted, 0);
    for (var i = 0; i < d.dryingDays; i++) {
      expect(s.state.driedStock, isEmpty);
      s.startNextDay();
      if (i < d.dryingDays - 1) {
        stockAndOpen(s);
        s.state.pendingArrivals.clear();
        s.state.earlyClosesInARow = 0;
        s.closeEarly();
      }
    }
    expect(s.state.drying, isEmpty);
    expect(s.state.driedStock, {'rose': out});
  });

  test('storage cap counts rack + shelf', () {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 10, freshnessLeft: 1),
    ]);
    final d = s.data.wilting.drying;
    s.state.driedStock['daisy'] = d.storageCap - 1;
    expect(sendToDry(s, {'rose': 10}), isFalse);
    expect(s.stockCount('rose'), 10);
    s.state.driedStock['daisy'] = d.storageCap - dryYield(s, 'rose', 10);
    expect(sendToDry(s, {'rose': 10}), isTrue);
    expect(driedStorageUsed(s), d.storageCap);
  });

  test('picks above the candidates are refused', () {
    final s = _summary([
      StockBatch(flowerId: 'rose', count: 2, freshnessLeft: 1),
    ]);
    expect(sendToDry(s, {'rose': 3}), isFalse);
    expect(sendToDry(s, {'peony': 1}), isFalse);
  });

  test('shelf buyers sell single dried stems at driedSellPrice', () {
    var sawSale = false;
    for (var seed = 1; seed <= 20; seed++) {
      final s = newSession(seed: seed);
      stockAndOpen(s);
      s.state.pendingArrivals.clear();
      s.state.dryingUnlocked = true;
      s.state.driedStock['sunflower'] = 6;
      final d = s.data.wilting.drying;
      final money = s.state.money;
      while (s.state.elapsed < s.e.dayRealSeconds - 0.5) {
        s.state.elapsed += 1;
        tickDriedShelf(s);
      }
      final m = s.state.metrics;
      final price = d.byId('sunflower')!.driedSellPrice;
      expect(m.driedIncome, m.driedStemsSold * price);
      expect(s.state.money - money, m.driedIncome);
      expect(s.state.driedStock['sunflower'] ?? 0, 6 - m.driedStemsSold);
      if (m.driedStemsSold > 0) sawSale = true;
    }
    expect(sawSale, isTrue);
  });

  test('rack and shelf survive the save', () {
    final g = newSession().state
      ..dryingUnlocked = true
      ..drying = [DryingBatch(flowerId: 'rose', stems: 2, daysLeft: 1)]
      ..driedStock = {'baby': 3};
    final back = GameState.decode(g.encode())!;
    expect(back.dryingUnlocked, isTrue);
    expect(back.drying.single.toJson(), g.drying.single.toJson());
    expect(back.driedStock, {'baby': 3});
  });
}
