part of 'shop_session.dart';

/// Drops today's orders and vehicles. The morning generator fills them again.
void clearDeliveryDay(ShopSession s) {
  s.onlineOrders.clear();
  s.shipperRuns.clear();
  s.tableOrder = null;
  s.teaserDismissed = false;
  s.preorderBoardOpen = false;
  s._nextOnlineId = 1;
  s._spawnSecond = -1;
  s._deliveryClosed = false;
  s._expectedOnline = 0;
}

bool hasPreorderBoard(ShopSession s) => s.preorderBoardOpen;

bool _ordersActive(ShopSession s) =>
    s.state.ordersFromDay > 0 &&
    s.state.day >= s.state.ordersFromDay &&
    shippersHiredCount(s.state.shipperLevels) > 0;

void prepareDeliveryMorning(ShopSession s) {
  clearDeliveryDay(s);
  if (!_ordersActive(s)) return;
  _rebuildRuns(s);
  s._expectedOnline = expectedOnlineOrders(
    s.e,
    shopRank: s.rank.rank,
    rating: s.rating.average,
    levels: s.state.shipperLevels,
    holiday: s.holidayToday != null,
  );
  final n = preorderCount(s.e, s._expectedOnline, s.rng);
  for (var i = 0; i < n; i++) {
    _addGenerated(
      s,
      kind: OrderKind.preorder,
      spawnAt: 0,
      deadline: preorderDeadlineSeconds(s.e, s.rng),
    );
  }
  s.preorderBoardOpen = s.onlineOrders.isNotEmpty;
}

void _rebuildRuns(ShopSession s) {
  s.shipperRuns.clear();
  for (final def in s.e.delivery.shippers) {
    final lv = def.levelDef(s.state.shipperLevels[def.id] ?? 0);
    if (lv == null) continue;
    s.shipperRuns.add(
      ShipperRun(
        id: def.id,
        capacity: lv.capacity,
        deliverSeconds: lv.deliverSeconds,
        returnSeconds: lv.returnSeconds,
      ),
    );
  }
}

OnlineOrder? _findOrder(ShopSession s, int id) {
  for (final o in s.onlineOrders) {
    if (o.id == id) return o;
  }
  return null;
}

void _addGenerated(
  ShopSession s, {
  required OrderKind kind,
  required double spawnAt,
  required double deadline,
}) {
  final request = generateRequest(
    s.e,
    owned: s.owned,
    rng: s.rng,
    stemTotalRange: s.e.delivery.stemRange,
  );
  final used = s.onlineOrders.map((o) => o.customerName).toSet();
  final people = s.data.orders.customers
      .where((c) => !used.contains(c.name))
      .toList();
  final pool = people.isEmpty ? s.data.orders.customers : people;
  final profile = pool.isEmpty ? null : pool[s.rng.nextInt(pool.length)];
  final speech = pickOnlineLine(
    s.data.orders,
    kind,
    s.rng,
    s.state.recentOrderLines,
  );
  if (speech.isNotEmpty) {
    s.state.recentOrderLines.add(speech);
    final keep = s.data.orders.noRepeatLast;
    if (s.state.recentOrderLines.length > keep) {
      s.state.recentOrderLines.removeRange(
        0,
        s.state.recentOrderLines.length - keep,
      );
    }
  }
  s.onlineOrders.add(
    OnlineOrder(
      id: s._nextOnlineId++,
      kind: kind,
      customerName: profile?.name ?? 'Khách online',
      avatarId: profile?.avatarId ?? '',
      request: request,
      line: orderLine(s.e, request),
      speech: speech,
      deadline: deadline,
      spawnAt: spawnAt,
      acceptLeft: s.e.delivery.acceptSeconds,
    ),
  );
  s.sounds.effect('online_order');
}

bool _covers(ShopSession s, OnlineOrder o) {
  for (final en in stemNeeds(o.request).entries) {
    if (s.stockAvailable(en.key) < en.value) return false;
  }
  return true;
}

void _reserve(ShopSession s, OnlineOrder o) {
  for (final en in stemNeeds(o.request).entries) {
    o.reserved[en.key] = (o.reserved[en.key] ?? 0) + en.value;
  }
}

