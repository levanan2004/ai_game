part of 'shop_session.dart';

// Hoa sắp héo (hoa_sap_heo_block.json): the end-of-day clearance basket.
// Numbers come from [WiltingRules]; the dice are the session's [ShopSession.rng].

/// Clears today's basket plan. Called when a day starts.
void resetWiltingDay(ShopSession s) {
  s._clearanceRolled = false;
  s._clearanceBuyers = [];
  s._shelfRolled = false;
  s._shelfBuyers = [];
}

ClearanceRules _clearance(ShopSession s) => s.data.wilting.clearance;

/// The shop is open, the clock is between `startHour` and closing time.
bool clearanceHours(ShopSession s) {
  final c = _clearance(s);
  if (!c.enabled || s.state.phase != DayPhase.open || s.afterClose) {
    return false;
  }
  return gameHour(s.e, s.state.elapsed) >= c.startHour;
}

/// Stems in the "Rổ hoa giảm giá" per flower: on their last fresh day
/// (`freshnessThreshold`), less what accepted online orders keep.
Map<String, int> clearanceBasket(ShopSession s) {
  final c = _clearance(s);
  if (!c.enabled) return const {};
  final wilting = <String, int>{};
  for (final b in s.state.stock) {
    if (b.count > 0 && b.freshnessLeft <= c.freshnessThreshold) {
      wilting[b.flowerId] = (wilting[b.flowerId] ?? 0) + b.count;
    }
  }
  final out = <String, int>{};
  for (final w in wilting.entries) {
    final free = c.reservedStemsExcluded
        ? s.stockAvailable(w.key)
        : s.stockCount(w.key);
    final n = min(w.value, free);
    if (n > 0) out[w.key] = n;
  }
  return out;
}

int clearanceBasketCount(ShopSession s) =>
    clearanceBasket(s).values.fold(0, (a, b) => a + b);

/// Basket price of one stem of [flowerId].
int clearancePrice(ShopSession s, String flowerId) =>
    _clearance(s).priceFor(s.e.flower(flowerId).sellPrice);

/// Runs on the shop clock. At `startHour` the day's clearance buyers are
/// rolled once (Poisson(buyersPerDay)) and spread until closing time; each
/// takes up to `stemsPerBuyer`, the day at most `maxStemsSoldPerDay`.
/// Returns true when something changed on screen.
bool tickClearance(ShopSession s) {
  if (!clearanceHours(s)) return false;
  final c = _clearance(s);
  var changed = false;
  if (!s._clearanceRolled) {
    s._clearanceRolled = true;
    if (clearanceBasketCount(s) == 0) return false;
    final n = poisson(c.buyersPerDay, s.rng);
    final now = s.state.elapsed;
    final span = s.e.dayRealSeconds - now;
    s._clearanceBuyers = [
      for (var i = 0; i < n; i++) now + span * (i + 1) / (n + 1),
    ];
    s.showNotice(
      s.data.wilting.text.get('clearance', 'basketOpenToast'),
      quiet: true,
    );
    changed = true;
  }
  while (s._clearanceBuyers.isNotEmpty &&
      s._clearanceBuyers.first <= s.state.elapsed) {
    s._clearanceBuyers.removeAt(0);
    if (_clearanceBuyer(s)) changed = true;
  }
  return changed;
}

/// One clearance buyer takes stems of the flower with the most in the basket.
bool _clearanceBuyer(ShopSession s) {
  final c = _clearance(s);
  final m = s.state.metrics;
  final room = c.maxStemsSoldPerDay - m.clearanceStems;
  if (room <= 0) return false;
  final basket = clearanceBasket(s);
  if (basket.isEmpty) return false;
  final pick = basket.entries.reduce((a, b) => b.value > a.value ? b : a);
  final n = min(min(c.stemsPerBuyer, room), pick.value);
  final price = clearancePrice(s, pick.key);
  _takeOldest(s, pick.key, n);
  final money = price * n;
  s.state.money += money;
  m.clearanceStems += n;
  m.clearanceIncome += money;
  s.showNotice(
    s.data.wilting.text.get('clearance', 'soldToast', {
      'n': n,
      'tenHoa': s.e.flower(pick.key).nameVi,
      'tien': vndLabel(money),
    }),
    quiet: true,
  );
  return true;
}

