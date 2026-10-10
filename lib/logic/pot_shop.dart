part of 'shop_session.dart';

/// Tiệm Chậu Hoa, Sổ sưu tầm and the pot placing mode
/// (SPEC_tiem_chau_hoa.md, SPEC_C_final.md).
extension PotShopSession on ShopSession {
  Economy get eco => this.e;

  // ---- groups, numbers, names ------------------------------------------

  /// Pots of [group] in book order (`potBookOrder`), skipping ids this
  /// economy does not know.
  List<PotDef> potGroupPots(String group) => [
    for (final id in potBookOrder[group] ?? const <String>[])
      for (final p in eco.pots)
        if (p.id == id) p,
  ];

  /// Same pots as the shop shows them: cheapest first, ties keep book order.
  List<PotDef> potShopList(String group) {
    final list = potGroupPots(group);
    final order = potBookOrder[group] ?? const <String>[];
    list.sort((a, b) {
      final byPrice = a.cost.compareTo(b.cost);
      return byPrice != 0
          ? byPrice
          : order.indexOf(a.id).compareTo(order.indexOf(b.id));
    });
    return list;
  }

  String potGroupName(String group) {
    for (final s in eco.potSets) {
      if (s.id == group) return s.nameVi;
    }
    return group;
  }

  /// Number printed on a cell (1-based) inside its group.
  int potNumber(PotDef pot) {
    final g = potGroupOf(pot);
    return (potBookOrder[g]?.indexOf(pot.id) ?? -1) + 1;
  }

  String potGroupOf(PotDef pot) => pot.set ?? 'linhVat';

  /// Name in sentences ("Song Tử", "Cá chép"): `shortVi`, else the full name
  /// without the word "Chậu".
  String potShortName(PotDef pot) {
    final s = pot.shortVi;
    if (s != null && s.isNotEmpty) return s;
    final full = data.cosmetics.find(pot.id)?.nameVi ?? pot.nameVi;
    return full.startsWith('Chậu ') ? full.substring(5) : full;
  }

  /// Full name ("Chậu Song Tử").
  String potFullName(PotDef pot) =>
      data.cosmetics.find(pot.id)?.nameVi ?? pot.nameVi;

  // ---- ownership and buying -------------------------------------------

  /// Pots bought so far (the free bucket is not counted).
  int get potsOwnedCount => [
    for (final p in eco.pots)
      if (!p.unlimited && potHas(p.id)) p,
  ].length;

  bool potHas(String id) => (state.potCounts[id] ?? 0) > 0;

  /// Copies not on a shelf yet.
  bool potHasSpare(String id) => potOwned(id) > potPlaced(id);

  int groupOwned(String group) => [
    for (final p in potGroupPots(group))
      if (potHas(p.id)) p,
  ].length;

  int groupTotal(String group) => potGroupPots(group).length;

  /// Can this pot be bought now: on sale, and not owned yet.
  bool potCanBuy(PotDef pot) => pot.purchasable && !potHas(pot.id);

  /// How much xu or Pha lê is still missing for [pot]; 0 when it can pay.
  int potShortfall(PotDef pot) {
    final have = pot.paysPhaLe ? state.phaLe : state.money;
    return have >= pot.cost ? 0 : pot.cost - have;
  }

  // ---- screens ----------------------------------------------------------

  /// Where Back goes from the shop and the book.
  List<Screen> get _potBack => _potBackStack;

  void _pushPotBack() {
    if (screen == Screen.potShop || screen == Screen.potBook) {
      _potBack.add(screen);
    } else {
      _potBack
        ..clear()
        ..add(screen);
    }
  }

  void _popPotScreen() {
    var next = _potBack.isEmpty ? Screen.shop : _potBack.removeLast();
    if (_potBack.isEmpty && state.phase == DayPhase.summary) {
      next = next == Screen.potShop || next == Screen.potBook
          ? Screen.summary
          : next;
    }
    screen = next;
  }