void _release(OnlineOrder o) {
  o.reserved.clear();
  o.reservedUids.clear();
}

bool _fullyReserved(OnlineOrder o) {
  for (final en in stemNeeds(o.request).entries) {
    if ((o.reserved[en.key] ?? 0) < en.value) return false;
  }
  return true;
}

void reservePreorders(ShopSession s) {
  for (final o in s.onlineOrders) {
    if (o.kind != OrderKind.preorder || o.status != OrderStatus.accepted) {
      continue;
    }
    if (o.reserved.isNotEmpty) continue;
    if (_covers(s, o)) _reserve(s, o);
  }
}

void cancelUnboughtPreorders(ShopSession s) {
  for (final o in s.onlineOrders) {
    if (o.kind != OrderKind.preorder || o.status != OrderStatus.accepted) {
      continue;
    }
    if (_fullyReserved(o)) continue;
    _release(o);
    o.status = OrderStatus.cancelled;
  }
}

void _addToCart(ShopSession s, OnlineOrder o) {
  for (final en in stemNeeds(o.request).entries) {
    final size = s.e.flower(en.key).bundleSize;
    final bundles = (en.value + size - 1) ~/ size;
    if (bundles <= 0) continue;
    o.cartBundles[en.key] = bundles;
    s.cart[en.key] = (s.cart[en.key] ?? 0) + bundles;
  }
}

void _removeFromCart(ShopSession s, OnlineOrder o) {
  for (final en in o.cartBundles.entries) {
    final left = (s.cart[en.key] ?? 0) - en.value;
    if (left <= 0) {
      s.cart.remove(en.key);
    } else {
      s.cart[en.key] = left;
    }
  }
  o.cartBundles.clear();
}

double _previewRun(ShopSession s, ShipperRun r, double now) {
  final d = s.e.delivery;
  final stops = r.load.length;
  final double depart;
  if (r.load.length + 1 >= r.capacity) {
    depart = now;
  } else if (r.load.isEmpty) {
    depart = now + d.loadWaitSeconds;
  } else {
    depart = r.loadStarted + d.loadWaitSeconds;
  }
  return depart + r.deliverSeconds + d.extraStopSeconds * stops;
}

void _departRun(ShopSession s, ShipperRun r, double at) {
  final d = s.e.delivery;
  r.departAt = at;
  r.trip
    ..clear()
    ..addAll(r.load);
  r.handoverAt.clear();
  for (var i = 0; i < r.trip.length; i++) {
    final id = r.trip[i];
    r.handoverAt[id] = at + r.deliverSeconds + d.extraStopSeconds * i;
    final o = _findOrder(s, id);
    if (o != null && o.status == OrderStatus.packed) {
      o.status = OrderStatus.dispatched;
    }
  }
  final n = r.trip.length;
  r.routeDoneAt = n == 0
      ? at
      : at + r.deliverSeconds + d.extraStopSeconds * (n - 1);
  r.backAt = r.routeDoneAt + r.returnSeconds;
  r.load.clear();
  r.handed = 0;
}

void _arriveRun(ShipperRun r) {
  r.departAt = -1;
  r.routeDoneAt = -1;
  r.backAt = -1;
  r.trip.clear();
  r.handoverAt.clear();
  r.load.clear();
  r.handed = 0;
}

void dispatchPacked(ShopSession s, double now) {
  if (s.shipperRuns.isEmpty) _rebuildRuns(s);
  while (true) {
    final shelf = [
      for (final o in s.onlineOrders)
        if (o.status == OrderStatus.packed && !_onVehicle(s, o)) o,
    ]..sort((a, b) => a.deadline.compareTo(b.deadline));
    if (shelf.isEmpty) return;
    final home = [
      for (final r in s.shipperRuns)
        if (!r.awayAt(now) && r.load.length < r.capacity) r,
    ];
    if (home.isEmpty) return;
    final order = shelf.first;
    ShipperRun? best;
    var bestH = double.infinity;
    for (final r in home) {
      final h = _previewRun(s, r, now);
      if (h < bestH) {
        bestH = h;
        best = r;
      }
    }
    final run = best!;
    if (run.load.isEmpty) run.loadStarted = now;
    run.load.add(order.id);
    order.shipperId = run.id;
    if (run.load.length >= run.capacity) _departRun(s, run, now);
  }
}

