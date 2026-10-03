/// The cream cat, its treats, and the gifts an admin can send.
///
/// One feeding adds [biscuitProgress] and costs more bánh mật as the cat
/// grows: 1, then 2, then 3. At 100% giọt hoa raises the stage: 10, then 100.
library;

import 'format.dart';
import 'xu_grant.dart';

const petStageIds = ['au', 'lon', 'truong'];
const petStageNames = ['Ấu thú', 'Lớn', 'Trưởng thành'];
const biscuitProgress = 25;

/// Bánh mật one feeding costs. Ấu thú 1, lớn 2, trưởng thành 3.
int biscuitsToEat(int stage) {
  if (stage <= 0) return 1;
  if (stage == 1) return 2;
  return 3;
}

const maxGiftCount = 99;

/// The stray kitten asks once, when this day ends.
const strayCatDay = 5;

/// Price of the cream cat at the pet shop.
const catPrice = 100000;

/// Stems the mouse tries to take before the cat helps. Doubled so a pet
/// matters: day 5 is 4, day 20 is 8, day 40 is 12.
int mouseWantedStems(int day) {
  final d = day < 1 ? 1 : day;
  return 2 * (2 + d ~/ 10);
}

/// Wanted stems, never more than 15% of the stems the counter can still sell.
int mouseAimedStems({required int day, required int available}) {
  if (available <= 0) return 0;
  final cap = (available * 0.15).floor();
  if (cap <= 0) return 0;
  final wanted = mouseWantedStems(day);
  return wanted < cap ? wanted : cap;
}

/// Stems actually lost. No cat loses all of [aimed]. Ấu thú loses 70%,
/// lớn 40%, trưởng thành 20%, rounded down.
int mouseStemsLost({
  required int aimed,
  required bool hasCat,
  required int stage,
}) {
  if (aimed <= 0) return 0;
  final fraction = !hasCat
      ? 1.0
      : stage <= 0
      ? 0.7
      : stage == 1
      ? 0.4
      : 0.2;
  return (aimed * fraction).floor();
}

const giftCat = 'meo';
const giftBiscuit = 'banh_mat';
const giftDrop = 'giat_hoa';
const giftSeat = 'dem_xanh';
const giftBowl = 'bat_la';
const giftXu = 'xu';

/// One pet the shop can sell. Later pets get a price of their own.
class ShopPet {
  const ShopPet({
    required this.id,
    required this.name,
    required this.blurb,
    required this.price,
    required this.asset,
  });

  final String id;
  final String name;
  final String blurb;
  final int price;
  final String asset;
}

const petsForSale = <ShopPet>[
  ShopPet(
    id: giftCat,
    name: 'Mèo',
    blurb: 'Ấu thú. Bắt chuột gặm hoa.',
    price: catPrice,
    asset: 'meo_au_ngoi',
  ),
];

ShopPet? shopPet(String id) {
  for (final pet in petsForSale) {
    if (pet.id == id) return pet;
  }
  return null;
}

const biscuitPrice = 20000;

/// Food the pet shop sells. Counts stack up to [maxGiftCount].
class PetTreat {
  const PetTreat({
    required this.id,
    required this.name,
    required this.blurb,
    required this.price,
    required this.asset,
  });

  final String id;
  final String name;
  final String blurb;
  final int price;
  final String asset;
}

const treatsForSale = <PetTreat>[
  PetTreat(
    id: giftBiscuit,
    name: 'Bánh mật',
    blurb: 'Ăn vào tăng 25% tiến trình',
    price: biscuitPrice,
    asset: giftBiscuit,
  ),
];

/// The guest who visits on day 10, 20, 30… and leaves giọt hoa.
const mysteryAvatar = 'than_bi';
const mysteryName = 'Khách thần bí';

/// Giọt hoa a full bar spends. Ấu thú to lớn, then lớn to trưởng thành.
const stonesYoung = 10;
const stonesGrown = 100;

/// Stones one mysterious visit leaves, from the bouquet's stars.
/// 5 sao is 6–10, 4 sao is 2–6, a weaker bouquet leaves 1.
(int, int) stoneGiftRange(int stars) {
  if (stars >= 5) return (6, 10);
  if (stars >= 4) return (2, 6);
  return (1, 1);
}

int stonesToGrow(int stage) => stage <= 0 ? stonesYoung : stonesGrown;

PetTreat? petTreat(String id) {
  for (final treat in treatsForSale) {
    if (treat.id == id) return treat;
  }
  return null;
}

const skinSeat = 'seat';
const skinBowl = 'bowl';

