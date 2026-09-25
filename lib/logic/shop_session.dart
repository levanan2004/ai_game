import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/economy.dart';
import '../data/game_data.dart';
import '../data/texts.dart';
import '../save/game_state.dart';
import '../save/progress_store.dart';
import 'bouquet.dart';
import 'customers.dart';
import 'delivery.dart';
import 'format.dart';
import 'goals.dart';
import 'match_scoring.dart';
import 'payment.dart';
import 'rating.dart';
import 'review_picker.dart';
import 'upgrades.dart';

part 'delivery_runtime.dart';

enum Screen {
  title,
  market,
  shop,
  table,
  reviews,
  summary,
  upgrades,
  preorders,
}

/// Celebration popups, shown one at a time in this order
/// (spec_popup_va_mo_dau.md: lên hạng, mở khóa, rồi ngày lễ).
sealed class GamePopup {
  const GamePopup();
  int get order;
}

class RankUpPopup extends GamePopup {
  const RankUpPopup(this.rank);
  final ShopRankDef rank;
  @override
  int get order => 0;
}

class UnlockPopup extends GamePopup {
  const UnlockPopup(this.itemId);
  final String itemId;
  @override
  int get order => 1;
}

class HolidayPopup extends GamePopup {
  const HolidayPopup(this.holiday);
  final HolidayDef holiday;
  @override
  int get order => 2;
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.avatarId,
    required this.request,
    required this.requestLine,
    required this.patienceMax,
    required this.walkIn,
  }) : patienceLeft = patienceMax;

  final int id;
  final String name;

  /// File name in assets/images/customers ('' = drawn placeholder).
  final String avatarId;
  final BouquetRequest request;
  final String requestLine;
  final double patienceMax;
  double patienceLeft;

  /// Seconds until the customer reaches the queue (not servable before).
  double walkIn;

  /// Patience stops while the bouquet is being wrapped or auto-served.
  bool frozen = false;

  /// Seconds left while the florist (staff level 2) serves this customer.
  double? autoServeLeft;

  /// Tutorial customer: patience stands still until the tutorial ends.
  bool patienceLocked = false;

  bool get arrived => walkIn <= 0;
  double get patienceFraction =>
      patienceMax <= 0 ? 0 : (patienceLeft / patienceMax).clamp(0.0, 1.0);
}

/// A customer who ran out of patience; the shop shows an angry bubble.
class Departure {
  Departure(this.customer, this.stars);

  final Customer customer;
  final int stars;
  double age = 0;
}

class DeliveryResult {
  const DeliveryResult({
    required this.customer,
    required this.match,
    required this.payment,
    required this.review,
    required this.wrapHit,
  });

  final Customer customer;
  final MatchResult match;
  final Payment payment;
  final ReviewRecord review;
  final bool wrapHit;
}

/// Summary of the settled day (Tổng kết), built from [DayMetrics].
class DaySummaryView {
  const DaySummaryView(this.metrics, this.rating, this.upkeep);

  final DayMetrics metrics;
  final double rating;
  final int upkeep;
}

/// The whole game model: day loop, queue, stock, bouquet, reviews, save.
///
/// Pure Dart + [ChangeNotifier]; the Flame game calls [tick] every frame and
/// Flutter widgets listen to it.
class ShopSession extends ChangeNotifier {
  ShopSession({
    required this.data,
    required ProgressStore store,
    GameState? saved,
    Random? random,
  }) : _store = store,
       rng = random ?? Random(),
       hasSave = saved != null {
    state = saved ?? _newGame();
    _checkpoint = state.encode();
    _resumeScreen();
  }

  final GameData data;
  final ProgressStore _store;
  final Random rng;
  late GameState state;

  Economy get e => data.economy;

  Screen screen = Screen.market;
  Screen _reviewsReturn = Screen.shop;

  /// Reviews screen filter to show when it opens (0 = all, 1 = today).
  int reviewsInitialFilter = 0;

  /// Upgrades screen tab to show when it opens.
  int upgradesInitialTab = 0;
  Screen _upgradesReturn = Screen.shop;

  bool paused = false;

  /// Pause popup visible (spec_popup_va_mo_dau.md §1).
  bool pauseMenuOpen = false;

  /// Whether a save existed when the game started or has been written since
  /// (title screen: "Chơi tiếp" vs "Bắt đầu").
  bool hasSave;

  /// Last committed start-of-day state ("Về màn đầu" goes back to it).
  late String _checkpoint;

  /// Celebration popups waiting to be shown; the first one is visible.
  final List<GamePopup> popups = [];
  int _holidayPopupDay = 0;

  /// First-day tutorial step 1..8, 0 = not running (spec §6).
  int tutorialStep = 0;

  /// Tutorial opened from the pause popup in view mode (1..8, 0 = closed).
  int tutorialViewStep = 0;

  static const tutorialSteps = 8;

  final List<Customer> queue = [];
  final List<Departure> departures = [];
  int _nextCustomerId = 1;
  int _nextStemUid = 1;

  /// Customer at the bouquet table, and the bouquet being built.
  Customer? tableCustomer;
  Bouquet draft = Bouquet();
  bool wrapping = false;
  bool _fastService = false;

  /// Result shown in the review popup (null = no popup).
  DeliveryResult? lastDelivery;

  /// Money not yet shown in the top bar (revealed when the popup closes).
  int pendingReveal = 0;

  /// Market cart: flower id to number of bundles.
  final Map<String, int> cart = {};