bool _onVehicle(ShopSession s, OnlineOrder o) {
  for (final r in s.shipperRuns) {
    if (r.load.contains(o.id) || r.trip.contains(o.id)) return true;
  }
  return false;
}

void _pullOffVehicle(ShopSession s, OnlineOrder o) {
  for (final r in s.shipperRuns) {
    r.load.remove(o.id);
    r.trip.remove(o.id);
    r.handoverAt.remove(o.id);
    if (r.load.isEmpty && r.departAt < 0) r.loadStarted = 0;
  }
  o.shipperId = null;
}

void _addOnlineReview(
  ShopSession s,
  OnlineOrder o, {
  required String outcome,
  String? issue,
}) {
  final before = s.rating.average.toStringAsFixed(1);
  final stars = s.e.reviewStars[outcome];
  if (stars == null) return;
  final comment = pickReviewComment(
    s.data.reviews,
    outcome: outcome,
    occasionId: o.request.occasionId,
    holidayId: s.holidayToday?.id,
    mismatchReason: null,
    rng: s.rng,
    recent: [for (final r in s.state.reviews) r.comment],
  );
  final bouquet = o.bouquet;
  s.state.addReview(
    ReviewRecord(
      day: s.state.day,
      customerName: o.customerName,
      avatarId: o.avatarId,
      occasionId: o.request.occasionId,
      stars: stars,
      comment: comment,
      outcome: outcome,
      stems: bouquet?.counts ?? Map<String, int>.from(o.request.stems),
      paperId: bouquet?.paperId ?? o.request.paperId,
      ribbonId: bouquet?.ribbonId ?? o.request.ribbonId,
      online: true,
      deliveryIssue: issue,
    ),
  );
  s.state.metrics.newReviews++;
  s._soundRating(before);
}

void _missOrder(ShopSession s, OnlineOrder o) {
  if (o.status == OrderStatus.done ||
      o.status == OrderStatus.missed ||
      o.status == OrderStatus.cancelled ||
      o.status == OrderStatus.declined ||
      o.status == OrderStatus.dispatched) {
    return;
  }
  final packed = o.status == OrderStatus.packed;
  _pullOffVehicle(s, o);
  if (!packed) _release(o);
  o.bouquet = null;
  o.status = OrderStatus.missed;
  s.state.metrics.onlineMissed++;
  s.state.money -= s.e.delivery.missedMoneyPenalty;
  _addOnlineReview(s, o, outcome: s.e.delivery.missedReview, issue: 'missed');
}

void _handover(ShopSession s, OnlineOrder o, double at) {
  if (o.status != OrderStatus.dispatched) return;
  final occasion = s.e.occasion(o.request.occasionId);
  final late = at > o.deadline + 1e-6;
  final pay = late
      ? payLate(s.e, price: o.bouquetPrice)
      : payOnTime(
          s.e,
          price: o.bouquetPrice,
          tier: o.tier,
          wrapHit: o.wrapHit,
          holidayTip: s.holidayToday?.tipMultiplier ?? 1,
          occasionTip: occasion.tipMultiplier,
        );
  o.payout = pay.total;
  o.late = late;
  o.status = OrderStatus.done;
  s.state.money += pay.total;
  s.state.metrics.onlineIncome += pay.total;
  if (late) {
    s.state.metrics.onlineLate++;
  } else {
    s.state.metrics.onlineDelivered++;
  }
  s.state.metrics.bouquetsSold++;
  if (o.tier == Tier.great) s.state.metrics.greatCount++;
  if (o.wrapHit) s.state.metrics.wrapHits++;
  s.state.metrics.occasionServed[occasion.id] =
      (s.state.metrics.occasionServed[occasion.id] ?? 0) + 1;
  s.state.lifetimeBouquetsSold++;
  s.sounds.effect('cash_register');
  _addOnlineReview(
    s,
    o,
    outcome: pay.reviewOutcome,
    issue: late ? 'late' : null,
  );
  s._soundGoals();
  for (final r in s.shipperRuns) {
    if (r.id != o.shipperId) continue;
    r.handed++;
    r.floatText = late ? 'Trễ' : '+${formatK(pay.total)}';
    r.floatLeft = 1.2;
  }
}

