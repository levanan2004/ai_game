/// The cream cat, its treats, and the gifts an admin can send.
///
/// One feeding adds [biscuitProgress] and costs more bánh mật as the cat
/// grows: 1, then 2, then 3. At 100% giọt hoa raises the stage: 10, then 100.
library;

import '../data/economy.dart';
import '../save/game_state.dart';
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

/// Price of the cream cat. economy.json `pets.list` (meo) is the shop's
/// source; this matches it for the map and older tests.
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

/// Stems actually lost. A caught mouse takes nothing; a miss takes
/// [lossOnMiss] of [aimed], rounded down (1.0 without a mouse-catching
/// pet; the cat keeps 0.7 / 0.4 / 0.2 by stage, `mouseLossOnMiss`).
int mouseStemsLost({
  required int aimed,
  required bool caught,
  required double lossOnMiss,
}) {
  if (aimed <= 0 || caught) return 0;
  return (aimed * lossOnMiss.clamp(0.0, 1.0)).floor();
}

/// Police get the money back this often, before the pet bonus.
const theftPoliceChance = 0.7;

/// Chasing the thief works this often, before the pet bonus.
const theftChaseChance = 0.5;

/// What the pet in the "Thu nhập" slot adds today (economy.json
/// `pets.list[].abilities` at its stage, capped by `petCaps`). Only that
/// pet counts; a pet in no slot, or only in "Mị lực", does nothing.
class PetEffects {
  const PetEffects({this.def, this.stage = 0, this.caps = PetCaps.defaults});

  /// The income-slot pet of [state], or none.
  factory PetEffects.of(Economy e, GameState state) {
    final id = state.petIncome;
    final owned = id == null ? null : state.ownedPet(id);
    final def = owned == null ? null : e.pet(owned.id);
    return PetEffects(def: def, stage: owned?.stage ?? 0, caps: e.petCaps);
  }

  static const none = PetEffects();

  final PetDef? def;
  final int stage;
  final PetCaps caps;

  double _a(String key) => def?.ability(key, stage) ?? 0;
  double _cap(double v, double cap) => v < 0 ? 0 : (v > cap ? cap : v);

  /// Chance the mouse is caught before it takes anything.
  double get mouseCatch => _cap(_a('mouseCatch'), caps.mouseCatch);

  /// Share of the aimed stems a missed mouse still takes.
  double get mouseLossOnMiss {
    if (def?.abilities.containsKey('mouseLossOnMiss') != true) return 1.0;
    return _a('mouseLossOnMiss').clamp(0.0, 1.0);
  }

  /// The pet chases the mouse at all (for the event text).
  bool get fightsMice => mouseCatch > 0 || mouseLossOnMiss < 1;

  /// Added to [theftPoliceChance] and [theftChaseChance].
  double get theftRecoverBonus => _cap(_a('theftRecoverBonus'), 1);

  /// Chance of a Khách thần bí on a day not divisible by 10.
  double get mysteryChance => _cap(_a('mysteryChance'), caps.mysteryChance);

  /// Share of the day's takings (bouquets + tips + online) added at close.
  double get incomeBonus => _cap(_a('incomeBonus'), caps.incomeBonus);

  /// Customers wait this much longer (0.03 = 3%).
  double get patienceBonus => _cap(_a('patienceBonus'), 1);

  /// Extra fresh days on newly bought stems.
  int get freshnessBonusDays => _a('freshnessBonusDays').round();

  String get name => def?.nameVi ?? '';
}

/// Ability keys the cards and the buy popup describe, with Nhất's lines.
/// `mouseLossOnMiss` has no line: it only softens the cat's misses.
const _abilityLines = <String, String>{
  'mouseCatch': 'Bắt chuột +{n}%',
  'incomeBonus': 'Thu nhập +{n}%',
  'patienceBonus': 'Khách chờ lâu hơn {n}%',
  'theftRecoverBonus': 'Lấy lại tiền khi bị trộm +{n}%',
  'freshnessBonusDays': 'Hoa tươi thêm {n} ngày',
  'mysteryChance': 'Khách thần bí ghé thêm {n}%',
};

