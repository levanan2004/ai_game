/// Data of the new pot features (Hà Phương, tinh_nang_moi_block_v2,
/// 17/10/2026): Mị lực parts, pot stats on the shelf, the weekly wheel and
/// the VIP tiers. Numbers live in economy.json only; these classes read them
/// with safe defaults (0 / empty) when a block is missing.
library;

/// Keys of `pots[].stats`, as named in `potStatsRules.keys`. A stat the pets
/// already had keeps the pet's name (`mysteryChance`, `mouseCatch`,
/// `patienceBonus`, `incomeBonus`, `theftRecoverBonus`).
abstract final class PotStat {
  static const incomeBonus = 'incomeBonus';
  static const tipBonus = 'tipBonus';
  static const onlineOrderBonus = 'onlineOrderBonus';
  static const theftRecoverBonus = 'theftRecoverBonus';
  static const mouseCatch = 'mouseCatch';
  static const patienceBonus = 'patienceBonus';
  static const wiltSaveChance = 'wiltSaveChance';
  static const marketDiscount = 'marketDiscount';
  static const wrapSpeedBonus = 'wrapSpeedBonus';
  static const mysteryChance = 'mysteryChance';

  static const all = [
    incomeBonus,
    tipBonus,
    onlineOrderBonus,
    theftRecoverBonus,
    mouseCatch,
    patienceBonus,
    wiltSaveChance,
    marketDiscount,
    wrapSpeedBonus,
    mysteryChance,
  ];
}

/// `pots[].stats`: known keys with a number; anything else is dropped.
Map<String, double> potStatsFromJson(Object? json) {
  if (json is! Map) return const {};
  return {
    for (final k in PotStat.all)
      if (json[k] is num && (json[k] as num) != 0)
        k: (json[k] as num).toDouble(),
  };
}

/// `charm`: how Mị lực is made of three parts, each clamped to its max.
/// There is no overall cap.
class CharmRules {
  const CharmRules({
    this.petMax = 0,
    this.petItemsMax = 0,
    this.potsMax = 0,
    this.sonHaiCharmPerType = 0,
  });

  /// Nothing read: every part adds 0 until economy.json has the block.
  static const none = CharmRules();

  /// `charm.partMax.pet`: the charm-slot pet (base x stage).
  final int petMax;

  /// `charm.partMax.petItems`: the items that pet wears.
  final int petItemsMax;

  /// `charm.partMax.sonHaiPots`: owned pot types.
  final int potsMax;

  /// `charm.sonHaiCharmPerType`: what an owned Sơn Hải type adds when its
  /// pot entry has no `charm` of its own.
  final int sonHaiCharmPerType;

  factory CharmRules.fromJson(Object? json) {
    if (json is! Map) return none;
    final part = json['partMax'];
    int n(Object? v) => v is num && v > 0 ? v.toInt() : 0;
    return CharmRules(
      petMax: part is Map ? n(part['pet']) : 0,
      petItemsMax: part is Map ? n(part['petItems']) : 0,
      potsMax: part is Map ? n(part['sonHaiPots']) : 0,
      sonHaiCharmPerType: n(json['sonHaiCharmPerType']),
    );
  }

  /// The most a player can reach (the three maxes added up).
  int get total => petMax + petItemsMax + potsMax;
}

/// `potStatsRules`: pot stats count only while the pot is on the shelf.
class PotStatsRules {
  const PotStatsRules({this.shelfSlots = 0});

  /// `shelfSlots`: bar + display slots (11).
  final int shelfSlots;

  factory PotStatsRules.fromJson(Object? json) => PotStatsRules(
    shelfSlots: json is Map && json['shelfSlots'] is num
        ? (json['shelfSlots'] as num).toInt()
        : 0,
  );
}

/// One line of `gacha.table_permyriad` (weights out of 10.000).
class GachaEntry {
  const GachaEntry({
    required this.weight,
    this.item,
    this.coins = 0,
    this.giotHoa = 0,
    this.banhMat = 0,
    this.split = const [],
    this.splitNote,
    this.ifOwnedCoins = 0,
  });

  final int weight;

  /// `potOfWeek`, `petItemRare`, `chomSaoPot`, `petItemCommon`; null for a
  /// plain currency line.
  final String? item;
  final int coins;
  final int giotHoa;
  final int banhMat;

  /// Item ids the prize is drawn from, when listed.
  final List<String> split;

  /// `split` given as words rather than ids ("12 chậu Hoàng đạo").
  final String? splitNote;

  /// `ifOwned.coins`: what the pot of the week turns into when owned.
  final int ifOwnedCoins;

  factory GachaEntry.fromJson(Map json) {
    int n(Object? v) => v is num ? v.toInt() : 0;
    final split = json['split'];
    final owned = json['ifOwned'];
    return GachaEntry(
      weight: n(json['w']),
      item: json['item'] is String ? json['item'] as String : null,
      coins: n(json['coins']),
      giotHoa: n(json['giotHoa']),
      banhMat: n(json['banhMat']),
      split: split is List ? split.whereType<String>().toList() : const [],
      splitNote: split is String ? split : null,
      ifOwnedCoins: owned is Map ? n(owned['coins']) : 0,
    );
  }
}

/// `gacha.ticketPrice.coinsByDay`: xu per ticket from a play day on.
class GachaCoinPrice {
  const GachaCoinPrice({
    required this.fromDay,
    this.toDay,
    required this.coins,
  });

  final int fromDay;