  /// Today's online orders and hired vehicles. Cleared each morning.
  final List<OnlineOrder> onlineOrders = [];
  final List<ShipperRun> shipperRuns = [];

  /// Bouquet table opened for an online order (no walk-in customer).
  OnlineOrder? tableOrder;

  /// Teaser card dismissed for today only.
  bool teaserDismissed = false;

  /// Morning preorder board is up until "Đi chợ hoa".
  bool preorderBoardOpen = false;

  int _nextOnlineId = 1;
  int _spawnSecond = -1;
  bool _deliveryClosed = false;
  double _expectedOnline = 0;

  /// One-line message under the main button (e.g. upgrades while open).
  String? shopNotice;
  double _noticeLeft = 0;

  double _notifyAccumulator = 0;
  Future<void> _pendingSaves = Future<void>.value();

  /// Completes after queued writes finish (tests await this).
  Future<void> get pendingSaves => _pendingSaves;

  // ---------------------------------------------------------------------
  // Derived values
  // ---------------------------------------------------------------------

  Set<String> get owned => state.unlockedItems.toSet();

  UpgradeEffects get effects =>
      UpgradeEffects(e, state.upgradeLevels, adsActive: state.adsDaysLeft > 0);

  List<FlowerDef> get unlockedFlowers => [
    for (final f in e.flowers)
      if (owned.contains(f.id)) f,
  ];
  List<ItemDef> get unlockedPapers => [
    for (final p in e.papers)
      if (owned.contains(p.id)) p,
  ];
  List<ItemDef> get unlockedRibbons => [
    for (final r in e.ribbons)
      if (owned.contains(r.id)) r,
  ];

  RatingSummary get rating => summarizeRatings(
    [for (final r in state.reviews) r.stars],
    window: e.ratingWindow,
    fallback: e.startRating,
  );

  ShopRankDef get rank => e.rankFor(state.lifetimeBouquetsSold);
  HolidayDef? get holidayToday => e.holidayOn(state.day);

  int get displayMoney => state.money - pendingReveal;

  bool get shopClosed =>
      state.phase == DayPhase.market || state.phase == DayPhase.preparing;

  int stockCount(String flowerId) => state.stock
      .where((b) => b.flowerId == flowerId)
      .fold(0, (a, b) => a + b.count);

  /// Oldest batch (used first) of a flower, or null when out of stock.
  StockBatch? oldestBatch(String flowerId) {
    StockBatch? best;
    for (final b in state.stock) {
      if (b.flowerId != flowerId || b.count <= 0) continue;
      if (best == null || b.freshnessLeft < best.freshnessLeft) best = b;
    }
    return best;
  }

  /// Full freshness for newly bought stems (cold storage adds days).
  int fullFreshness(FlowerDef f) =>
      f.freshnessDays + effects.freshnessBonusDays;

  /// 0..1 freshness of the stems that will be used next.
  double freshnessFraction(String flowerId) {
    final b = oldestBatch(flowerId);
    if (b == null) return 0;
    return (b.freshnessLeft / fullFreshness(e.flower(flowerId))).clamp(
      0.0,
      1.0,
    );
  }

  bool isWilting(String flowerId) =>
      (oldestBatch(flowerId)?.freshnessLeft ?? 9) <= 1;

  /// Stems a walk-in (or [forOrder]) may still take. Accepted online orders
  /// keep their reservation in stock until the bouquet is packed.
  int stockAvailable(String flowerId, {OnlineOrder? forOrder}) {
    var reserved = 0;
    for (final o in onlineOrders) {
      if (forOrder != null && identical(o, forOrder)) continue;
      if (o.status == OrderStatus.accepted) {
        reserved += o.reserved[flowerId] ?? 0;
      }
    }
    final n = stockCount(flowerId) - reserved;
    return n < 0 ? 0 : n;
  }

  /// Every unlocked pot is out of stems the counter can still sell.
  bool get shelfEmpty =>
      unlockedFlowers.isEmpty ||
      unlockedFlowers.every((f) => stockAvailable(f.id) == 0);

  /// Open, and the clock has reached `day.closeHour`.
  bool get afterClose =>
      state.phase == DayPhase.open &&
      state.elapsed / e.secondsPerHour >= (e.closeHour - e.openHour);

  /// In-game time "10:40", or "Đóng cửa" once [afterClose].
  String get clockText {
    if (afterClose) return 'Đóng cửa';
    if (state.phase != DayPhase.open) return formatClock(e.openHour, 0);
    final hours = (state.elapsed / e.secondsPerHour).clamp(
      0.0,
      (e.closeHour - e.openHour).toDouble(),
    );
    final total = (hours * 60).floor();
    return formatClock(e.openHour + total ~/ 60, total % 60);
  }

  bool get dayOver => afterClose;

  /// First arrived customer the player can serve.
  Customer? get nextForPlayer {
    for (final c in queue) {
      if (c.arrived && c.autoServeLeft == null) return c;
    }
    return null;
  }

  MatchResult? get draftMatch {
    final request = tableOrder?.request ?? tableCustomer?.request;
    if (request == null) return null;
    return scoreBouquet(e, request, draft);
  }

  bool get canDeliver =>
      (tableCustomer != null || tableOrder != null) &&
      draft.stems.isNotEmpty &&
      draft.paperId != null;

  List<String> get _recentComments => [
    for (final r in state.reviews) r.comment,
  ];

  // ---------------------------------------------------------------------
  // New game / resume
  // ---------------------------------------------------------------------

