/// Pet items (pet_thuoc_tinh.md): they only add Mị lực. Every pet has three
/// equip slots (`neck`, `head`, `accessory`) and an item fits one of them.
/// Which items exist and how they are obtained is not decided yet, so
/// `petItems.list` in economy.json is empty; tests bring their own catalog.
library;

/// The four tiers, cheapest first. [key] is the id used in the data files.
enum PetItemTier {
  thuong('thuong', 5),
  hiem('hiem', 15),
  suThi('suThi', 40),
  huyenThoai('huyenThoai', 100);

  const PetItemTier(this.key, this.defaultCharm);

  final String key;

  /// Mị lực used when the data file has no `charm.itemCharmByRarity`.
  final int defaultCharm;

  static PetItemTier? fromKey(Object? key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

/// The equip slots of a pet when the data file has no `charm.itemSlots`.
const defaultPetItemSlots = ['neck', 'head', 'accessory'];

/// `charm.itemSlots` and `charm.itemCharmByRarity`: how much an item adds.
class PetItemRules {
  const PetItemRules({
    this.slots = defaultPetItemSlots,
    this.charmByTier = const {},
  });

  static const defaults = PetItemRules();

  final List<String> slots;
  final Map<PetItemTier, int> charmByTier;

  /// Mị lực a worn item of [tier] adds.
  int charmOfTier(PetItemTier tier) => charmByTier[tier] ?? tier.defaultCharm;

  factory PetItemRules.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final rawSlots = json['itemSlots'];
    final slots = rawSlots is List
        ? [
            for (final s in rawSlots)
              if (s is String && s.isNotEmpty) s,
          ]
        : <String>[];
    final byTier = <PetItemTier, int>{};
    final raw = json['itemCharmByRarity'];
    if (raw is Map) {
      for (final tier in PetItemTier.values) {
        final v = raw[tier.key];
        if (v is num && v >= 0) byTier[tier] = v.toInt();
      }
    }
    return PetItemRules(
      slots: slots.isEmpty ? defaultPetItemSlots : slots,
      charmByTier: byTier,
    );
  }
}

/// One entry of `petItems.list`. Mị lực comes from the tier
/// ([PetItemRules.charmOfTier]); the file's own `charm` is only a check.
class PetItemDef {
  const PetItemDef({
    required this.id,
    required this.nameVi,
    required this.tier,
    required this.slot,
    this.description = '',
    this.price = 0,
    this.currency = 'coins',
    this.resaleValue = -1,
  });

  final String id;
  final String nameVi;
  final PetItemTier tier;

  /// One of [PetItemRules.slots]. An item fits this slot only.
  final String slot;
  final String description;

  /// Shop price in [currency] (`coins` or `phaLe`).
  final int price;
  final String currency;

  /// What one copy sells back for, in [currency] (`resaleValue`); -1 when
  /// the file has none and [petItemSellValue] uses the rate.
  final int resaleValue;

  bool get paysPhaLe => currency == 'phaLe';

  static PetItemDef? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final tier = PetItemTier.fromKey(json['rarity'] ?? json['tier']);
    final slot = json['slot'];
    if (id is! String || id.isEmpty || tier == null || slot is! String) {
      return null;
    }
    final name = json['nameVi'];
    final desc = json['description'];
    final price = json['price'];
    return PetItemDef(
      id: id,
      nameVi: name is String ? name : id,
      tier: tier,
      slot: slot,
      description: desc is String ? desc : '',
      price: price is num && price >= 0 ? price.toInt() : 0,
      currency: json['currency'] == 'phaLe' ? 'phaLe' : 'coins',
      resaleValue: json['resaleValue'] is num && json['resaleValue'] >= 0
          ? (json['resaleValue'] as num).toInt()
          : -1,
    );
  }
}

/// What one copy sells back for: [rate] (petItems.resaleRate, 0.3) of the
/// item's CURRENT price, rounded down, in the item's own currency. It is read
/// from the live price at the moment of the sale, never from what the player
/// paid, so a price change moves the resale with it. The same for a bought
/// item, a mystery visitor's and a rank reward. The file's resaleValue is
/// only a cross-check kept equal to this (a test guards it).
int petItemSellValue(PetItemDef item, double rate) =>
    (item.price * rate + 1e-9).floor();

/// `petItems.list`; entries that are malformed or repeat an id are skipped.
List<PetItemDef> petItemList(Object? json) {
  final list = json is Map ? json['list'] : null;
  if (list is! List) return const [];
  final seen = <String>{};
  final out = <PetItemDef>[];
  for (final item in list) {
    final def = PetItemDef.fromJson(item);
    if (def != null && seen.add(def.id)) out.add(def);
  }
  return out;
}

/// Mị lực of what a pet wears. [worn] maps a slot to an item id; an id the
/// catalog does not know (an item removed later) or one sitting in the wrong
/// slot adds nothing, so an old save can never break the score.
int wornItemsCharm(
  Map<String, String> worn,
  PetItemRules rules,
  PetItemDef? Function(String id) find,
) {
  var sum = 0;
  for (final slot in rules.slots) {
    final id = worn[slot];
    if (id == null) continue;
    final def = find(id);
    if (def == null || def.slot != slot) continue;
    sum += rules.charmOfTier(def.tier);
  }
  return sum;
}
