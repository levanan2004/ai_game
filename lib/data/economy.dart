/// Typed view of `assets/data/economy.json` (Hà Phương, v0.3-draft).
///
/// Every number the game uses comes from this file at runtime. Keys that
/// start with `_` are comments and are ignored. A missing required key throws
/// a [FormatException] naming the key, so a bad data file fails loudly.
library;

import 'pet_items.dart';
import 'rarity_rules.dart';

/// `alphaGift`: one-time mailbox gift for the alpha testers (uids in the
/// 8/10 export), to be sent after 10/10. Not sent by the game yet.
class AlphaGift {
  const AlphaGift({this.phaLe = 50, this.giotHoa = 10, this.coins = 100000});

  static const defaults = AlphaGift();

  final int phaLe;
  final int giotHoa;
  final int coins;

  /// Missing key or field keeps the default.
  factory AlphaGift.fromJson(Object? json) {
    if (json is! Map) return defaults;
    int pick(String k, int d) => (json[k] as num?)?.toInt() ?? d;
    return AlphaGift(
      phaLe: pick('phaLe', defaults.phaLe),
      giotHoa: pick('giotHoa', defaults.giotHoa),
      coins: pick('coins', defaults.coins),
    );
  }
}

/// `phaLePrices`: Pha lê prices for a future Pha lê shop (not wired yet).
class PhaLePrices {
  const PhaLePrices({this.petPot = 300});

  static const defaults = PhaLePrices();

  /// One thần thú / linh vật pot.
  final int petPot;

  factory PhaLePrices.fromJson(Object? json) {
    if (json is! Map) return defaults;
    return PhaLePrices(
      petPot: (json['petPot'] as num?)?.toInt() ?? defaults.petPot,
    );
  }
}

/// One pet of `pets.list`. [abilities] map an ability key to its value
/// at [au, lon, truong]; fractions are 0..1, `freshnessBonusDays` is days.
class PetDef {
  const PetDef({
    required this.id,
    required this.nameVi,
    required this.rarity,
    required this.price,
    required this.currency,
    required this.charmBase,
    this.abilities = const {},
  });

  final String id;
  final String nameVi;
  final String rarity;
  final int price;

  /// `coins` (xu) or `phaLe`.
  final String currency;
  final int charmBase;
  final Map<String, List<double>> abilities;

  bool get paysPhaLe => currency == 'phaLe';

  /// [key] at [stage] (0 ấu thú, 1 lớn, 2 trưởng thành). 0 when the pet
  /// has no such ability.
  double ability(String key, int stage) {
    final values = abilities[key];
    if (values == null || values.isEmpty) return 0;
    final i = stage < 0
        ? 0
        : (stage >= values.length ? values.length - 1 : stage);
    return values[i];
  }

  static PetDef? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final price = json['price'];
    if (id is! String || id.isEmpty || price is! num) return null;
    final raw = json['abilities'];
    final abilities = <String, List<double>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = entry.key;
        final list = entry.value;
        if (key is! String || key.startsWith('_') || list is! List) continue;
        abilities[key] = [
          for (final v in list)
            if (v is num) v.toDouble(),
        ];
      }
    }
    final name = json['nameVi'];
    final rarity = json['rarity'];
    final charm = json['charmBase'];
    return PetDef(
      id: id,
      nameVi: name is String ? name : id,
      rarity: rarity is String ? rarity : 'thuong',
      price: price.toInt(),
      currency: json['currency'] == 'phaLe' ? 'phaLe' : 'coins',
      charmBase: charm is num ? charm.toInt() : 0,
      abilities: abilities,
    );
  }
}

/// `charm.stageMultiplier`, 1 / 1.5 / 2 when the file has none.
List<double> _charmMultipliers(Object? json) {
  final raw = json is Map ? json['stageMultiplier'] : null;
  if (raw is List && raw.length >= 3 && raw.every((v) => v is num)) {
    return [for (final v in raw) (v as num).toDouble()];
  }
  return const [1.0, 1.5, 2.0];
}

/// `petCaps`: the most any pet effect may add, whatever the slots hold.
class PetCaps {
  const PetCaps({
    this.incomeBonus = 0.05,
    this.mysteryChance = 0.1,
    this.mouseCatch = 0.75,
  });