int _pendingSameday(ShopSession s) {
  var n = 0;
  for (final o in s.onlineOrders) {
    if (o.kind != OrderKind.sameday) continue;
    if (o.status == OrderStatus.offered ||
        o.status == OrderStatus.accepted ||
        o.status == OrderStatus.packed) {
      n++;
    }
  }
  return n;
}

/// Advances accept timers, spawns, departures and hand-overs.
/// Returns true when something the screens care about changed.
bool tickDelivery(ShopSession s, double dt, bool clockRuns) {
  var changed = false;
  for (final r in s.shipperRuns) {
    if (r.floatLeft <= 0) continue;
    r.floatLeft -= dt;
    if (r.floatLeft <= 0) {
      r.floatText = null;
      changed = true;
    }
  }
  if (!clockRuns || s.state.phase != DayPhase.open || !_ordersActive(s)) {
    return changed;
  }
  for (final o in s.onlineOrders) {
    if (o.kind != OrderKind.sameday || o.status != OrderStatus.offered) {
      continue;
    }
    o.acceptLeft -= dt;
    if (o.acceptLeft <= 0) {
      o.status = OrderStatus.declined;
      changed = true;
    }
  }
  final sec = s.state.elapsed.floor();
  while (s._spawnSecond < sec) {
    s._spawnSecond++;
    final t = s._spawnSecond.toDouble();
    if (t >= s.e.dayRealSeconds) break;
    final hour = gameHour(s.e, t);
    if (_pendingSameday(s) >= s.e.delivery.maxPending) continue;
    final p = samedaySpawnChance(s.e, hour: hour, expected: s._expectedOnline);
    if (s.rng.nextDouble() < p) {
      _addGenerated(
        s,
        kind: OrderKind.sameday,
        spawnAt: t,
        deadline: samedayDeadline(s.e, t),
      );
      changed = true;
    }
  }
  for (final r in s.shipperRuns) {
    if (!r.awayAt(s.state.elapsed) &&
        r.load.isNotEmpty &&
        r.load.length < r.capacity &&
        s.state.elapsed >= r.loadStarted + s.e.delivery.loadWaitSeconds) {
      _departRun(s, r, r.loadStarted + s.e.delivery.loadWaitSeconds);
      changed = true;
    }
    if (r.departAt >= 0) {
      for (final id in [...r.trip]) {
        final o = _findOrder(s, id);
        final at = r.handoverAt[id];
        if (o == null || at == null || s.state.elapsed < at) continue;
        if (o.status == OrderStatus.dispatched) {
          _handover(s, o, at);
          changed = true;
        }
      }
      if (s.state.elapsed >= r.backAt) {
        _arriveRun(r);
        changed = true;
      }
    }
  }
  final before = s.onlineOrders.where((o) => o.shipperId == null).length;
  dispatchPacked(s, s.state.elapsed);
  if (s.onlineOrders.where((o) => o.shipperId == null).length != before) {
    changed = true;
  }
  for (final o in [...s.onlineOrders]) {
    if (!o.waitingDispatch || s.state.elapsed < o.deadline) continue;
    _missOrder(s, o);
    changed = true;
  }
  return changed;
}

void settleDeliveryClose(ShopSession s) {
  if (s._deliveryClosed) return;
  s._deliveryClosed = true;
  var out = 0;
  for (final r in s.shipperRuns) {
    if (r.departAt >= 0 && s.state.elapsed < r.backAt) out++;
  }
  s.state.metrics.tripsOutAtClose = out;
  for (final o in [...s.onlineOrders]) {
    if (o.status == OrderStatus.offered) o.status = OrderStatus.declined;
    if (o.waitingDispatch) _missOrder(s, o);
  }
  for (final r in s.shipperRuns) {
    if (r.departAt < 0) continue;
    for (final id in [...r.trip]) {
      final o = _findOrder(s, id);
      final at = r.handoverAt[id];
      if (o != null && at != null) _handover(s, o, at);
    }
    _arriveRun(r);
  }
  s.state.metrics.shipperWages = shipperWages(s.e, s.state.shipperLevels);
}

