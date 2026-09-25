import 'dart:convert';
import 'dart:math';

import 'package:ai_game/data/economy.dart';
import 'package:ai_game/logic/bouquet.dart';
import 'package:ai_game/logic/delivery.dart';
import 'package:ai_game/logic/goals.dart';
import 'package:ai_game/logic/match_scoring.dart';
import 'package:ai_game/logic/payment.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = loadTestData().economy;

  ShipperDef ship(String id) => e.delivery.shipper(id);

  group('unlock rules', () {
    test('day, rank and the previous shipper', () {
      final bike = ship('bike');
      final moto = ship('motorbike');
      final ebike = ship('ebike');
      expect(
        shipperIsUnlocked(
          e,
          bike,
          day: bike.unlock.day! - 1,
          rank: 1,
          levels: const {},
        ),
        isFalse,
      );
      expect(
        shipperIsUnlocked(
          e,
          bike,
          day: bike.unlock.day!,
          rank: 1,
          levels: const {},
        ),
        isTrue,
      );
      expect(
        shipperLockLabel(
          e,
          bike,
          day: bike.unlock.day! - 1,
          rank: 1,
          levels: const {},
        ),
        'Mở ngày ${bike.unlock.day}',
      );
      expect(
        shipperLockLabel(
          e,
          moto,
          day: 99,
          rank: moto.unlock.rank! - 1,
          levels: const {},
        ),
        'Cần hạng ${moto.unlock.rank}',
      );
      expect(
        shipperIsUnlocked(
          e,
          moto,
          day: 99,
          rank: moto.unlock.rank! - 1,
          levels: const {},
        ),
        isFalse,
      );
      expect(
        shipperIsUnlocked(
          e,
          moto,
          day: 99,
          rank: moto.unlock.rank!,
          levels: const {},
        ),
        isTrue,
      );
      expect(
        shipperIsUnlocked(
          e,
          ebike,
          day: 99,
          rank: ebike.unlock.rank!,
          levels: const {},
        ),
        isFalse,
      );
      expect(
        shipperIsUnlocked(
          e,
          ebike,
          day: 99,
          rank: ebike.unlock.rank!,
          levels: {ebike.unlock.shipper!: 1},
        ),
        isTrue,
      );
      expect(
        shipperLockLabel(
          e,
          ebike,
          day: 99,
          rank: ebike.unlock.rank!,
          levels: const {},
        ),
        'Cần ${ship(ebike.unlock.shipper!).nameVi}',
      );
    });

    test('online goal waits for a shipper and caps the target', () {
      final template = e.goalTemplates.firstWhere(
        (t) => t.id == 'online_orders',
      );
      expect(template.requiresShippersHired, 1);
      for (var seed = 0; seed < 20; seed++) {
        final goals = pickDailyGoals(
          e,
          shopRank: 1,
          isHoliday: false,
          unlockedOccasions: e.occasions,
          ownedUpgrades: const {},
          shippersHired: 0,
          rng: Random(seed),
        );
        expect(goals.every((g) => g.templateId != 'online_orders'), isTrue);
      }
      final uncapped = template.targetBase + template.targetPerRank * (5 - 1);
      final capped = cappedGoalTarget(
        targetBase: template.targetBase,
        targetPerRank: template.targetPerRank,
        shopRank: 5,
        metric: template.metric,
        requiresShippers: template.requiresShippersHired,
        shippersHired: 1,
      );
      expect(uncapped, greaterThan(onlineGoalCapPerShipper));
      expect(capped, onlineGoalCapPerShipper);
    });
  });

  test(
    'order line does not repeat giấy when the paper name already has it',
    () {
      final line = orderLine(
        e,
        const BouquetRequest(
          occasionId: 'birthday',
          stems: {'rose': 7},
          paperId: 'kraft',
          ribbonId: 'twine',
        ),
      );
      expect(line, '7 Hoa hồng · giấy kraft · nơ dây cói');
      expect(line.contains('giấy giấy'), isFalse);
    },
  );

  group('accepting an order', () {
    test('same-day Nhận needs every stem in stock', () {
      final s = newSession();
      s.state.phase = DayPhase.open;
      final flower = s.unlockedFlowers.first;
      final request = BouquetRequest(
        occasionId: s.e.occasions.first.id,
        stems: {flower.id: 5},
        paperId: s.unlockedPapers.first.id,
        ribbonId: s.unlockedRibbons.first.id,
      );
      final short = s.debugIncoming(request);
      expect(s.acceptSameDay(short), isFalse);
      expect(short.status, OrderStatus.offered);
      expect(s.sameDayShortage(short)!.$2, 5);

      s.state.stock.add(
        StockBatch(flowerId: flower.id, count: 5, freshnessLeft: 3),
      );
      expect(s.acceptSameDay(short), isTrue);
      expect(short.status, OrderStatus.accepted);
      expect(s.stockAvailable(flower.id), 0);
      expect(s.stockCount(flower.id), 5);

      final another = s.debugIncoming(request);
      expect(s.acceptSameDay(another), isFalse);
      expect(another.status, OrderStatus.offered);
    });
  });

  group('payout', () {
    test(
      'on time multiplies price and tip and adds the fee; late does not',
      () {
        const price = 80000;
        final tier = e.tiers['great']!;
        final holiday = 1.1;
        final occasion = e.occasions.first.tipMultiplier;
        final onTime = payOnTime(
          e,
          price: price,
          tier: Tier.great,
          wrapHit: true,
          holidayTip: holiday,
          occasionTip: occasion,
        );
        final wrapBonus = max(
          e.wrapBonusMin,
          roundTo1000(price * e.wrapBonusPercent),
        );
        expect(
          onTime.pay,
          roundTo1000(
            price * tier.payFactor * e.delivery.onlinePriceMultiplier,
          ),
        );
        expect(
          onTime.tip,
          roundTo1000(
            (price * tier.tipPercent * holiday * occasion + wrapBonus) *
                e.delivery.onlinePriceMultiplier,
          ),
        );
        expect(onTime.fee, e.delivery.deliveryFee);
        expect(onTime.late, isFalse);

        final late = payLate(e, price: price);
        expect(late.pay, roundTo1000(price * e.delivery.latePayFactor));
        expect(late.tip, e.delivery.lateTip);
        expect(late.fee, e.delivery.lateDeliveryFee);
        expect(late.reviewOutcome, e.delivery.lateReview);
        expect(late.total, lessThan(onTime.total));
      },
    );
  });

  group('auto-assign', () {
    test('a full bike leaves at once; the next order waits for the return', () {
      final bike = ship('bike').levels.first;
      final times = planHandovers(
        e,
        shippers: [
          PlannedShipper(
            id: 'bike',
            deliverSeconds: bike.deliverSeconds,
            returnSeconds: bike.returnSeconds,
            capacity: bike.capacity,
          ),
        ],
        deadlines: const [100, 200],
      );
      expect(bike.capacity, 1);
      expect(times[0], bike.deliverSeconds);
      expect(
        times[1],
        bike.deliverSeconds + bike.returnSeconds + bike.deliverSeconds,
      );
    });

    test('two orders fill a bigger vehicle and leave together', () {
      final level = ship('motorbike').levels.first;
      final times = planHandovers(
        e,
        shippers: [
          PlannedShipper(
            id: 'motorbike',
            deliverSeconds: level.deliverSeconds,
            returnSeconds: level.returnSeconds,
            capacity: level.capacity,
          ),
        ],
        deadlines: const [100, 120],
      );
      expect(level.capacity, greaterThan(1));
      expect(times[0], level.deliverSeconds);
      expect(times[1], level.deliverSeconds + e.delivery.extraStopSeconds);
    });

    test('the order goes to whoever hands it over soonest', () {
      final bike = ship('bike').levels.first;
      final moto = ship('motorbike').levels.first;
      final times = planHandovers(
        e,
        shippers: [
          PlannedShipper(
            id: 'bike',
            deliverSeconds: bike.deliverSeconds,
            returnSeconds: bike.returnSeconds,
            capacity: bike.capacity,
          ),
          PlannedShipper(
            id: 'motorbike',
            deliverSeconds: moto.deliverSeconds,
            returnSeconds: moto.returnSeconds,
            capacity: moto.capacity,
          ),
        ],
        deadlines: const [150],
      );
      final bikeHandover = bike.capacity == 1
          ? bike.deliverSeconds
          : e.delivery.loadWaitSeconds + bike.deliverSeconds;
      final motoHandover = moto.capacity == 1
          ? moto.deliverSeconds
          : e.delivery.loadWaitSeconds + moto.deliverSeconds;
      final sooner = bikeHandover < motoHandover ? bikeHandover : motoHandover;
      expect(times[0], sooner);
      expect(sooner, motoHandover);
    });
  });

  test('shipper wages are charged with the end-of-day costs', () {
    final s = newSession();
    s.state.day = ship('bike').unlock.day!;
    final before = s.state.money;
    expect(s.hireShipper('bike'), isTrue);
    expect(s.state.shipperLevels['bike'], 1);
    expect(s.state.ordersFromDay, s.state.day + 1);
    expect(s.state.money, before - ship('bike').hireCost);
    s.buyAndGoToShop();
    s.openShop();
    s.state.pendingArrivals.clear();
    s.queue.clear();
    for (var i = 0; i < 400 && s.state.phase != DayPhase.summary; i++) {
      s.tick(1);
    }
    final wage = ship('bike').dailyWage;
    expect(s.state.metrics.shipperWages, wage);
    expect(
      s.state.metrics.fixedCosts,
      s.e.fixedCostsTotal + s.effects.dailyCosts + wage,
    );
    expect(
      s.state.money,
      before - ship('bike').hireCost - s.e.fixedCostsTotal - wage,
    );
  });

  test('an old save without shippers still loads', () {
    final fresh = newSession();
    final json = jsonDecode(fresh.state.encode()) as Map<String, dynamic>;
    json.remove('shipperLevels');
    json.remove('ordersFromDay');
    final metrics = json['metrics'] as Map<String, dynamic>;
    metrics.remove('onlineLate');
    metrics.remove('onlineMissed');
    metrics.remove('onlineIncome');
    metrics.remove('shipperWages');
    metrics.remove('tripsOutAtClose');
    final loaded = GameState.decode(jsonEncode(json))!;
    expect(loaded.shipperLevels, isEmpty);
    expect(loaded.ordersFromDay, 0);
    expect(loaded.metrics.onlineDelivered, 0);
    expect(loaded.metrics.shipperWages, 0);

    fresh.state.shipperLevels['bike'] = 2;
    fresh.state.ordersFromDay = 5;
    final round = GameState.decode(fresh.state.encode())!;
    expect(round.shipperLevels['bike'], 2);
    expect(round.ordersFromDay, 5);
  });

  test('on-time hand-over pays the online total; a late one pays half', () {
    final s = _openWithBike();
    final flower = s.unlockedFlowers.first;
    final paper = s.unlockedPapers.first;
    final ribbon = s.unlockedRibbons.first;
    s.state.stock.add(
      StockBatch(flowerId: flower.id, count: 20, freshnessLeft: 3),
    );
    final request = BouquetRequest(
      occasionId: s.e.occasions.first.id,
      stems: {flower.id: 5},
      paperId: paper.id,
      ribbonId: ribbon.id,
    );
    final onTime = s.debugIncoming(request);
    expect(s.acceptSameDay(onTime), isTrue);
    _pack(s, onTime, flower.id, paper.id, ribbon.id);
    expect(onTime.status, OrderStatus.dispatched);
    final due = payOnTime(
      s.e,
      price: onTime.bouquetPrice,
      tier: onTime.tier,
      wrapHit: onTime.wrapHit,
      holidayTip: s.holidayToday?.tipMultiplier ?? 1,
      occasionTip: s.e.occasion(onTime.request.occasionId).tipMultiplier,
    );
    final deliver = ship('bike').levels.first.deliverSeconds;
    s.tick(deliver);
    expect(onTime.status, OrderStatus.done);
    expect(onTime.late, isFalse);
    expect(s.state.metrics.onlineDelivered, 1);
    expect(s.state.metrics.onlineIncome, due.total);

    final homeAt = deliver + ship('bike').levels.first.returnSeconds;
    while (s.state.elapsed < homeAt) {
      s.tick(5);
    }
    s.state.stock.add(
      StockBatch(flowerId: flower.id, count: 10, freshnessLeft: 3),
    );
    // Dispatched at once (capacity 1) but handed over after the deadline.
    final lateOrder = s.debugIncoming(
      request,
      deadline: s.state.elapsed + deliver / 2,
    );
    expect(s.acceptSameDay(lateOrder), isTrue);
    _pack(s, lateOrder, flower.id, paper.id, ribbon.id);
    expect(lateOrder.status, OrderStatus.dispatched);
    s.tick(deliver);
    expect(lateOrder.status, OrderStatus.done);
    expect(lateOrder.late, isTrue);
    expect(s.state.metrics.onlineLate, 1);
    expect(s.state.metrics.onlineDelivered, 1);
    final latePay = payLate(s.e, price: lateOrder.bouquetPrice);
    expect(lateOrder.payout, latePay.total);
    expect(s.state.reviews.last.outcome, s.e.delivery.lateReview);
    expect(s.state.reviews.last.online, isTrue);
    expect(s.state.reviews.last.deliveryIssue, 'late');
    expect(
      s.state.reviews.last.stars,
      s.e.reviewStars[s.e.delivery.lateReview],
    );
  });
}

ShopSession _openWithBike() {
  final s = newSession(seed: 2);
  s.state.day = 4;
  s.state.ordersFromDay = 4;
  s.state.shipperLevels['bike'] = 1;
  s.state.phase = DayPhase.open;
  s.state.elapsed = 0;
  return s;
}

void _pack(
  ShopSession s,
  OnlineOrder order,
  String flower,
  String paper,
  String ribbon,
) {
  s.openOnlineOrder(order.id);
  final need = order.request.total;
  for (var i = 0; i < need; i++) {
    expect(s.addStem(flower), isTrue);
  }
  s.selectPaper(paper);
  s.selectRibbon(ribbon);
  expect(s.beginWrap(), isNotNull);
  s.finishWrap(hit: true);
  s.showShopAfterOnlinePack();
}