  /// Opens Tiệm Chậu Hoa on [group], scrolled to [focus] when given.
  /// Coming from the book it replaces the shop already on the stack.
  void openPotShop({String? group, String? focus}) {
    if (potPickerOpen) potPickerBar = null;
    if (screen == Screen.potBook &&
        _potBack.isNotEmpty &&
        _potBack.last == Screen.potShop) {
      _potBack.removeLast();
    } else if (screen != Screen.potShop) {
      _pushPotBack();
    }
    potShopTab = group != null && potGroupIds.contains(group)
        ? group
        : (potShopTab);
    potShopFocusId = focus;
    screen = Screen.potShop;
    petSlotsOpen = false;
    charmBoardOpen = false;
    visitPotShop();
    sounds.effect('ui_tap');
    _changed();
  }

  void selectPotShopTab(String group) {
    if (!potGroupIds.contains(group)) return;
    potShopTab = group;
    potShopFocusId = null;
    _changed();
  }

  void closePotShop() {
    if (screen != Screen.potShop) return;
    _popPotScreen();
    sounds.effect('popup_close');
    _changed();
  }

  /// Opens Sổ sưu tầm on [group] (and the detail of [detail] when given).
  void openPotBook({String? group, String? detail}) {
    if (potPickerOpen) potPickerBar = null;
    if (screen != Screen.potBook) _pushPotBack();
    if (detail != null) {
      potBookDetailId = detail;
      final pot = eco.pots.where((p) => p.id == detail).firstOrNull;
      if (pot != null) potBookTab = potGroupOf(pot);
    } else {
      potBookDetailId = null;
    }
    if (group != null && potGroupIds.contains(group)) potBookTab = group;
    screen = Screen.potBook;
    sounds.effect('ui_tap');
    _changed();
  }

  void selectPotBookTab(String group) {
    if (!potGroupIds.contains(group)) return;
    potBookTab = group;
    potBookDetailId = null;
    _changed();
  }

  void openPotBookDetail(String id) {
    potBookDetailId = id;
    _changed();
  }

  /// Back in the book: the detail page first, then the screen before it.
  void closePotBook() {
    if (screen != Screen.potBook) return;
    if (potBookDetailId != null) {
      potBookDetailId = null;
      _changed();
      return;
    }
    _popPotScreen();
    sounds.effect('popup_close');
    _changed();
  }

  // ---- red dot and the one-time reminder ---------------------------------

  /// Pots the shop sells now.
  List<String> get potShopOnSale => [
    for (final p in eco.pots)
      if (p.purchasable) p.id,
  ];

  /// Red dot on the "Chậu hoa" tab: a pot on sale the player never saw in
  /// the shop. No number.
  bool get potShopRedDot =>
      potShopOnSale.any((id) => !state.potShopSeenIds.contains(id));

  /// Opening the shop records what is on sale and counts as having seen
  /// the reminder.
  void visitPotShop() {
    final onSale = potShopOnSale;
    final fresh = [
      for (final id in onSale)
        if (!state.potShopSeenIds.contains(id)) id,
    ];
    final firstTime = !state.potShopHintShown;
    if (fresh.isEmpty && !firstTime) return;
    state.potShopSeenIds.addAll(fresh);
    state.potShopHintShown = true;
    _patchMorning((cp) {
      for (final id in fresh) {
        if (!cp.potShopSeenIds.contains(id)) cp.potShopSeenIds.add(id);
      }
      cp.potShopHintShown = true;
    });
  }

  /// The cheapest pot the player can pay for now and does not own.
  /// [xuOnly] limits it to pots sold for xu (the Tổng kết card).
  PotDef? potAffordable({bool xuOnly = false}) {
    PotDef? best;
    for (final p in eco.pots) {
      if (!potCanBuy(p) || (xuOnly && p.paysPhaLe)) continue;
      if (potShortfall(p) > 0) continue;
      if (best == null || p.cost < best.cost) best = p;
    }
    return best;
  }

  /// Form A of the reminder: the dimmed hint box over the "Chậu hoa" tab.
  /// Never while the shop is open, during the tutorial, or on day 1, and
  /// not over another popup.
  bool get potHintBoxDue =>
      !state.potShopHintShown &&
      screen == Screen.shop &&
      state.phase == DayPhase.preparing &&
      state.day >= 2 &&
      !tutorialActive &&
      popups.isEmpty &&
      namePrompt == null &&
      !petSlotsOpen &&
      !potPickerOpen &&
      pendingPlacePotId == null &&
      potAffordable() != null;

