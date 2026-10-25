part of 'shop_session.dart';

// Hoa sắp héo (hoa_sap_heo_block.json): the end-of-day clearance basket.
// Numbers come from [WiltingRules]; the dice are the session's [ShopSession.rng].

/// Clears today's basket plan. Called when a day starts.
void resetWiltingDay(ShopSession s) {
  s._clearanceRolled = false;
  s._clearanceBuyers = [];
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
