/// Typed view of `assets/data/economy.json` (Hà Phương, v0.2-draft).
///
/// Every number the game uses comes from this file at runtime. Keys that
/// start with `_` are comments and are ignored. A missing required key throws
/// a [FormatException] naming the key, so a bad data file fails loudly.
library;

class FlowerDef {
  const FlowerDef({
    required this.id,
    required this.nameVi,
    required this.buyPrice,
    required this.sellPrice,
    required this.freshnessDays,
    required this.bundleSize,
    required this.unlockCost,
  });

  final String id;
  final String nameVi;
  final int buyPrice;
  final int sellPrice;
  final int freshnessDays;
  final int bundleSize;
  final int unlockCost;
}

/// A paper or a ribbon. They never expire and are paid per use.
class ItemDef {
  const ItemDef({
    required this.id,
    required this.nameVi,
    required this.buyPrice,
    required this.sellPrice,
    required this.unlockCost,
  });

  final String id;
  final String nameVi;
  final int buyPrice;
  final int sellPrice;
  final int unlockCost;
}

class OccasionDef {
  const OccasionDef({
    required this.id,
    required this.nameVi,
    required this.weight,
    required this.species,
    required this.stemOptions,
    required this.stemRange,
    required this.fillerAllowed,
    required this.papers,
    required this.ribbons,
    required this.unlockWhen,
    required this.tipMultiplier,
  });

  final String id;
  final String nameVi;
  final double weight;
  final List<String> species;
  final List<int>? stemOptions;
  final List<int>? stemRange;
  final bool fillerAllowed;
  final List<String> papers;
  final List<String> ribbons;
  final String? unlockWhen;
  final double tipMultiplier;
}

class HolidayDef {
  const HolidayDef({
    required this.id,
    required this.nameVi,
    required this.days,
    required this.customerMultiplier,
    required this.tipMultiplier,
    required this.featuredFlowers,
    required this.marketPriceMultiplier,
  });

  final String id;
  final String nameVi;
  final List<int> days;
  final double customerMultiplier;
  final double tipMultiplier;
  final List<String> featuredFlowers;
  final double marketPriceMultiplier;
}

class TierDef {
  const TierDef({required this.payFactor, required this.tipPercent});

  final double payFactor;
  final double tipPercent;
}

class ShopRankDef {
  const ShopRankDef({
    required this.rank,
    required this.nameVi,
    required this.minBouquetsSold,
  });

  final int rank;
  final String nameVi;
  final int minBouquetsSold;
}

class GoalTemplate {
  const GoalTemplate({
    required this.id,
    required this.titleVi,
    required this.metric,
    required this.compare,
    required this.targetBase,
    required this.targetPerRank,
    required this.rewardBase,
    required this.rewardPerRank,
    required this.weight,
    required this.noHoliday,
    required this.holidayOnly,
    required this.requiresUpgrade,
  });

  final String id;
  final String titleVi;
  final String metric;
  final String compare;
  final int targetBase;
  final int targetPerRank;
  final int rewardBase;
  final int rewardPerRank;
  final double weight;
  final bool noHoliday;
  final bool holidayOnly;
  final String? requiresUpgrade;
}

class UpgradeLevel {
  const UpgradeLevel({
    required this.level,
    required this.cost,
    required this.dailyUpkeep,
    required this.dailyWage,
    required this.durationDays,
    required this.nameVi,
    required this.effect,
    required this.requires,
  });

  final int level;
  final int cost;
  final int dailyUpkeep;
  final int dailyWage;

  /// Consumables (ads): how many days one purchase lasts.
  final int? durationDays;
  final String? nameVi;

  /// Effect keys to values (num or bool), `_` comments and `requires` removed.
  final Map<String, Object> effect;

  /// Upgrade id to minimum level needed before this level can be bought.
  final Map<String, int> requires;
}

class UpgradeDef {
  const UpgradeDef({
    required this.id,
    required this.nameVi,
    required this.consumable,
    required this.levels,
  });

  final String id;
  final String nameVi;
  final bool consumable;
  final List<UpgradeLevel> levels;

  int get maxLevel => levels.length;
}

/// Scores for one paper or ribbon comparison (`matchScoring.paper|ribbon`).
class ChoiceScores {
  const ChoiceScores({
    required this.exact,
    required this.otherAccepted,
    required this.other,
  });

