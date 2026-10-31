part of 'shop_session.dart';

/// Skin trang trí (spec_skin_trang_tri.md): what is owned and worn, and
/// buying. Cosmetic only. The cushion and bowl keep the old save fields
/// petSeat/petBowl (+ petSeats/petBowls); the other six slots use
/// ownedSkins/equippedSkins.
extension SkinShopSession on ShopSession {
  SkinCatalog get skins => data.skins;

  List<String>? _skinList(String slot) => switch (slot) {
    'choNgoi' => state.petSeats,
    'batAn' => state.petBowls,
    _ => null,
  };

  /// Owned (the free skin of every slot always is).
  bool skinHas(String id) {
    final s = skins.byId(id);
    if (s == null) return false;
    if (s.isDefault) return true;
    return (_skinList(s.slot) ?? state.ownedSkins).contains(s.id);
  }

  /// Skin worn in [slot]: the saved one while it is owned, else the free one.
  String skinWorn(String slot) {
    final id = switch (slot) {
      'choNgoi' => state.petSeat,
      'batAn' => state.petBowl,
      _ => state.equippedSkins[slot],
    };
    final s = id == null ? null : skins.byId(id);
    if (s != null && s.slot == slot && skinHas(s.id)) return s.id;
    return skins.defaultId(slot);
  }

  /// File of the skin worn in [slot].
  String skinAsset(String slot) => skins.byId(skinWorn(slot))?.asset ?? '';

  /// Today's price (thuong xu follows the game day).
  SkinPrice skinPrice(SkinDef s) => skins.priceOf(s, state.day);

  /// Xu or Pha lê still missing for [s]; 0 when it can be paid.
  int skinShortfall(SkinDef s) {
    final p = skinPrice(s);
    final have = p.phaLe ? state.phaLe : state.money;
    return have >= p.amount ? 0 : p.amount - have;
  }

  /// Shop skins change only while the doors are shut (spec §4), like
  /// placing pots. The pet room can be decorated any time.
  bool skinGroupEditable(String group) =>
      group != skinGroupShop || state.phase != DayPhase.open;

  /// Avatar frames are bought any time (they are not in the shop scene).
  bool _skinEditable(SkinDef s) =>
      s.slot == skinAvatarFrameSlot || skinGroupEditable(s.group);

  /// Puts on every owned skin of [picks] (slot -> id). Unowned ones are
  /// skipped. Returns how many slots changed.
  int wearSkins(Map<String, String> picks) {
    var n = 0;
    for (final e in picks.entries) {
      final s = skins.byId(e.value);
      if (s == null || s.slot != e.key || !skinHas(s.id)) continue;
      if (!skinGroupEditable(s.group)) continue;
      if (skinWorn(s.slot) == s.id) continue;
      switch (s.slot) {
        case 'choNgoi':
          state.petSeat = s.id;
        case 'batAn':
          state.petBowl = s.id;
        default:
          state.equippedSkins[s.slot] = s.id;
      }
      n++;
    }
    if (n > 0) {
      _patchSkins();
      sounds.effect('ui_tap');
      _changed();
    }
    return n;
  }

  /// Local purchase: takes the price from the save and adds the skin. The
  /// Pha lê one runs after the server took the Pha lê ([buySkin]).
  bool _buySkinLocal(String id) {
    final s = skins.byId(id);
    if (s == null || s.isDefault || s.isEvent || skinHas(s.id)) return false;
    if (!_skinEditable(s)) return false;
    final p = skinPrice(s);
    if (p.amount <= 0 || skinShortfall(s) > 0) return false;
    if (p.phaLe) {
      state.phaLe -= p.amount;
    } else {
      state.money -= p.amount;
    }
    _addSkin(s);
    _patchSkins(
      moneyDelta: p.phaLe ? 0 : -p.amount,
      phaLeDelta: p.phaLe ? -p.amount : 0,
    );
    sounds.effect('market_buy');
    _changed();
    return true;
  }

  /// Skins the server granted (Season Pass claim): owned from now on, in
  /// the save. Unknown ids (no art or name yet) are skipped.
  void addServerSkins(List<String> ids) {
    var n = 0;
    for (final id in ids) {
      final s = skins.byId(id);
      if (s == null || skinHas(s.id)) continue;
      _addSkin(s);
      n++;
    }
    if (n == 0) return;
    _patchSkins();
    _changed();
  }

  void _addSkin(SkinDef s) {
    final list = _skinList(s.slot) ?? state.ownedSkins;
    if (!list.contains(s.id)) list.add(s.id);
  }

  /// Buys one skin: xu in the save, Pha lê on the server first
  /// (phaleBuy kind `skin`, which also records it in the wallet).
  Future<bool> buySkin(String id) async {
    final s = skins.byId(id);
    if (s == null) return false;
    final p = skinPrice(s);
    if (!p.phaLe || !usesServerWallet) return _buySkinLocal(id);
    if (s.isDefault || s.isEvent || skinHas(s.id) || skinShortfall(s) > 0) {
      return false;
    }
    if (!_skinEditable(s)) return false;
    return _payPhaLe('skin', id, p.amount, () => _buySkinLocal(id));
  }

  void _patchSkins({int moneyDelta = 0, int phaLeDelta = 0}) {
    _patchMorning((cp) {
      if (moneyDelta != 0) cp.money += moneyDelta;
      if (phaLeDelta != 0) cp.phaLe += phaLeDelta;
      cp.petSeats = [...state.petSeats];
      cp.petBowls = [...state.petBowls];
      cp.petSeat = state.petSeat;
      cp.petBowl = state.petBowl;
      cp.ownedSkins = [...state.ownedSkins];
      cp.equippedSkins = {...state.equippedSkins};
    });
  }

  /// The worn set of [group] (slot -> id).
  Map<String, String> skinWornSet(String group) => {
    for (final slot in group == skinGroupShop ? skinShopSlots : skinRoomSlots)
      slot: skinWorn(slot),
  };

  /// Opens Tiệm Trang Trí on [group]. The shop set waits for closing time;
  /// returns false then (the caller shows `skin.closedOnly`).
  bool openDecorate(String group) {
    if (group != skinGroupShop && group != skinGroupRoom) return false;
    if (!skinGroupEditable(group)) return false;
    decorateGroup = group;
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  void closeDecorate() {
    if (decorateGroup == null) return;
    decorateGroup = null;
    sounds.effect('popup_close');
    _changed();
  }
}
