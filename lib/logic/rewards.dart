import 'package:flutter/foundation.dart';

import '../save/game_state.dart';
import 'pet.dart';
import 'xu_grant.dart';

/// One shared reward model for every place that hands out gifts: admin
/// gifts and grants today, the gift mailbox, 7-day login rewards and
/// giftcodes later. Build a [RewardBundle], then call
/// `ShopSession.grantRewards`.
///
/// JSON shape (the same for every source):
/// `{"items": [{"kind": "coins", "amount": 5000},
///             {"kind": "pot", "id": "dragon", "amount": 1}]}`
/// Unknown kinds and broken items are skipped, never thrown, so an older
/// build can still read a bundle written by a newer one.
enum RewardKind {
  /// Xu, added to the shop money.
  coins('coins'),

  /// Giọt hoa (the pet's breakthrough drops).
  giotHoa('giotHoa'),

  /// Pha lê, a currency with no shop yet. Only rewards give it.
  phaLe('phaLe'),

  /// One paid pot by economy id. Stacks like buying one.
  pot('pot'),

  /// Pet food by treat id ([giftBiscuit] by default).
  treat('treat'),

  /// The cat. Owned once.
  cat('cat'),

  /// A pet seat or bowl ([giftSeat], [giftBowl]). Owned once.
  petSkin('petSkin'),

  /// One pet by pet id ([knownPetIds]), owned once. Typed so the pet
  /// `nghe` and the pot `nghe` never mix: `{"kind": "pet", "id": "nghe"}`
  /// vs `{"kind": "pot", "id": "nghe"}`. An item without a kind is never
  /// read, and old pot items stay pots.
  pet('pet');

  const RewardKind(this.json);

  final String json;

  static RewardKind? fromJson(Object? raw) {
    for (final kind in values) {
      if (kind.json == raw) return kind;
    }
    return null;
  }

  /// Kinds that only make sense with an id.
  bool get needsId => this == pot || this == petSkin || this == pet;
}

/// Largest amount one item may carry. Matches the admin xu cap.
const maxRewardAmount = maxGrantMoney;

@immutable
class RewardItem {
  const RewardItem({required this.kind, this.id, required this.amount});

  const RewardItem.coins(int amount)
    : this(kind: RewardKind.coins, amount: amount);
  const RewardItem.giotHoa(int amount)
    : this(kind: RewardKind.giotHoa, amount: amount);
  const RewardItem.phaLe(int amount)
    : this(kind: RewardKind.phaLe, amount: amount);
  const RewardItem.pot(String id, [int amount = 1])
    : this(kind: RewardKind.pot, id: id, amount: amount);
  const RewardItem.treat(int amount, {String id = giftBiscuit})
    : this(kind: RewardKind.treat, id: id, amount: amount);
  const RewardItem.cat() : this(kind: RewardKind.cat, amount: 1);
  const RewardItem.petSkin(String id)
    : this(kind: RewardKind.petSkin, id: id, amount: 1);
  const RewardItem.pet(String id)
    : this(kind: RewardKind.pet, id: id, amount: 1);

  final RewardKind kind;

  /// Pot, treat or skin id. Null for currencies and the cat.
  final String? id;
  final int amount;

  bool get valid =>
      amount >= 1 &&
      amount <= maxRewardAmount &&
      (!kind.needsId || (id != null && id!.isNotEmpty));

  Map<String, Object?> toJson() => {
    'kind': kind.json,
    if (id != null) 'id': id,
    'amount': amount,
  };