  GameState _newGame() {
    final s = GameState(
      money: e.startCash,
      day: 1,
      lifetimeBouquetsSold: 0,
      stock: [],
      reviews: [],
      goals: [],
      metrics: DayMetrics(),
      phase: DayPhase.market,
      unlockedItems: [
        ...e.unlockedFlowers,
        ...e.unlockedPapers,
        ...e.unlockedRibbons,
      ],
    );
    state = s;
    _startDay();
    return s;
  }

  void _startDay() {
    state.metrics = DayMetrics()..ratingAtStart = rating.average;
    state.goals = pickDailyGoals(
      e,
      shopRank: rank.rank,
      isHoliday: holidayToday != null,
      unlockedOccasions: unlockedOccasions(e, owned),
      ownedUpgrades: state.upgradeLevels.keys.toSet(),
      shippersHired: shippersHiredCount(state.shipperLevels),
      rng: rng,
    );
    state.phase = DayPhase.market;
    state.elapsed = 0;
    state.pendingArrivals = [];
    prepareDeliveryMorning(this);
  }

  void _resumeScreen() {
    if (state.phase == DayPhase.market && hasPreorderBoard(this)) {
      screen = Screen.preorders;
      return;
    }
    screen = switch (state.phase) {
      DayPhase.market => Screen.market,
      DayPhase.preparing || DayPhase.open => Screen.shop,
      DayPhase.summary => Screen.summary,
    };
  }

  /// Writes the current state as the save. Only called at day boundaries
  /// (new game, "Sang ngày mới"): mid-day progress is never committed, so
  /// leaving mid-day replays the day from its morning (spec §1).
  void _commit() {
    _checkpoint = state.encode();
    hasSave = true;
    final copy = GameState.decode(_checkpoint);
    if (copy == null) return;
    _pendingSaves = _pendingSaves.then((_) => _store.save(copy));
  }

  /// Persists the tutorial flag into the morning save without committing
  /// the rest of today's progress.
  void _setTutorialDone() {
    state.tutorialDone = true;
    final cp = GameState.decode(_checkpoint);
    if (cp == null) return;
    cp.tutorialDone = true;
    _checkpoint = cp.encode();
    if (!hasSave) return;
    _pendingSaves = _pendingSaves.then((_) => _store.save(cp));
  }

  void _resetTransient() {
    queue.clear();
    departures.clear();
    tableCustomer = null;
    draft = Bouquet();
    wrapping = false;
    lastDelivery = null;
    pendingReveal = 0;
    cart.clear();
    popups.clear();
    tutorialStep = 0;
    tutorialViewStep = 0;
    shopNotice = null;
    paused = false;
    pauseMenuOpen = false;
    clearDeliveryDay(this);
  }

  // ---------------------------------------------------------------------
  // Title screen, pause, popups
  // ---------------------------------------------------------------------

  void showTitle() {
    screen = Screen.title;
    _changed();
  }

  /// "Chơi tiếp": resume the saved morning.
  void continueGame() {
    _resetTransient();
    if (state.phase == DayPhase.market) prepareDeliveryMorning(this);
    _resumeScreen();
    if (state.phase == DayPhase.market) _queueHolidayPopup();
    _maybeStartTutorial();
    _changed();
  }

  /// "Bắt đầu" / "Chơi mới": day 1 from `start`. The tutorial flag is kept
  /// so a returning player isn't walked through it again.
  void startNewGame() {
    final seen = state.tutorialDone;
    _resetTransient();
    _newGame();
    state.tutorialDone = seen;
    _commit();
    screen = hasPreorderBoard(this) ? Screen.preorders : Screen.market;
    _maybeStartTutorial();
    _changed();
  }

  /// "Về màn đầu": drop today's progress and reload the morning save.
  void backToTitle() {
    final cp = GameState.decode(_checkpoint);
    if (cp != null) state = cp;
    _resetTransient();
    screen = Screen.title;
    _changed();
  }

  /// Pause button (Tiệm chính, Bàn bó hoa) or hidden browser tab.
  void openPause() {
    paused = true;
    pauseMenuOpen = true;
    _changed();
  }

  void resumeFromPause() {
    paused = false;
    pauseMenuOpen = false;
    tutorialViewStep = 0;
    _changed();
  }

  /// Browser tab hidden: pause only while the shop is open.
  void autoPause() {
    if (state.phase != DayPhase.open || pauseMenuOpen) return;
    if (screen != Screen.shop && screen != Screen.table) return;
    openPause();
  }

  GamePopup? get currentPopup => popups.isEmpty ? null : popups.first;

  void _pushPopup(GamePopup p) {
    popups.add(p);
    popups.sort((a, b) => a.order.compareTo(b.order));
  }

  void closePopup() {
    if (popups.isNotEmpty) popups.removeAt(0);
    _changed();
  }

  /// Unlock popup "Ra chợ": only offered in the morning (market phase).
  void closePopupAndGoToMarket() {
    if (popups.isNotEmpty) popups.removeAt(0);
    if (state.phase == DayPhase.market) {
      screen = hasPreorderBoard(this) ? Screen.preorders : Screen.market;
    }
    _changed();
  }

  void _queueHolidayPopup() {
    final h = holidayToday;
    if (h == null || _holidayPopupDay == state.day) return;
    _holidayPopupDay = state.day;
    _pushPopup(HolidayPopup(h));
  }

  /// Upcoming holiday for the market poster: (holiday, days until).
  (HolidayDef, int)? get posterHoliday =>
      e.upcomingHoliday(state.day, e.posterDaysBefore);

