import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/sounds.dart';
import '../data/account_gateway.dart';
import '../data/economy.dart';
import '../data/game_data.dart';
import '../data/texts.dart';
import '../save/game_state.dart';
import '../save/progress_store.dart';
import '../save/terms_consent.dart';
import 'bouquet.dart';
import 'garden.dart';
import 'cloud_merge.dart';
import 'customers.dart';
import 'delivery.dart';
import 'format.dart';
import 'goals.dart';
import 'match_scoring.dart';
import 'payment.dart';
import 'pet.dart';
import 'play_analytics.dart';
import 'rating.dart';
import 'review_picker.dart';
import 'rewards.dart';
import 'shop_name.dart';
import 'supporters.dart';
import 'upgrades.dart';
import 'xu_grant.dart';

part 'delivery_runtime.dart';
part 'shop_events.dart';

enum Screen {
  title,
  market,
  shop,
  table,
  reviews,
  stock,
  summary,
  upgrades,
  preorders,
  donors,
  prices,
  garden,
  pets,
  petShop,
}

/// Terms screen (spec_dieu_khoan.md): asking for consent, or read-only
/// from Cài đặt.
enum TermsMode { accept, review }

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

class EventChoice {
  const EventChoice(this.id, this.label);
  final String id;
  final String label;
}

class EventOffer {
  const EventOffer({
    required this.id,
    required this.title,
    required this.body,
    required this.choices,
  });