void packOnlineOrder(ShopSession s, bool hit) {
  final o = s.tableOrder;
  if (o == null) return;
  final match = scoreBouquet(s.e, o.request, s.draft);
  o.bouquet = s.draft;
  o.tier = match.tier;
  o.wrapHit = hit;
  o.bouquetPrice = bouquetPrice(s.e, s.draft, multiplier: 1);
  var supplies = 0;
  if (s.draft.paperId != null) supplies += s.e.paper(s.draft.paperId!).buyPrice;
  if (s.draft.ribbonId != null) {
    supplies += s.e.ribbon(s.draft.ribbonId!).buyPrice;
  }
  s.state.money -= supplies;
  s.state.metrics.wrapSupplies += supplies;
  o.reserved.clear();
  o.reservedUids.clear();
  o.status = OrderStatus.packed;
  s.sounds.effect('bouquet_done');
  s.draft = Bouquet();
  s.wrapping = false;
  s.tableOrder = null;
  if (s.state.phase == DayPhase.open) dispatchPacked(s, s.state.elapsed);
}

extension DeliveryApi on ShopSession {
  bool get ordersActive => _ordersActive(this);

  bool get showShipperTeaser {
    if (teaserDismissed || shippersHiredCount(state.shipperLevels) > 0) {
      return false;
    }
    if (state.phase != DayPhase.preparing) return false;
    int? day;
    for (final shipper in this.e.delivery.shippers) {
      final unlockDay = shipper.unlock.day;
      if (unlockDay != null && (day == null || unlockDay < day)) {
        day = unlockDay;
      }
    }
    return day != null && state.day >= day;
  }

  void dismissTeaser() {
    teaserDismissed = true;
    _changed();
  }

  bool get hasOnlineStrip =>
      (state.phase == DayPhase.preparing || state.phase == DayPhase.open) &&
      onlineOrders.any((o) => o.open);

  List<OnlineOrder> get stripOrders => [
    for (final o in onlineOrders)
      if (o.open) o,
  ];

  OnlineOrder? get incomingSameDay {
    for (final o in onlineOrders) {
      if (o.kind == OrderKind.sameday && o.status == OrderStatus.offered) {
        return o;
      }
    }
    return null;
  }

  int get extraIncoming {
    var n = 0;
    var seen = false;
    for (final o in onlineOrders) {
      if (o.kind != OrderKind.sameday || o.status != OrderStatus.offered) {
        continue;
      }
      if (!seen) {
        seen = true;
        continue;
      }
      n++;
    }
    return n;
  }

  int onlineStemDemand(String flowerId) {
    var n = 0;
    for (final o in onlineOrders) {
      if (o.kind != OrderKind.preorder || o.status != OrderStatus.accepted) {
        continue;
      }
      n += stemNeeds(o.request)[flowerId] ?? 0;
    }
    return n;
  }

  bool orderOnTime(OnlineOrder o) {
    final accepted = [
      for (final other in onlineOrders)
        if (other.kind == OrderKind.preorder &&
            other.status == OrderStatus.accepted &&
            other.id != o.id)
          other.deadline,
    ];
    return wouldArriveOnTime(
      this.e,
      levels: state.shipperLevels,
      acceptedDeadlines: accepted,
      extraDeadline: o.deadline,
    );
  }

  bool orderUrgent(OnlineOrder o) {
    if (!o.open || state.phase != DayPhase.open) return false;
    final start = o.kind == OrderKind.preorder ? 0.0 : o.spawnAt;
    final total = o.deadline - start;
    if (total <= 0) return o.deadline - state.elapsed <= 0;
    return (o.deadline - state.elapsed) / total < 0.2;
  }

  (String, int)? sameDayShortage(OnlineOrder o) =>
      missingStem(this.e, o.request, (id) => stockAvailable(id));

  ShipperOffer shipperOfferFor(String id) => shipperOffer(
    this.e,
    this.e.delivery.shipper(id),
    day: state.day,
    rank: rank.rank,
    levels: state.shipperLevels,
    money: state.money,
    shopClosed: shopClosed,
  );

