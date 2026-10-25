/// Skin trang trí (spec_skin_trang_tri.md): prices and slots from the
/// economy.json `skins` block (Hà Phương), names and UI words from
/// assets/data/ten_skin.json (Nhất). Cosmetic only: no stat reads these.
library;

import 'dart:convert';

/// Slot ids, as in the `skins` block.
const skinShopSlots = ['nenManHinh', 'khungChau', 'bienHieu', 'quay'];
const skinRoomSlots = ['choNgoi', 'batAn', 'doChoi', 'nenPhong'];

/// Group ids of [SkinDef.group].
const skinGroupShop = 'shop';
const skinGroupRoom = 'petRoom';

/// Theme every slot has for free.
const skinDefaultTheme = 'mac_dinh';

const skinCurrencyXu = 'xu';
const skinCurrencyPhaLe = 'phaLe';

/// Old save ids of the first cushion and bowl (pet.dart giftSeat/giftBowl)
/// and the skin id they are now.
const legacySkinIds = {
  'dem_xanh': 'cho_ngoi_mac_dinh',
  'bat_la': 'bat_an_mac_dinh',
};

/// [id] as a skin id: the old cushion/bowl ids turn into the new ones.
String skinIdOf(String id) => legacySkinIds[id] ?? id;

class SkinDef {
  const SkinDef({
    required this.id,
    required this.slot,
    required this.group,
    required this.theme,
    required this.tier,
    required this.name,
    required this.desc,
  });

  final String id;
  final String slot;
  final String group;
  final String theme;

  /// `free`, `thuong`, `dep`, `hiem` or `suKien`.
  final String tier;
  final String name;
  final String desc;

  bool get isDefault => tier == 'free';
  bool get isEvent => tier == 'suKien';

  /// File under assets/images (spec §8, WebP like the other art).
  String get asset =>
      'assets/images/skin/${group == skinGroupShop ? 'tiem' : 'phong_pet'}/$id.webp';
}

/// What one skin costs today. [amount] 0: free or not for sale.
class SkinPrice {
  const SkinPrice(this.currency, this.amount);
  final String currency;
  final int amount;
  bool get phaLe => currency == skinCurrencyPhaLe;
}

class SkinCatalog {
  SkinCatalog._(this._block, this._ui, this.list);

  static final empty = SkinCatalog._(const {}, const {}, const []);

  final Map<String, dynamic> _block;
  final Map<String, String> _ui;
  final List<SkinDef> list;

  /// [block] is economy.json `skins`, [text] the decoded ten_skin.json.
  factory SkinCatalog.parse(Object? block, Object? text) {
    final b = block is Map<String, dynamic> ? block : const <String, dynamic>{};
    final t = text is Map<String, dynamic> ? text : const <String, dynamic>{};
    final themeTiers = (b['themeTiers'] as Map?) ?? const {};
    final skins = (t['skins'] as Map?) ?? const {};
    final list = <SkinDef>[
      for (final e in skins.entries)
        if (e.value is Map && themeTiers[e.value['theme']] is String)
          SkinDef(
            id: e.key as String,
            slot: e.value['slot'] as String,
            group: e.value['group'] as String,
            theme: e.value['theme'] as String,
            tier: themeTiers[e.value['theme']] as String,
            name: (e.value['name'] as String?) ?? '',
            desc: (e.value['desc'] as String?) ?? '',
          ),
    ];
    final ui = (t['ui'] as Map?) ?? const {};
    return SkinCatalog._(b, {
      for (final e in ui.entries)
        if (e.value is String) e.key as String: e.value as String,
    }, list);
  }

  factory SkinCatalog.fromStrings(Object? block, String? text) =>
      SkinCatalog.parse(block, text == null ? null : jsonDecode(text));

  SkinDef? byId(String id) {
    final key = skinIdOf(id);
    for (final s in list) {
      if (s.id == key) return s;
    }
    return null;
  }

  /// Skins of [slot]: the free one first, then by theme order of
  /// `themeTiers` (Hà Phương's order).
  List<SkinDef> ofSlot(String slot) {
    final order = [...((_block['themeTiers'] as Map?) ?? const {}).keys];
    return [
      for (final s in list)
        if (s.slot == slot) s,
    ]..sort((a, b) => order.indexOf(a.theme).compareTo(order.indexOf(b.theme)));
  }

  /// `{slot_snake}` of a slot id (skinIds.slotIds).
  String slotSnake(String slot) {
    final ids = (_block['skinIds'] as Map?)?['slotIds'] as Map?;
    return (ids?[slot] as String?) ?? slot;
  }

  /// The free skin of [slot].
  String defaultId(String slot) => '${slotSnake(slot)}_$skinDefaultTheme';

  /// Price on game day [day]: thuong is xu by `priceByGameDay`, dep/hiem
  /// Pha lê; backgrounds × `bigSlotMultiplier`. Free and event skins: 0.
  SkinPrice priceOf(SkinDef s, int day) {
    final tier = (_block['tiers'] as Map?)?[s.tier];
    if (tier is! Map) return const SkinPrice('none', 0);
    final currency = (tier['currency'] as String?) ?? 'none';
    num base = 0;
    if (tier['price'] is num) {
      base = tier['price'] as num;
    } else if (tier['priceByGameDay'] is List) {
      for (final row in tier['priceByGameDay'] as List) {
        if (row is Map && day >= ((row['fromDay'] as num?) ?? 1)) {
          base = (row['price'] as num?) ?? base;
        }
      }
    }
    final mult = ((_block['bigSlotMultiplier'] as Map?)?[s.slot] as num?) ?? 1;
    if (currency != skinCurrencyXu && currency != skinCurrencyPhaLe) {
      return SkinPrice(currency, 0);
    }
    return SkinPrice(currency, (base * mult).round());
  }

  /// Nhất's UI word for [key] (`skin.save`, `tier.dep`, ...), the key
  /// itself when missing so a gap shows up in testing.
  String ui(String key, [Map<String, Object> args = const {}]) {
    var s = _ui[key] ?? key;
    for (final e in args.entries) {
      s = s.replaceAll('{${e.key}}', '${e.value}');
    }
    return s;
  }
}
