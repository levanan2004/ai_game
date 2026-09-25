import 'dart:math';

import '../data/economy.dart';
import 'format.dart';

/// Per-day counters. Covers every `dailyGoals` metric plus the end-of-day
/// summary lines.
class DayMetrics {
  DayMetrics();

  int bouquetsSold = 0;
  int greatCount = 0;
  int wrapHits = 0;
  int fastServed = 0;
  int customersLeft = 0;
  int stemsWilted = 0;
  int onlineDelivered = 0;
  int newReviews = 0;
  Map<String, int> occasionServed = {};
  Map<String, int> wiltedByFlower = {};

  // Money (VND).
  int flowerIncome = 0;
  int tipIncome = 0;
  int goalRewards = 0;
  int marketSpend = 0;
  int wrapSupplies = 0;
  int fixedCosts = 0;

  /// Shop rating when the day started (for "tăng/giảm" in the summary).
  double ratingAtStart = 0;

  /// True once end-of-day money (rewards, rent) has been applied.
  bool settled = false;

  int get revenue => flowerIncome + tipIncome;
  int get income => flowerIncome + tipIncome + goalRewards;
  int get expenses => marketSpend + wrapSupplies + fixedCosts;
  int get profit => income - expenses;

  int value(String metric, {String? occasionId}) => switch (metric) {
    'bouquetsSold' => bouquetsSold,
    'greatCount' => greatCount,
    'wrapHits' => wrapHits,
    'revenue' => revenue,
    'fastServed' => fastServed,
    'customersLeft' => customersLeft,
    'stemsWilted' => stemsWilted,
    'occasionServed' => occasionServed[occasionId] ?? 0,
    'onlineDelivered' => onlineDelivered,
    _ => 0,
  };

  Map<String, Object?> toJson() => {
    'bouquetsSold': bouquetsSold,
    'greatCount': greatCount,
    'wrapHits': wrapHits,
    'fastServed': fastServed,
    'customersLeft': customersLeft,
    'stemsWilted': stemsWilted,
    'onlineDelivered': onlineDelivered,
    'newReviews': newReviews,
    'occasionServed': occasionServed,
    'wiltedByFlower': wiltedByFlower,
    'flowerIncome': flowerIncome,
    'tipIncome': tipIncome,
    'goalRewards': goalRewards,
    'marketSpend': marketSpend,
    'wrapSupplies': wrapSupplies,
    'fixedCosts': fixedCosts,
    'ratingAtStart': ratingAtStart,
    'settled': settled,
  };

  static DayMetrics fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    Map<String, int> m(String k) => {
      for (final e in ((j[k] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    };
    return DayMetrics()
      ..bouquetsSold = i('bouquetsSold')
      ..greatCount = i('greatCount')
      ..wrapHits = i('wrapHits')
      ..fastServed = i('fastServed')
      ..customersLeft = i('customersLeft')
      ..stemsWilted = i('stemsWilted')
      ..onlineDelivered = i('onlineDelivered')
      ..newReviews = i('newReviews')
      ..occasionServed = m('occasionServed')
      ..wiltedByFlower = m('wiltedByFlower')
      ..flowerIncome = i('flowerIncome')
      ..tipIncome = i('tipIncome')
      ..goalRewards = i('goalRewards')
      ..marketSpend = i('marketSpend')
      ..wrapSupplies = i('wrapSupplies')
      ..fixedCosts = i('fixedCosts')
      ..ratingAtStart = (j['ratingAtStart'] as num?)?.toDouble() ?? 0
      ..settled = j['settled'] == true;
  }
}

/// One "Mục tiêu hôm nay" card.
class DailyGoal {
  const DailyGoal({
    required this.templateId,
    required this.title,
    required this.metric,
    required this.compare,
    required this.target,
    required this.reward,
    this.occasionId,
  });

  final String templateId;
  final String title;
  final String metric;
  final String compare;
  final int target;
  final int reward;
  final String? occasionId;

  int progress(DayMetrics m) => m.value(metric, occasionId: occasionId);

  /// "Héo không quá N", "Tối đa N khách bỏ về": staying under the cap.
  bool get isLimit => compare == '<=';

  bool isDone(DayMetrics m) {
    final v = progress(m);
    return isLimit ? v <= target : v >= target;
  }

  /// Limit broken (more wilted stems, more walk-outs, …).
  bool isExceeded(DayMetrics m) => isLimit && progress(m) > target;

  /// "a/b" on the card, or "a / tối đa b" for a limit.
  /// Revenue is shown in money format.
  String progressLabel(DayMetrics m) {
    final v = progress(m);
    if (metric == 'revenue') return '${formatK(v)}/${formatK(target)}';
    if (isLimit) return '$v / tối đa $target';
    return '$v/$target';
  }

  Map<String, Object?> toJson() => {
    'templateId': templateId,
    'title': title,
    'metric': metric,
    'compare': compare,
    'target': target,
    'reward': reward,
    'occasionId': occasionId,
  };

  static DailyGoal fromJson(Map<String, dynamic> j) => DailyGoal(
    templateId: j['templateId'] as String,
    title: j['title'] as String,
    metric: j['metric'] as String,
    compare: j['compare'] as String,
    target: (j['target'] as num).toInt(),
    reward: (j['reward'] as num).toInt(),
    occasionId: j['occasionId'] as String?,
  );
}

T weightedPick<T>(List<T> items, double Function(T) weight, Random rng) {
  final total = items.fold<double>(0, (a, b) => a + weight(b));
  var r = rng.nextDouble() * total;
  for (final it in items) {
    r -= weight(it);
    if (r < 0) return it;
  }
  return items.last;
}

/// `dailyGoals._rules`.
List<DailyGoal> pickDailyGoals(
  Economy e, {
  required int shopRank,
  required bool isHoliday,
  required List<OccasionDef> unlockedOccasions,
  required Set<String> ownedUpgrades,
  required Random rng,
}) {
  DailyGoal build(GoalTemplate t) {
    final target = t.targetBase + t.targetPerRank * (shopRank - 1);
    final reward = t.rewardBase + t.rewardPerRank * (shopRank - 1);
    OccasionDef? occ;
    if (t.metric == 'occasionServed' && unlockedOccasions.isNotEmpty) {
      occ = weightedPick<OccasionDef>(unlockedOccasions, (o) => o.weight, rng);
    }
    final targetText = t.metric == 'revenue' ? formatK(target) : '$target';
    final title = t.titleVi
        .replaceAll('{target}', targetText)
        .replaceAll('{occasion}', occ?.nameVi ?? '');
    return DailyGoal(
      templateId: t.id,
      title: title,
      metric: t.metric,
      compare: t.compare,
      target: target,
      reward: reward,
      occasionId: occ?.id,
    );
  }

  final out = <DailyGoal>[];
  if (isHoliday) {
    final holidayTemplates = e.goalTemplates.where((t) => t.holidayOnly);
    if (holidayTemplates.isNotEmpty) out.add(build(holidayTemplates.first));
  }
  final pool = e.goalTemplates.where((t) {
    if (t.holidayOnly || t.weight <= 0) return false;
    if (isHoliday && t.noHoliday) return false;
    if (t.requiresUpgrade != null &&
        !ownedUpgrades.contains(t.requiresUpgrade)) {
      return false;
    }
    if (t.metric == 'occasionServed' && unlockedOccasions.isEmpty) return false;
    return true;
  }).toList();
  while (out.length < e.goalCardsPerDay && pool.isNotEmpty) {
    final t = weightedPick(pool, (t) => t.weight, rng);
    pool.remove(t);
    out.add(build(t));
  }
  return out;
}