  ShipperLevelDef shipperStats(String id) {
    final def = this.e.delivery.shipper(id);
    final lv = state.shipperLevels[id] ?? 0;
    return def.levelDef(lv <= 0 ? 1 : lv)!;
  }

  bool hireShipper(String id) {
    final offer = shipperOfferFor(id);
    if (!offer.canBuy) return false;
    final current = state.shipperLevels[id] ?? 0;
    state.money -= offer.cost;
    if (current <= 0) {
      state.shipperLevels[id] = 1;
      if (state.ordersFromDay == 0) state.ordersFromDay = state.day + 1;
    } else {
      state.shipperLevels[id] = current + 1;
    }
    _rebuildRuns(this);
    _changed();
    return true;
  }

  void acceptPreorder(OnlineOrder o) {
    if (o.kind != OrderKind.preorder || o.status != OrderStatus.offered) {
      return;
    }
    o.status = OrderStatus.accepted;
    _addToCart(this, o);
    _changed();
  }

  void unacceptPreorder(OnlineOrder o) {
    if (o.kind != OrderKind.preorder || o.status != OrderStatus.accepted) {
      return;
    }
    if (state.phase != DayPhase.market) return;
    _removeFromCart(this, o);
    _release(o);
    o.status = OrderStatus.offered;
    _changed();
  }

  void declinePreorder(OnlineOrder o) {
    if (o.kind != OrderKind.preorder || o.status != OrderStatus.offered) {
      return;
    }
    o.status = OrderStatus.declined;
    _changed();
  }

  void leavePreorderBoard() {
    for (final o in onlineOrders) {
      if (o.kind == OrderKind.preorder && o.status == OrderStatus.offered) {
        o.status = OrderStatus.declined;
      }
    }
    preorderBoardOpen = false;
    screen = Screen.market;
    _changed();
  }

  bool acceptSameDay(OnlineOrder o) {
    if (o.kind != OrderKind.sameday || o.status != OrderStatus.offered) {
      return false;
    }
    if (this.e.delivery.acceptRequiresStock && !_covers(this, o)) return false;
    _reserve(this, o);
    o.status = OrderStatus.accepted;
    _changed();
    return true;
  }

  void skipSameDay(OnlineOrder o) {
    if (o.status != OrderStatus.offered) return;
    o.status = OrderStatus.declined;
    _changed();
  }

  void openOnlineOrder(int id) {
    final o = _findOrder(this, id);
    if (o == null || o.status != OrderStatus.accepted) return;
    if (state.phase != DayPhase.preparing && state.phase != DayPhase.open) {
      return;
    }
    if (screen == Screen.table &&
        (tableCustomer != null || tableOrder != null)) {
      return;
    }
    tableCustomer = null;
    tableOrder = o;
    draft = Bouquet();
    if (effects.autoPaperRibbon) {
      if (owned.contains(o.request.paperId)) draft.paperId = o.request.paperId;
      if (owned.contains(o.request.ribbonId)) {
        draft.ribbonId = o.request.ribbonId;
      }
    }
    screen = Screen.table;
    _changed();
  }

  void sendShipper(String id) {
    for (final r in shipperRuns) {
      if (r.id != id || r.load.isEmpty || r.awayAt(state.elapsed)) continue;
      _departRun(this, r, state.elapsed);
      _changed();
      return;
    }
  }

  void showShopAfterOnlinePack() {
    if (screen == Screen.table && tableCustomer == null && tableOrder == null) {
      screen = Screen.shop;
      _changed();
    }
  }

  /// Test hook: an incoming same-day order with a chosen request.
  OnlineOrder debugIncoming(BouquetRequest request, {double? deadline}) {
    final o = OnlineOrder(
      id: _nextOnlineId++,
      kind: OrderKind.sameday,
      customerName: 'Khách online',
      avatarId: '',
      request: request,
      line: orderLine(this.e, request),
      speech: data.orders.onlineSameday.isEmpty
          ? ''
          : data.orders.onlineSameday.first,
      deadline: deadline ?? samedayDeadline(this.e, state.elapsed),
      spawnAt: state.elapsed,
      acceptLeft: this.e.delivery.acceptSeconds,
    );
    onlineOrders.add(o);
    _changed();
    return o;
  }
}