  // ---------------------------------------------------------------------
  // First-day tutorial (spec §6)
  // ---------------------------------------------------------------------

  bool get tutorialActive => tutorialStep > 0;

  /// Day clock and new arrivals stand still from step 3 to step 8.
  bool get _tutorialHoldsClock => tutorialStep >= 3;

  void _maybeStartTutorial() {
    if (state.tutorialDone || state.day != 1) return;
    if (state.phase != DayPhase.market || state.lifetimeBouquetsSold > 0) {
      return;
    }
    tutorialStep = 1;
  }

  void _advanceTutorial(int from) {
    if (tutorialStep != from) return;
    tutorialStep = from + 1;
    _changed();
  }

  /// Step 5 ends when the player taps the dialogue card.
  void tutorialCardTapped() => _advanceTutorial(5);

  /// Step 7 ends on the first release of the mini-game button.
  void tutorialWrapReleased() => _advanceTutorial(7);

  void _endTutorial() {
    tutorialStep = 0;
    for (final c in queue) {
      c.patienceLocked = false;
    }
    _setTutorialDone();
    _changed();
  }

  /// "Bỏ qua": ends the tutorial for good.
  void skipTutorial() => _endTutorial();

  void openTutorialView() {
    pauseMenuOpen = false;
    tutorialViewStep = 1;
    _changed();
  }

  /// View mode: next step, back to the pause popup after the last one.
  void nextTutorialView() {
    tutorialViewStep++;
    if (tutorialViewStep > tutorialSteps) closeTutorialView();
    _changed();
  }

  void closeTutorialView() {
    tutorialViewStep = 0;
    pauseMenuOpen = paused;
    _changed();
  }

  void _checkTutorialDraft() {
    final c = tableCustomer;
    if (tutorialStep != 6 || c == null) return;
    final need = c.request.total + c.request.fillerCount;
    if (draft.stems.length >= need && draft.paperId != null) tutorialStep = 7;
  }