/// Removes [n] stems of [flowerId], least fresh first.
void _takeOldest(ShopSession s, String flowerId, int n) {
  var left = n;
  while (left > 0) {
    final b = s.oldestBatch(flowerId);
    if (b == null) return;
    final take = min(left, b.count);
    b.count -= take;
    left -= take;
    if (b.count <= 0) s.state.stock.remove(b);
  }
}

// ---------------------------------------------------------------------------
// Hoa khô: "Giàn phơi hoa" (unlock), drying at the summary, "Kệ hoa khô".
// ---------------------------------------------------------------------------

DryingRules _drying(ShopSession s) => s.data.wilting.drying;

/// The "Giàn phơi hoa" can be bought today.
bool dryingUnlockable(ShopSession s) {
  final d = _drying(s);
  return d.enabled && !s.state.dryingUnlocked && s.state.day >= d.unlockDay;
}

/// Buys the "Giàn phơi hoa" for `unlock.unlockCost`.
bool unlockDrying(ShopSession s) {
  final d = _drying(s);
  if (!dryingUnlockable(s)) return false;
  final t = s.data.wilting.text;
  if (s.state.money < d.unlockCost) {
    s.showNotice(
      t.get('unlock', 'popupNotEnough', {'tien': vndLabel(d.unlockCost)}),
    );
    return false;
  }
  s.state.money -= d.unlockCost;
  s.state.dryingUnlocked = true;
  s.showNotice(t.get('unlock', 'unlockedToast'), quiet: true);
  return true;
}

bool dryingActive(ShopSession s) =>
    _drying(s).enabled && s.state.dryingUnlocked;

/// Rack + shelf: dried stems still drying plus finished ones (`storageCap`).
int driedStorageUsed(ShopSession s) =>
    s.state.drying.fold(0, (a, b) => a + b.stems) +
    s.state.driedStock.values.fold(0, (a, b) => a + b);

int driedStockCount(ShopSession s) =>
    s.state.driedStock.values.fold(0, (a, b) => a + b);

/// Stems the player may hang tonight, by flower: on the summary, dryable
/// (the block's list) and at most `inputFreshnessMax` days left.
Map<String, int> dryCandidates(ShopSession s) {
  final d = _drying(s);
  if (!dryingActive(s) || s.state.phase != DayPhase.summary) return const {};
  final out = <String, int>{};
  for (final b in s.state.stock) {
    if (b.count <= 0 || b.freshnessLeft > d.inputFreshnessMax) continue;
    if (!d.canDry(b.flowerId)) continue;
    out[b.flowerId] = (out[b.flowerId] ?? 0) + b.count;
  }
  return out;
}

/// Dried stems from [n] fresh stems: floor(n × conversionRatio) per lot.
int dryYield(ShopSession s, String flowerId, int n) {
  final f = _drying(s).byId(flowerId);
  if (f == null || n <= 0) return 0;
  return (n * f.conversionRatio).floor();
}