  final String id;
  final String title;
  final String body;
  final List<EventChoice> choices;
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
    this.mysterious = false,
  }) : patienceLeft = patienceMax;

  final int id;
  final String name;

  /// File name in assets/images/customers ('' = drawn placeholder).
  final String avatarId;
  final BouquetRequest request;
  final String requestLine;
  final double patienceMax;

  /// Decade-day guest. A finished bouquet leaves a handful of stones.
  final bool mysterious;

  double patienceLeft;

  /// Seconds until the customer reaches the queue (not servable before).
  double walkIn;

  /// Patience stops while the bouquet is being wrapped or auto-served.
  bool frozen = false;

  /// Seconds left while the florist (staff level 2) serves this customer.
  double? autoServeLeft;

  /// Tutorial customer: patience stands still until the tutorial ends.
  bool patienceLocked = false;

  /// The low-patience reminder has already played for this visit.
  bool patienceWarned = false;

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
    this.stones = 0,
  });

  final Customer customer;
  final MatchResult match;
  final Payment payment;
  final ReviewRecord review;
  final bool wrapHit;

  /// Stones this visit left. 0 for an ordinary guest.
  final int stones;
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
    SupporterSource? supporters,
    SupporterAdmin? supporterAdmin,
    PlayerDirectory? playerDirectory,
    AccountGateway? account,
    Sounds? sounds,
    this.terms,
    String? tabId,
    DateTime Function()? now,
    AccountProfile? lastAccount,
    bool guestSaves = false,
    Future<void> Function(int attempt)? retryWait,
  }) : _store = store,
       _now = now ?? DateTime.now,
       _guestSaves = guestSaves,
       _retryWait = retryWait ?? _defaultRetryWait,
       accountOpening = lastAccount != null,
       tabId = tabId ?? 'tab-local',
       rng = random ?? Random(),
       hasSave = saved != null,
       supporters = supporters ?? const UnavailableSupporterSource(),
       supporterAdmin = supporterAdmin ?? const NoSupporterAdmin(),
       playerDirectory = playerDirectory ?? const NoPlayerDirectory(),
       account = account ?? const OfflineAccount(),
       sounds = sounds ?? Sounds() {
    state = saved ?? _newGame();
    _fitGardenPlots();
    _fitPetHome();
    this.sounds.musicOn = state.musicOn;
    this.sounds.effectsOn = state.sfxOn;
    _armGoals();
    final filledReplies = _fillMissingCustomerReplies();
    _checkpoint = state.encode();
    if (filledReplies && hasSave) {
      final copy = GameState.decode(_checkpoint);
      if (copy != null) _saveLocal(copy);
    }
    _resumeScreen();
  }

  final Sounds sounds;

  /// Test hook: guest play is saved on the old guest slot like before.
  /// The game never sets it; only signed-in play is saved.
  final bool _guestSaves;

  final Future<void> Function(int attempt) _retryWait;

  static Future<void> _defaultRetryWait(int attempt) =>
      Future<void>.delayed(Duration(seconds: min(30, 1 << min(attempt, 5))));

  /// A reload with a remembered account: its copy is on screen and the
  /// login is still being restored. Play waits ("Đang mở tiệm...") so
  /// nothing falls back to an unsaved guest day 1.
  bool accountOpening;

  /// [accountOpening] already failed once and keeps retrying.
  bool openingRetry = false;

  bool _disposed = false;

  /// Day of the account's cloud save as last read or written. An upload
  /// that would move it back needs a confirmed "Chơi mới".
  int _cloudDay = 0;
  int get cloudDay => _cloudDay;

  /// Uploads refused because they would lower the cloud day. For tests.
  int blockedLowerPushes = 0;

  /// Local saves go to the account slot. Guest play stays in memory.
  bool get _savesLocal => _guestSaves || _store.slotUid != null;

  /// Queues a local save into the slot in use now.
  void _saveLocal(GameState copy) {
    if (!_savesLocal) return;
    final uid = _store.slotUid;
    _pendingSaves = _pendingSaves.then((_) => _store.saveFor(uid, copy));
  }

  /// Line on the title and in Cài đặt: whose save is in play.
  String get saveLabel {
    if (signedIn) {
      final name = accountName ?? '';
      final email = accountEmail ?? '';
      return accountSaveLabel(
        name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Chủ tiệm'),
      );
    }
    if (accountOpening) {
      return openingRetry ? openingRetryLabel : openingShopLabel;
    }
    return guestSaveLabel;
  }

  /// Amber strip under the coin bar while playing as a guest.
  bool get showGuestBanner => !signedIn && !accountOpening;

  final GameData data;
  final ProgressStore _store;
  final Random rng;
  final SupporterSource supporters;
  final SupporterAdmin supporterAdmin;
  final PlayerDirectory playerDirectory;
  final AccountGateway account;

  /// This browser tab. A reload keeps it; a new tab has another one.
  final String tabId;

  /// Clock for the garden. Tests pass a fixed time.
  final DateTime Function() _now;

  /// Another tab or device opened this account and took the seat, so this
  /// tab went back to its guest save. The dialog explains it once.
  bool seatLost = false;

  bool _seatBlocked = false;

  /// Bumped whenever this tab gains or loses the seat. A cloud save queued
  /// under an older value is dropped.
  int _seatEpoch = 0;
  bool _leaving = false;
  bool _joining = false;

  /// Uploads stay off until this tab is playing the account's morning.
  /// A guest morning must not be written while sign-in is still deciding.
  bool _uploads = false;
  bool _sawOwnSeat = false;
  Future<void> _authFlow = Future<void>.value();

  /// In-flight sign-in, takeover, or kick. Tests await this after a seat change.
  Future<void> get pendingAuth => _authFlow;

  late GameState state;

  Economy get e => data.economy;

  Screen screen = Screen.market;

  /// Looping track for [screen]: the evening summary and the temple
  /// courtyard each have their own piece. Everywhere else is the shop tune.
  String get musicTrack => switch (screen) {
    Screen.summary => 'bgm_summary',
    Screen.donors => 'bgm_temple',
    _ => 'bgm_main',
  };

  /// Quiet shop loop while the doors are open. Muted with the effects switch.
  bool get playShopAmbience => state.phase == DayPhase.open;
  Screen _reviewsReturn = Screen.shop;
  Screen _stockReturn = Screen.shop;
  Screen _pricesReturn = Screen.shop;
  Screen _gardenReturn = Screen.market;

  /// Reviews screen filter to show when it opens (0 = all, 1 = today).
  int reviewsInitialFilter = 0;

  /// Upgrades screen tab to show when it opens.
  int upgradesInitialTab = 0;
  Screen _upgradesReturn = Screen.shop;

  bool paused = false;

  /// The event card on screen. While it is open the day clock stands still.
  EventOffer? eventOffer;

  /// One line under the top bar while a choice is still playing out.
  String? eventStatus;

  /// Shown on the summary when the police result is known.
  String? eventSummaryNote;

  double? _eventAt;
  int _grandmaPay = 0;
  bool _extraWilt = false;
  int _theftHeld = 0;
  int _mouseLost = 0;
  int _mouseSaved = 0;
  String _mouseDetail = '';

  /// Name of the pet that chased today's mouse, or empty.
  String _mousePet = '';
  bool _policePending = false;
  int _wholesaleLeft = 0;
  double _wholesaleDeadline = 0;
  int _wholesaleSum = 0;
  double _patienceDrain = 1;
  double _patienceUntil = 0;

  /// Pause popup visible (spec_popup_va_mo_dau.md §1). Now the Cài đặt popup.
  bool pauseMenuOpen = false;

  /// Đổi avatar popup, on top of Cài đặt.
  bool avatarPickerOpen = false;

  /// Filled in by Google sign-in. Empty until then, so offline play is unchanged.
  bool authBusy = false;
  String? authError;
  bool uploadBusy = false;
  String? uploadError;
  String? accountUid;
  String? accountName;
  String? accountEmail;
  String? accountPhotoUrl;
  DateTime? lastSavedAt;

  /// One line under the account in Cài đặt after signing in: which
  /// progress was loaded (see [accountLoadedNotice]).
  String? accountNotice;

  bool get signedIn => accountUid != null;

  /// Signed in and this tab still holds the account, so a reward added now
  /// reaches its morning save (Hộp thư claims check this).
  bool get canWriteAccount =>
      signedIn && !_seatBlocked && !_leaving && !_discardLocal;

  /// Stored consent. Null until the player accepts the terms once.
  TermsConsent? terms;

  /// Terms screen on top of everything. Null when it is closed.
  TermsMode? termsMode;

  /// "Tiệm vẫn chờ bạn" popup over the title after "Để sau".
  bool termsLaterOpen = false;

  /// What the tap that opened the terms screen wanted to do next.
  VoidCallback? _afterTerms;

  bool get termsAccepted => terms?.isCurrent ?? false;

  /// Consent from an older [termsVersion]: the screen says it was updated.
  bool get termsOutdated => terms != null && !termsAccepted;

  /// Naming popup. Null when it is closed.
  ShopNameMode? namePrompt;
  bool _nameThenContinue = false;

  /// True while Firebase is checking that nobody else has this name.
  bool nameBusy = false;

  /// Shown on the naming popup. Null when the last check succeeded.
  String? nameError;

  /// The signed-in name belongs to another tiệm, so the popup cannot close
  /// until they pick a free one.
  bool nameLocked = false;

  /// Shown on the title after an old duplicate name was given a free one.
  String? renamedShopNote;

  bool get needsShopName {
    final name = state.shopName;
    return name == null || name.trim().isEmpty;
  }

  /// Whether a save existed when the game started or has been written since
  /// (title screen: "Chơi tiếp" vs "Bắt đầu").
  bool hasSave;

  /// Sign-out is wiping the morning. Later commits must not write it back.
  bool _discardLocal = false;

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

  /// Card line for the bouquet on the table, picked from the theme cards.
  /// Null when no card is picked.
  String? cardNote;
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

  /// A mysterious guest still has to walk in today.
  bool _mysteryLeft = false;

  /// A Khách thần bí is still due today.
  bool get mysteryVisitorDue => _mysteryLeft;
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

  /// What the pet in the "Thu nhập" slot adds (capped by `petCaps`).
  PetEffects get petEffects => PetEffects.of(e, state);

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

  /// Full freshness for newly bought stems (cold storage and the
  /// income-slot pet add days).
  int fullFreshness(FlowerDef f) =>
      f.freshnessDays +
      effects.freshnessBonusDays +
      petEffects.freshnessBonusDays;

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
    _fitGardenPlots();
    _startDay();
    return s;
  }

  /// Old saves have no beds. A short list grows to the starting count.
  /// Bought beds above that count are kept, up to the yard maximum.
  void _fitGardenPlots() {
    final minPlots = e.gardenPlotCount;
    final maxPlots = e.gardenMaxPlots;
    if (state.plots.isEmpty) {
      state.plots = freshGardenPlots(minPlots);
      return;
    }
    while (state.plots.length < minPlots) {
      state.plots.add(GardenPlot());
    }
    if (state.plots.length > maxPlots) {
      state.plots.removeRange(maxPlots, state.plots.length);
    }
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
    resetShopEventDay(this);
    prepareDeliveryMorning(this);
    _armGoals();
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
  void _commit({bool allowLower = false}) {
    if (_discardLocal) return;
    if (accountUid != null) state.accountUid = accountUid;
    _checkpoint = state.encode();
    hasSave = true;
    final copy = GameState.decode(_checkpoint);
    if (copy == null) return;
    _saveLocal(copy);
    _pushCloud(copy, allowLower: allowLower);
  }

  /// Writes one setting into the morning save. Mid-day progress stays unsaved.
  void _patchMorning(void Function(GameState cp) edit) {
    if (_discardLocal) return;
    final cp = GameState.decode(_checkpoint);
    if (cp == null) return;
    if (accountUid != null) cp.accountUid = accountUid;
    edit(cp);
    _checkpoint = cp.encode();
    if (!hasSave) return;
    _saveLocal(cp);
    _pushCloud(cp);
  }

  /// Uploads the morning save. A network failure leaves the local save as it is.
  /// A save at an earlier day than the cloud is refused unless [allowLower]
  /// (a confirmed "Chơi mới").
  void _pushCloud(GameState saved, {bool allowLower = false}) {
    if (!signedIn || _seatBlocked || _leaving || !_uploads) return;
    final epoch = _seatEpoch;
    _pendingSaves = _pendingSaves.then((_) async {
      // The seat may have moved while this save waited in line.
      if (epoch != _seatEpoch || _seatBlocked || _leaving) return;
      if (!mayReplaceCloud(
        cloudDay: _cloudDay,
        nextDay: saved.day,
        allowLower: allowLower,
      )) {
        blockedLowerPushes++;
        return;
      }
      try {
        await account.push(saved);
        _cloudDay = saved.day;
        lastSavedAt = DateTime.now();
        _changed();
      } catch (_) {}
    });
  }

  /// Persists the tutorial flag into the morning save without committing
  /// the rest of today's progress.
  void _setTutorialDone() {
    state.tutorialDone = true;
    final cp = GameState.decode(_checkpoint);
    if (cp == null || _discardLocal) return;
    cp.tutorialDone = true;
    _checkpoint = cp.encode();
    if (!hasSave) return;
    _saveLocal(cp);
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
    avatarPickerOpen = false;
    namePrompt = null;
    _nameThenContinue = false;
    clearDeliveryDay(this);
  }

  // ---------------------------------------------------------------------
  // Title screen, pause, popups
  // ---------------------------------------------------------------------

  /// App start. Without current consent the terms screen comes first, and
  /// accepting goes on to naming (new player) or the shop (returning one).
  void showTitle() {
    screen = Screen.title;
    if (!termsAccepted) {
      termsMode = TermsMode.accept;
      _afterTerms = _startFromTitle;
    }
    _changed();
  }

  /// The title's main button.
  void _startFromTitle() => hasSave ? continueFromTitle() : requestNewGame();

  /// Opens the terms screen instead of [then] until the player accepts.
  bool _askTermsFirst(VoidCallback then) {
    if (termsAccepted) return false;
    termsMode = TermsMode.accept;
    termsLaterOpen = false;
    _afterTerms = then;
    sounds.effect('popup_open');
    _changed();
    return true;
  }

  /// "Nhận chìa khóa tiệm". The screen only enables it once the box is ticked.
  void acceptTerms() {
    if (termsMode != TermsMode.accept) return;
    final consent = TermsConsent(
      version: termsVersion,
      acceptedAt: DateTime.now(),
    );
    terms = consent;
    _pendingSaves = _pendingSaves.then((_) => _store.saveTerms(consent));
    termsMode = null;
    final then = _afterTerms;
    _afterTerms = null;
    if (then != null) {
      then();
    } else {
      _changed();
    }
  }

  /// "Để sau": nothing is saved and progress stays. Back to the title with
  /// the "Tiệm vẫn chờ bạn" popup.
  void postponeTerms() {
    if (termsMode != TermsMode.accept) return;
    termsMode = null;
    _afterTerms = null;
    termsLaterOpen = true;
    screen = Screen.title;
    sounds.effect('popup_open');
    _changed();
  }

  /// "Đọc lại điều khoản" on the popup.
  void reopenTerms() {
    termsLaterOpen = false;
    _askTermsFirst(_startFromTitle);
  }

  void closeTermsLater() {
    if (!termsLaterOpen) return;
    termsLaterOpen = false;
    sounds.effect('popup_close');
    _changed();
  }

  /// "Xem lại" in Cài đặt: read-only, closes back to Cài đặt.
  void openTermsReview() {
    termsMode = TermsMode.review;
    sounds.effect('popup_open');
    _changed();
  }

  void closeTermsReview() {
    if (termsMode != TermsMode.review) return;
    termsMode = null;
    sounds.effect('popup_close');
    _changed();
  }

  /// "Chơi tiếp" from the title. An old save with no name asks once first.
  void continueFromTitle() {
    if (_askTermsFirst(continueFromTitle)) return;
    if (needsShopName) {
      namePrompt = ShopNameMode.start;
      _nameThenContinue = true;
      sounds.effect('popup_open');
      _changed();
      return;
    }
    continueGame();
  }

  /// "Bắt đầu" / confirmed "Chơi mới": the name popup, then [startNewGame].
  void requestNewGame() {
    if (_askTermsFirst(requestNewGame)) return;
    namePrompt = ShopNameMode.start;
    nameError = null;
    nameLocked = false;
    _nameThenContinue = false;
    sounds.effect('popup_open');
    _changed();
  }

  void openRename() {
    namePrompt = ShopNameMode.rename;
    nameError = null;
    _nameThenContinue = false;
    sounds.effect('popup_open');
    _changed();
  }

  void cancelShopName() {
    if (namePrompt != ShopNameMode.rename || nameLocked) return;
    namePrompt = null;
    nameError = null;
    sounds.effect('popup_close');
    _changed();
  }

  void clearShopNameError() {
    if (nameError == null) return;
    nameError = null;
    _changed();
  }

  Future<bool> confirmShopName(String raw) async {
    final name = normalizeShopName(raw);
    if (name == null || namePrompt == null || nameBusy) return false;
    final previous = state.shopName;
    if (previous == name && !nameLocked) {
      namePrompt = null;
      nameError = null;
      _nameThenContinue = false;
      sounds.effect('popup_close');
      _changed();
      return true;
    }
    nameBusy = true;
    nameError = null;
    _changed();
    final claim = await playerDirectory.claimShopName(
      uid: accountUid,
      shopName: name,
      previousName: previous,
    );
    nameBusy = false;
    if (claim == ShopNameClaim.taken) {
      nameError = 'Tên này đã có tiệm khác dùng rồi.';
      sounds.effect('error');
      _changed();
      return false;
    }
    if (claim == ShopNameClaim.failed) {
      nameError = 'Chưa kiểm tra được tên, thử lại nhé.';
      sounds.effect('error');
      _changed();
      return false;
    }
    state.shopName = name;
    final cont = _nameThenContinue;
    final mode = namePrompt;
    namePrompt = null;
    nameError = null;
    nameLocked = false;
    _nameThenContinue = false;
    sounds.effect('popup_close');
    if (mode == ShopNameMode.rename || cont) {
      _patchMorning((cp) => cp.shopName = name);
    }
    _syncProfile();
    if (cont) {
      continueGame();
      return true;
    }
    if (mode == ShopNameMode.start) {
      startNewGame();
      return true;
    }
    _changed();
    return true;
  }

  /// A free suggestion for the dice: one of the eight names plus a number
  /// from 1 to 100000, then a Firebase check. Taken names are skipped.
  Future<String?> suggestFreeShopName(String current) async {
    final seen = <String>{shopNameKey(current)};
    for (var i = 0; i < 12; i++) {
      final name = rollNumberedShopName(rng, avoid: current);
      if (name == null || !seen.add(shopNameKey(name))) continue;
      final claim = await playerDirectory.claimShopName(
        uid: null,
        shopName: name,
      );
      if (claim == ShopNameClaim.claimed) return name;
      if (claim == ShopNameClaim.failed) {
        nameError = 'Chưa kiểm tra được tên, thử lại nhé.';
        sounds.effect('error');
        _changed();
        return null;
      }
    }
    nameError = 'Tên gợi ý đang kín. Bạn nhập tên khác nhé.';
    sounds.effect('error');
    _changed();
    return null;
  }

  /// "Chơi tiếp": resume the saved morning.
  void continueGame() {
    renamedShopNote = null;
    _resetTransient();
    if (state.phase == DayPhase.market) prepareDeliveryMorning(this);
    _resumeScreen();
    if (state.phase == DayPhase.market) _queueHolidayPopup();
    _maybeStartTutorial();
    _changed();
  }

  /// "Bắt đầu" / "Chơi mới": day 1 from `start`. The tutorial flag is kept
  /// so a returning player isn't walked through it again. Music and the
  /// chosen avatar are settings, so a new game keeps them too.
  void startNewGame() {
    final seen = state.tutorialDone;
    final music = state.musicOn;
    final sfx = state.sfxOn;
    final avatar = state.ownerAvatar;
    final avatarRev = state.ownerAvatarRev;
    final shopName = state.shopName;
    _resetTransient();
    _newGame();
    state.tutorialDone = seen;
    state.musicOn = music;
    state.sfxOn = sfx;
    sounds.musicOn = music;
    sounds.effectsOn = sfx;
    state.ownerAvatar = avatar;
    state.ownerAvatarRev = avatarRev;
    state.shopName = shopName;
    sounds.effect('day_start');
    // The player confirmed "Chơi mới", so day 1 may replace the cloud.
    _commit(allowLower: true);
    screen = hasPreorderBoard(this) ? Screen.preorders : Screen.market;
    _maybeStartTutorial();
    _changed();
  }

  /// "Về màn đầu": drop today's progress and reload the morning save.
  void backToTitle() {
    final cp = GameState.decode(_checkpoint);
    if (cp != null) state = cp;
    _fitPetHome();
    _resetTransient();
    screen = Screen.title;
    _changed();
  }

  /// Pause button (Tiệm chính, Bàn bó hoa) or hidden browser tab.
  /// The account pill under the TopBar: Cài đặt opens with the account
  /// group on top.
  void openAccountSettings() => openPause();

  void openPause() {
    paused = true;
    pauseMenuOpen = true;
    sounds.effect('popup_open');
    _changed();
  }

  void resumeFromPause() {
    paused = false;
    pauseMenuOpen = false;
    avatarPickerOpen = false;
    tutorialViewStep = 0;
    sounds.effect('popup_close');
    _changed();
  }

  void openAvatarPicker() {
    avatarPickerOpen = true;
    sounds.effect('popup_open');
    _changed();
  }

  void closeAvatarPicker() {
    avatarPickerOpen = false;
    sounds.effect('popup_close');
    _changed();
  }

  void setMusic(bool on) {
    if (state.musicOn == on) return;
    state.musicOn = on;
    sounds.musicOn = on;
    sounds.effect('toggle');
    _patchMorning((cp) => cp.musicOn = on);
    _changed();
  }

  void setSfx(bool on) {
    if (state.sfxOn == on) return;
    if (!on) sounds.effect('toggle');
    state.sfxOn = on;
    sounds.effectsOn = on;
    if (on) sounds.effect('toggle');
    if (!on) sounds.setAmbience(false);
    _patchMorning((cp) => cp.sfxOn = on);
    _changed();
  }

  String get _ratingLabel => rating.average.toStringAsFixed(1);

  void _soundRating(String before) {
    final after = _ratingLabel;
    if (after == before) return;
    sounds.effect(
      double.parse(after) > double.parse(before) ? 'star_up' : 'star_down',
    );
  }

  final Set<String> _goalsHeard = {};

  String _goalKey(DailyGoal g) =>
      '${g.templateId}|${g.occasionId ?? ''}|${g.target}';

  void _armGoals() {
    _goalsHeard.clear();
    for (final g in state.goals) {
      if (!g.isLimit && g.isDone(state.metrics)) _goalsHeard.add(_goalKey(g));
    }
  }

  void _soundGoals() {
    for (final g in state.goals) {
      if (g.isLimit || !g.isDone(state.metrics)) continue;
      if (_goalsHeard.add(_goalKey(g))) sounds.effect('goal_done');
    }
  }

  void setOwnerAvatar(String id, {bool bumpRev = false}) {
    final same = state.ownerAvatar == id;
    if (same && !bumpRev) return;
    if (bumpRev) {
      final now = DateTime.now().millisecondsSinceEpoch;
      state.ownerAvatarRev = now > state.ownerAvatarRev
          ? now
          : state.ownerAvatarRev + 1;
    }
    state.ownerAvatar = id;
    sounds.effect('avatar_saved');
    _patchMorning((cp) {
      cp.ownerAvatar = id;
      cp.ownerAvatarRev = state.ownerAvatarRev;
    });
    _changed();
    _publishAvatar(id);
  }

  void applySignedIn(AccountProfile profile) {
    _setAccount(profile);
    _syncProfile();
    _avatarRestore = _restoreOrPublishAvatar();
  }

  /// The default portrait must not replace a photo already published for
  /// this account. Opening the game used to re-encode that portrait into
  /// `users/{uid}/avatar.jpg`, which is also where "Tải ảnh lên" writes.
  Future<void> _restoreOrPublishAvatar() async {
    final uid = accountUid;
    if (uid == null) return;
    final current = state.ownerAvatar;
    if (isUploadedAvatar(current) || current != GameState.defaultOwnerAvatar) {
      _publishAvatar(current);
      return;
    }
    try {
      final published = await playerDirectory.publishedAvatar(uid);
      if (accountUid != uid) return;
      if (state.ownerAvatar != GameState.defaultOwnerAvatar) return;
      if (published != null && isUploadedAvatar(published)) {
        setOwnerAvatar(published, bumpRev: true);
        return;
      }
    } catch (_) {}
  }

  /// Writes run one at a time so a preset publish started at sign-in cannot
  /// finish after an upload and point the board back at the default portrait.
  Future<void> _avatarWrites = Future<void>.value();
  Future<void> _avatarRestore = Future<void>.value();

  /// Visible to tests. Waits until the board pointer matches the portrait.
  Future<void> get pendingAvatarWrites async {
    await _avatarRestore;
    await _avatarWrites;
  }

  /// Points the Đại thiện nhân board at the chosen portrait.
  ///
  /// An uploaded photo stays at `users/{uid}/avatar.jpg`. A preset or Google
  /// photo is only a pointer — it must not be copied over that file.
  void _publishAvatar(String id) {
    final uid = accountUid;
    if (uid == null || id.isEmpty) return;
    final rev = state.ownerAvatarRev;
    final photoUrl = accountPhotoUrl;
    _avatarWrites = _avatarWrites.then((_) async {
      if (accountUid != uid) return;
      try {
        final path = id == 'google' ? (photoUrl ?? '') : id;
        if (path.isEmpty) return;
        await playerDirectory.publishAvatar(uid: uid, path: path, rev: rev);
      } catch (_) {
        showNotice('Chưa lưu ảnh lên được, thử lại nhé.');
      }
    });
  }

  /// Reserves this shop's name when it is still free. A name another
  /// tiệm already holds stays as the player wrote it.
  Future<void> _claimHeldShopName() async {
    final uid = accountUid;
    final name = state.shopName;
    if (uid == null || name == null || name.trim().isEmpty) return;
    await playerDirectory.claimShopName(uid: uid, shopName: name);
  }

  /// So the admin picker can find this account by uid. Failures stay quiet.
  void _syncProfile() {
    final uid = accountUid;
    if (uid == null) return;
    playerDirectory.sync(
      uid: uid,
      name: accountName ?? '',
      email: accountEmail ?? '',
      shopName: state.shopName ?? '',
    );
  }

  Future<void> signIn() async {
    if (authBusy || _joining) return;
    _joining = true;
    authBusy = true;
    authError = null;
    accountNotice = null;
    seatLost = false;
    _changed();
    try {
      await account.useLastingLogin();
      final profile = await account.signIn();
      if (profile == null) {
        authError = 'Chưa đăng nhập được, thử lại nhé.';
        sounds.effect('error');
        return;
      }
      final entered = await _joinAccount(profile, announce: true);
      if (entered) {
        sounds.effect('login_ok');
        PlayAnalytics.login();
      } else if (authError != null) {
        sounds.effect('error');
      }
    } catch (_) {
      authError = 'Chưa đăng nhập được, thử lại nhé.';
      sounds.effect('error');
    } finally {
      _joining = false;
      authBusy = false;
      _changed();
    }
  }

  /// Reload of a tab that is still signed in. Waits for Firebase to restore
  /// the login first: on the web it is not there yet on the first frame.
  /// The login is shared by every tab, so a new tab or a reload of a
  /// kicked tab takes the seat (newest session wins).
  ///
  /// With a remembered account ([accountOpening]) a slow login, a timeout
  /// or an unreadable cloud save does not fall back to guest play: it keeps
  /// trying with a growing wait. Only a login Firebase reports as gone
  /// ends it ([loginExpiredNotice]).
  Future<void> resumeAccount() async {
    if (authBusy || signedIn || _joining) return;
    _joining = true;
    var attempt = 0;
    try {
      while (!_disposed && !signedIn) {
        AccountProfile? profile;
        var known = false;
        try {
          profile = await account.restoreProfile();
          known = true;
        } catch (_) {}
        if (_disposed || signedIn) return;
        if (known && profile == null) {
          if (accountOpening) _loginGone();
          return;
        }
        if (profile != null) {
          try {
            await account.useLastingLogin();
            if (await _joinAccount(profile)) return;
          } catch (_) {}
        }
        attempt++;
        if (!accountOpening) {
          if (attempt >= _guestRetries) {
            authError = 'Chưa đăng nhập được, thử lại nhé.';
            return;
          }
        } else {
          openingRetry = true;
          authError = null;
          _changed();
        }
        await _retryWait(attempt);
      }
    } finally {
      _joining = false;
      _changed();
    }
  }

  /// Tries before a reload without a remembered account gives up.
  static const _guestRetries = 3;

  /// The remembered login is gone. Play continues as an unsaved guest,
  /// and the account's copy stays in its slot for the next sign-in.
  void _loginGone() {
    accountOpening = false;
    openingRetry = false;
    _pendingSaves = _pendingSaves.then((_) => _store.clearLastAccount());
    _store.useAccount(null);
    _resetTransient();
    _installGuest();
    screen = Screen.title;
    authError = loginExpiredNotice;
  }

  /// Newest session wins: this tab takes the seat at once, and the tab or
  /// device that held it sees the change and goes back to its guest save.
  /// [keepLocal] is a reload of the tab that already held the seat.
  Future<bool> _joinAccount(
    AccountProfile profile, {
    bool announce = false,
  }) async {
    final holder = await account.seatHolder();
    await account.takeSeat(tabId);
    return _bindAndMerge(
      profile,
      keepLocal: holder == tabId,
      announce: announce,
    );
  }

  /// Enters [profile]'s account (see [accountLoadedNotice]).
  ///
  /// The cloud save is the account's progress and wins over this device
  /// (see [pickMorning]). An account with no cloud save uses its own copy on
  /// this device, else starts a new game; nothing is uploaded until the
  /// player plays it. Guest play is never saved, so it is never written to
  /// the account.
  ///
  /// [keepLocal] is the tab that already holds the seat, coming back from
  /// a reload. Its cached morning for this same account is kept unless the
  /// cloud is further along (a save whose upload had not finished yet).
  Future<bool> _bindAndMerge(
    AccountProfile profile, {
    required bool keepLocal,
    bool announce = false,
  }) async {
    try {
      await _pendingSaves;
    } catch (_) {}
    _uploads = false;
    account.bindSeat(tabId);
    _seatEpoch++;
    _seatBlocked = false;
    seatLost = false;
    CloudRecord? cloud;
    try {
      cloud = await account.pull();
    } catch (_) {
      await _abortJoin();
      return false;
    }
    _setAccount(profile);
    _sawOwnSeat = false;
    account.watchSeat(_onSeat);
    _store.useAccount(profile.uid);
    GameState? cached;
    try {
      cached = await _store.load();
    } catch (_) {}
    final String notice;
    _cloudDay = cloud?.state.day ?? 0;
    switch (pickMorning(
      keepLocal: keepLocal,
      cached: cached,
      cloud: cloud?.state,
    )) {
      case MorningPick.cached:
        _installMorning(cached!);
        notice = accountLoadedNotice(state.day);
      case MorningPick.cloud:
        await _adoptCloud(cloud!, cached);
        notice = accountLoadedNotice(state.day);
      case MorningPick.fresh:
        _startFreshAccount();
        notice = newAccountNotice;
    }
    accountOpening = false;
    openingRetry = false;
    _pendingSaves = _pendingSaves.then((_) => _store.saveLastAccount(profile));
    if (cloud != null &&
        accountAlreadyPlayed(
          day: cloud.state.day,
          joined: cloud.joinedAt != null,
        )) {
      await account.rememberJoin();
    }
    _uploads = true;
    _syncProfile();
    _avatarRestore = _restoreOrPublishAvatar();
    accountNotice = announce ? notice : null;
    if (hasSave) {
      await _applyCloudGrant();
      await _applyCloudGift();
    }
    await _claimHeldShopName();
    _changed();
    return true;
  }

  /// The cloud save could not be read, so this tab does not enter: an
  /// unreadable account must not look empty. Firebase keeps the login, so a
  /// reload or another tap on Đăng nhập tries again.
  Future<void> _abortJoin() async {
    account.bindSeat(null);
    try {
      await account.releaseSeat(tabId);
    } catch (_) {}
    // A remembered account keeps retrying; its line says so instead.
    authError = accountOpening ? null : accountPullFailedNotice;
  }

  void _setAccount(AccountProfile profile) {
    accountUid = profile.uid;
    accountEmail = profile.email;
    accountName = profile.name;
    accountPhotoUrl = profile.photoUrl;
    authError = null;
  }

  /// A Google account with no cloud save: a new game for this account,
  /// with the normal first run. Sound switches are device settings, so
  /// they carry over; nothing else from the guest game does.
  void _startFreshAccount() {
    final music = state.musicOn;
    final sfx = state.sfxOn;
    _resetTransient();
    _newGame();
    state.musicOn = music;
    state.sfxOn = sfx;
    state.accountUid = accountUid;
    _fitPetHome();
    _checkpoint = state.encode();
    hasSave = false;
    lastSavedAt = null;
    screen = Screen.title;
  }

  void _installMorning(GameState morning) {
    state = morning;
    if (accountUid != null) state.accountUid = accountUid;
    sounds.musicOn = state.musicOn;
    sounds.effectsOn = state.sfxOn;
    _fitPetHome();
    _checkpoint = state.encode();
    hasSave = true;
    _armGoals();
    final copy = GameState.decode(_checkpoint);
    if (copy != null) _saveLocal(copy);
    if (screen != Screen.title) {
      _resetTransient();
      screen = Screen.title;
    }
  }

  /// Guest play after leaving an account: a new game that lives in memory
  /// only. Sound switches are device settings and carry over.
  void _installGuest() {
    final music = state.musicOn;
    final sfx = state.sfxOn;
    _newGame();
    state.musicOn = music;
    state.sfxOn = sfx;
    hasSave = false;
    _fitPetHome();
    sounds.musicOn = music;
    sounds.effectsOn = sfx;
    _armGoals();
    _checkpoint = '';
    lastSavedAt = null;
  }

  /// Another tab or device took the account. This tab stops every write
  /// (cloud and the shared local slot) and pauses behind "Mở lại tiệm ở
  /// đây". It keeps the account; it never drops into guest play.
  void _onSeat(String? id) {
    if (id == tabId) {
      _sawOwnSeat = true;
      return;
    }
    if (_leaving || _discardLocal || seatLost) return;
    if (!_sawOwnSeat || !signedIn) return;
    _seatEpoch++;
    _uploads = false;
    _seatBlocked = true;
    account.bindSeat(null);
    account.stopWatchingSeat();
    _discardLocal = true;
    seatLost = true;
    paused = true;
    _changed();
  }

  /// "Mở lại tiệm ở đây": take the seat back and load the account's
  /// newest morning (the other tab may have played on).
  Future<void> reopenHere() {
    _authFlow = _reopenHere();
    return _authFlow;
  }

  Future<void> _reopenHere() async {
    if (!seatLost || _joining || authBusy) return;
    _joining = true;
    authBusy = true;
    authError = null;
    _changed();
    var entered = false;
    try {
      var profile = account.currentProfile();
      if (profile == null) {
        try {
          profile = await account.restoreProfile();
        } catch (_) {}
      }
      profile ??= await account.signIn();
      if (profile != null) {
        _discardLocal = false;
        entered = await _joinAccount(profile);
      }
    } catch (_) {
      entered = false;
    } finally {
      if (entered) {
        seatLost = false;
        paused = false;
      } else {
        _discardLocal = true;
        _seatBlocked = true;
        _uploads = false;
        seatLost = true;
        paused = true;
        authError ??= 'Chưa mở lại được, thử lại nhé.';
      }
      _joining = false;
      authBusy = false;
      _changed();
    }
  }

  Future<void> signOut() {
    _authFlow = _leaveAccount(release: true);
    return _authFlow;
  }

  /// "Đăng xuất": back to unsaved guest play. The account's morning stays
  /// cached under its uid, and this browser no longer opens it on reload.
  /// [release] is false when another tab took the seat: that tab owns it
  /// now, and the shared login must stay. Nothing more is uploaded.
  Future<void> _leaveAccount({required bool release}) async {
    if (_leaving) return;
    _leaving = true;
    _seatEpoch++;
    _uploads = false;
    _seatBlocked = true;
    account.stopWatchingSeat();
    account.bindSeat(null);
    _discardLocal = true;
    try {
      await _pendingSaves;
    } catch (_) {}
    if (release) {
      try {
        await account.releaseSeat(tabId);
      } catch (_) {}
    }
    if (release) {
      try {
        await account.signOut();
      } catch (_) {}
    }
    accountUid = null;
    accountEmail = null;
    accountName = null;
    accountPhotoUrl = null;
    authError = null;
    accountNotice = null;
    lastSavedAt = null;
    _cloudDay = 0;
    accountOpening = false;
    openingRetry = false;
    try {
      await _store.clearLastAccount();
    } catch (_) {}
    _store.useAccount(null);
    _resetTransient();
    _installGuest();
    _discardLocal = false;
    _sawOwnSeat = false;
    _leaving = false;
    seatLost = false;
    paused = false;
    screen = Screen.title;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _leaving = true;
    account.stopWatchingSeat();
    super.dispose();
  }

  /// Installs [cloud] as the morning. An uploaded photo on [cached], this
  /// account's own copy on this device, is kept. Nothing is uploaded here:
  /// the cloud is written by the next save while playing.
  Future<void> _adoptCloud(CloudRecord cloud, GameState? cached) async {
    final cloudAvatar = cloud.state.ownerAvatar;
    state = cloud.state;
    keepUploadedAvatar(state, cached);
    _fitGardenPlots();
    _fitPetHome();
    if (accountUid != null) state.accountUid = accountUid;
    sounds.musicOn = state.musicOn;
    sounds.effectsOn = state.sfxOn;
    _armGoals();
    if (state.ownerAvatar != cloudAvatar) _publishAvatar(state.ownerAvatar);
    _checkpoint = state.encode();
    hasSave = true;
    lastSavedAt = cloud.updatedAt ?? DateTime.now();
    final adopted = GameState.decode(_checkpoint);
    if (adopted != null) _saveLocal(adopted);
    try {
      await _pendingSaves;
    } catch (_) {}
    if (screen != Screen.title) {
      _resetTransient();
      screen = Screen.title;
    }
    _changed();
  }

  /// Adds an admin grant into the account morning just loaded.
  /// The same grant id is stored on the save so the next login skips it.
  Future<void> _applyCloudGrant() async {
    if (!signedIn || _discardLocal) return;
    final XuGrant? grant;
    try {
      grant = await account.pullGrant();
    } catch (_) {
      return;
    }
    final effect = grantEffect(
      appliedId: state.appliedGrantId,
      currentDay: state.day,
      grant: grant,
    );
    if (effect == null) return;
    // The day raise is not a reward item; it rides along with the save.
    grantRewards(
      RewardBundle.coins(effect.money),
      source: RewardSource.adminGrant,
      mark: (target) {
        if (effect.day != null) target.day = effect.day!;
        target.appliedGrantId = effect.grantId;
      },
    );
    final parts = <String>[
      if (effect.money > 0) 'thêm ${formatK(effect.money)}',
      if (effect.day != null) 'màn ${effect.day}',
    ];
    showNotice('Tiệm nhận ${parts.join(', ')}.', quiet: true, seconds: 4);
    _changed();
    try {
      await _pendingSaves;
    } catch (_) {}
  }

  /// Adds an admin gift into the morning. The shipment id is stored so
  /// the next login does not add the same box again.
  Future<void> _applyCloudGift() async {
    if (!signedIn || _discardLocal) return;
    final PetGiftBox? box;
    try {
      box = await account.pullGift();
    } catch (_) {
      return;
    }
    final bundle = giftBundle(box, appliedId: state.appliedGiftId);
    if (bundle == null) return;
    final id = box!.id;
    final granted = grantRewards(
      bundle,
      source: RewardSource.adminGift,
      mark: (target) => target.appliedGiftId = id,
    );
    showNotice(giftGrantedLine(granted), quiet: true, seconds: 4);
    _changed();
    try {
      await _pendingSaves;
    } catch (_) {}
  }

  /// The one way rewards enter the shop (admin gifts and grants, the
  /// mystery customer, events; later the mailbox, login rewards and
  /// giftcodes). Adds [bundle] to the day, and for a [RewardSource] that
  /// persists now also to the morning save (local + cloud). [mark] edits
  /// both copies too, e.g. the applied gift id. Returns only what was
  /// really added, for the UI. See [applyRewards] for owned pots and pets.
  RewardBundle grantRewards(
    RewardBundle bundle, {
    required RewardSource source,
    void Function(GameState target)? mark,
  }) {
    final granted = applyRewards(state, bundle).granted;
    mark?.call(state);
    if (source.persistNow) {
      _patchMorning((cp) {
        applyRewards(cp, granted);
        mark?.call(cp);
      });
      _changed();
    }
    return granted;
  }

  void useGooglePhoto() {
    if (!signedIn) return;
    setOwnerAvatar('google');
  }

  Future<void> uploadOwnerPhoto() async {
    if (!signedIn || uploadBusy) return;
    uploadBusy = true;
    uploadError = null;
    _changed();
    try {
      final jpeg = await account.pickAvatarJpeg();
      if (jpeg == null) return;
      final path = await account.uploadAvatar(jpeg);
      if (path == null) {
        uploadError = 'Chưa tải ảnh lên được, thử lại nhé.';
        sounds.effect('error');
        return;
      }
      setOwnerAvatar(path, bumpRev: true);
    } catch (_) {
      uploadError = 'Chưa tải ảnh lên được, thử lại nhé.';
      sounds.effect('error');
    } finally {
      uploadBusy = false;
      _changed();
    }
  }

  Screen? _screenBeforeDonors;
  bool _pausedForDonors = false;

  /// Đại thiện nhân. Pauses the day clock like the pause popup, then
  /// [closeDonors] returns to the screen that opened it. A clock that was
  /// already paused (settings) stays paused.
  void openDonors() {
    if (screen == Screen.donors) return;
    _screenBeforeDonors = screen;
    if (!paused) {
      paused = true;
      _pausedForDonors = true;
    }
    screen = Screen.donors;
    sounds.effect('temple_bell');
    _changed();
  }

  void closeDonors() {
    if (screen != Screen.donors) return;
    if (_pausedForDonors) {
      paused = false;
      _pausedForDonors = false;
    }
    screen = _screenBeforeDonors ?? Screen.summary;
    _screenBeforeDonors = null;
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
    sounds.effect('popup_open');
  }

  void closePopup() {
    if (popups.isNotEmpty) {
      popups.removeAt(0);
      sounds.effect('popup_close');
    }
    _changed();
  }

  /// Unlock popup "Ra chợ": only offered in the morning (market phase).
  void closePopupAndGoToMarket() {
    if (popups.isNotEmpty) {
      popups.removeAt(0);
      sounds.effect('popup_close');
    }
    if (state.phase == DayPhase.market) {
      screen = hasPreorderBoard(this) ? Screen.preorders : Screen.market;
    }
    _changed();
  }

  void _queueHolidayPopup() {
    final h = holidayToday;
    if (h == null || _holidayPopupDay == state.day) return;
    _holidayPopupDay = state.day;
    sounds.effect('holiday_banner');
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

  void _endTutorial({bool skipped = false}) {
    tutorialStep = 0;
    for (final c in queue) {
      c.patienceLocked = false;
    }
    _setTutorialDone();
    PlayAnalytics.tutorialDone(skipped: skipped);
    _changed();
  }

  /// "Bỏ qua": ends the tutorial for good.
  void skipTutorial() => _endTutorial(skipped: true);

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
    sounds.effect('market_add');
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
    if (total > 0) sounds.effect('market_buy');
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
        (h?.customerMultiplier ?? 1.0) *
        priceCustomerFactor(e, priceMultiplier);
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
    sounds.effect('shop_open');
    // Day 10, 20, 30…; other days the income-slot pet may bring one. No
    // roll without such a pet, so the day's dice stay as they were.
    final mysteryOdds = petEffects.mysteryChance;
    _mysteryLeft =
        state.day > 0 &&
        (state.day % 10 == 0 ||
            (mysteryOdds > 0 && rng.nextDouble() < mysteryOdds));
    armShopEvent(this);
    PlayAnalytics.dayOpen(state.day);
    if (tutorialStep == 3) {
      tutorialStep = 4;
      _spawnCustomer(tutorial: true);
    }
    _changed();
  }

  /// Top-bar pause button: opens the pause popup.
  void togglePause() => pauseMenuOpen ? resumeFromPause() : openPause();

  /// A button on the event card.
  void chooseEvent(String choiceId) => chooseShopEvent(this, choiceId);

  /// Opens one event card now. The clock uses this after the roll.
  void presentEvent(String id) => _showEvent(this, id);

  void showNotice(String text, {bool quiet = false, double seconds = 2}) {
    if (!quiet) sounds.effect('error');
    shopNotice = text;
    // spec_ban_bo_hoa / tiem_chinh do not give a duration; 2 s like the
    // angry-bubble timing order of magnitude.
    _noticeLeft = seconds;
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
      final clockRuns = !_tutorialHoldsClock && eventOffer == null;
      if (clockRuns) {
        state.elapsed += dt;
        maybeShowShopEvent(this);
        tickWholesale(this);
      }
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
          if (c.walkIn <= 0) {
            sounds.effect('customer_arrive');
            if (identical(nextForPlayer, c)) sounds.effect('order_bubble');
            structural = true;
          }
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
        c.patienceLeft -= dt * patienceDrain(this);
        if (!c.patienceWarned && c.patienceFraction < e.patienceWarningAt) {
          c.patienceWarned = true;
          sounds.effect('patience_low');
        }
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
        _finishDay(reachedClose: true);
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
    final mysterious = !tutorial && _mysteryLeft;
    final CustomerProfile? profile;
    if (mysterious) {
      profile = const CustomerProfile(
        name: mysteryName,
        gender: 'f',
        age: 'adult',
        avatarId: mysteryAvatar,
      );
    } else {
      final inQueue = queue.map((c) => c.name).toSet();
      final everyone = data.orders.customers;
      final free = everyone.where((c) => !inQueue.contains(c.name)).toList();
      profile = free.isNotEmpty
          ? free[rng.nextInt(free.length)]
          : (everyone.isEmpty ? null : everyone[rng.nextInt(everyone.length)]);
    }
    final BouquetRequest? request = tutorial
        ? easyRequest(e, stock: _stockByFlower(), rng: rng)
        : requestForShelf(
            e,
            owned: owned,
            shelf: {for (final f in e.flowers) f.id: stockAvailable(f.id)},
            rng: rng,
          );
    if (request == null) return;
    if (mysterious) _mysteryLeft = false;
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
        patienceMax:
            e.patienceSeconds *
            fx.patienceMultiplier *
            (1 + petEffects.patienceBonus) *
            pricePatienceFactor(e, priceMultiplier),
        walkIn: e.walkInSeconds,
        mysterious: mysterious,
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
    final before = _ratingLabel;
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
      sounds.effect('review_new');
    }
    state.metrics.customersLeft++;
    _soundRating(before);
    sounds.effect('customer_leave');
    _soundGoals();
    departures.add(Departure(c, stars ?? 0));
    if (identical(tableCustomer, c)) {
      final hadBouquet = !draft.isEmpty;
      _returnDraftToStock();
      tableCustomer = null;
      wrapping = false;
      screen = Screen.shop;
      if (hadBouquet) {
        // Without this the player is dropped back to the shop with no reason.
        final who = c.name.length <= 12 ? c.name : 'Khách';
        shopNotice = '$who đã đi mất rồi, bó này chưa giao được.';
        _noticeLeft = 3;
      }
    }
  }

  // ---------------------------------------------------------------------
  // Florist (staff level 2+): serves other customers while the player
  // keeps the first one. Higher levels wrap more than one at a time.
  // ---------------------------------------------------------------------

  void _startAutoServeIfPossible() {
    final secs = effects.autoServeSeconds;
    if (secs == null) return;
    final slots = effects.autoServeSlots;
    var busy = 0;
    for (final c in queue) {
      if (c.autoServeLeft != null) busy++;
    }
    if (busy >= slots) return;
    // The player keeps the first servable customer.
    final player = tableCustomer ?? nextForPlayer;
    for (final c in queue) {
      if (!c.arrived || identical(c, player) || c.autoServeLeft != null) {
        continue;
      }
      final r = c.request;
      final stems = r.total + r.fillerCount;
      if (stems > effects.autoServeMaxStems) continue;
      if (!_hasStockFor(r)) continue;
      c.autoServeLeft = secs;
      c.frozen = true;
      busy++;
      if (busy >= slots) return;
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
    final result = _settleDelivery(
      c,
      b,
      match,
      tier: tier,
      fast: false,
      wrapHit: false,
      byStaff: true,
    );
    showNotice(
      'Nhân viên bó cho ${c.name} · ★${result.review.stars} · ${formatSignedK(result.payment.total)}${result.stones > 0 ? ' · tặng ${result.stones} giọt hoa' : ''}',
      quiet: true,
      seconds: 2.5,
    );
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
    cardNote = null;
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
    sounds.effect('flower_pick');
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
    sounds.effect('flower_remove');
    final order = tableOrder;
    if (order != null && order.reservedUids.remove(stem.uid)) {
      order.reserved[stem.flowerId] = (order.reserved[stem.flowerId] ?? 0) + 1;
    }
    _changed();
  }

  void selectPaper(String id) {
    if (wrapping || !owned.contains(id)) return;
    draft.paperId = id;
    sounds.effect('wrap_paper');
    _checkTutorialDraft();
    _changed();
  }

  void selectRibbon(String id) {
    if (wrapping || !owned.contains(id)) return;
    draft.ribbonId = id;
    sounds.effect('ribbon_tie');
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
    final note = cardNote;
    cardNote = null;
    final match = scoreBouquet(e, c.request, bouquet);
    final result = _settleDelivery(
      c,
      bouquet,
      match,
      tier: match.tier,
      fast: _fastService,
      wrapHit: hit,
      cardText: note,
    );
    draft = Bouquet();
    wrapping = false;
    // The full card teaches the screen once. Later sales stay a one-line
    // notice; the comment itself lives on the Đánh giá tab.
    final showCard = !state.reviewIntroSeen || tutorialStep > 0;
    if (showCard) {
      lastDelivery = result;
      sounds.effect('popup_open');
      pendingReveal += result.payment.total;
    } else {
      screen = Screen.shop;
      final tip = result.payment.tipTotal;
      final tipLine = tip > 0 ? ' · boa ${formatSignedK(tip)}' : '';
      final stoneLine = result.stones > 0 ? ' · ${result.stones} giọt hoa' : '';
      showNotice(
        '★${result.review.stars} · ${formatSignedK(result.payment.pay)}$tipLine$stoneLine. Xem ở Đánh giá',
        quiet: true,
        seconds: 2.5,
      );
    }
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
    bool byStaff = false,
    String? cardText,
  }) {
    final before = _ratingLabel;
    final occasion = e.occasion(c.request.occasionId);
    final price = bouquetPrice(e, bouquet, multiplier: priceMultiplier);
    final payment = computePayment(
      e,
      price: price,
      tier: tier,
      fastService: fast,
      wrapHit: wrapHit,
      holidayTipMultiplier: holidayToday?.tipMultiplier ?? 1.0,
      occasionTipMultiplier: occasion.tipMultiplier,
      noteTip: cardNoteTip(e, occasionId: occasion.id, note: cardText),
    );
    var supplies = 0;
    if (bouquet.paperId != null) supplies += e.paper(bouquet.paperId!).buyPrice;
    if (bouquet.ribbonId != null) {
      supplies += e.ribbon(bouquet.ribbonId!).buyPrice;
    }
    state.money += payment.total - supplies;
    noteWholesale(this, bouquet, price);
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
      byStaff: byStaff,
      cardText: cardChoiceText(e, cardText),
    );
    state.addReview(review);
    m.newReviews++;
    sounds.effect('review_new');
    if (payment.tipTotal > 0) sounds.effect('tip_coins');
    queue.remove(c);
    if (identical(tableCustomer, c)) tableCustomer = null;
    sounds.effect('bouquet_done');
    sounds.effect('cash_register');
    _soundRating(before);
    _soundGoals();
    final range = stoneGiftRange(review.stars);
    final gifted = c.mysterious
        ? range.$1 + rng.nextInt(range.$2 - range.$1 + 1)
        : 0;
    if (gifted > 0) {
      grantRewards(
        RewardBundle.giotHoa(gifted),
        source: RewardSource.mysteryCustomer,
      );
    }
    return DeliveryResult(
      customer: c,
      match: match,
      payment: payment,
      review: review,
      wrapHit: wrapHit,
      stones: gifted,
    );
  }

  /// "Tiếp tục" on the review popup: coins reach the top bar, back to shop.
  void closeDeliveryPopup() {
    final gifted = lastDelivery?.stones ?? 0;
    if (lastDelivery != null && !state.reviewIntroSeen) {
      state.reviewIntroSeen = true;
      _patchMorning((cp) => cp.reviewIntroSeen = true);
    }
    lastDelivery = null;
    pendingReveal = 0;
    screen = Screen.shop;
    sounds.effect('popup_close');
    if (gifted > 0) {
      showNotice('Khách thần bí tặng $gifted giọt hoa.', quiet: true);
    }
    if (tutorialStep == 8) _endTutorial();
    _changed();
  }

  /// The walk-in wants stems the shelf cannot cover, even counting the draft.
  bool get cannotFillCustomer {
    final c = tableCustomer;
    if (c == null || wrapping) return false;
    final held = <String, int>{};
    for (final stem in draft.stems) {
      held[stem.flowerId] = (held[stem.flowerId] ?? 0) + 1;
    }
    for (final need in stemNeeds(c.request).entries) {
      if (stockAvailable(need.key) + (held[need.key] ?? 0) < need.value) {
        return true;
      }
    }
    return false;
  }

  /// "Từ chối": the customer leaves unhappy, same as running out of patience.
  void declineCustomer() {
    final c = tableCustomer;
    if (c == null || wrapping || tutorialStep > 0) return;
    cardNote = null;
    _returnDraftToStock();
    _customerLeaves(c);
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

  void openStock() {
    _stockReturn = screen == Screen.stock ? _stockReturn : screen;
    screen = Screen.stock;
    _changed();
  }

  void closeStock() {
    screen = _stockReturn;
    if (state.phase == DayPhase.summary) screen = Screen.summary;
    _changed();
  }

  /// Walk-in price level, snapped to the Giá bán steps.
  double get priceMultiplier => snapPriceMultiplier(e, state.priceMultiplier);

  bool get canEditPrice => state.phase != DayPhase.open;

  void openPrices() {
    if (!pricesUnlocked) return;
    _pricesReturn = screen == Screen.prices ? _pricesReturn : screen;
    screen = Screen.prices;
    _changed();
  }

  /// Giá bán stays on the normal price until this morning.
  bool get pricesUnlocked => state.day >= e.pricesOpenDay;

  void closePrices() {
    screen = _pricesReturn;
    if (state.phase == DayPhase.summary) screen = Screen.summary;
    _changed();
  }

  // ---------------------------------------------------------------------
  // Garden (real-world minutes, saved with the morning)
  // ---------------------------------------------------------------------

  /// The shift is only a few minutes. Watering happens around it.
  /// The yard itself stays shut until [Economy.gardenOpenDay].
  bool get gardenUnlocked => state.day >= e.gardenOpenDay;

  bool get canGarden => gardenUnlocked && state.phase != DayPhase.open;

  /// Extra beds can be bought from this morning on.
  bool get plotShopUnlocked => state.day >= e.gardenPlotBuyDay;

  void openGarden() {
    if (!canGarden) return;
    _gardenReturn = screen == Screen.garden ? _gardenReturn : screen;
    screen = Screen.garden;
    _changed();
  }

  void closeGarden() {
    screen = _gardenReturn;
    if (state.phase == DayPhase.summary) screen = Screen.summary;
    _changed();
  }

  Screen _petReturn = Screen.shop;

  /// The room and the pet shop open on the morning of day 5.
  bool get petsUnlocked => state.day >= strayCatDay;

  void openPets() {
    if (!petsUnlocked) return;
    _petReturn = screen == Screen.pets ? _petReturn : screen;
    screen = Screen.pets;
    _changed();
  }

  /// Pet shown in the room. Null picks the income-slot pet, then the first.
  String? petRoomId;

  /// The pet in the room, or null when the shop has none.
  OwnedPet? get roomPet {
    final chosen = petRoomId == null ? null : state.ownedPet(petRoomId!);
    if (chosen != null) return chosen;
    final income = state.petIncome == null
        ? null
        : state.ownedPet(state.petIncome!);
    return income ?? (state.pets.isEmpty ? null : state.pets.first);
  }

  /// Name of a pet id from economy.json.
  String petName(String id) => e.pet(id)?.nameVi ?? id;

  /// "Vào phòng": the room with [id] in it.
  void openPetRoom(String id) {
    if (!state.ownsPet(id)) return;
    petRoomId = id;
    petCatalogOpen = false;
    if (screen == Screen.pets) {
      _changed();
      return;
    }
    openPets();
  }

  /// The pet the room shows and the one whose abilities count.
  void useRoomPet(String id) {
    if (!state.ownsPet(id)) return;
    petRoomId = id;
    state.petIncome = id;
    _patchPet();
    sounds.effect('ui_tap');
    _changed();
  }

  void closePets() {
    screen = _petReturn;
    if (state.phase == DayPhase.summary) screen = Screen.summary;
    _changed();
  }

  bool get petHungry {
    final pet = roomPet;
    return pet != null &&
        petIsHungry(hasCat: true, fedDay: pet.fedDay, day: state.day);
  }

  bool get petReadyToGrow {
    final pet = roomPet;
    return pet != null && pet.stage < 2 && pet.progress >= 100;
  }

  /// The room pet eats one meal. A bigger pet spends more bánh mật.
  /// Returns the pose, or null when there is none.
  String? feedPet() {
    final pet = roomPet;
    if (pet == null) return null;
    final meal = biscuitsToEat(pet.stage);
    if (state.biscuits < meal) return null;
    state.biscuits -= meal;
    pet.fedDay = state.day;
    final growing = pet.stage < 2 && pet.progress < 100;
    if (growing) {
      final next = pet.progress + biscuitProgress;
      pet.progress = next > 100 ? 100 : next;
    }
    _patchPet();
    sounds.effect(growing ? 'upgrade_buy' : 'market_buy');
    _changed();
    return growing ? 'nang' : 'an';
  }

  /// Spends giọt hoa and raises the room pet's stage. Returns the pose,
  /// or null.
  String? breakthroughPet() {
    final pet = roomPet;
    if (pet == null) return null;
    final cost = stonesToGrow(pet.stage);
    final held = state.drops + state.stones;
    if (!petReadyToGrow || held < cost) return null;
    state.drops = held - cost;
    state.stones = 0;
    pet.stage += 1;
    pet.progress = 0;
    pet.fedDay = state.day;
    _patchPet();
    sounds.effect('level_up');
    _changed();
    return 'dotpha';
  }

  /// The first cushion and bowl come with the room. Later skins are gifts.
  void _fitPetHome() {
    if (!state.petSeats.contains(giftSeat)) state.petSeats.add(giftSeat);
    state.petSeat ??= giftSeat;
    if (!state.petBowls.contains(giftBowl)) state.petBowls.add(giftBowl);
    state.petBowl ??= giftBowl;
  }

  void _patchPet({int moneyDelta = 0, int phaLeDelta = 0}) {
    _patchMorning((cp) {
      if (moneyDelta != 0) cp.money += moneyDelta;
      if (phaLeDelta != 0) cp.phaLe += phaLeDelta;
      cp.pets = [for (final pet in state.pets) pet.copy()];
      cp.petIncome = state.petIncome;
      cp.petCharm = state.petCharm;
      cp.biscuits = state.biscuits;
      cp.drops = state.drops;
      cp.stones = state.stones;
      cp.petSeats = [...state.petSeats];
      cp.petBowls = [...state.petBowls];
      cp.petSeat = state.petSeat;
      cp.petBowl = state.petBowl;
      cp.appliedGiftId = state.appliedGiftId;
      cp.strayCatSeen = state.strayCatSeen;
    });
  }

  /// The day-5 stray kitten, still waiting for an answer on the summary.
  bool get strayCatOffer =>
      state.phase == DayPhase.summary &&
      state.day == strayCatDay &&
      !state.strayCatSeen &&
      !state.hasCat;

  void chooseStrayCat(bool adopt) {
    if (!strayCatOffer) return;
    state.strayCatSeen = true;
    if (adopt) {
      state.addPet(catPetId, fedDay: state.day);
      sounds.effect('level_up');
      showNotice('Bé mèo đã về phòng.', quiet: true);
    } else {
      sounds.effect('popup_close');
      showNotice('Bé mèo đi tiếp.', quiet: true);
    }
    _patchPet();
    _changed();
  }

  bool petCatalogOpen = false;

  /// `seat` or `bowl` while the skin cupboard is open.
  String? skinPicker;

  void openPetCatalog() {
    if (!petsUnlocked) return;
    petCatalogOpen = true;
    skinPicker = null;
    sounds.effect('popup_open');
    _changed();
  }

  void closePetCatalog() {
    if (!petCatalogOpen) return;
    petCatalogOpen = false;
    sounds.effect('popup_close');
    _changed();
  }

  void openSkinPicker(String kind) {
    skinPicker = kind;
    sounds.effect('popup_open');
    _changed();
  }

  void closeSkinPicker() {
    if (skinPicker == null) return;
    skinPicker = null;
    sounds.effect('popup_close');
    _changed();
  }

  bool skinOwned(PetSkin skin) {
    if (skin.price <= 0) return true;
    final owned = skin.kind == skinSeat ? state.petSeats : state.petBowls;
    return owned.contains(skin.id);
  }

  bool skinEquipped(PetSkin skin) => skin.kind == skinSeat
      ? state.petSeat == skin.id
      : state.petBowl == skin.id;

  void usePetSkin(String id) {
    final skin = petSkinById(id);
    if (skin == null || !skinOwned(skin)) return;
    if (skin.kind == skinSeat) {
      state.petSeat = skin.id;
    } else {
      state.petBowl = skin.id;
    }
    _patchPet();
    sounds.effect('ui_tap');
    _changed();
  }

  /// Buys a paid skin and puts it in the room. Free skins are already owned.
  bool buyPetSkin(String id) {
    final skin = petSkinById(id);
    if (skin == null || skin.price <= 0 || !petShopOpen) return false;
    if (skinOwned(skin) || state.money < skin.price) return false;
    state.money -= skin.price;
    if (skin.kind == skinSeat) {
      if (!state.petSeats.contains(skin.id)) state.petSeats.add(skin.id);
      state.petSeat = skin.id;
    } else {
      if (!state.petBowls.contains(skin.id)) state.petBowls.add(skin.id);
      state.petBowl = skin.id;
    }
    _patchPet(moneyDelta: -skin.price);
    sounds.effect('market_buy');
    _changed();
    return true;
  }

  Screen _petShopReturn = Screen.shop;

  void openPetShop() {
    _petShopReturn = screen == Screen.petShop ? _petShopReturn : screen;
    screen = Screen.petShop;
    _changed();
  }

  void closePetShop() {
    screen = _petShopReturn;
    if (state.phase == DayPhase.summary) screen = Screen.summary;
    _changed();
  }

  /// The pet shop takes money only while the doors are shut.
  bool get petShopOpen => state.phase != DayPhase.open;

  /// Pets of the shop: xu pets first, then Pha lê pets, each by price
  /// (SPEC_shop_thu_cung.md §1).
  List<PetDef> get petShopList {
    final list = [...e.pets];
    list.sort((a, b) {
      if (a.paysPhaLe != b.paysPhaLe) return a.paysPhaLe ? 1 : -1;
      final byPrice = a.price.compareTo(b.price);
      return byPrice != 0 ? byPrice : e.pets.indexOf(a) - e.pets.indexOf(b);
    });
    return list;
  }

  /// How much xu or Pha lê is still missing for [pet]. 0 when it can pay.
  int petShortfall(PetDef pet) {
    final have = pet.paysPhaLe ? state.phaLe : state.money;
    return have >= pet.price ? 0 : pet.price - have;
  }

  /// Buys one shop pet with xu or Pha lê. Closed hours only, so the money
  /// stays saved. The pet arrives at ấu thú; empty slots take it.
  bool buyPet(String id) {
    final pet = e.pet(id);
    if (pet == null || !petShopOpen) return false;
    if (state.ownsPet(id) || petShortfall(pet) > 0) return false;
    if (pet.paysPhaLe) {
      state.phaLe -= pet.price;
    } else {
      state.money -= pet.price;
    }
    state.addPet(id, fedDay: state.day);
    _patchPet(
      moneyDelta: pet.paysPhaLe ? 0 : -pet.price,
      phaLeDelta: pet.paysPhaLe ? -pet.price : 0,
    );
    sounds.effect('unlock');
    _changed();
    return true;
  }

  /// Buys one biscuit or drop. Same closed-shop rule as [buyPet].
  bool buyTreat(String id) {
    final treat = petTreat(id);
    if (treat == null || !petShopOpen) return false;
    final have = switch (id) {
      giftBiscuit => state.biscuits,
      giftDrop => state.drops,
      _ => -1,
    };
    if (have < 0 || have >= maxGiftCount) return false;
    if (state.money < treat.price) return false;
    state.money -= treat.price;
    if (id == giftBiscuit) {
      state.biscuits += 1;
    } else {
      state.drops += 1;
    }
    _patchPet(moneyDelta: -treat.price);
    sounds.effect('market_buy');
    _changed();
    return true;
  }

  int seedCount(String flowerId) => state.seeds[flowerId] ?? 0;

  int get shovelCount => state.shovels;

  bool buyShovel() {
    if (state.phase != DayPhase.market && state.phase != DayPhase.preparing) {
      return false;
    }
    if (state.money < e.shovelPrice) return false;
    state.money -= e.shovelPrice;
    state.shovels += 1;
    _patchGarden(moneyDelta: -e.shovelPrice);
    sounds.effect('market_buy');
    _changed();
    return true;
  }

  /// Buys the next dry bed. The price rises after each purchase.
  bool buyPlot() {
    if (!canGarden || !plotShopUnlocked) return false;
    if (state.plots.length >= e.gardenMaxPlots) return false;
    final price = e.gardenPlotPrice(state.plots.length);
    if (state.money < price) return false;
    state.money -= price;
    state.plots.add(GardenPlot());
    _patchGarden(moneyDelta: -price);
    sounds.effect('upgrade_buy');
    _changed();
    return true;
  }

  GardenView gardenView(int index) {
    final plot = state.plots[index];
    final seed = plot.flowerId == null ? null : e.gardenSeed(plot.flowerId!);
    return viewPlot(plot, seed?.stepMinutes ?? 1, _now());
  }

  bool buySeed(String flowerId) {
    if (state.phase != DayPhase.market && state.phase != DayPhase.preparing) {
      return false;
    }
    final seed = e.gardenSeed(flowerId);
    if (seed == null || !owned.contains(flowerId)) return false;
    if (state.money < seed.price) return false;
    state.money -= seed.price;
    state.seeds[flowerId] = seedCount(flowerId) + 1;
    _patchGarden(moneyDelta: -seed.price);
    sounds.effect('market_buy');
    _changed();
    return true;
  }

  bool tillPlot(int index) {
    if (!_gardenIndex(index) || !canGarden) return false;
    final plot = state.plots[index];
    if (plot.tilled) return false;
    if (state.shovels < 1) return false;
    state.shovels -= 1;
    plot.tilled = true;
    _patchGarden();
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  bool plantPlot(int index, String flowerId) {
    if (!_gardenIndex(index) || !canGarden) return false;
    final view = gardenView(index);
    if (view.phase != GardenPhase.empty) return false;
    final seed = e.gardenSeed(flowerId);
    if (seed == null || !owned.contains(flowerId)) return false;
    if (seedCount(flowerId) <= 0) return false;
    final left = seedCount(flowerId) - 1;
    if (left == 0) {
      state.seeds.remove(flowerId);
    } else {
      state.seeds[flowerId] = left;
    }
    final plot = state.plots[index];
    plot.flowerId = flowerId;
    plot.stage = 0;
    plot.nextAtMs = _now()
        .add(Duration(minutes: seed.stepMinutes))
        .millisecondsSinceEpoch;
    _patchGarden();
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  bool waterPlot(int index) {
    if (!_gardenIndex(index) || !canGarden) return false;
    final view = gardenView(index);
    if (!view.thirsty) return false;
    final plot = state.plots[index];
    final seed = e.gardenSeed(plot.flowerId!);
    if (seed == null) return false;
    plot.stage += 1;
    if (plot.stage < 2) {
      plot.nextAtMs = _now()
          .add(Duration(minutes: seed.stepMinutes))
          .millisecondsSinceEpoch;
    }
    _patchGarden();
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  bool harvestPlot(int index) {
    if (!_gardenIndex(index) || !canGarden) return false;
    final view = gardenView(index);
    if (view.phase != GardenPhase.bloom || view.flowerId == null) return false;
    final seed = e.gardenSeed(view.flowerId!);
    if (seed == null) return false;
    final batch = StockBatch(
      flowerId: view.flowerId!,
      count: seed.yieldStems,
      freshnessLeft: fullFreshness(e.flower(view.flowerId!)),
    );
    state.stock.add(batch);
    final plot = state.plots[index];
    plot.flowerId = null;
    plot.stage = 0;
    plot.nextAtMs = 0;
    _patchGarden(harvested: batch);
    sounds.effect('market_buy');
    _changed();
    return true;
  }

  bool clearPlot(int index) {
    if (!_gardenIndex(index) || !canGarden) return false;
    if (gardenView(index).phase != GardenPhase.wilted) return false;
    final plot = state.plots[index];
    plot.flowerId = null;
    plot.stage = 0;
    plot.nextAtMs = 0;
    _patchGarden();
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  bool _gardenIndex(int index) => index >= 0 && index < state.plots.length;

  /// Garden changes survive closing the tab. The rest of today still replays
  /// from the morning. [moneyDelta] is applied to that morning on its own,
  /// so a seed bought after the market does not save the flower cart.
  void _patchGarden({int moneyDelta = 0, StockBatch? harvested}) {
    _patchMorning((cp) {
      if (moneyDelta != 0) cp.money += moneyDelta;
      cp.seeds
        ..clear()
        ..addAll(state.seeds);
      cp.shovels = state.shovels;
      cp.plots = [for (final p in state.plots) p.copy()];
      if (harvested != null) {
        cp.stock.add(
          StockBatch(
            flowerId: harvested.flowerId,
            count: harvested.count,
            freshnessLeft: harvested.freshnessLeft,
          ),
        );
      }
    });
  }

  /// Ignored while the doors are open: today's crowd was already counted.
  void setPriceMultiplier(double next) {
    if (!canEditPrice) return;
    final snapped = snapPriceMultiplier(e, next);
    if (snapped == priceMultiplier) return;
    state.priceMultiplier = snapped;
    sounds.effect('ui_tap');
    _changed();
  }

  /// Picks the theme card for [occasionId]. Picking it again clears it.
  void pickCardTheme(String occasionId) {
    final line = cardLineFor(e, occasionId);
    cardNote = cardNote == line ? null : line;
    _changed();
  }

  /// Clears the picked theme card.
  void clearCardNote() {
    cardNote = null;
    _changed();
  }

  /// Reviews answered before the customer line existed get that third message
  /// on the next launch. Stars stay as they were.
  bool _fillMissingCustomerReplies() {
    var filled = false;
    for (var i = 0; i < state.reviews.length; i++) {
      final review = state.reviews[i];
      if (review.replyText == null || review.customerReply != null) continue;
      final tone = ownerReplyToneOf(
        data.reviews,
        review.outcome,
        review.replyText!,
      );
      final follow = pickCustomerFollowUp(data.reviews, tone ?? 'typed', rng);
      if (follow == null) continue;
      state.reviews[i] = review.copyWith(customerReply: follow);
      filled = true;
    }
    return filled;
  }

  /// Which shelf slot the pot cupboard is editing. Null while it is closed.
  bool? potPickerBar;
  int potPickerIndex = 0;
  bool get potPickerOpen => potPickerBar != null;

  void openPotPicker({required bool bar, required int index}) {
    potPickerBar = bar;
    potPickerIndex = index;
    sounds.effect('popup_open');
    _changed();
  }

  void closePotPicker() {
    if (potPickerBar == null) return;
    potPickerBar = null;
    sounds.effect('popup_close');
    _changed();
  }

  String potInSlot({required bool bar, required int index}) =>
      bar ? state.barPots[index] : state.displayPots[index];

  /// Shown in Kho chậu: the free bucket, pots on sale, and any pot the
  /// player already owns (a catalog-only pot stays hidden until then).
  bool potListed(PotDef pot) =>
      pot.unlimited || pot.purchasable || (state.potCounts[pot.id] ?? 0) > 0;

  int potOwned(String id) {
    final pot = e.pot(id);
    if (pot.unlimited) return 99;
    return state.potCounts[id] ?? 0;
  }

  int potPlaced(String id) => [
    for (final slot in state.barPots)
      if (slot == id) slot,
    for (final slot in state.displayPots)
      if (slot == id) slot,
  ].length;

  bool canPlacePot(String id, {required bool bar, required int index}) {
    if (potInSlot(bar: bar, index: index) == id) return true;
    final pot = e.pot(id);
    if (pot.unlimited) return true;
    return potPlaced(id) < potOwned(id);
  }

  /// Puts [id] in the open slot. A limited pot cannot exceed copies owned.
  bool placePot(String id) {
    final bar = potPickerBar;
    if (bar == null) return false;
    final index = potPickerIndex;
    if (!canPlacePot(id, bar: bar, index: index)) return false;
    final slots = bar ? state.barPots : state.displayPots;
    slots[index] = id;
    _patchMorning((cp) {
      final saved = bar ? cp.barPots : cp.displayPots;
      saved[index] = id;
    });
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  /// Buys one more copy. The morning save keeps the pot and the spent money.
  bool buyPot(String id) {
    final pot = e.pot(id);
    if (!pot.purchasable) return false;
    final cost = pot.cost;
    if (pot.paysPhaLe) {
      if (state.phaLe < cost) return false;
      state.phaLe -= cost;
    } else {
      if (state.money < cost) return false;
      state.money -= cost;
    }
    state.potCounts[id] = (state.potCounts[id] ?? 0) + 1;
    _patchMorning((cp) {
      if (pot.paysPhaLe) {
        cp.phaLe -= cost;
        if (cp.phaLe < 0) cp.phaLe = 0;
      } else {
        cp.money -= cost;
        if (cp.money < 0) cp.money = 0;
      }
      cp.potCounts[id] = (cp.potCounts[id] ?? 0) + 1;
    });
    sounds.effect('upgrade_buy');
    _changed();
    return true;
  }

  /// One reply per review. Written into the morning save so it survives
  /// leaving mid-day. A review from today is kept in memory until the next
  /// day-boundary commit, like the rest of today's progress.
  bool replyToReview(ReviewRecord review, String raw) {
    final text = normalizeReply(raw);
    if (text == null || review.replyText != null) return false;
    final i = state.reviews.indexWhere((r) => identical(r, review));
    if (i < 0) return false;
    final before = _ratingLabel;
    final tone = ownerReplyToneOf(data.reviews, review.outcome, text);
    final raised =
        tone != null &&
        replyStarTones.contains(tone) &&
        review.stars < replyStarCap;
    final follow = pickCustomerFollowUp(
      data.reviews,
      raised ? 'raised' : (tone ?? 'typed'),
      rng,
    );
    final updated = review.copyWith(
      replyText: text,
      customerReply: follow,
      stars: raised ? review.stars + 1 : review.stars,
      starRaised: raised,
    );
    state.reviews[i] = updated;
    final cp = GameState.decode(_checkpoint);
    if (cp != null &&
        i < cp.reviews.length &&
        cp.reviews[i].replyText == null &&
        cp.reviews[i].day == review.day &&
        cp.reviews[i].customerName == review.customerName &&
        cp.reviews[i].comment == review.comment) {
      cp.reviews[i] = cp.reviews[i].copyWith(
        replyText: text,
        customerReply: follow,
        stars: updated.stars,
        starRaised: raised,
      );
      _checkpoint = cp.encode();
      if (hasSave && !_discardLocal) _saveLocal(cp);
    }
    sounds.effect('reply_sent');
    _soundRating(before);
    _changed();
    return true;
  }

  // ---------------------------------------------------------------------
  // End of day (Tổng kết)
  // ---------------------------------------------------------------------

  void _finishDay({required bool reachedClose}) {
    resolveShopEventDay(this);
    final ending = state.phase != DayPhase.summary;
    if (ending) {
      state.earlyClosesInARow = reachedClose ? 0 : state.earlyClosesInARow + 1;
    }
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
      // Income-slot pet: a share of the day's takings, paid at close.
      final takings = m.flowerIncome + m.tipIncome + m.onlineIncome;
      m.petBonus = (takings * petEffects.incomeBonus).round();
      m.fixedCosts = e.fixedCostsTotal + effects.dailyCosts + m.shipperWages;
      state.money += rewards + m.petBonus - m.fixedCosts;
      m.settled = true;
    }
    state.phase = DayPhase.summary;
    screen = Screen.summary;
    if (ending) {
      PlayAnalytics.dayEnd(
        revenue: m.flowerIncome + m.tipIncome + m.onlineIncome,
        bouquets: m.bouquetsSold,
        left: m.customersLeft,
        wilted: m.stemsWilted,
        stars: rating.average,
      );
    }
    tableCustomer = null;
    paused = false;
    pauseMenuOpen = false;
    sounds.effect('summary_count');
  }

  /// Upgrade upkeep + staff wages included in today's fixed costs.
  int get todayUpkeep => effects.dailyCosts;

  int get shippersHired => shippersHiredCount(state.shipperLevels);

  /// Two early closes in a row. The next open day must reach closing time.
  static const maxEarlyClosesInARow = 2;

  /// Shown when [mustPlayUntilClose] blocks Kết thúc ngày.
  static const playUntilCloseHint =
      'Đã đóng sớm hai ngày. Hôm nay chơi đến giờ đóng cửa nhé';

  /// True while this open day cannot be ended before the clock hits close.
  bool get mustPlayUntilClose =>
      state.phase == DayPhase.open &&
      !afterClose &&
      state.earlyClosesInARow >= maxEarlyClosesInARow;

  /// "Đóng cửa sớm": skip the rest of the open hours and show the summary.
  void closeEarly() {
    if (state.phase != DayPhase.open) return;
    if (mustPlayUntilClose) {
      showNotice(playUntilCloseHint);
      return;
    }
    state.pendingArrivals.clear();
    _returnDraftToStock();
    tableCustomer = null;
    tableOrder = null;
    wrapping = false;
    lastDelivery = null;
    pendingReveal = 0;
    queue.clear();
    departures.clear();
    _finishDay(reachedClose: afterClose);
    _changed();
  }

  /// "Sang ngày mới": freshness tick, next day, market.
  void startNextDay() {
    if (state.phase != DayPhase.summary) return;
    if (strayCatOffer) chooseStrayCat(false);
    rememberDayRevenue(this);
    applyMorningEvent(this);
    var discarded = false;
    var warning = false;
    for (final b in [...state.stock]) {
      b.freshnessLeft -= 1;
      if (b.freshnessLeft <= 0) {
        state.stock.remove(b);
        discarded = true;
      } else if (b.freshnessLeft == 1) {
        warning = true;
      }
    }
    if (discarded) sounds.effect('wilted_discard');
    if (warning) sounds.effect('wilt_warning');
    if (state.adsDaysLeft > 0) state.adsDaysLeft--;
    state.day++;
    _startDay();
    queue.clear();
    departures.clear();
    screen = hasPreorderBoard(this) ? Screen.preorders : Screen.market;
    if (rank.rank > state.rankSeen) {
      sounds.effect('level_up');
      _pushPopup(RankUpPopup(rank));
      state.rankSeen = rank.rank;
    }
    _queueHolidayPopup();
    sounds.effect('day_start');
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
      PlayAnalytics.adReward();
    } else {
      state.upgradeLevels[id] = (state.upgradeLevels[id] ?? 0) + 1;
      PlayAnalytics.upgrade(id);
    }
    // Cold storage also applies to stems already in stock.
    final diff = effects.freshnessBonusDays - beforeBonus;
    if (diff > 0) {
      for (final b in state.stock) {
        b.freshnessLeft += diff;
      }
    }
    sounds.effect('upgrade_buy');
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
    sounds.effect('unlock');
    _pushPopup(UnlockPopup(itemId));
    _changed();
    return true;
  }
}