/// A cushion or bowl. Price 0 is free and already in the room.
class PetSkin {
  const PetSkin({
    required this.id,
    required this.name,
    required this.kind,
    required this.price,
    required this.asset,
  });

  final String id;
  final String name;
  final String kind;
  final int price;
  final String asset;
}

const petSkins = <PetSkin>[
  PetSkin(
    id: giftSeat,
    name: 'Đệm xanh',
    kind: skinSeat,
    price: 0,
    asset: giftSeat,
  ),
  PetSkin(
    id: giftBowl,
    name: 'Bát lá',
    kind: skinBowl,
    price: 0,
    asset: giftBowl,
  ),
];

List<PetSkin> skinsOf(String kind) => [
  for (final skin in petSkins)
    if (skin.kind == kind) skin,
];

PetSkin? petSkinById(String id) {
  for (final skin in petSkins) {
    if (skin.id == id) return skin;
  }
  return null;
}

/// Sprite id under assets/images/pets, without the folder.
String petSprite(int stage, String pose) {
  final index = stage < 0 ? 0 : (stage > 2 ? 2 : stage);
  return 'meo_${petStageIds[index]}_$pose';
}

String petStageName(int stage) {
  final index = stage < 0 ? 0 : (stage > 2 ? 2 : stage);
  return petStageNames[index];
}

bool petIsHungry({
  required bool hasCat,
  required int fedDay,
  required int day,
}) => hasCat && fedDay < day;

enum GiftArt { pet, pot, coin }

/// One kind of gift. A [cap] of 1 can be owned only once.
class GiftKind {
  const GiftKind({
    required this.id,
    required this.name,
    required this.blurb,
    required this.asset,
    this.art = GiftArt.pet,
    this.cap = maxGiftCount,
  });

  final String id;
  final String name;
  final String blurb;
  final String asset;
  final GiftArt art;

  /// Most one shipment may include. Xu uses [maxGrantMoney].
  final int cap;

  bool get unique => cap <= 1;
}

const giftCatalog = <GiftKind>[
  GiftKind(
    id: giftCat,
    name: 'Mèo',
    blurb: 'Một mèo ấu thú',
    asset: 'meo_au_ngoi',
    cap: 1,
  ),
  GiftKind(
    id: giftBiscuit,
    name: 'Bánh mật',
    blurb: 'Ăn vào tăng 25% tiến trình',
    asset: 'banh_mat',
  ),
  GiftKind(
    id: giftDrop,
    name: 'Giọt hoa',
    blurb: 'Dùng khi đủ 100% để đột phá',
    asset: 'giat_hoa',
  ),
  GiftKind(
    id: giftSeat,
    name: 'Đệm xanh',
    blurb: 'Chỗ mèo ngồi',
    asset: 'dem_xanh',
    cap: 1,
  ),
  GiftKind(
    id: giftBowl,
    name: 'Bát lá',
    blurb: 'Bát để bánh',
    asset: 'bat_la',
    cap: 1,
  ),
  GiftKind(
    id: 'dragon',
    name: 'Chậu rồng thiên',
    blurb: 'Thêm một chậu vào kho',
    asset: 'dragon',
    art: GiftArt.pot,
  ),
  GiftKind(
    id: 'phoenix',
    name: 'Chậu phượng hoàng',
    blurb: 'Thêm một chậu vào kho',
    asset: 'phoenix',
    art: GiftArt.pot,
  ),
  GiftKind(
    id: 'tiger',
    name: 'Chậu bạch hổ',
    blurb: 'Thêm một chậu vào kho',
    asset: 'tiger',
    art: GiftArt.pot,
  ),
  GiftKind(
    id: 'tortoise',
    name: 'Chậu huyền vũ',
    blurb: 'Thêm một chậu vào kho',
    asset: 'tortoise',
    art: GiftArt.pot,
  ),
  GiftKind(
    id: 'qilin',
    name: 'Chậu kỳ lân',
    blurb: 'Thêm một chậu vào kho',
    asset: 'qilin',
    art: GiftArt.pot,
  ),
  GiftKind(
    id: 'nghe',
    name: 'Chậu nghê',
    blurb: 'Thêm một chậu vào kho',
    asset: 'nghe',
    art: GiftArt.pot,
  ),
  GiftKind(
    id: 'crane',
    name: 'Chậu hạc',
    blurb: 'Thêm một chậu vào kho',
    asset: 'crane',
    art: GiftArt.pot,
  ),
  GiftKind(
    id: 'koi',
    name: 'Chậu cá chép',
    blurb: 'Thêm một chậu vào kho',
    asset: 'koi',
    art: GiftArt.pot,
  ),
  GiftKind(
    id: giftXu,
    name: 'Xu',
    blurb: 'Cộng vào tiền của tiệm',
    asset: 'xu',
    art: GiftArt.coin,
    cap: maxGrantMoney,
  ),
];