  /// Null for an unknown kind or a broken item.
  static RewardItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = RewardKind.fromJson(raw['kind']);
    final amount = raw['amount'];
    final id = raw['id'];
    if (kind == null || amount is! num || amount != amount.roundToDouble()) {
      return null;
    }
    final item = RewardItem(
      kind: kind,
      id: switch (kind) {
        RewardKind.coins || RewardKind.giotHoa || RewardKind.phaLe => null,
        RewardKind.cat => null,
        RewardKind.treat => id is String && id.isNotEmpty ? id : giftBiscuit,
        RewardKind.pot ||
        RewardKind.petSkin ||
        RewardKind.pet => id is String ? id : null,
      },
      amount: amount.toInt(),
    );
    return item.valid ? item : null;
  }

  @override
  bool operator ==(Object other) =>
      other is RewardItem &&
      other.kind == kind &&
      other.id == id &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(kind, id, amount);

  @override
  String toString() =>
      'RewardItem(${kind.json}${id == null ? '' : ':$id'} x$amount)';
}

/// A list of rewards handed out together. Invalid items are dropped.
@immutable
class RewardBundle {
  RewardBundle([Iterable<RewardItem> items = const []])
    : items = List.unmodifiable([
        for (final item in items)
          if (item.valid) item,
      ]);

  RewardBundle.coins(int amount) : this([RewardItem.coins(amount)]);
  RewardBundle.giotHoa(int amount) : this([RewardItem.giotHoa(amount)]);

  static final empty = RewardBundle();

  final List<RewardItem> items;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Total of one kind (and id, when given).
  int amountOf(RewardKind kind, [String? id]) {
    var sum = 0;
    for (final item in items) {
      if (item.kind == kind && (id == null || item.id == id)) {
        sum += item.amount;
      }
    }
    return sum;
  }

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
  };

  /// Reads `{"items": [...]}` or a bare list. Never throws.
  static RewardBundle fromJson(Object? raw) {
    final list = raw is Map ? raw['items'] : raw;
    if (list is! List) return empty;
    return RewardBundle([
      for (final entry in list) ?RewardItem.fromJson(entry),
    ]);
  }

  /// An admin gift `items` map (`users/{uid}.gift.items`), id to count.
  /// Ids outside [giftCatalog] are skipped. Order follows the catalog.
  static RewardBundle fromGiftItems(Map<String, int> gift) {
    final out = <RewardItem>[];
    for (final kind in giftCatalog) {
      final count = gift[kind.id] ?? 0;
      if (count <= 0) continue;
      final item = switch (kind.id) {
        giftCat => const RewardItem.cat(),
        giftBiscuit => RewardItem.treat(count),
        giftDrop => RewardItem.giotHoa(count),
        giftSeat || giftBowl => RewardItem.petSkin(kind.id),
        giftXu => RewardItem.coins(count),
        giftPhaLe => RewardItem.phaLe(count),
        _ when petIdOfGiftKey(kind.id) != null => RewardItem.pet(
          petIdOfGiftKey(kind.id)!,
        ),
        _ => kind.art == GiftArt.pot ? RewardItem.pot(kind.id, count) : null,
      };
      if (item != null) out.add(item);
    }
    return RewardBundle(out);
  }

  /// Back to admin gift ids, summed, for [giftLabel] and the admin card.
  Map<String, int> toGiftItems() {
    final out = <String, int>{};
    void add(String id, int n) => out[id] = (out[id] ?? 0) + n;
    for (final item in items) {
      switch (item.kind) {
        case RewardKind.coins:
          add(giftXu, item.amount);
        case RewardKind.giotHoa:
          add(giftDrop, item.amount);
        case RewardKind.phaLe:
          add(giftPhaLe, item.amount);
        case RewardKind.cat:
          add(giftCat, 1);
        case RewardKind.pet:
          add(petGiftKey(item.id!), 1);
        case RewardKind.pot || RewardKind.treat || RewardKind.petSkin:
          add(item.id!, item.amount);
      }
    }
    return out;
  }

  /// "Mèo, Bánh mật ×3, Xu 50k" in catalog order.
  String get label => giftLabel(toGiftItems());

  @override
  bool operator ==(Object other) =>
      other is RewardBundle && listEquals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);

  @override
  String toString() => 'RewardBundle($items)';
}