/// Hangs [picks] (flower id → fresh stems) on the rack. Refused when a pick
/// is not a candidate, the dried stems would pass `storageCap`, or the fee
/// (`dryingCostPerStem` each) is more than the money.
bool sendToDry(ShopSession s, Map<String, int> picks) {
  final d = _drying(s);
  final t = s.data.wilting.text;
  final can = dryCandidates(s);
  var stems = 0;
  var dried = 0;
  for (final p in picks.entries) {
    if (p.value <= 0) continue;
    if ((can[p.key] ?? 0) < p.value) return false;
    stems += p.value;
    dried += dryYield(s, p.key, p.value);
  }
  if (stems == 0) return false;
  if (driedStorageUsed(s) + dried > d.storageCap) {
    s.showNotice(t.get('dried', 'storageFull', {'toiDa': d.storageCap}));
    return false;
  }
  final cost = stems * d.dryingCostPerStem;
  if (s.state.money < cost) return false;
  final m = s.state.metrics;
  for (final p in picks.entries) {
    if (p.value <= 0) continue;
    _takeOldest(s, p.key, p.value);
    final out = dryYield(s, p.key, p.value);
    if (out > 0) {
      s.state.drying.add(
        DryingBatch(flowerId: p.key, stems: out, daysLeft: d.dryingDays),
      );
    }
    final wilted = (m.wiltedByFlower[p.key] ?? 0) - p.value;
    if (wilted > 0) {
      m.wiltedByFlower[p.key] = wilted;
    } else {
      m.wiltedByFlower.remove(p.key);
    }
  }
  m.stemsWilted = m.wiltedByFlower.values.fold(0, (a, b) => a + b);
  s.state.money -= cost;
  m.driedSent += stems;
  m.dryingCost += cost;
  return true;
}

/// "Sang ngày mới": one day off every rack batch; finished ones go on the
/// shelf.
void dryingMorning(ShopSession s) {
  final t = s.data.wilting.text;
  final done = <String, int>{};
  for (final b in [...s.state.drying]) {
    b.daysLeft -= 1;
    if (b.daysLeft > 0) continue;
    s.state.drying.remove(b);
    s.state.driedStock[b.flowerId] =
        (s.state.driedStock[b.flowerId] ?? 0) + b.stems;
    done[b.flowerId] = (done[b.flowerId] ?? 0) + b.stems;
  }
  for (final d in done.entries) {
    s.showNotice(
      t.get('dried', 'doneToast', {
        'n': d.value,
        'tenHoaKho': _drying(s).byId(d.key)?.name ?? d.key,
      }),
      quiet: true,
    );
  }
}

/// Runs on the shop clock. Once a day (shelf not empty) the shelf buyers
/// are rolled (Poisson(buyersPerDay × holiday multiplier)) and spread over
/// the open hours; each takes up to `stemsPerBuyer` at `driedSellPrice`.
bool tickDriedShelf(ShopSession s) {
  if (!dryingActive(s) || s.state.phase != DayPhase.open || s.afterClose) {
    return false;
  }
  final d = _drying(s);
  var changed = false;
  if (!s._shelfRolled) {
    s._shelfRolled = true;
    if (driedStockCount(s) == 0) return false;
    final mul = s.holidayToday != null ? d.holidayBuyersMultiplier : 1.0;
    final n = poisson(d.shelfBuyersPerDay * mul, s.rng);
    final now = s.state.elapsed;
    final span = s.e.dayRealSeconds - now;
    s._shelfBuyers = [
      for (var i = 0; i < n; i++) now + span * (i + 1) / (n + 1),
    ];
  }
  while (s._shelfBuyers.isNotEmpty && s._shelfBuyers.first <= s.state.elapsed) {
    s._shelfBuyers.removeAt(0);
    if (_shelfBuyer(s)) changed = true;
  }
  return changed;
}

bool _shelfBuyer(ShopSession s) {
  final d = _drying(s);
  final stock = s.state.driedStock;
  if (stock.isEmpty) return false;
  final pick = stock.entries.reduce((a, b) => b.value > a.value ? b : a);
  final def = d.byId(pick.key);
  if (def == null) return false;
  final n = min(d.shelfStemsPerBuyer, pick.value);
  if (n <= 0) return false;
  if (pick.value - n > 0) {
    stock[pick.key] = pick.value - n;
  } else {
    stock.remove(pick.key);
  }
  final money = def.driedSellPrice * n;
  s.state.money += money;
  final m = s.state.metrics;
  m.driedStemsSold += n;
  m.driedIncome += money;
  s.showNotice(
    s.data.wilting.text.get('dried', 'soldToast', {
      'n': n,
      'tenHoaKho': def.name,
      'tien': vndLabel(money),
    }),
    quiet: true,
  );
  return true;
}