  final double exact;
  final double otherAccepted;
  final double other;
}

class Economy {
  Economy._(Map<String, dynamic> j)
    : startCash = _int(j, 'start.cash'),
      startRating = _double(j, 'start.rating'),
      unlockedFlowers = _strings(j, 'start.unlockedFlowers'),
      unlockedPapers = _strings(j, 'start.unlockedPapers'),
      unlockedRibbons = _strings(j, 'start.unlockedRibbons'),
      dayRealSeconds = _double(j, 'day.realSeconds'),
      openHour = _int(j, 'day.openHour'),
      closeHour = _int(j, 'day.closeHour'),
      fixedCosts = _intMap(j, 'day.fixedCosts'),
      arrivalWeightsByHour = _doubleMap(
        j,
        'day.arrivalWeightsByHour',
      ).map((k, v) => MapEntry(int.parse(k), v)),
      baseCustomersDay1 = _double(j, 'customers.baseCustomersDay1'),
      growthPerDay = _double(j, 'customers.growthPerDay'),
      baseCustomersCap = _double(j, 'customers.baseCustomersCap'),
      ratingFactor = _doubleMap(
        j,
        'customers.ratingFactor',
      ).map((k, v) => MapEntry(int.parse(k), v)),
      ratingWindow = _int(j, 'customers.ratingWindow'),
      reviewStars = (_get(j, 'customers.reviewStars') as Map).map(
        (k, v) => MapEntry(k as String, (v as num?)?.toInt()),
      )..removeWhere((k, _) => k.startsWith('_')),
      patienceSeconds = _double(j, 'customers.patienceSeconds'),
      patienceWarningAt = _double(j, 'customers.patienceWarningAt'),
      walkInSeconds = _double(j, 'customers.walkInSeconds'),
      counterSlots = _int(j, 'customers.counterSlots'),
      maxQueue = _int(j, 'customers.maxQueue'),
      priceMultiplierDefault = _double(j, 'pricing.priceMultiplier.default'),
      maxStems = _int(j, 'bouquet.maxStems'),
      okayThreshold = _double(j, 'bouquet.matchThresholds.okay'),
      greatThreshold = _double(j, 'bouquet.matchThresholds.great'),
      tiers = {
        for (final t in const ['unhappy', 'okay', 'great'])
          t: TierDef(
            payFactor: _double(j, 'bouquet.tiers.$t.payFactor'),
            tipPercent: _double(j, 'bouquet.tiers.$t.tipPercent'),
          ),
      },
      fastServiceBonusPercent = _double(j, 'bouquet.fastServiceBonusPercent'),
      fastServiceThreshold = _double(j, 'bouquet.fastServiceThreshold'),
      weightSpecies = _double(j, 'matchScoring.weights.species'),
      weightStemCount = _double(j, 'matchScoring.weights.stemCount'),
      weightPaper = _double(j, 'matchScoring.weights.paper'),
      weightRibbon = _double(j, 'matchScoring.weights.ribbon'),
      wrongSpeciesPenalty = _double(
        j,
        'matchScoring.species.wrongSpeciesPenalty',
      ),
      fillerSpecies = _strings(j, 'matchScoring.species.fillerSpecies'),
      creditByDifference = _doubleMap(
        j,
        'matchScoring.stemCount.creditByDifference',
      ).map((k, v) => MapEntry(int.parse(k), v)),
      paperScores = _choice(j, 'matchScoring.paper'),
      ribbonScores = _choice(j, 'matchScoring.ribbon'),
      wiltingPenalty = _double(j, 'matchScoring.wiltingPenalty'),
      wrapFillSeconds = _double(j, 'wrapMiniGame.fillSeconds'),
      wrapBaseWidth = _double(j, 'wrapMiniGame.greenZone.baseWidth'),
      wrapNarrowPerRank = _double(j, 'wrapMiniGame.greenZone.narrowPerRank'),
      wrapMinWidth = _double(j, 'wrapMiniGame.greenZone.minWidth'),
      wrapCenterRange = _doubles(j, 'wrapMiniGame.greenZone.centerRange'),
      wrapBonusPercent = _double(j, 'wrapMiniGame.bonusTip.percentOfPrice'),
      wrapBonusMin = _int(j, 'wrapMiniGame.bonusTip.minAmount'),
      wrapAnimationSeconds = _double(j, 'wrapMiniGame.wrapAnimationSeconds'),
      shopRanks = [
        for (final r in _list(j, 'shopRanks'))
          ShopRankDef(
            rank: _int(r, 'rank'),
            nameVi: _str(r, 'nameVi'),
            minBouquetsSold: _int(r, 'minBouquetsSold'),
          ),
      ],
      minMarketBudget = _int(j, 'safetyNet.minMarketBudget'),
      flowers = [
        for (final f in _list(j, 'flowers'))
          FlowerDef(
            id: _str(f, 'id'),
            nameVi: _str(f, 'nameVi'),
            buyPrice: _int(f, 'buyPrice'),
            sellPrice: _int(f, 'sellPrice'),
            freshnessDays: _int(f, 'freshnessDays'),
            bundleSize: _int(f, 'bundleSize'),
            unlockCost: _int(f, 'unlockCost'),
          ),
      ],
      papers = _items(j, 'papers'),
      ribbons = _items(j, 'ribbons'),
      occasions = [
        for (final o in _list(j, 'occasions'))
          OccasionDef(
            id: _str(o, 'id'),
            nameVi: _str(o, 'nameVi'),
            weight: _double(o, 'weight'),
            species: _strings(o, 'species'),
            stemOptions: o.containsKey('stemOptions')
                ? _ints(o, 'stemOptions')
                : null,
            stemRange: o.containsKey('stemRange')
                ? _ints(o, 'stemRange')
                : null,
            fillerAllowed: o['fillerAllowed'] == true,
            papers: _strings(o, 'papers'),
            ribbons: _strings(o, 'ribbons'),
            unlockWhen: o['unlockWhen'] as String?,
            tipMultiplier: (o['tipMultiplier'] as num?)?.toDouble() ?? 1.0,
          ),
      ],
      yearLengthDays = _int(j, 'holidays.yearLengthDays'),
      posterDaysBefore = _int(j, 'holidays.posterDaysBefore'),
      holidayPriceWindowDays = _int(j, 'market.holidayPriceWindowDays'),
      holidays = [
        for (final h in _list(j, 'holidays.list'))
          HolidayDef(
            id: _str(h, 'id'),
            nameVi: _str(h, 'nameVi'),
            days: _ints(h, 'days'),
            customerMultiplier: _double(h, 'customerMultiplier'),
            tipMultiplier: _double(h, 'tipMultiplier'),
            featuredFlowers: _strings(h, 'featuredFlowers'),
            marketPriceMultiplier: _double(h, 'marketPriceMultiplier'),
          ),
      ],
      upgrades = [
        for (final u in _list(j, 'upgrades'))
          UpgradeDef(
            id: _str(u, 'id'),
            nameVi: _str(u, 'nameVi'),
            consumable: u['consumable'] == true,
            levels: [for (final l in _list(u, 'levels')) _upgradeLevel(l)],
          ),
      ],
      goalCardsPerDay = _int(j, 'dailyGoals.cardsPerDay'),
      goalTemplates = [
        for (final g in _list(j, 'dailyGoals.templates'))
          GoalTemplate(
            id: _str(g, 'id'),
            titleVi: _str(g, 'titleVi'),
            metric: _str(g, 'metric'),
            compare: _str(g, 'compare'),
            targetBase: _int(g, 'targetBase'),
            targetPerRank: _int(g, 'targetPerRank'),
            rewardBase: _int(g, 'rewardBase'),
            rewardPerRank: _int(g, 'rewardPerRank'),
            weight: _double(g, 'weight'),
            noHoliday: g['noHoliday'] == true,
            holidayOnly: g['holidayOnly'] == true,
            requiresUpgrade: (g['requires'] as Map?)?['upgrade'] as String?,
          ),
      ];