GiftKind? giftKind(String id) {
  for (final kind in giftCatalog) {
    if (kind.id == id) return kind;
  }
  return null;
}

bool giftMatches(GiftKind kind, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return kind.name.toLowerCase().contains(q) ||
      kind.blurb.toLowerCase().contains(q);
}

/// Drops unknown ids, zeros, and counts above the cap. Unique gifts stay at 1.
Map<String, int> sanitizeGiftItems(Map<String, int> items) {
  final out = <String, int>{};
  for (final kind in giftCatalog) {
    final count = items[kind.id] ?? 0;
    if (count <= 0) continue;
    out[kind.id] = count > kind.cap ? kind.cap : count;
  }
  return out;
}

/// Adds [sending] onto a gift that is still waiting. A unique gift stays at 1.
Map<String, int> combineGiftItems(
  Map<String, int> waiting,
  Map<String, int> sending,
) {
  final out = sanitizeGiftItems(waiting);
  for (final entry in sanitizeGiftItems(sending).entries) {
    final kind = giftKind(entry.key)!;
    final sum = (out[entry.key] ?? 0) + entry.value;
    out[entry.key] = sum > kind.cap ? kind.cap : sum;
  }
  return out;
}

String? giftFormError(Map<String, int> items, {required String note}) {
  if (sanitizeGiftItems(items).isEmpty) return 'Chọn ít nhất một quà.';
  if (note.trim().length > 200) return 'Lời nhắn tối đa 200 ký tự.';
  return null;
}

/// One shipment waiting on `users/{uid}.gift`.
class PetGiftBox {
  const PetGiftBox({required this.id, required this.items, this.note = ''});

  final String id;
  final Map<String, int> items;
  final String note;
}

PetGiftBox? giftFromMap(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['id'];
  final items = raw['items'];
  if (id is! String || id.isEmpty || items is! Map) return null;
  final counts = <String, int>{};
  for (final entry in items.entries) {
    if (entry.key is! String || entry.value is! num) continue;
    counts[entry.key as String] = (entry.value as num).toInt();
  }
  final clean = sanitizeGiftItems(counts);
  if (clean.isEmpty) return null;
  final note = raw['note'];
  return PetGiftBox(id: id, items: clean, note: note is String ? note : '');
}

String giftLabel(Map<String, int> items) {
  final parts = <String>[];
  for (final kind in giftCatalog) {
    final count = items[kind.id] ?? 0;
    if (count <= 0) continue;
    if (kind.id == giftXu) {
      parts.add('Xu ${formatK(count)}');
    } else {
      parts.add(kind.unique || count == 1 ? kind.name : '${kind.name} ×$count');
    }
  }
  return parts.join(', ');
}

/// What one shipment adds. Unique things the player already has are skipped.
class GiftApply {
  const GiftApply({
    required this.id,
    required this.giveCat,
    required this.biscuits,
    required this.drops,
    required this.seats,
    required this.bowls,
    required this.pots,
    required this.money,
    required this.skipped,
  });

  final String id;
  final bool giveCat;
  final int biscuits;
  final int drops;
  final List<String> seats;
  final List<String> bowls;
  final Map<String, int> pots;
  final int money;
  final List<String> skipped;

  bool get empty =>
      !giveCat &&
      biscuits == 0 &&
      drops == 0 &&
      seats.isEmpty &&
      bowls.isEmpty &&
      pots.isEmpty &&
      money == 0;
}

GiftApply? giftApply({
  required String? appliedId,
  required bool hasCat,
  required Iterable<String> seats,
  required Iterable<String> bowls,
  required PetGiftBox? box,
}) {
  if (box == null || box.id.isEmpty || box.id == appliedId) return null;
  final ownedSeats = seats.toSet();
  final ownedBowls = bowls.toSet();
  final skipped = <String>[];
  var giveCat = false;
  var biscuits = 0;
  var drops = 0;
  var money = 0;
  final addSeats = <String>[];
  final addBowls = <String>[];
  final addPots = <String, int>{};
  for (final entry in box.items.entries) {
    switch (entry.key) {
      case giftCat:
        if (hasCat) {
          skipped.add(giftCat);
        } else {
          giveCat = true;
        }
      case giftBiscuit:
        biscuits += entry.value;
      case giftDrop:
        drops += entry.value;
      case giftSeat:
        if (ownedSeats.contains(giftSeat)) {
          skipped.add(giftSeat);
        } else {
          addSeats.add(giftSeat);
        }
      case giftBowl:
        if (ownedBowls.contains(giftBowl)) {
          skipped.add(giftBowl);
        } else {
          addBowls.add(giftBowl);
        }
      case giftXu:
        money += entry.value;
      default:
        final kind = giftKind(entry.key);
        if (kind != null && kind.art == GiftArt.pot) {
          addPots[entry.key] = entry.value;
        }
    }
  }
  return GiftApply(
    id: box.id,
    giveCat: giveCat,
    biscuits: biscuits,
    drops: drops,
    seats: addSeats,
    bowls: addBowls,
    pots: addPots,
    money: money,
    skipped: skipped,
  );
}