  static const defaults = PetCaps();

  final double incomeBonus;
  final double mysteryChance;
  final double mouseCatch;

  factory PetCaps.fromJson(Object? json) {
    if (json is! Map) return defaults;
    double pick(String k, double d) => (json[k] as num?)?.toDouble() ?? d;
    return PetCaps(
      incomeBonus: pick('incomeBonus', defaults.incomeBonus),
      mysteryChance: pick('mysteryChance', defaults.mysteryChance),
      mouseCatch: pick('mouseCatch', defaults.mouseCatch),
    );
  }
}

List<PetDef> _petList(Object? json) {
  final list = json is Map ? json['list'] : null;
  if (list is! List) return const [];
  return [for (final item in list) ?PetDef.fromJson(item)];
}

/// A decorative pot. [unlimited] means every shelf slot may use it.
class PotDef {
  const PotDef({
    required this.id,
    required this.nameVi,
    required this.price,
    required this.unlimited,
    this.set,
    this.currency = 'coins',
    this.phaLePrice = 0,
    this.howVi,
    this.shortVi,
  });

  final String id;
  final String nameVi;

  /// Cost in xu. 0 for the free bucket and for pots paid in Pha lê.
  final int price;
  final bool unlimited;

  /// `coins` (default) or `phaLe`. A `phaLe` pot is paid from the same Pha lê
  /// balance as the pet shop and has no xu price.
  final String currency;

  /// Cost in Pha lê when [currency] is `phaLe`, else 0.
  final int phaLePrice;

  /// Short "how to get" label for the catalog (`Mua 250 Pha lê`).
  final String? howVi;

  /// Name for a grid cell, without the word "Chậu" (`Sư Tử`). Data only for
  /// now: the Kho chậu still shows [nameVi].
  final String? shortVi;

  /// Set the pot belongs to (`linhVat`, `chomSao`, `sonHai`); null for the
  /// free bucket. Names are in [Economy.potSets].
  final String? set;

  /// Paid in Pha lê rather than xu.
  bool get paysPhaLe => currency == 'phaLe';

  /// What one costs, in xu or in Pha lê depending on [paysPhaLe].
  int get cost => paysPhaLe ? phaLePrice : price;

  /// Can be bought. A pot with no price in its currency is in the catalog
  /// only: it has art and a name but no way to get it yet.
  bool get purchasable => !unlimited && cost > 0;

  /// Display scale of the art, from [potScaleBySet].
  double get potScale => potScaleBySet[set] ?? 1.0;
}

/// Display scale of a pot's art per set. Phú drew the Chòm sao and Sơn Hải
/// pots about 10% smaller in the same canvas as the old Linh vật pots, so
/// they are drawn 1.1 times larger to match. Change a number here to retune.
const Map<String, double> potScaleBySet = {
  'linhVat': 1.0,
  'chomSao': 1.1,
  'sonHai': 1.1,
};

/// A named set of pots (`potSets`).
class PotSetDef {
  const PotSetDef({required this.id, required this.nameVi});
  final String id;
  final String nameVi;
}

/// Pha lê reward for owning every pot of a set once (`potCollections`).
/// Data only: there is no claim screen yet.
class PotCollectionDef {
  const PotCollectionDef({
    required this.id,
    required this.nameVi,
    required this.rewardPhaLe,
    required this.pots,
  });
  final String id;
  final String nameVi;
  final int rewardPhaLe;
  final List<String> pots;
}

List<PotSetDef> _potSetList(Object? json) => [
  if (json is List)
    for (final s in json)
      if (s is Map && s['id'] is String && s['nameVi'] is String)
        PotSetDef(id: s['id'] as String, nameVi: s['nameVi'] as String),
];

List<PotCollectionDef> _potCollectionList(Object? json) {
  final list = json is Map ? json['list'] : null;
  return [
    if (list is List)
      for (final c in list)
        if (c is Map && c['id'] is String && c['pots'] is List)
          PotCollectionDef(
            id: c['id'] as String,
            nameVi: (c['nameVi'] as String?) ?? c['id'] as String,
            rewardPhaLe:
                ((c['reward'] as Map?)?['phaLe'] as num?)?.toInt() ?? 0,
            pots: (c['pots'] as List).cast<String>(),
          ),
  ];
}

