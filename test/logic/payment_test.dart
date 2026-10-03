import 'dart:math';

import 'package:ai_game/logic/match_scoring.dart';
import 'package:ai_game/logic/payment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = loadTestData().economy;

  test('bouquet price sums sell prices and rounds to 1000', () {
    final b = bouquetOf(
      {'rose': 3, 'baby': 2},
      paper: 'kraft',
      ribbon: 'twine',
    );
    final raw =
        3 * e.flower('rose').sellPrice +
        2 * e.flower('baby').sellPrice +
        e.paper('kraft').sellPrice +
        e.ribbon('twine').sellPrice;
    expect(bouquetPrice(e, b), roundTo1000(raw));
    expect(roundTo1000(1499), 1000);
    expect(roundTo1000(1500), 2000);
  });

  test('tiers set pay factor and tip; fast bonus only for okay/great', () {
    const price = 40000;
    final great = computePayment(
      e,
      price: price,
      tier: Tier.great,
      fastService: false,
      wrapHit: false,
    );
    expect(great.pay, price);
    expect(great.tip, roundTo1000(price * e.tiers['great']!.tipPercent));
    final fast = computePayment(
      e,
      price: price,
      tier: Tier.great,
      fastService: true,
      wrapHit: false,
    );
    expect(
      fast.tip,
      roundTo1000(
        price * (e.tiers['great']!.tipPercent + e.fastServiceBonusPercent),
      ),
    );
    final unhappy = computePayment(
      e,
      price: price,
      tier: Tier.unhappy,
      fastService: true,
      wrapHit: false,
    );
    expect(unhappy.pay, (price * e.tiers['unhappy']!.payFactor).round());
    expect(unhappy.tip, 0);
  });

  test('wrap hit adds max(minAmount, percent of price) on every tier', () {
    final small = computePayment(
      e,
      price: 10000,
      tier: Tier.unhappy,
      fastService: false,
      wrapHit: true,
    );
    expect(small.wrapBonus, e.wrapBonusMin);
    final big = computePayment(
      e,
      price: 100000,
      tier: Tier.okay,
      fastService: false,
      wrapHit: true,
    );
    expect(
      big.wrapBonus,
      max(e.wrapBonusMin, roundTo1000(100000 * e.wrapBonusPercent)),
    );
    final miss = computePayment(
      e,
      price: 100000,
      tier: Tier.great,
      fastService: false,
      wrapHit: false,
    );
    expect(miss.wrapBonus, 0);
  });

  test('holiday and occasion tip multipliers apply', () {
    final p = computePayment(
      e,
      price: 100000,
      tier: Tier.great,
      fastService: false,
      wrapHit: false,
      holidayTipMultiplier: 1.2,
      occasionTipMultiplier: 1.3,
    );
    expect(
      p.tip,
      roundTo1000(100000 * e.tiers['great']!.tipPercent * 1.2 * 1.3),
    );
  });

  test('four card themes always include the customer occasion', () {
    final rng = Random(4);
    for (final occasion in e.occasions) {
      final picks = cardThemeChoices(e, occasionId: occasion.id, rng: rng);
      expect(picks, hasLength(cardThemeChoiceCount));
      expect(picks.toSet(), hasLength(cardThemeChoiceCount));
      expect(picks, contains(occasion.id));
    }
  });

  test('only the matching theme tips', () {
    expect(
      cardNoteTip(e, occasionId: 'birthday', note: cardLineFor(e, 'birthday')),
      e.cardNoteTip,
    );
    expect(
      cardNoteTip(e, occasionId: 'thanks', note: cardLineFor(e, 'thanks')),
      e.cardNoteTip,
    );
    expect(
      cardNoteTip(
        e,
        occasionId: 'birthday',
        note: cardLineFor(e, 'confession'),
      ),
      0,
    );
    expect(cardNoteTip(e, occasionId: 'birthday', note: '   '), 0);
    expect(cardNoteTip(e, occasionId: 'birthday', note: 'Viết bừa'), 0);
    final paid = computePayment(
      e,
      price: 20000,
      tier: Tier.great,
      fastService: false,
      wrapHit: false,
      noteTip: e.cardNoteTip,
    );
    expect(paid.noteBonus, e.cardNoteTip);
    expect(paid.tipTotal, paid.tip + paid.noteBonus);
  });

  test('green zone width follows rank and stays inside the bar', () {
    final rng = Random(3);
    for (var i = 0; i < 200; i++) {
      final z = wrapZoneFor(e, shopRank: 1, rng: rng);
      expect(z.width, closeTo(e.wrapBaseWidth, 1e-9));
      expect(z.start, greaterThanOrEqualTo(0));
      expect(z.end, lessThanOrEqualTo(1));
    }
    final r5 = wrapZoneFor(e, shopRank: 99, rng: rng);
    expect(r5.width, closeTo(e.wrapMinWidth, 1e-9));
    final bonus = wrapZoneFor(e, shopRank: 1, rng: rng, tableBonus: 0.03);
    expect(bonus.width, closeTo(e.wrapBaseWidth + 0.03, 1e-9));
  });

  test('price steps and the crowd formula', () {
    expect(snapPriceMultiplier(e, 1.24), 1.2);
    expect(snapPriceMultiplier(e, 9), e.priceMultiplierMax);
    expect(snapPriceMultiplier(e, 0), e.priceMultiplierMin);
    expect(priceCustomerFactor(e, 1), 1);
    expect(priceCustomerFactor(e, 1.5), closeTo(0.6, 1e-9));
    expect(priceCustomerFactor(e, 0.8), closeTo(1.08, 1e-9));
    expect(pricePatienceFactor(e, 1.5), closeTo(0.75, 1e-9));
    expect(pricePatienceFactor(e, 0.8), 1);
    final rose = bouquetOf({'rose': 1}, paper: 'kraft', ribbon: 'twine');
    expect(
      bouquetPrice(e, rose, multiplier: 1.5),
      roundTo1000(bouquetPrice(e, rose) * 1.5),
    );
  });
}