  /// Form B of the reminder on Tổng kết: only for a pot sold for xu.
  PotDef? get potNudgeCardPot => state.potShopHintShown
      ? null
      : state.phase == DayPhase.summary
      ? potAffordable(xuOnly: true)
      : null;

  /// The reminder has appeared: the one flag goes on.
  void markPotHintShown() {
    if (state.potShopHintShown) return;
    state.potShopHintShown = true;
    _patchMorning((cp) => cp.potShopHintShown = true);
    _changed();
  }

  // ---- collection rewards -----------------------------------------------

  PotCollectionDef? collectionOfGroup(String group) {
    final id = potGroupCollection[group];
    for (final c in eco.potCollections) {
      if (c.id == id) return c;
    }
    return null;
  }

  int collectionReward(String group) =>
      collectionOfGroup(group)?.rewardPhaLe ?? 0;

  bool collectionComplete(String group) {
    final c = collectionOfGroup(group);
    if (c == null || c.pots.isEmpty) return false;
    return c.pots.every(potHas);
  }

  bool collectionClaimed(String group) {
    final c = collectionOfGroup(group);
    return c != null && state.claimedSets.contains(c.id);
  }

  /// Once per set: complete, not claimed yet. Players who finished a set
  /// before this existed can still claim it.
  bool collectionClaimable(String group) =>
      collectionComplete(group) &&
      !collectionClaimed(group) &&
      collectionReward(group) > 0;

  bool claimCollection(String group) {
    if (!collectionClaimable(group)) return false;
    final c = collectionOfGroup(group)!;
    state.claimedSets.add(c.id);
    state.phaLe += c.rewardPhaLe;
    _patchMorning((cp) {
      if (!cp.claimedSets.contains(c.id)) {
        cp.claimedSets.add(c.id);
        cp.phaLe += c.rewardPhaLe;
      }
    });
    sounds.effect('reward');
    _changed();
    return true;
  }

  // ---- placing mode -------------------------------------------------------

  /// The shop is not serving: pots may be placed.
  bool get potPlaceAllowed => shopClosed;

  /// Placing mode is on (and still allowed).
  bool get placeModeActive => pendingPlacePotId != null && shopClosed;

  /// Can [id] be placed from the shop or the book now.
  bool potPlaceable(String id) =>
      potPlaceAllowed && potHas(id) && potHasSpare(id);

  /// Goes to the main screen in placing mode for [id].
  bool startPlaceMode(String id) {
    if (!potPlaceable(id)) return false;
    pendingPlacePotId = id;
    pendingPlaceBar = null;
    pendingPlaceIndex = 0;
    potPickerBar = null;
    petSlotsOpen = false;
    charmBoardOpen = false;
    _potBack.clear();
    screen = Screen.shop;
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  /// Looks at [id] on a slot. No pot is moved yet.
  void previewPlaceSlot({required bool bar, required int index}) {
    if (!placeModeActive) return;
    pendingPlaceBar = bar;
    pendingPlaceIndex = index;
    sounds.effect('ui_tap');
    _changed();
  }

  /// "Chọn chỗ khác": keep the pot, forget the slot.
  void clearPlacePreview() {
    pendingPlaceBar = null;
    _changed();
  }

  /// "Đặt ở đây". The pot that was in the slot goes back to the cupboard.
  bool confirmPlace() {
    final id = pendingPlacePotId;
    final bar = pendingPlaceBar;
    if (id == null || bar == null || !shopClosed) return false;
    if (!canPlacePot(id, bar: bar, index: pendingPlaceIndex)) return false;
    final index = pendingPlaceIndex;
    final slots = bar ? state.barPots : state.displayPots;
    slots[index] = id;
    _patchMorning((cp) {
      (bar ? cp.barPots : cp.displayPots)[index] = id;
    });
    pendingPlacePotId = null;
    pendingPlaceBar = null;
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  /// "Thôi" or Back.
  void cancelPlaceMode() {
    if (pendingPlacePotId == null) return;
    pendingPlacePotId = null;
    pendingPlaceBar = null;
    _changed();
  }
}