/// A flower with art (fresh and wilted) that is not in the game yet: no
/// price, freshness or unlock, so it is not in `flowers`.
class NewFlowerDef {
  const NewFlowerDef({required this.id, required this.nameVi});

  final String id;
  final String nameVi;
}

List<NewFlowerDef> _newFlowerList(Object? json) {
  final list = json is Map ? json['list'] : null;
  if (list is! List) return const [];
  return [
    for (final f in list)
      if (f is Map && f['id'] is String && f['nameVi'] is String)
        NewFlowerDef(id: f['id'] as String, nameVi: f['nameVi'] as String),
  ];
}

/// One seed packet. [stepMinutes] is the real-world wait before the next
/// watering. Two waterings finish the plant. Missing that wait again wilts it.
class GardenSeedDef {
  const GardenSeedDef({
    required this.id,
    required this.price,
    required this.yieldStems,
    required this.stepMinutes,
  });

  final String id;
  final int price;
  final int yieldStems;
  final int stepMinutes;
}

class FlowerDef {
  const FlowerDef({
    required this.id,
    required this.nameVi,
    required this.buyPrice,
    required this.sellPrice,
    required this.freshnessDays,
    required this.bundleSize,
    required this.unlockCost,
    this.wiltedArt = false,
  });

  final String id;
  final String nameVi;
  final int buyPrice;
  final int sellPrice;
  final int freshnessDays;
  final int bundleSize;
  final int unlockCost;

  /// Has its own wilted picture (`flowers/<id>_heo.webp`, [Art.flowerWilted]).
  /// Flowers without one only droop.
  final bool wiltedArt;
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

  /// Short date for the top-bar day pill ("Lễ tình nhân 14/2" -> "14/2").
  /// Names without a date (e.g. "Tết") are shown as they are.
  String get shortLabel =>
      RegExp(r'\d{1,2}/\d{1,2}').allMatches(nameVi).lastOrNull?.group(0) ??
      nameVi;
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
    this.requiresShippersHired = 0,
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

  /// `requires.shippersHired`: the card is offered only once this many
  /// shippers are hired. 0 means no shipper requirement.
  final int requiresShippersHired;
}

class ShipperUnlock {
  const ShipperUnlock({this.day, this.rank, this.shipper});

  final int? day;
  final int? rank;

  /// Another shipper id that must already be hired.
  final String? shipper;
}

class ShipperLevelDef {
  const ShipperLevelDef({
    required this.level,
    required this.nameVi,
    required this.cost,
    required this.deliverSeconds,
    required this.returnSeconds,
    required this.capacity,
  });

  final int level;
  final String nameVi;
  final int cost;
  final double deliverSeconds;
  final double returnSeconds;
  final int capacity;
}

class ShipperDef {
  const ShipperDef({
    required this.id,
    required this.nameVi,
    required this.unlock,
    required this.hireCost,
    required this.dailyWage,
    required this.demandBonusPerDay,
    required this.levels,
  });

  final String id;
  final String nameVi;
  final ShipperUnlock unlock;
  final int hireCost;
  final int dailyWage;
  final double demandBonusPerDay;
  final List<ShipperLevelDef> levels;

  ShipperLevelDef? levelDef(int level) {
    if (level <= 0 || level > levels.length) return null;
    return levels[level - 1];
  }
}

/// `delivery` in economy.json: online orders and the three shippers.
class DeliveryRules {
  const DeliveryRules({
    required this.unlockRule,
    required this.ordersBase,
    required this.ordersPerRank,
    required this.holidayMultiplier,
    required this.ordersCap,
    required this.preorderShare,
    required this.deadlineHours,
    required this.maxBoard,
    required this.samedayShare,
    required this.spawnHourStart,
    required this.spawnHourEnd,
    required this.acceptSeconds,
    required this.deadlineSeconds,
    required this.maxPending,
    required this.acceptRequiresStock,
    required this.stemRange,
    required this.deliveryFee,
    required this.onlinePriceMultiplier,
    required this.latePayFactor,
    required this.lateDeliveryFee,
    required this.lateTip,
    required this.lateReview,
    required this.missedMoneyPenalty,
    required this.missedReview,
    required this.autoAssign,
    required this.loadWaitSeconds,
    required this.extraStopSeconds,
    required this.shippers,
  });