  factory Economy.fromJson(Map<String, dynamic> json) => Economy._(json);

  final int startCash;
  final double startRating;
  final List<String> unlockedFlowers;
  final List<String> unlockedPapers;
  final List<String> unlockedRibbons;

  final double dayRealSeconds;
  final int openHour;
  final int closeHour;
  final Map<String, int> fixedCosts;
  final Map<int, double> arrivalWeightsByHour;

  final double baseCustomersDay1;
  final double growthPerDay;
  final double baseCustomersCap;
  final Map<int, double> ratingFactor;
  final int ratingWindow;

  /// Outcome id to stars. `null` means no review (walkedPast).
  final Map<String, int?> reviewStars;
  final double patienceSeconds;
  final double patienceWarningAt;
  final double walkInSeconds;
  final int counterSlots;
  final int maxQueue;

  final double priceMultiplierDefault;

  final int maxStems;
  final double okayThreshold;
  final double greatThreshold;
  final Map<String, TierDef> tiers;
  final double fastServiceBonusPercent;
  final double fastServiceThreshold;

  final double weightSpecies;
  final double weightStemCount;
  final double weightPaper;
  final double weightRibbon;
  final double wrongSpeciesPenalty;
  final List<String> fillerSpecies;
  final Map<int, double> creditByDifference;
  final ChoiceScores paperScores;
  final ChoiceScores ribbonScores;
  final double wiltingPenalty;