  /// null: no end.
  final int? toDay;
  final int coins;
}

/// `gacha`: the weekly wheel (data only; no wheel yet).
class GachaConfig {
  const GachaConfig({
    this.weeklyRotation = const [],
    this.rotationRepeat = false,
    this.ticketPerPot = false,
    this.pityPerPot = false,
    this.pityCarryOver = false,
    this.pityAt = 0,
    this.ticketPhaLe = 0,
    this.coinsByDay = const [],
    this.maxCoinTicketsPerDay = 0,
    this.giftTicketBecomesCurrentWeekPot = false,
    this.table = const [],
    this.assetIdByPot = const {},
  });

  static const none = GachaConfig();

  /// Pot ids, one per week, in order.
  final List<String> weeklyRotation;
  final bool rotationRepeat;
  final bool ticketPerPot;
  final bool pityPerPot;
  final bool pityCarryOver;
  final int pityAt;
  final int ticketPhaLe;
  final List<GachaCoinPrice> coinsByDay;
  final int maxCoinTicketsPerDay;
  final bool giftTicketBecomesCurrentWeekPot;
  final List<GachaEntry> table;

  /// Game pot id -> Phú's art folder name.
  final Map<String, String> assetIdByPot;

  int get tableWeight => table.fold(0, (a, b) => a + b.weight);

  /// Xu price of one ticket on play [day], or 0 when no line covers it.
  int ticketCoinsOnDay(int day) {
    for (final p in coinsByDay) {
      if (day >= p.fromDay && (p.toDay == null || day <= p.toDay!)) {
        return p.coins;
      }
    }
    return 0;
  }

  factory GachaConfig.fromJson(Object? json) {
    if (json is! Map) return none;
    int n(Object? v) => v is num ? v.toInt() : 0;
    final price = json['ticketPrice'] is Map ? json['ticketPrice'] as Map : {};
    final assets = json['assetIdByPot'];
    return GachaConfig(
      weeklyRotation: json['weeklyRotation'] is List
          ? (json['weeklyRotation'] as List).whereType<String>().toList()
          : const [],
      rotationRepeat: json['rotationRepeat'] == true,
      ticketPerPot: json['ticketPerPot'] == true,
      pityPerPot: json['pityPerPot'] == true,
      pityCarryOver: json['pityCarryOver'] == true,
      pityAt: n(json['pityAt']),
      ticketPhaLe: n(price['phaLe']),
      coinsByDay: [
        for (final p
            in (price['coinsByDay'] is List
                ? price['coinsByDay'] as List
                : const []))
          if (p is Map)
            GachaCoinPrice(
              fromDay: n(p['fromDay']),
              toDay: p['toDay'] is num ? (p['toDay'] as num).toInt() : null,
              coins: n(p['coins']),
            ),
      ],
      maxCoinTicketsPerDay: n(price['maxCoinTicketsPerDay']),
      giftTicketBecomesCurrentWeekPot:
          json['giftTicketBecomesCurrentWeekPot'] == true,
      table: [
        for (final e
            in (json['table_permyriad'] is List
                ? json['table_permyriad'] as List
                : const []))
          if (e is Map) GachaEntry.fromJson(e),
      ],
      assetIdByPot: assets is Map
          ? {
              for (final e in assets.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            }
          : const {},
    );
  }
}

/// One `vip.tiers` line.
class VipTier {
  const VipTier({
    required this.level,
    required this.minVnd,
    required this.giftTickets,
    required this.frame,
  });

  final int level;
  final int minVnd;
  final int giftTickets;
  final String frame;
}

/// A `vip.vipPots` entry: the VIP level that gives the pot.
class VipPot {
  const VipPot({required this.level, this.charm = 0, this.stats = const {}});

  final int level;
  final int charm;
  final Map<String, double> stats;
}

/// `vip`: tiers by total VND topped up (data only; no VIP screen yet).
class VipConfig {
  const VipConfig({
    this.tiers = const [],
    this.giftTicketsTotal = 0,
    this.pots = const {},
  });

  static const none = VipConfig();

  /// Lowest level first.
  final List<VipTier> tiers;
  final int giftTicketsTotal;
  final Map<String, VipPot> pots;

  /// Level reached with [vnd] topped up; 0 below the first tier.
  int levelFor(int vnd) {
    var level = 0;
    for (final t in tiers) {
      if (vnd >= t.minVnd && t.level > level) level = t.level;
    }
    return level;
  }

  factory VipConfig.fromJson(Object? json) {
    if (json is! Map) return none;
    int n(Object? v) => v is num ? v.toInt() : 0;
    final tiers = [
      for (final t
          in (json['tiers'] is List ? json['tiers'] as List : const []))
        if (t is Map)
          VipTier(
            level: n(t['level']),
            minVnd: n(t['minVnd']),
            giftTickets: n(t['giftTickets']),
            frame: t['frame'] is String ? t['frame'] as String : '',
          ),
    ]..sort((a, b) => a.level.compareTo(b.level));
    final pots = json['vipPots'];
    return VipConfig(
      tiers: tiers,
      giftTicketsTotal: n(json['giftTicketsTotal']),
      pots: pots is Map
          ? {
              for (final e in pots.entries)
                if (e.key is String && e.value is Map)
                  e.key as String: VipPot(
                    level: n((e.value as Map)['level']),
                    charm: n((e.value as Map)['charm']),
                    stats: potStatsFromJson((e.value as Map)['stats']),
                  ),
            }
          : const {},
    );
  }
}