/// Where a bundle came from. [persistNow] sources write the morning save
/// (local + cloud) right away, so a reload cannot lose or repeat them.
/// The others land mid-day like money from a sale and are saved with the
/// rest of the day when it ends, so replaying the day cannot farm them.
enum RewardSource {
  adminGift(persistNow: true),
  adminGrant(persistNow: true),
  mysteryCustomer(persistNow: false),
  shopEvent(persistNow: false),
  mailbox(persistNow: true),
  loginReward(persistNow: true),
  giftcode(persistNow: true);

  const RewardSource({required this.persistNow});

  final bool persistNow;
}

/// What [applyRewards] did.
class RewardResult {
  const RewardResult({required this.granted, required this.skipped});

  /// Only what really changed the save. Show this in the UI.
  final RewardBundle granted;

  /// Items left out: a cat or skin already owned, an unknown pot,
  /// treat or skin id.
  final List<RewardItem> skipped;
}

/// Adds [bundle] to [target]. Pure, so the session and the morning
/// checkpoint can both run it.
///
/// Pots stack in `potCounts` exactly like buying one, so a pot the shop
/// already owns adds another copy (never a second "owned" flag). Only the
/// paid pots of the admin gift list count; the free sage bucket and
/// unknown ids are skipped. The cat and the pet skins stay one per save:
/// already owned means skipped, as admin gifts always did.
RewardResult applyRewards(GameState target, RewardBundle bundle) {
  final granted = <RewardItem>[];
  final skipped = <RewardItem>[];
  for (final item in bundle.items) {
    switch (item.kind) {
      case RewardKind.coins:
        target.money += item.amount;
        granted.add(item);
      case RewardKind.giotHoa:
        target.drops += item.amount;
        granted.add(item);
      case RewardKind.phaLe:
        target.phaLe += item.amount;
        granted.add(item);
      case RewardKind.treat:
        if (item.id == giftBiscuit) {
          target.biscuits += item.amount;
          granted.add(item);
        } else if (item.id == giftDrop) {
          target.drops += item.amount;
          granted.add(item);
        } else {
          skipped.add(item);
        }
      case RewardKind.pot:
        if (giftKind(item.id!)?.art == GiftArt.pot) {
          target.potCounts[item.id!] =
              (target.potCounts[item.id!] ?? 0) + item.amount;
          granted.add(item);
        } else {
          skipped.add(item);
        }
      case RewardKind.cat:
        if (target.hasCat) {
          skipped.add(item);
        } else {
          target.hasCat = true;
          target.petStage = 0;
          target.petProgress = 0;
          granted.add(const RewardItem.cat());
        }
      case RewardKind.pet:
        final id = item.id!;
        if (!knownPetIds.contains(id) || target.ownsPet(id)) {
          skipped.add(item);
        } else {
          target.addPet(id, fedDay: target.day);
          granted.add(RewardItem.pet(id));
        }
      case RewardKind.petSkin:
        final List<String>? owned = switch (item.id) {
          giftSeat => target.petSeats,
          giftBowl => target.petBowls,
          _ => null,
        };
        if (owned == null || owned.contains(item.id)) {
          skipped.add(item);
        } else {
          owned.add(item.id!);
          granted.add(RewardItem.petSkin(item.id!));
        }
    }
  }
  target.petSeat ??= target.petSeats.isEmpty ? null : target.petSeats.first;
  target.petBowl ??= target.petBowls.isEmpty ? null : target.petBowls.first;
  return RewardResult(granted: RewardBundle(granted), skipped: skipped);
}

/// The bundle of an admin gift box, or null when there is none or the
/// same shipment id was already added.
RewardBundle? giftBundle(PetGiftBox? box, {required String? appliedId}) {
  if (box == null || box.id.isEmpty || box.id == appliedId) return null;
  return RewardBundle.fromGiftItems(box.items);
}

/// The notice after an admin gift. Same words as before the shared model.
String giftGrantedLine(RewardBundle granted) {
  if (granted.isEmpty) return 'Quà này tiệm đã có rồi.';
  return 'Nhận quà: ${granted.label}.';
}