/// 0.105 -> "10,5", 0.01 -> "1".
String petPercent(double fraction) {
  final tenths = (fraction * 1000).round();
  final whole = tenths ~/ 10;
  final rest = tenths % 10;
  return rest == 0 ? '$whole' : '$whole,$rest';
}

/// One line per ability at [stage] (trưởng thành by default), in the
/// order of economy.json. Zero values are left out.
List<String> petAbilityParts(PetDef pet, {int stage = 2}) {
  final parts = <String>[];
  for (final key in pet.abilities.keys) {
    final template = _abilityLines[key];
    if (template == null) continue;
    final v = pet.ability(key, stage);
    if (v <= 0) continue;
    final n = key == 'freshnessBonusDays' ? '${v.round()}' : petPercent(v);
    parts.add(template.replaceAll('{n}', n));
  }
  return parts;
}

String petAbilityLine(PetDef pet, {int stage = 2}) =>
    petAbilityParts(pet, stage: stage).join(', ');

/// Shared picture frame from the slot mock. The ink sits in 88% of the
/// frame, then [petFrameFit] and the stage (ấu 0.80, lớn 0.90, trưởng thành 1).
const petFrameContain = 0.88;

const petFrameFit = <String, double>{'ca_chep': 0.86, 'hac': 0.92};

const petStageFrame = <double>[0.80, 0.90, 1.0];

double petFrameScale(String id, int stage) {
  final index = stage < 0 ? 0 : (stage > 2 ? 2 : stage);
  return petFrameContain * (petFrameFit[id] ?? 1) * petStageFrame[index];
}

/// Picture of [id] at [stage]. The cat has poses (`meo_<stage>_<pose>`);
/// the other pets have one picture per stage (`pet_<id>_<stage>`).
String petArtId(String id, int stage, {String pose = 'ngoi'}) {
  final index = stage < 0 ? 0 : (stage > 2 ? 2 : stage);
  if (id == catPetId) return 'meo_${petStageIds[index]}_$pose';
  return 'pet_${id}_${petStageIds[index]}';
}

/// Only the cat has eat / hold / hungry poses so far.
bool petHasPoses(String id) => id == catPetId;

/// Every pet id a gift or mail may carry, the cat first. Matches
/// `pets.list` in economy.json.
const knownPetIds = [
  'meo',
  'ca_chep',
  'hac',
  'nghe',
  'huyen_vu',
  'bach_ho',
  'ky_lan',
  'phuong_hoang',
  'rong_thien',
  'kim_long',
];

/// Admin gift key of a pet. The cat keeps its old key `meo`; the others are
/// `pet:<id>` so the pet `nghe` never meets the pot `nghe` (a key without
/// a prefix is the pot, as old gifts always were).
String petGiftKey(String id) => id == catPetId ? giftCat : '$petGiftPrefix$id';

const petGiftPrefix = 'pet:';

/// The pet id of a gift key, or null when the key is not a pet.
String? petIdOfGiftKey(String key) {
  if (key == giftCat) return catPetId;
  if (!key.startsWith(petGiftPrefix)) return null;
  final id = key.substring(petGiftPrefix.length);
  return knownPetIds.contains(id) ? id : null;
}

const giftCat = 'meo';
const giftBiscuit = 'banh_mat';
const giftDrop = 'giat_hoa';
const giftSeat = 'dem_xanh';
const giftBowl = 'bat_la';
const giftXu = 'xu';

/// Pha lê, the newer currency. Only rewards give it for now.
const giftPhaLe = 'pha_le';

/// Most Pha lê one admin gift may carry. Matches firestore.rules.
const maxPhaLeGift = 999;

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

