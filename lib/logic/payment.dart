import 'dart:math';

import '../data/economy.dart';
import 'bouquet.dart';
import 'match_scoring.dart';

int roundTo1000(num v) => (v / 1000).round() * 1000;

/// Snaps [raw] onto the Giá bán steps (0.8 … 1.5 by 0.1).
double snapPriceMultiplier(Economy e, double raw) {
  final step = e.priceMultiplierStep;
  if (step <= 0) return e.priceMultiplierDefault;
  var steps = ((raw - e.priceMultiplierMin) / step).round();
  final maxSteps = ((e.priceMultiplierMax - e.priceMultiplierMin) / step)
      .round();
  if (steps < 0) steps = 0;
  if (steps > maxSteps) steps = maxSteps;
  final tenths =
      (e.priceMultiplierMin * 10).round() + steps * (step * 10).round();
  return tenths / 10;
}

/// `pricing.priceDemandFactor._formula` for how many customers walk in.
double priceCustomerFactor(Economy e, double multiplier) {
  if (multiplier > 1) {
    return (1 - e.priceAboveSlope * (multiplier - 1)).clamp(0.0, 3.0);
  }
  if (multiplier < 1) {
    return 1 + e.priceBelowSlope * (1 - multiplier);
  }
  return 1;
}

/// Patience shrinks only while the shop charges above the normal price.
double pricePatienceFactor(Economy e, double multiplier) {
  if (multiplier <= 1) return 1;
  return (1 - e.pricePatienceSlope * (multiplier - 1)).clamp(0.2, 1.0);
}

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
    this.noteBonus = 0,
  });

  final int price;

  /// What the customer pays for the flowers (price * payFactor).
  final int pay;

  /// Tier tip (+ fast-service bonus), with holiday/occasion multipliers.
  final int tip;

  /// Wrap mini-game bonus (0 on a miss).
  final int wrapBonus;

  /// Flat tip for a written card on a listed occasion. 0 otherwise.
  final int noteBonus;

  int get tipTotal => tip + wrapBonus + noteBonus;
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
  int noteTip = 0,
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
  return Payment(
    price: price,
    pay: pay,
    tip: tip,
    wrapBonus: bonus,
    noteBonus: noteTip,
  );
}

/// How many theme cards the Bó xong step offers. One of them is the
/// customer's occasion.
const cardThemeChoiceCount = 4;

/// The line written on the card when the player picks [occasionId].
String cardLineFor(Economy e, String occasionId) {
  final lines = e.cardNoteSuggestions[occasionId];
  if (lines != null && lines.isNotEmpty) return lines.first;
  return e.occasion(occasionId).nameVi;
}

/// [text] when it is one of the card lines, else null. Older saves can hold a
/// typed wish from before the four theme cards; that text is dropped.
String? cardChoiceText(Economy e, String? text) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return null;
  for (final lines in e.cardNoteSuggestions.values) {
    if (lines.contains(t)) return t;
  }
  for (final occasion in e.occasions) {
    if (t == occasion.nameVi) return t;
  }
  return null;
}

/// Four occasion ids for the card step. [occasionId] is always included.
List<String> cardThemeChoices(
  Economy e, {
  required String occasionId,
  required Random rng,
  int count = cardThemeChoiceCount,
}) {
  final others = [
    for (final occasion in e.occasions)
      if (occasion.id != occasionId) occasion.id,
  ]..shuffle(rng);
  final picks = <String>[
    if (e.occasions.any((occasion) => occasion.id == occasionId)) occasionId,
    ...others.take(count - 1),
  ];
  picks.shuffle(rng);
  return picks;
}

/// Pays [Economy.cardNoteTip] only when [note] is a line of the customer's
/// occasion. A wrong theme, a blank card, or text that is not a card line
/// (a typed wish from an old save) pays nothing.
/// Match and stars stay unchanged.
int cardNoteTip(Economy e, {required String occasionId, String? note}) {
  final text = note?.trim() ?? '';
  if (text.isEmpty) return 0;
  final lines = e.cardNoteSuggestions[occasionId] ?? const <String>[];
  if (lines.contains(text)) return e.cardNoteTip;
  if (lines.isEmpty && text == e.occasion(occasionId).nameVi) {
    return e.cardNoteTip;
  }
  return 0;
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
      max(
        e.wrapMinWidth,
        e.wrapBaseWidth - e.wrapNarrowPerRank * (shopRank - 1),
      ) +
      tableBonus;
  final lo = e.wrapCenterRange[0];
  final hi = e.wrapCenterRange[1];
  final center = lo + (hi - lo) * rng.nextDouble();
  var start = center - w / 2;
  if (start < 0) start = 0;
  if (start + w > 1) start = 1 - w;
  return WrapZone(start, start + w);
}
