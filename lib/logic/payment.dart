import 'dart:math';

import '../data/economy.dart';
import 'bouquet.dart';
import 'match_scoring.dart';

int roundTo1000(num v) => (v / 1000).round() * 1000;

/// `pricing._formula`: roundTo1000((stems + paper + ribbon) * multiplier).
int bouquetPrice(Economy e, Bouquet b, {double? multiplier}) {
  var sum = 0;
  for (final s in b.stems) {
    sum += e.flower(s.flowerId).sellPrice;
  }
  if (b.paperId != null) sum += e.paper(b.paperId!).sellPrice;
  if (b.ribbonId != null) sum += e.ribbon(b.ribbonId!).sellPrice;
  return roundTo1000(sum * (multiplier ?? e.priceMultiplierDefault));
}

class Payment {
  const Payment({
    required this.price,
    required this.pay,
    required this.tip,
    required this.wrapBonus,
  });

  final int price;

  /// What the customer pays for the flowers (price * payFactor).
  final int pay;

  /// Tier tip (+ fast-service bonus), with holiday/occasion multipliers.
  final int tip;

  /// Wrap mini-game bonus (0 on a miss).
  final int wrapBonus;

  int get tipTotal => tip + wrapBonus;
  int get total => pay + tipTotal;
}

/// `bouquet._tierNote`, `bouquet._fastNote` and `wrapMiniGame._bonusNote`.
Payment computePayment(
  Economy e, {
  required int price,
  required Tier tier,
  required bool fastService,
  required bool wrapHit,
  double holidayTipMultiplier = 1.0,
  double occasionTipMultiplier = 1.0,
}) {
  final t = e.tiers[tier.name]!;
  final pay = (price * t.payFactor).round();
  var tipPercent = t.tipPercent;
  if (fastService && tier != Tier.unhappy) {
    tipPercent += e.fastServiceBonusPercent;
  }
  final tip = roundTo1000(
    price * tipPercent * holidayTipMultiplier * occasionTipMultiplier,
  );
  final bonus = wrapHit
      ? max(e.wrapBonusMin, roundTo1000(price * e.wrapBonusPercent))
      : 0;
  return Payment(price: price, pay: pay, tip: tip, wrapBonus: bonus);
}

/// Green zone of the wrap mini-game on the 0..1 fill bar.
class WrapZone {
  const WrapZone(this.start, this.end);

  final double start;
  final double end;

  double get width => end - start;
  bool contains(double fill) => fill >= start && fill <= end;
}

/// `wrapMiniGame.greenZone._formula`. [tableBonus] is the wrapping_table
/// upgrade's greenZoneBonus (0 until upgrades exist).
WrapZone wrapZoneFor(
  Economy e, {
  required int shopRank,
  required Random rng,
  double tableBonus = 0,
}) {
  final w =
      max(e.wrapMinWidth, e.wrapBaseWidth - e.wrapNarrowPerRank * (shopRank - 1)) +
      tableBonus;
  final lo = e.wrapCenterRange[0];
  final hi = e.wrapCenterRange[1];
  final center = lo + (hi - lo) * rng.nextDouble();
  var start = center - w / 2;
  if (start < 0) start = 0;
  if (start + w > 1) start = 1 - w;
  return WrapZone(start, start + w);
}