/// [GiftArt.phaLe] is `nav/pha_le` like the coin; `PhaLeIcon` draws it.
enum GiftArt { pet, pot, coin, phaLe }

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
    id: 'pet:ca_chep',
    name: 'Thú cá chép',
    blurb: 'Một cá chép ấu thú',
    asset: 'pet_ca_chep_au',
    cap: 1,
  ),
  GiftKind(
    id: 'pet:hac',
    name: 'Thú hạc',
    blurb: 'Một hạc ấu thú',
    asset: 'pet_hac_au',
    cap: 1,
  ),
  GiftKind(
    id: 'pet:nghe',
    name: 'Thú nghê',
    blurb: 'Một nghê ấu thú',
    asset: 'pet_nghe_au',
    cap: 1,
  ),
  GiftKind(
    id: 'pet:huyen_vu',
    name: 'Thú huyền vũ',
    blurb: 'Một huyền vũ ấu thú',
    asset: 'pet_huyen_vu_au',
    cap: 1,
  ),
  GiftKind(
    id: 'pet:bach_ho',
    name: 'Thú bạch hổ',
    blurb: 'Một bạch hổ ấu thú',
    asset: 'pet_bach_ho_au',
    cap: 1,
  ),
  GiftKind(
    id: 'pet:ky_lan',
    name: 'Thú kỳ lân',
    blurb: 'Một kỳ lân ấu thú',
    asset: 'pet_ky_lan_au',
    cap: 1,
  ),
  GiftKind(
    id: 'pet:phuong_hoang',
    name: 'Thú phượng hoàng',
    blurb: 'Một phượng hoàng ấu thú',
    asset: 'pet_phuong_hoang_au',
    cap: 1,
  ),
  GiftKind(
    id: 'pet:rong_thien',
    name: 'Thú rồng thiên',
    blurb: 'Một rồng thiên ấu thú',
    asset: 'pet_rong_thien_au',
    cap: 1,
  ),
  GiftKind(
    id: 'pet:kim_long',
    name: 'Thú kim long',
    blurb: 'Một kim long ấu thú',
    asset: 'pet_kim_long_au',
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
  GiftKind(
    id: giftPhaLe,
    name: 'Pha lê',
    blurb: 'Cộng vào Pha lê của tiệm',
    asset: 'pha_le',
    art: GiftArt.phaLe,
    cap: maxPhaLeGift,
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

/// What the save already holds, for the admin card.
class PetPocket {
  const PetPocket({
    this.petIds = const [],
    this.hasCat = false,
    this.stage = 0,
    this.progress = 0,
    this.biscuits = 0,
    this.drops = 0,
    this.seats = const [],
    this.bowls = const [],
    this.pots = const {},
    this.money = 0,
    this.phaLe = 0,
  });

  /// Pet ids the save owns (`pets`, or the cat of an older save).
  final List<String> petIds;
  final bool hasCat;
  final int stage;
  final int progress;
  final int biscuits;
  final int drops;
  final List<String> seats;
  final List<String> bowls;
  final Map<String, int> pots;
  final int money;
  final int phaLe;

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
    final phaLe = raw['phaLe'];
    final rawPots = raw['potCounts'];
    final rawPets = raw['pets'];
    final petIds = rawPets is List
        ? [
            for (final p in rawPets)
              if (p is Map && p['id'] is String) p['id'] as String,
          ]
        : [if (raw['hasCat'] == true) catPetId];
    return PetPocket(
      petIds: petIds,
      hasCat: petIds.contains(catPetId),
      stage: stage is num ? stage.toInt() : 0,
      progress: progress is num ? progress.toInt() : 0,
      biscuits: biscuits is num ? biscuits.toInt() : 0,
      drops: drops is num ? drops.toInt() : 0,
      seats: names(raw['petSeats']),
      bowls: names(raw['petBowls']),
      money: money is num ? money.toInt() : 0,
      phaLe: phaLe is num ? phaLe.toInt() : 0,
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
    if (id == giftPhaLe) return phaLe;
    final petId = petIdOfGiftKey(id);
    if (petId != null) return petIds.contains(petId) ? 1 : 0;
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
    if (petIds.isEmpty &&
        biscuits == 0 &&
        drops == 0 &&
        seats.isEmpty &&
        bowls.isEmpty) {
      return 'Tiệm chưa có quà thú cưng.';
    }
    final parts = <String>[
      if (hasCat) '${petStageName(stage)} $progress%',
      if (!hasCat) 'Chưa có mèo',
      if (petIds.length > (hasCat ? 1 : 0))
        '${petIds.length - (hasCat ? 1 : 0)} thú khác',
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