String giftApplyLine(GiftApply effect) {
  if (effect.empty) return 'Quà này tiệm đã có rồi.';
  final items = <String, int>{
    if (effect.giveCat) giftCat: 1,
    if (effect.biscuits > 0) giftBiscuit: effect.biscuits,
    if (effect.drops > 0) giftDrop: effect.drops,
    for (final id in effect.seats) id: 1,
    for (final id in effect.bowls) id: 1,
    for (final entry in effect.pots.entries) entry.key: entry.value,
    if (effect.money > 0) giftXu: effect.money,
  };
  return 'Nhận quà: ${giftLabel(items)}.';
}

/// What the save already holds, for the admin card.
class PetPocket {
  const PetPocket({
    this.hasCat = false,
    this.stage = 0,
    this.progress = 0,
    this.biscuits = 0,
    this.drops = 0,
    this.seats = const [],
    this.bowls = const [],
    this.pots = const {},
    this.money = 0,
  });

  final bool hasCat;
  final int stage;
  final int progress;
  final int biscuits;
  final int drops;
  final List<String> seats;
  final List<String> bowls;
  final Map<String, int> pots;
  final int money;

  static PetPocket fromProgress(Object? raw) {
    if (raw is! Map) return const PetPocket();
    List<String> names(Object? value) => [
      for (final id in value is List ? value : const [])
        if (id is String && giftKind(id) != null) id,
    ];
    final stage = raw['petStage'];
    final progress = raw['petProgress'];
    final biscuits = raw['biscuits'];
    final drops = raw['drops'];
    final money = raw['money'];
    final rawPots = raw['potCounts'];
    return PetPocket(
      hasCat: raw['hasCat'] == true,
      stage: stage is num ? stage.toInt() : 0,
      progress: progress is num ? progress.toInt() : 0,
      biscuits: biscuits is num ? biscuits.toInt() : 0,
      drops: drops is num ? drops.toInt() : 0,
      seats: names(raw['petSeats']),
      bowls: names(raw['petBowls']),
      money: money is num ? money.toInt() : 0,
      pots: {
        for (final kind in giftCatalog)
          if (kind.art == GiftArt.pot &&
              rawPots is Map &&
              rawPots[kind.id] is num &&
              (rawPots[kind.id] as num) > 0)
            kind.id: (rawPots[kind.id] as num).toInt(),
      },
    );
  }

  /// How many of this gift the save already holds.
  int countOf(String id) {
    if (id == giftXu) return money;
    final potsHeld = pots[id];
    if (potsHeld != null) return potsHeld;
    return switch (id) {
      giftCat => hasCat ? 1 : 0,
      giftBiscuit => biscuits,
      giftDrop => drops,
      giftSeat => seats.contains(giftSeat) ? 1 : 0,
      giftBowl => bowls.contains(giftBowl) ? 1 : 0,
      _ => 0,
    };
  }

  String get line {
    if (!hasCat &&
        biscuits == 0 &&
        drops == 0 &&
        seats.isEmpty &&
        bowls.isEmpty) {
      return 'Tiệm chưa có quà thú cưng.';
    }
    final parts = <String>[
      if (hasCat) '${petStageName(stage)} $progress%',
      if (!hasCat) 'Chưa có mèo',
      if (biscuits > 0) 'bánh $biscuits',
      if (drops > 0) 'giọt $drops',
      if (seats.isNotEmpty) 'đệm',
      if (bowls.isNotEmpty) 'bát',
    ];
    return parts.join(' · ');
  }
}

String giftStatus({required PetGiftBox? gift, required String? appliedId}) {
  if (gift == null) return 'Chưa gửi quà.';
  final what = giftLabel(gift.items);
  if (gift.id == appliedId) return 'Đã vào save: $what.';
  return 'Đang chờ lần đăng nhập sau: $what.';
}