  final double wrapFillSeconds;
  final double wrapBaseWidth;
  final double wrapNarrowPerRank;
  final double wrapMinWidth;
  final List<double> wrapCenterRange;
  final double wrapBonusPercent;
  final int wrapBonusMin;
  final double wrapAnimationSeconds;

  final List<ShopRankDef> shopRanks;
  final int minMarketBudget;

  final List<FlowerDef> flowers;
  final List<ItemDef> papers;
  final List<ItemDef> ribbons;
  final List<OccasionDef> occasions;

  final int yearLengthDays;
  final int posterDaysBefore;
  final int holidayPriceWindowDays;
  final List<HolidayDef> holidays;

  final List<UpgradeDef> upgrades;

  final int goalCardsPerDay;
  final List<GoalTemplate> goalTemplates;

  UpgradeDef upgrade(String id) => upgrades.firstWhere((u) => u.id == id);

  /// Real seconds per in-game hour.
  double get secondsPerHour => dayRealSeconds / (closeHour - openHour);

  int get fixedCostsTotal => fixedCosts.values.fold(0, (a, b) => a + b);

  FlowerDef flower(String id) => flowers.firstWhere((f) => f.id == id);
  ItemDef paper(String id) => papers.firstWhere((p) => p.id == id);
  ItemDef ribbon(String id) => ribbons.firstWhere((r) => r.id == id);
  OccasionDef occasion(String id) => occasions.firstWhere((o) => o.id == id);

  bool isFiller(String flowerId) => fillerSpecies.contains(flowerId);

  /// Rank from lifetime bouquets sold (`shopRanks`).
  ShopRankDef rankFor(int lifetimeBouquetsSold) {
    var best = shopRanks.first;
    for (final r in shopRanks) {
      if (lifetimeBouquetsSold >= r.minBouquetsSold) best = r;
    }
    return best;
  }

  /// Holiday on game [day] (1-based), repeating every [yearLengthDays].
  HolidayDef? holidayOn(int day) {
    final dayOfYear = ((day - 1) % yearLengthDays) + 1;
    for (final h in holidays) {
      if (h.days.contains(dayOfYear)) return h;
    }
    return null;
  }

  /// Next holiday strictly after [day] within [withinDays] days, with the
  /// number of days until it.
  (HolidayDef, int)? upcomingHoliday(int day, int withinDays) {
    for (var d = 1; d <= withinDays; d++) {
      final h = holidayOn(day + d);
      if (h != null) return (h, d);
    }
    return null;
  }

  /// Holiday whose market price rise applies on [day]: the holiday itself and
  /// the `holidayPriceWindowDays` days before it.
  HolidayDef? priceRiseHoliday(int day) {
    for (var d = 0; d <= holidayPriceWindowDays; d++) {
      final h = holidayOn(day + d);
      if (h != null) return h;
    }
    return null;
  }

  /// Market price of one bundle on [day] (`buyPrice × bundleSize`, times the
  /// holiday `marketPriceMultiplier` for featured flowers).
  int bundlePrice(FlowerDef f, int day) {
    final base = f.buyPrice * f.bundleSize;
    final h = priceRiseHoliday(day);
    if (h != null && h.featuredFlowers.contains(f.id)) {
      return (base * h.marketPriceMultiplier).round();
    }
    return base;
  }