  final String unlockRule;
  final double ordersBase;
  final double ordersPerRank;
  final double holidayMultiplier;
  final int ordersCap;
  final double preorderShare;
  final List<int> deadlineHours;
  final int maxBoard;
  final double samedayShare;
  final int spawnHourStart;
  final int spawnHourEnd;
  final double acceptSeconds;
  final double deadlineSeconds;
  final int maxPending;
  final bool acceptRequiresStock;
  final List<int> stemRange;
  final int deliveryFee;
  final double onlinePriceMultiplier;
  final double latePayFactor;
  final int lateDeliveryFee;
  final int lateTip;
  final String lateReview;
  final int missedMoneyPenalty;
  final String missedReview;
  final bool autoAssign;
  final double loadWaitSeconds;
  final double extraStopSeconds;
  final List<ShipperDef> shippers;

  ShipperDef shipper(String id) => shippers.firstWhere((s) => s.id == id);
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
      pricesOpenDay = _int(j, 'pricing.openDay'),
      priceMultiplierMin = _double(j, 'pricing.priceMultiplier.min'),
      priceMultiplierMax = _double(j, 'pricing.priceMultiplier.max'),
      priceMultiplierStep = _double(j, 'pricing.priceMultiplier.step'),
      priceAboveSlope = _double(j, 'pricing.priceDemandFactor.aboveSlope'),
      priceBelowSlope = _double(j, 'pricing.priceDemandFactor.belowSlope'),
      pricePatienceSlope = _double(
        j,
        'pricing.priceDemandFactor.patienceSlope',
      ),
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
      cardNoteTip = _int(j, 'cardNote.tip'),
      cardNoteSuggestions = _stringListMap(j, 'cardNote.suggestions'),
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
            wiltedArt: f['wiltedArt'] == true,
          ),
      ],
      pots = j['pots'] is List
          ? [
              for (final p in _list(j, 'pots'))
                PotDef(
                  id: _str(p, 'id'),
                  nameVi: _str(p, 'nameVi'),
                  price: p['price'] is num ? (p['price'] as num).toInt() : 0,
                  unlimited: p['unlimited'] == true,
                  set: p['set'] is String ? p['set'] as String : null,
                  currency: p['currency'] == 'phaLe' ? 'phaLe' : 'coins',
                  phaLePrice: p['phaLePrice'] is num
                      ? (p['phaLePrice'] as num).toInt()
                      : 0,
                  howVi: p['howVi'] is String ? p['howVi'] as String : null,
                  shortVi: p['shortVi'] is String
                      ? p['shortVi'] as String
                      : null,
                ),
            ]
          : const [
              PotDef(id: 'sage', nameVi: 'Xô xanh', price: 0, unlimited: true),
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
            requiresShippersHired:
                ((g['requires'] as Map?)?['shippersHired'] as num?)?.toInt() ??
                0,
          ),
      ],
      gardenPlotCount = _int(j, 'garden.plotCount'),
      gardenOpenDay = _int(j, 'garden.openDay'),
      gardenPlotBuyDay = _int(j, 'garden.plotBuyDay'),
      gardenMaxPlots = _int(j, 'garden.maxPlots'),
      shovelPrice = _int(j, 'garden.shovelPrice'),
      extraPlotBase = _int(j, 'garden.extraPlotBase'),
      extraPlotStep = _int(j, 'garden.extraPlotStep'),
      gardenSeeds = [
        for (final s in _list(j, 'garden.seeds'))
          GardenSeedDef(
            id: _str(s, 'id'),
            price: _int(s, 'price'),
            yieldStems: _int(s, 'yield'),
            stepMinutes: _int(s, 'stepMinutes'),
          ),
      ],
      delivery = _delivery(j),
      rewardRarity = RarityRules.fromJson(j['rewardRarity']),
      phaLePrices = PhaLePrices.fromJson(j['phaLePrices']),
      alphaGift = AlphaGift.fromJson(j['alphaGift']),
      newFlowers = _newFlowerList(j['newFlowers']),
      potSets = _potSetList(j['potSets']),
      potCollections = _potCollectionList(j['potCollections']),
      pets = _petList(j['pets']),
      petCaps = PetCaps.fromJson(j['petCaps']),
      charmStageMultiplier = _charmMultipliers(j['charm']),
      petItemRules = PetItemRules.fromJson(j['charm']),
      petItems = petItemList(j['petItems']);

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
  final double priceMultiplierMin;
  final double priceMultiplierMax;
  final double priceMultiplierStep;

  /// Morning Giá bán starts working. Earlier taps say which day.
  final int pricesOpenDay;

  /// `pricing.priceDemandFactor`: dearer prices thin the crowd and shorten
  /// patience. A cheaper price only brings more customers.
  final double priceAboveSlope;
  final double priceBelowSlope;
  final double pricePatienceSlope;

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

  /// Theme card on a bouquet (`cardNote` in economy.json): the tip for the
  /// right theme and the line written for each occasion.
  final int cardNoteTip;
  final Map<String, List<String>> cardNoteSuggestions;

  final List<ShopRankDef> shopRanks;
  final int minMarketBudget;

  /// Beds a new garden starts with. They are dry until a shovel is used.
  final int gardenPlotCount;

  /// First morning the yard can be opened.
  final int gardenOpenDay;

  /// First morning an extra bed can be bought.
  final int gardenPlotBuyDay;

  /// Beds after [gardenPlotCount], up to this many.
  final int gardenMaxPlots;

  /// One shovel turns one dry bed into fresh soil.
  final int shovelPrice;

  /// Price of the first bed past [gardenPlotCount].
  final int extraPlotBase;

  /// Added for each bed after the first extra one.
  final int extraPlotStep;

  final List<GardenSeedDef> gardenSeeds;

  final List<FlowerDef> flowers;
  final List<PotDef> pots;

  /// `potSets`: names of the pot sets (`linhVat`, `chomSao`, `sonHai`).
  final List<PotSetDef> potSets;

  /// `potCollections`: one-time Pha lê reward per complete set. Data only.
  final List<PotCollectionDef> potCollections;

  /// `newFlowers`: Phú's dot 2 flowers, in the catalog but not playable.
  final List<NewFlowerDef> newFlowers;
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
  final DeliveryRules delivery;

  /// `rewardRarity`: amount tiers for the reward frames. Optional; missing
  /// keys keep [RarityRules.defaults].
  final RarityRules rewardRarity;

  /// `phaLePrices` (optional): future Pha lê shop prices.
  final PhaLePrices phaLePrices;

  /// `alphaGift` (optional): the alpha testers' mailbox gift.
  final AlphaGift alphaGift;

  /// `pets.list`: every pet the pet shop sells, in file order.
  final List<PetDef> pets;

  /// `petCaps`: limits on the income-slot pet's effects.
  final PetCaps petCaps;

  /// `charm.itemSlots` and `charm.itemCharmByRarity`.
  final PetItemRules petItemRules;

  /// `petItems.list`: empty until the item catalog is decided.
  final List<PetItemDef> petItems;

  PetItemDef? petItem(String id) {
    for (final i in petItems) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// `charm.stageMultiplier`: Mị lực by stage (ấu thú, lớn, trưởng thành).
  final List<double> charmStageMultiplier;

  PetDef? pet(String id) {
    for (final p in pets) {
      if (p.id == id) return p;
    }
    return null;
  }

  UpgradeDef upgrade(String id) => upgrades.firstWhere((u) => u.id == id);

  /// Real seconds per in-game hour.
  double get secondsPerHour => dayRealSeconds / (closeHour - openHour);

  int get fixedCostsTotal => fixedCosts.values.fold(0, (a, b) => a + b);

  FlowerDef flower(String id) => flowers.firstWhere((f) => f.id == id);

  GardenSeedDef? gardenSeed(String id) {
    for (final s in gardenSeeds) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Price of the next bed when [ownedPlots] beds already exist.
  int gardenPlotPrice(int ownedPlots) {
    final extra = ownedPlots - gardenPlotCount;
    final steps = extra < 0 ? 0 : extra;
    return extraPlotBase + steps * extraPlotStep;
  }

  PotDef pot(String id) => pots.firstWhere((p) => p.id == id);
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
  static Map<String, List<String>> _stringListMap(
    Map<dynamic, dynamic> j,
    String p,
  ) => {
    for (final e in (_get(j, p) as Map).entries)
      if (!(e.key as String).startsWith('_'))
        e.key as String: (e.value as List).cast<String>(),
  };
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

  static DeliveryRules _delivery(Map<dynamic, dynamic> j) {
    final spawn = _ints(j, 'delivery.orders.sameday.spawnHours');
    final stem = _ints(j, 'delivery.orders.stemRange');
    return DeliveryRules(
      unlockRule: _str(j, 'delivery.unlock.rule'),
      ordersBase: _double(j, 'delivery.orders.perDay.base'),
      ordersPerRank: _double(j, 'delivery.orders.perDay.perRank'),
      holidayMultiplier: _double(j, 'delivery.orders.perDay.holidayMultiplier'),
      ordersCap: _int(j, 'delivery.orders.perDay.cap'),
      preorderShare: _double(j, 'delivery.orders.preorder.share'),
      deadlineHours: _ints(j, 'delivery.orders.preorder.deadlineHours'),
      maxBoard: _int(j, 'delivery.orders.preorder.maxBoard'),
      samedayShare: _double(j, 'delivery.orders.sameday.share'),
      spawnHourStart: spawn[0],
      spawnHourEnd: spawn[1],
      acceptSeconds: _double(j, 'delivery.orders.sameday.acceptSeconds'),
      deadlineSeconds: _double(j, 'delivery.orders.sameday.deadlineSeconds'),
      maxPending: _int(j, 'delivery.orders.sameday.maxPending'),
      acceptRequiresStock:
          _get(j, 'delivery.orders.acceptRequiresStock') == true,
      stemRange: stem,
      deliveryFee: _int(j, 'delivery.payment.deliveryFee'),
      onlinePriceMultiplier: _double(
        j,
        'delivery.payment.onlinePriceMultiplier',
      ),
      latePayFactor: _double(j, 'delivery.late.payFactor'),
      lateDeliveryFee: _int(j, 'delivery.late.deliveryFee'),
      lateTip: _int(j, 'delivery.late.tip'),
      lateReview: _str(j, 'delivery.late.review'),
      missedMoneyPenalty: _int(j, 'delivery.missed.moneyPenalty'),
      missedReview: _str(j, 'delivery.missed.review'),
      autoAssign: _get(j, 'delivery.assignment.autoAssign') == true,
      loadWaitSeconds: _double(j, 'delivery.assignment.loadWaitSeconds'),
      extraStopSeconds: _double(j, 'delivery.assignment.extraStopSeconds'),
      shippers: [
        for (final s in _list(j, 'delivery.shippers'))
          ShipperDef(
            id: _str(s, 'id'),
            nameVi: _str(s, 'nameVi'),
            unlock: ShipperUnlock(
              day: ((s['unlock'] as Map?)?['day'] as num?)?.toInt(),
              rank: ((s['unlock'] as Map?)?['rank'] as num?)?.toInt(),
              shipper: (s['unlock'] as Map?)?['shipper'] as String?,
            ),
            hireCost: _int(s, 'hireCost'),
            dailyWage: _int(s, 'dailyWage'),
            demandBonusPerDay: _double(s, 'demandBonusPerDay'),
            levels: [
              for (final l in _list(s, 'levels'))
                ShipperLevelDef(
                  level: _int(l, 'level'),
                  nameVi: _str(l, 'nameVi'),
                  cost: _int(l, 'cost'),
                  deliverSeconds: _double(l, 'deliverSeconds'),
                  returnSeconds: _double(l, 'returnSeconds'),
                  capacity: _int(l, 'capacity'),
                ),
            ],
          ),
      ],
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