  void _changed() {
    _notifyAccumulator = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Market (Chợ hoa)
  // ---------------------------------------------------------------------

  int bundlePrice(FlowerDef f) => e.bundlePrice(f, state.day);

  int get cartTotal {
    var sum = 0;
    for (final entry in cart.entries) {
      sum += bundlePrice(e.flower(entry.key)) * entry.value;
    }
    return sum;
  }

  int get cartBundles => cart.values.fold(0, (a, b) => a + b);
  int get cartStems {
    var sum = 0;
    for (final entry in cart.entries) {
      sum += e.flower(entry.key).bundleSize * entry.value;
    }
    return sum;
  }

  /// Spending limit: cash, or `minMarketBudget` when buying on credit.
  int get marketLimit => max(state.money, e.minMarketBudget);

  bool get onCredit => cartTotal > state.money;

  bool canAddBundle(String flowerId) =>
      owned.contains(flowerId) &&
      cartTotal + bundlePrice(e.flower(flowerId)) <= marketLimit;

  void addBundle(String flowerId) {
    if (!canAddBundle(flowerId)) return;
    cart[flowerId] = (cart[flowerId] ?? 0) + 1;
    if (tutorialStep == 1) tutorialStep = 2;
    _changed();
  }

  void removeBundle(String flowerId) {
    final n = cart[flowerId] ?? 0;
    if (n <= 0) return;
    if (n == 1) {
      cart.remove(flowerId);
    } else {
      cart[flowerId] = n - 1;
    }
    if (tutorialStep == 2 && cart.isEmpty) tutorialStep = 1;
    _changed();
  }

  /// "Mua & mở cửa" / "Mở cửa luôn": pay, stock up, go to Preparing.
  void buyAndGoToShop() {
    final total = cartTotal;
    for (final entry in cart.entries) {
      final f = e.flower(entry.key);
      state.stock.add(
        StockBatch(
          flowerId: f.id,
          count: f.bundleSize * entry.value,
          freshnessLeft: fullFreshness(f),
        ),
      );
    }
    state.money -= total;
    state.metrics.marketSpend += total;
    cart.clear();
    reservePreorders(this);
    state.phase = DayPhase.preparing;
    screen = Screen.shop;
    if (tutorialStep == 2) tutorialStep = 3;
    _changed();
  }

  /// "Chợ hoa" button in the Preparing state.
  void backToMarket() {
    if (state.phase != DayPhase.preparing) return;
    state.phase = DayPhase.market;
    screen = Screen.market;
    _changed();
  }

  // ---------------------------------------------------------------------
  // Opening and the day clock
  // ---------------------------------------------------------------------

  double get expectedCustomers {
    final h = holidayToday;
    return e.baseCustomers(state.day) *
        e.ratingFactorFor(rating.average) *
        effects.customerMultiplier *
        (h?.customerMultiplier ?? 1.0);
  }

  void openShop() {
    if (state.phase != DayPhase.preparing) return;
    cancelUnboughtPreorders(this);
    state.phase = DayPhase.open;
    state.elapsed = 0;
    dispatchPacked(this, 0);
    state.pendingArrivals = scheduleArrivals(
      e,
      poisson(expectedCustomers, rng),
      rng,
    );
    if (tutorialStep == 3) {
      tutorialStep = 4;
      _spawnCustomer(tutorial: true);
    }
    _changed();
  }

  /// Top-bar pause button: opens the pause popup.
  void togglePause() => pauseMenuOpen ? resumeFromPause() : openPause();

  void showNotice(String text) {
    shopNotice = text;
    // spec_ban_bo_hoa / tiem_chinh do not give a duration; 2 s like the
    // angry-bubble timing order of magnitude.
    _noticeLeft = 2;
    _changed();
  }

  /// Advances the simulation by [dt] real seconds.
  void tick(double dt) {
    var structural = false;
    for (final d in departures) {
      d.age += dt;
    }
    final before = departures.length;
    departures.removeWhere((d) => d.age > departureSeconds + 1.2);
    if (departures.length != before) structural = true;
    if (_noticeLeft > 0) {
      _noticeLeft -= dt;
      if (_noticeLeft <= 0) {
        shopNotice = null;
        structural = true;
      }
    }

    if (!paused && state.phase == DayPhase.open) {
      final clockRuns = !_tutorialHoldsClock;
      if (clockRuns) state.elapsed += dt;
      // Arrivals are scheduled before closeHour. Once the clock reaches
      // closing time, drop anyone not yet spawned.
      final closeAt = e.dayRealSeconds;
      while (clockRuns &&
          state.pendingArrivals.isNotEmpty &&
          state.pendingArrivals.first <= state.elapsed &&
          state.pendingArrivals.first < closeAt) {
        state.pendingArrivals.removeAt(0);
        _spawnCustomer();
        structural = true;
      }
      if (clockRuns && state.elapsed >= closeAt) {
        if (state.pendingArrivals.isNotEmpty) {
          state.pendingArrivals.clear();
          structural = true;
        }
      }
      for (final c in [...queue]) {
        if (c.walkIn > 0) {
          c.walkIn -= dt;
          if (c.walkIn <= 0) structural = true;
          continue;
        }
        if (c.autoServeLeft != null) {
          c.autoServeLeft = c.autoServeLeft! - dt;
          if (c.autoServeLeft! <= 0) {
            _finishAutoServe(c);
            structural = true;
          }
          continue;
        }
        if (c.frozen || c.patienceLocked) continue;
        c.patienceLeft -= dt;
        if (c.patienceLeft <= 0) {
          _customerLeaves(c);
          structural = true;
        }
      }
      _startAutoServeIfPossible();
      if (tickDelivery(this, dt, clockRuns)) structural = true;
      // Closing time: whoever is already queued may still be served until
      // their patience runs out. An empty queue ends the day.
      if (clockRuns &&
          afterClose &&
          queue.isEmpty &&
          tableCustomer == null &&
          tableOrder == null &&
          lastDelivery == null &&
          !wrapping) {
        _finishDay();
        structural = true;
      }
    }

    _notifyAccumulator += dt;
    if (structural || _notifyAccumulator >= 0.1) _changed();
  }

  /// Angry bubble time on the main shop (spec_danh_gia.md: ~1.5 s).
  static const departureSeconds = 1.5;

  void _spawnCustomer({bool tutorial = false}) {
    final fx = effects;
    if (queue.length >= fx.counterSlots + fx.maxQueue) {
      // walkedPast: leaves at once, reviewStars null = no review.
      return;
    }
    final inQueue = queue.map((c) => c.name).toSet();
    final everyone = data.orders.customers;
    final free = everyone.where((c) => !inQueue.contains(c.name)).toList();
    final CustomerProfile? profile = free.isNotEmpty
        ? free[rng.nextInt(free.length)]
        : (everyone.isEmpty ? null : everyone[rng.nextInt(everyone.length)]);
    final request = tutorial
        ? easyRequest(e, stock: _stockByFlower(), rng: rng)
        : generateRequest(e, owned: owned, rng: rng);
    final line = pickOrderLine(
      data.orders,
      occasionId: request.occasionId,
      holidayId: holidayToday?.id,
      rng: rng,
      recent: state.recentOrderLines,
      speaker: profile,
    );
    if (line.isNotEmpty) {
      state.recentOrderLines.add(line);
      final keep = data.orders.noRepeatLast;
      if (state.recentOrderLines.length > keep) {
        state.recentOrderLines.removeRange(
          0,
          state.recentOrderLines.length - keep,
        );
      }
    }
    final id = _nextCustomerId++;
    queue.add(
      Customer(
        id: id,
        name: profile?.name ?? '',
        avatarId: profile?.avatarId ?? '',
        request: request,
        requestLine: line,
        patienceMax: e.patienceSeconds * fx.patienceMultiplier,
        walkIn: e.walkInSeconds,
      )..patienceLocked = tutorial,
    );
  }

  Map<String, int> _stockByFlower() {
    final m = <String, int>{};
    for (final b in state.stock) {
      m[b.flowerId] = (m[b.flowerId] ?? 0) + b.count;
    }
    return m;
  }

  void _customerLeaves(Customer c) {
    queue.remove(c);
    final stars = e.reviewStars['leftUnserved'];
    if (stars != null) {
      final comment = pickReviewComment(
        data.reviews,
        outcome: 'leftUnserved',
        occasionId: c.request.occasionId,
        holidayId: holidayToday?.id,
        rng: rng,
        recent: _recentComments,
      );
      state.addReview(
        ReviewRecord(
          day: state.day,
          customerName: c.name,
          avatarId: c.avatarId,
          occasionId: c.request.occasionId,
          stars: stars,
          comment: comment,
          outcome: 'leftUnserved',
        ),
      );
      state.metrics.newReviews++;
    }
    state.metrics.customersLeft++;
    departures.add(Departure(c, stars ?? 0));
    if (identical(tableCustomer, c)) {
      _returnDraftToStock();
      tableCustomer = null;
      wrapping = false;
      screen = Screen.shop;
    }
  }

  // ---------------------------------------------------------------------
  // Florist (staff level 2): serves a second customer in parallel
  // ---------------------------------------------------------------------

  void _startAutoServeIfPossible() {
    final secs = effects.autoServeSeconds;
    if (secs == null) return;
    if (queue.any((c) => c.autoServeLeft != null)) return;
    // The player keeps the first servable customer.
    final player = tableCustomer ?? nextForPlayer;
    for (final c in queue) {
      if (!c.arrived || identical(c, player)) continue;
      final r = c.request;
      final stems = r.total + r.fillerCount;
      if (stems > effects.autoServeMaxStems) continue;
      if (!_hasStockFor(r)) continue;
      c.autoServeLeft = secs;
      c.frozen = true;
      return;
    }
  }

  bool _hasStockFor(BouquetRequest r) {
    for (final entry in stemNeeds(r).entries) {
      if (stockAvailable(entry.key) < entry.value) return false;
    }
    return true;
  }

  void _finishAutoServe(Customer c) {
    c.autoServeLeft = null;
    final r = c.request;
    if (!_hasStockFor(r)) {
      c.frozen = false;
      return;
    }
    final b = Bouquet(
      paperId: owned.contains(r.paperId) ? r.paperId : unlockedPapers.first.id,
      ribbonId: owned.contains(r.ribbonId)
          ? r.ribbonId
          : unlockedRibbons.first.id,
    );
    void take(String id, int n) {
      for (var i = 0; i < n; i++) {
        final s = _takeStem(id);
        if (s != null) b.stems.add(s);
      }
    }

    for (final entry in r.stems.entries) {
      take(entry.key, entry.value);
    }
    if (r.fillerId != null) take(r.fillerId!, r.fillerCount);
    final tier = Tier.values.byName(effects.autoServeTier);
    final match = scoreBouquet(e, r, b);
    _settleDelivery(c, b, match, tier: tier, fast: false, wrapHit: false);
  }

  // ---------------------------------------------------------------------
  // Bouquet table
  // ---------------------------------------------------------------------

  void openTable() {
    // Already at the table: a second tap (for example one that leaked
    // through from the queue) must not swap the customer or clear the draft.
    if (screen == Screen.table &&
        (tableCustomer != null || tableOrder != null)) {
      return;
    }
    if (shelfEmpty) return;
    final c = nextForPlayer;
    if (c == null || state.phase != DayPhase.open) return;
    tableCustomer = c;
    draft = Bouquet();
    if (effects.autoPaperRibbon) {
      if (owned.contains(c.request.paperId)) draft.paperId = c.request.paperId;
      if (owned.contains(c.request.ribbonId)) {
        draft.ribbonId = c.request.ribbonId;
      }
    }
    screen = Screen.table;
    if (tutorialStep == 4) tutorialStep = 5;
    _changed();
  }

  Stem? _takeStem(String flowerId, {OnlineOrder? forOrder}) {
    if (stockAvailable(flowerId, forOrder: forOrder) <= 0) return null;
    final b = oldestBatch(flowerId);
    if (b == null) return null;
    b.count--;
    if (b.count <= 0) state.stock.remove(b);
    return Stem(
      uid: _nextStemUid++,
      flowerId: flowerId,
      freshnessLeft: b.freshnessLeft,
    );
  }

  void _returnStem(Stem s) {
    for (final b in state.stock) {
      if (b.flowerId == s.flowerId && b.freshnessLeft == s.freshnessLeft) {
        b.count++;
        return;
      }
    }
    state.stock.add(
      StockBatch(
        flowerId: s.flowerId,
        count: 1,
        freshnessLeft: s.freshnessLeft,
      ),
    );
  }

  void _returnDraftToStock() {
    for (final s in draft.stems) {
      _returnStem(s);
      final order = tableOrder;
      if (order != null && order.reservedUids.remove(s.uid)) {
        order.reserved[s.flowerId] = (order.reserved[s.flowerId] ?? 0) + 1;
      }
    }
    draft = Bouquet();
  }

  bool addStem(String flowerId) {
    if ((tableCustomer == null && tableOrder == null) || wrapping) return false;
    if (draft.stems.length >= e.maxStems) return false;
    final order = tableOrder;
    final fromReserve = order != null && (order.reserved[flowerId] ?? 0) > 0;
    final s = _takeStem(flowerId, forOrder: order);
    if (s == null) return false;
    if (fromReserve) {
      final left = order.reserved[flowerId]! - 1;
      if (left <= 0) {
        order.reserved.remove(flowerId);
      } else {
        order.reserved[flowerId] = left;
      }
      order.reservedUids.add(s.uid);
    }
    draft.stems.add(s);
    _checkTutorialDraft();
    _changed();
    return true;
  }

  void removeStem(int uid) {
    if (wrapping) return;
    final i = draft.stems.indexWhere((s) => s.uid == uid);
    if (i < 0) return;
    final stem = draft.stems.removeAt(i);
    _returnStem(stem);
    final order = tableOrder;
    if (order != null && order.reservedUids.remove(stem.uid)) {
      order.reserved[stem.flowerId] = (order.reserved[stem.flowerId] ?? 0) + 1;
    }
    _changed();
  }

  void selectPaper(String id) {
    if (wrapping || !owned.contains(id)) return;
    draft.paperId = id;
    _checkTutorialDraft();
    _changed();
  }

  void selectRibbon(String id) {
    if (wrapping || !owned.contains(id)) return;
    draft.ribbonId = id;
    _changed();
  }

  void resetDraft() {
    if (wrapping) return;
    _returnDraftToStock();
    _changed();
  }

  /// "Gói & giao hoa": freezes the customer and returns the green zone.
  WrapZone? beginWrap() {
    if (tableOrder != null) {
      if (!canDeliver || wrapping) return null;
      wrapping = true;
      _changed();
      return wrapZoneFor(
        e,
        shopRank: rank.rank,
        rng: rng,
        tableBonus: effects.greenZoneBonus,
      );
    }
    final c = tableCustomer;
    if (c == null || !canDeliver || wrapping) return null;
    wrapping = true;
    c.frozen = true;
    _fastService = c.patienceFraction > (1 - e.fastServiceThreshold);
    _changed();
    return wrapZoneFor(
      e,
      shopRank: rank.rank,
      rng: rng,
      tableBonus: effects.greenZoneBonus,
    );
  }

  /// Wrap animation length after release (wrapping_table shortens it).
  double get wrapAnimationSeconds =>
      e.wrapAnimationSeconds * (1 - effects.wrapTimeReduction);

  /// Mini-game finished: customer pays, review is saved, popup data is set.
  DeliveryResult? finishWrap({required bool hit}) {
    if (tableOrder != null) {
      if (!wrapping) return null;
      packOnlineOrder(this, hit);
      _changed();
      return null;
    }
    final c = tableCustomer;
    if (c == null || !wrapping) return null;
    final bouquet = draft;
    final match = scoreBouquet(e, c.request, bouquet);
    final result = _settleDelivery(
      c,
      bouquet,
      match,
      tier: match.tier,
      fast: _fastService,
      wrapHit: hit,
    );
    draft = Bouquet();
    wrapping = false;
    lastDelivery = result;
    pendingReveal += result.payment.total;
    _changed();
    return result;
  }

  DeliveryResult _settleDelivery(
    Customer c,
    Bouquet bouquet,
    MatchResult match, {
    required Tier tier,
    required bool fast,
    required bool wrapHit,
  }) {
    final occasion = e.occasion(c.request.occasionId);
    final price = bouquetPrice(e, bouquet);
    final payment = computePayment(
      e,
      price: price,
      tier: tier,
      fastService: fast,
      wrapHit: wrapHit,
      holidayTipMultiplier: holidayToday?.tipMultiplier ?? 1.0,
      occasionTipMultiplier: occasion.tipMultiplier,
    );
    var supplies = 0;
    if (bouquet.paperId != null) supplies += e.paper(bouquet.paperId!).buyPrice;
    if (bouquet.ribbonId != null) {
      supplies += e.ribbon(bouquet.ribbonId!).buyPrice;
    }
    state.money += payment.total - supplies;
    final m = state.metrics
      ..flowerIncome += payment.pay
      ..tipIncome += payment.tipTotal
      ..wrapSupplies += supplies
      ..bouquetsSold += 1;
    if (tier == Tier.great) m.greatCount++;
    if (wrapHit) m.wrapHits++;
    if (fast && tier != Tier.unhappy) m.fastServed++;
    m.occasionServed[occasion.id] = (m.occasionServed[occasion.id] ?? 0) + 1;
    state.lifetimeBouquetsSold++;

    final outcome = tier.name;
    final comment = pickReviewComment(
      data.reviews,
      outcome: outcome,
      occasionId: occasion.id,
      holidayId: holidayToday?.id,
      mismatchReason: match.mismatchReason,
      rng: rng,
      recent: _recentComments,
    );
    final review = ReviewRecord(
      day: state.day,
      customerName: c.name,
      avatarId: c.avatarId,
      occasionId: occasion.id,
      stars: e.reviewStars[outcome] ?? 0,
      comment: comment,
      outcome: outcome,
      stems: bouquet.counts,
      paperId: bouquet.paperId,
      ribbonId: bouquet.ribbonId,
    );
    state.addReview(review);
    m.newReviews++;
    queue.remove(c);
    if (identical(tableCustomer, c)) tableCustomer = null;
    return DeliveryResult(
      customer: c,
      match: match,
      payment: payment,
      review: review,
      wrapHit: wrapHit,
    );
  }

  /// "Tiếp tục" on the review popup: coins reach the top bar, back to shop.
  void closeDeliveryPopup() {
    lastDelivery = null;
    pendingReveal = 0;
    screen = Screen.shop;
    if (tutorialStep == 8) _endTutorial();
    _changed();
  }

  // ---------------------------------------------------------------------
  // Reviews screen
  // ---------------------------------------------------------------------

  void openReviews({bool todayOnly = false}) {
    _reviewsReturn = screen == Screen.reviews ? _reviewsReturn : screen;
    reviewsInitialFilter = todayOnly ? 1 : 0;
    screen = Screen.reviews;
    _changed();
  }

  void closeReviews() {
    screen = _reviewsReturn;
    if (state.phase == DayPhase.summary) screen = Screen.summary;
    _changed();
  }

  /// One reply per review. Written into the morning save so it survives
  /// leaving mid-day. A review from today is kept in memory until the next
  /// day-boundary commit, like the rest of today's progress.
  bool replyToReview(ReviewRecord review, String raw) {
    final text = normalizeReply(raw);
    if (text == null || review.replyText != null) return false;
    final i = state.reviews.indexWhere((r) => identical(r, review));
    if (i < 0) return false;
    state.reviews[i] = review.copyWith(replyText: text);
    final cp = GameState.decode(_checkpoint);
    if (cp != null &&
        i < cp.reviews.length &&
        cp.reviews[i].replyText == null &&
        cp.reviews[i].day == review.day &&
        cp.reviews[i].customerName == review.customerName &&
        cp.reviews[i].comment == review.comment) {
      cp.reviews[i] = cp.reviews[i].copyWith(replyText: text);
      _checkpoint = cp.encode();
      if (hasSave) {
        _pendingSaves = _pendingSaves.then((_) => _store.save(cp));
      }
    }
    _changed();
    return true;
  }

  // ---------------------------------------------------------------------
  // End of day (Tổng kết)
  // ---------------------------------------------------------------------

  void _finishDay() {
    settleDeliveryClose(this);
    final m = state.metrics;
    // Stems on their last fresh day wilt at the day-end tick.
    m.wiltedByFlower = {};
    for (final b in state.stock) {
      if (b.freshnessLeft <= 1) {
        m.wiltedByFlower[b.flowerId] =
            (m.wiltedByFlower[b.flowerId] ?? 0) + b.count;
      }
    }
    m.stemsWilted = m.wiltedByFlower.values.fold(0, (a, b) => a + b);
    if (!m.settled) {
      var rewards = 0;
      for (final g in state.goals) {
        if (g.isDone(m)) rewards += g.reward;
      }
      m.goalRewards = rewards;
      m.fixedCosts = e.fixedCostsTotal + effects.dailyCosts + m.shipperWages;
      state.money += rewards - m.fixedCosts;
      m.settled = true;
    }
    state.phase = DayPhase.summary;
    screen = Screen.summary;
    tableCustomer = null;
    paused = false;
    pauseMenuOpen = false;
  }

  /// Upgrade upkeep + staff wages included in today's fixed costs.
  int get todayUpkeep => effects.dailyCosts;

  int get shippersHired => shippersHiredCount(state.shipperLevels);

  /// "Đóng cửa sớm": skip the rest of the open hours and show the summary.
  void closeEarly() {
    if (state.phase != DayPhase.open) return;
    state.pendingArrivals.clear();
    _returnDraftToStock();
    tableCustomer = null;
    tableOrder = null;
    wrapping = false;
    lastDelivery = null;
    pendingReveal = 0;
    queue.clear();
    departures.clear();
    _finishDay();
    _changed();
  }

  /// "Sang ngày mới": freshness tick, next day, market.
  void startNextDay() {
    if (state.phase != DayPhase.summary) return;
    for (final b in [...state.stock]) {
      b.freshnessLeft -= 1;
      if (b.freshnessLeft <= 0) state.stock.remove(b);
    }
    if (state.adsDaysLeft > 0) state.adsDaysLeft--;
    state.day++;
    _startDay();
    queue.clear();
    departures.clear();
    screen = hasPreorderBoard(this) ? Screen.preorders : Screen.market;
    if (rank.rank > state.rankSeen) {
      _pushPopup(RankUpPopup(rank));
      state.rankSeen = rank.rank;
    }
    _queueHolidayPopup();
    _commit();
    _changed();
  }

  // ---------------------------------------------------------------------
  // Upgrades and unlocks (Nâng cấp)
  // ---------------------------------------------------------------------

  UpgradeStatus statusOf(String upgradeId) => upgradeStatus(
    e,
    id: upgradeId,
    levels: state.upgradeLevels,
    money: state.money,
    shopClosed: shopClosed,
    adsDaysLeft: state.adsDaysLeft,
  );

  void openUpgrades({int tab = 0}) {
    if (!shopClosed) {
      showNotice('Nâng cấp khi tiệm đóng cửa nhé');
      return;
    }
    _upgradesReturn = screen;
    upgradesInitialTab = tab;
    screen = Screen.upgrades;
    _changed();
  }

  /// Nav button: while open, only a reminder line is shown.
  void openUpgradesFromNav() => openUpgrades();

  void closeUpgrades() {
    screen = _upgradesReturn;
    _changed();
  }

  bool buyUpgrade(String id) {
    final st = statusOf(id);
    if (!st.canBuy || st.next == null) return false;
    final u = e.upgrade(id);
    final beforeBonus = effects.freshnessBonusDays;
    state.money -= st.next!.cost;
    if (u.consumable) {
      state.adsDaysLeft = st.next!.durationDays ?? 1;
    } else {
      state.upgradeLevels[id] = (state.upgradeLevels[id] ?? 0) + 1;
    }
    // Cold storage also applies to stems already in stock.
    final diff = effects.freshnessBonusDays - beforeBonus;
    if (diff > 0) {
      for (final b in state.stock) {
        b.freshnessLeft += diff;
      }
    }
    _changed();
    return true;
  }

  int? unlockCostOf(String itemId) {
    for (final f in e.flowers) {
      if (f.id == itemId) return f.unlockCost;
    }
    for (final p in [...e.papers, ...e.ribbons]) {
      if (p.id == itemId) return p.unlockCost;
    }
    return null;
  }

  bool canUnlock(String itemId) {
    if (owned.contains(itemId) || !shopClosed || state.money < 0) return false;
    final cost = unlockCostOf(itemId);
    return cost != null && state.money >= cost;
  }

  bool unlockItem(String itemId) {
    if (!canUnlock(itemId)) return false;
    state.money -= unlockCostOf(itemId)!;
    state.unlockedItems.add(itemId);
    _pushPopup(UnlockPopup(itemId));
    _changed();
    return true;
  }
}