  /// `ratingFactor`, linear between whole stars.
  double ratingFactorFor(double rating) {
    final r = rating.clamp(1.0, 5.0);
    final lo = r.floor();
    final hi = r.ceil();
    final a = ratingFactor[lo]!;
    if (lo == hi) return a;
    final b = ratingFactor[hi]!;
    return a + (b - a) * (r - lo);
  }

  /// Expected walk-in customers for [day] before holiday/upgrade multipliers.
  double baseCustomers(int day) {
    final v = baseCustomersDay1 + growthPerDay * (day - 1);
    return v < baseCustomersCap ? v : baseCustomersCap;
  }

  // ---- JSON helpers -------------------------------------------------------

  static Object? _get(Map<dynamic, dynamic> j, String path) {
    Object? cur = j;
    for (final part in path.split('.')) {
      if (cur is! Map || !cur.containsKey(part)) {
        throw FormatException('economy.json: missing "$path"');
      }
      cur = cur[part];
    }
    return cur;
  }

  static int _int(Map<dynamic, dynamic> j, String p) =>
      (_get(j, p) as num).toInt();
  static double _double(Map<dynamic, dynamic> j, String p) =>
      (_get(j, p) as num).toDouble();
  static String _str(Map<dynamic, dynamic> j, String p) => _get(j, p) as String;
  static List<Map<String, dynamic>> _list(Map<dynamic, dynamic> j, String p) =>
      (_get(j, p) as List).cast<Map<String, dynamic>>();
  static List<String> _strings(Map<dynamic, dynamic> j, String p) =>
      (_get(j, p) as List).cast<String>();
  static List<int> _ints(Map<dynamic, dynamic> j, String p) =>
      (_get(j, p) as List).map((e) => (e as num).toInt()).toList();
  static List<double> _doubles(Map<dynamic, dynamic> j, String p) =>
      (_get(j, p) as List).map((e) => (e as num).toDouble()).toList();
  static Map<String, double> _doubleMap(Map<dynamic, dynamic> j, String p) => {
    for (final e in (_get(j, p) as Map).entries)
      if (!(e.key as String).startsWith('_'))
        e.key as String: (e.value as num).toDouble(),
  };
  static Map<String, int> _intMap(Map<dynamic, dynamic> j, String p) => {
    for (final e in (_get(j, p) as Map).entries)
      if (!(e.key as String).startsWith('_'))
        e.key as String: (e.value as num).toInt(),
  };
  static ChoiceScores _choice(Map<dynamic, dynamic> j, String p) =>
      ChoiceScores(
        exact: _double(j, '$p.exact'),
        otherAccepted: _double(j, '$p.otherAcceptedForOccasion'),
        other: _double(j, '$p.other'),
      );
  static UpgradeLevel _upgradeLevel(Map<String, dynamic> l) {
    final rawEffect = (l['effect'] as Map<String, dynamic>?) ?? const {};
    final effect = <String, Object>{};
    Map<String, int> requires = const {};
    for (final e in rawEffect.entries) {
      if (e.key.startsWith('_')) continue;
      if (e.key == 'requires') {
        requires = {
          for (final r in (e.value as Map<String, dynamic>).entries)
            r.key: (r.value as num).toInt(),
        };
        continue;
      }
      if (e.value is num || e.value is bool || e.value is String) {
        effect[e.key] = e.value as Object;
      }
    }
    return UpgradeLevel(
      level: _int(l, 'level'),
      cost: _int(l, 'cost'),
      dailyUpkeep: (l['dailyUpkeep'] as num?)?.toInt() ?? 0,
      dailyWage: (l['dailyWage'] as num?)?.toInt() ?? 0,
      durationDays: (l['durationDays'] as num?)?.toInt(),
      nameVi: l['nameVi'] as String?,
      effect: effect,
      requires: requires,
    );
  }

  static List<ItemDef> _items(Map<dynamic, dynamic> j, String p) => [
    for (final i in _list(j, p))
      ItemDef(
        id: _str(i, 'id'),
        nameVi: _str(i, 'nameVi'),
        buyPrice: _int(i, 'buyPrice'),
        sellPrice: _int(i, 'sellPrice'),
        unlockCost: _int(i, 'unlockCost'),
      ),
  ];
}
