import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('new game starts at the market with start cash and no stock', () {
    final s = newSession();
    expect(s.screen, Screen.market);
    expect(s.state.money, s.e.startCash);
    expect(s.state.stock, isEmpty);
    expect(s.state.goals.length, s.e.goalCardsPerDay);
  });

  test('market buys bundles at buyPrice × bundleSize', () {
    final s = newSession();
    final rose = s.e.flower('rose');
    s.addBundle('rose');
    s.addBundle('rose');
    expect(s.cartTotal, 2 * rose.buyPrice * rose.bundleSize);
    s.buyAndGoToShop();
    expect(s.state.money, s.e.startCash - 2 * rose.buyPrice * rose.bundleSize);
    expect(s.stockCount('rose'), 2 * rose.bundleSize);
    expect(s.oldestBatch('rose')!.freshnessLeft, rose.freshnessDays);
    expect(s.screen, Screen.shop);
    expect(s.state.phase, DayPhase.preparing);
  });

  test('safety net: on credit you can buy up to minMarketBudget', () {
    final s = newSession();
    s.state.money = 10000;
    while (s.canAddBundle('rose')) {
      s.addBundle('rose');
    }
    expect(s.cartTotal, lessThanOrEqualTo(s.e.minMarketBudget));
    expect(s.cartTotal + s.bundlePrice(s.e.flower('rose')), greaterThan(s.e.minMarketBudget));
    expect(s.onCredit, isTrue);
    s.buyAndGoToShop();
    expect(s.state.money, lessThan(0));
  });

  test('locked flowers cannot be bought', () {
    final s = newSession();
    expect(s.canAddBundle('tulip'), isFalse);
  });

  test('customer leaves when patience runs out: no popup, review saved', () async {
    final backing = <String, String>{};
    final s = newSession(backing: backing);
    stockAndOpen(s);
    final c = waitForCustomer(s);
    final before = s.state.reviews.length;
    // Only this customer matters; stop new arrivals.
    s.state.pendingArrivals.clear();
    var t = 0.0;
    while (s.queue.contains(c) && t < c.patienceMax + 1) {
      s.tick(0.1);
      t += 0.1;
    }
    expect(s.queue.contains(c), isFalse);
    expect(t, closeTo(c.patienceMax, 0.3));
    expect(s.lastDelivery, isNull);
    expect(s.departures.single.customer, c);
    expect(s.state.reviews.length, before + 1);
    final r = s.state.reviews.last;
    expect(r.outcome, 'leftUnserved');
    expect(r.stars, s.e.reviewStars['leftUnserved']);
    expect(r.stems, isEmpty);
    expect(s.state.metrics.customersLeft, 1);
    await s.pendingSaves;
    final restored = await ProgressStore.memory(backing).load();
    expect(restored!.reviews.last.outcome, 'leftUnserved');
  });

  test('patience keeps ticking at the table, and leaving closes it', () {
    final s = newSession();
    stockAndOpen(s);
    final c = waitForCustomer(s);
    s.state.pendingArrivals.clear();
    s.openTable();
    expect(s.screen, Screen.table);
    s.addStem('rose');
    final stock = s.stockCount('rose');
    for (var i = 0; i < 1000 && s.queue.contains(c); i++) {
      s.tick(0.1);
    }
    expect(s.screen, Screen.shop);
    expect(s.tableCustomer, isNull);
    expect(s.stockCount('rose'), stock + 1, reason: 'stem returned to stock');
  });

  test('queue full -> walkedPast: no review', () {
    final s = newSession();
    stockAndOpen(s);
    final cap = s.effects.counterSlots + s.effects.maxQueue;
    s.state.pendingArrivals = List.filled(cap + 3, 0.0, growable: true);
    s.tick(0.01);
    expect(s.queue.length, cap);
    expect(s.state.reviews, isEmpty);
  });

  test('full delivery: exact bouquet pays price + tips and saves a review', () async {
    final backing = <String, String>{};
    final s = newSession(backing: backing, seed: 5);
    stockAndOpen(s);
    final c = waitForCustomer(s);
    s.openTable();
    final r = c.request;
    for (final e in r.stems.entries) {
      for (var i = 0; i < e.value; i++) {
        expect(s.addStem(e.key), isTrue);
      }
    }
    if (r.fillerId != null) {
      for (var i = 0; i < r.fillerCount; i++) {
        s.addStem(r.fillerId!);
      }
    }
    s.selectPaper(r.paperId);
    s.selectRibbon(r.ribbonId);
    expect(s.draftMatch!.score, 1.0);
    final moneyBefore = s.state.money;
    final zone = s.beginWrap();
    expect(zone, isNotNull);
    // Patience is frozen while wrapping.
    final p = c.patienceLeft;
    s.tick(1);
    expect(c.patienceLeft, p);
    final res = s.finishWrap(hit: true)!;
    expect(res.review.outcome, 'great');
    expect(res.review.stars, s.e.reviewStars['great']);
    expect(res.payment.wrapBonus, greaterThan(0));
    final supplies = s.e.paper(r.paperId).buyPrice + s.e.ribbon(r.ribbonId).buyPrice;
    expect(s.state.money, moneyBefore + res.payment.total - supplies);
    expect(s.lastDelivery, isNotNull);
    expect(s.displayMoney, moneyBefore - supplies);
    expect(s.state.metrics.bouquetsSold, 1);
    expect(s.state.metrics.wrapHits, 1);
    s.closeDeliveryPopup();
    expect(s.displayMoney, s.state.money);
    expect(s.screen, Screen.shop);
    await s.pendingSaves;
    final saved = await ProgressStore.memory(backing).load();
    expect(saved!.reviews.last.customerName, c.name);
    expect(saved.reviews.last.stems, r.stems.map((k, v) => MapEntry(k, v))..addAll({if (r.fillerId != null) r.fillerId!: r.fillerCount}));
  });

  test('day ends after close with an empty queue; summary settles money', () {
    final s = newSession();
    stockAndOpen(s);
    s.state.pendingArrivals.clear();
    final money = s.state.money;
    for (var t = 0.0; t < s.e.dayRealSeconds + 1; t += 0.5) {
      s.tick(0.5);
    }
    expect(s.state.phase, DayPhase.summary);
    expect(s.screen, Screen.summary);
    final m = s.state.metrics;
    expect(m.fixedCosts, s.e.fixedCostsTotal);
    expect(s.state.money, money + m.goalRewards - m.fixedCosts);
  });

  test('next day: freshness ticks, wilted stems are removed', () {
    final s = newSession();
    s.addBundle('daisy'); // freshnessDays 2
    s.buyAndGoToShop();
    s.openShop();
    s.state.pendingArrivals.clear();
    for (var t = 0.0; t < s.e.dayRealSeconds + 1; t += 0.5) {
      s.tick(0.5);
    }
    s.startNextDay();
    expect(s.state.day, 2);
    expect(s.screen, Screen.market);
    expect(s.oldestBatch('daisy')!.freshnessLeft, s.e.flower('daisy').freshnessDays - 1);
    // Day 2 ends: daisies on their last day wilt.
    s.buyAndGoToShop();
    s.openShop();
    s.state.pendingArrivals.clear();
    for (var t = 0.0; t < s.e.dayRealSeconds + 1; t += 0.5) {
      s.tick(0.5);
    }
    expect(s.state.metrics.stemsWilted, s.e.flower('daisy').bundleSize);
    s.startNextDay();
    expect(s.stockCount('daisy'), 0);
  });

  test('progress survives a reload in the middle of the day', () async {
    final backing = <String, String>{};
    final s = newSession(backing: backing);
    stockAndOpen(s);
    await s.pendingSaves;
    final saved = await ProgressStore.memory(backing).load();
    final s2 = newSession(backing: backing, saved: saved);
    expect(s2.state.phase, DayPhase.open);
    expect(s2.screen, Screen.shop);
    expect(s2.state.stock.length, s.state.stock.length);
    expect(s2.state.pendingArrivals, s.state.pendingArrivals);
  });

  test('reviews list keeps at most 50 entries', () {
    final st = newSession().state;
    for (var i = 0; i < 70; i++) {
      st.addReview(
        ReviewRecord(
          day: 1,
          customerName: 'x',
          avatarId: 0,
          occasionId: 'birthday',
          stars: 5,
          comment: '$i',
          outcome: 'great',
        ),
      );
    }
    expect(st.reviews.length, GameState.maxSavedReviews);
    expect(st.reviews.last.comment, '69');
  });
}
