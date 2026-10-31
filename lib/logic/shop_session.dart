import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/sounds.dart';
import '../ui/install_prompt.dart';
import '../data/account_gateway.dart';
import '../data/charm_board.dart';
import '../data/rating_board.dart';
import 'charm_board_controller.dart';
import 'rating_board_controller.dart';
import 'notice_feed.dart' show NoticeAccount;
import '../data/economy.dart';
import '../data/game_data.dart';
import '../data/pet_items.dart';
import '../data/pot_book.dart';
import '../data/regulars.dart';
import '../data/skins.dart';
import '../data/texts.dart';
import '../data/wilting.dart';
import '../save/game_state.dart';
import '../save/progress_store.dart';
import '../save/terms_consent.dart';
import '../data/phale_shop.dart';
import '../iap/apple_phale_client.dart';
import '../iap/phale_iap.dart';
import '../iap/phale_products.dart';
import 'account_prefs.dart';
import 'avatar_frames.dart';
import 'gacha.dart';
import 'season_pass_controller.dart';
import 'vip.dart';
import 'bouquet.dart';
import 'garden.dart';
import 'cloud_merge.dart';
import 'customers.dart';
import 'delivery.dart';
import 'format.dart';
import 'goals.dart';
import 'install_offer.dart';
import 'charm_rewards.dart';
import 'mailbox.dart' show MailClaimResult;
import 'market_prices.dart';
import 'match_scoring.dart';
import 'payment.dart';
import 'pet.dart';
import 'pet_item_room.dart';
import 'pot_bonus.dart';
import 'pha_le_exchange.dart';
import 'phale_shop_controller.dart';
import 'play_analytics.dart';
import 'price_format.dart';
import 'profile_report.dart';
import 'rating.dart';
import 'regulars.dart';
import 'review_picker.dart';
import 'rewarded_ad.dart';
import 'rewards.dart';
import 'shop_name.dart';
import 'stable_hash.dart';
import 'platform_flags.dart';
import 'supporters.dart';
import 'upgrades.dart';
import '../data/weather.dart';
import 'wallet.dart';
import 'weather.dart';
import 'world_chat.dart';
import 'xu_grant.dart';

part 'delivery_runtime.dart';
part 'shop_events.dart';
part 'hoa_sap_heo.dart';
part 'pot_shop.dart';
part 'skin_shop.dart';

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
  potShop,
  potBook,
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

/// Sổ tay khách quen opens (spec §1): once, at the day's summary.
class NotebookPopup extends GamePopup {
  const NotebookPopup();
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
    this.regularId,
    this.regularStep,
    this.regularRetry = false,
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

  /// Sổ tay khách quen: the regular's id ([RegularDef.id]); null = stranger.
  final String? regularId;

  /// The story step this visit plays; null = a casual visit.
  final int? regularStep;

  /// This story step failed before: `bonusExtra.retryHintMatchBonus` applies.
  final bool regularRetry;

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

/// What a tap on a pet did in the slot picker.
/// What [ShopSession.wearPetItem] did.
enum PetItemResult { worn, already, notOwned, unknownItem, noneLeft }

/// What [ShopSession.buyPetItem] and [ShopSession.sellPetItem] did.
enum PetItemTrade {
  bought,
  sold,
  unknownItem,

  /// Not enough xu or Pha lê.
  short,

  /// The shop is serving customers (closed hours only, like the pet shop).
  shopOpen,

  /// Buying: 99 copies already. Selling: no copy left to sell.
  noCopies,

  /// Selling: every copy is on a pet; take one off first.
  allWorn,
}

enum PetSlotResult { placed, already, pickSlot, notOwned }

class PetSlotPlacement {
  const PetSlotPlacement(this.result, {this.slot});

  final PetSlotResult result;

  /// The slot that was filled (or already held the pet).
  final String? slot;
}

/// The whole game model: day loop, queue, stock, bouquet, reviews, save.
///
/// Pure Dart + [ChangeNotifier]; the Flame game calls [tick] every frame and
/// Flutter widgets listen to it.
class ShopSession extends ChangeNotifier implements NoticeAccount {
  ShopSession({
    required this.data,
    required ProgressStore store,
    GameState? saved,
    Random? random,
    SupporterSource? supporters,
    SupporterAdmin? supporterAdmin,
    PlayerDirectory? playerDirectory,
    this.charmBoard,
    this.ratingBoardSource,
    this.reports,
    this.worldChatSource,
    this.avatarFrameSource,
    this.vipSource,
    this.gachaHistory,
    this.seasonPassSource,
    this.accountPrefsSource,
    AccountGateway? account,
    Sounds? sounds,
    this.terms,
    String? tabId,
    DateTime Function()? now,
    AccountProfile? lastAccount,
    bool guestSaves = false,
    bool guestBannerDismissed = false,
    bool installOfferSeen = false,
    Future<void> Function(int attempt)? retryWait,
    int Function()? newSaveSeed,
  }) : _store = store,
       _newSaveSeed = newSaveSeed ?? _randomSaveSeed,
       _guestBannerDismissed = guestBannerDismissed,
       _installOfferSeen = installOfferSeen,
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
    final seeded = _fitSaveSeed();
    _fitLifetimeGreat();
    _fitGardenPlots();
    _fitPetHome();
    this.sounds.musicOn = state.musicOn;
    this.sounds.effectsOn = state.sfxOn;
    _armGoals();
    final filledReplies = _fillMissingCustomerReplies();
    _checkpoint = state.encode();
    if ((filledReplies || seeded) && hasSave) {
      final copy = GameState.decode(_checkpoint);
      if (copy != null) _saveLocal(copy);
    }
    _resumeScreen();
  }

  final Sounds sounds;

  /// Makes [GameState.saveSeed] for a new game. Not [rng], so a new save
  /// does not shift the day's dice.
  final int Function() _newSaveSeed;

  static int _randomSaveSeed() => Random().nextInt(0x7fffffff) + 1;

  /// An old save without [GameState.saveSeed] gets one that only depends on
  /// the save itself, so reloading before the next save keeps the same
  /// prices. True when it was added.
  bool _fitSaveSeed() {
    if (state.saveSeed != 0) return false;
    final h = fnv1a32(
      'saveSeed|${state.accountUid ?? ''}|${state.shopName ?? ''}|'
      '${state.day}|${state.money}|${state.lifetimeBouquetsSold}',
    );
    state.saveSeed = h == 0 ? 1 : h;
    return true;
  }

  /// Where the Mị lực board lives (null offline and in most tests).
  final CharmBoardSource? charmBoard;

  /// Where Bảng xếp hạng Đánh giá is read (null offline and in most tests).
  final RatingBoardSource? ratingBoardSource;

  /// Where profile reports go (null offline and in most tests).
  final ProfileReports? reports;

  /// Where Tin thế giới lives (null offline and in most tests).
  final WorldChatSource? worldChatSource;

  /// Where avatar frames live (null offline and in most tests).
  final AvatarFrameSource? avatarFrameSource;

  /// Where the VIP hall and its switch live (null offline and in most tests).
  final VipSource? vipSource;

  /// VIP (spec 4): the tier from the server wallet, the VIP screen, the
  /// level-up popup.
  late final VipController vip = VipController(this, source: vipSource);

  /// Where Lịch sử quay is read (the wallet ledger; null offline / tests).
  final GachaHistorySource? gachaHistory;

  /// Vòng quay tuần (task 8): the week's pot, cards, pity, buy and spin.
  late final GachaController gacha = GachaController(
    this,
    history: gachaHistory,
  );

  /// Where the Season Pass is read (Firestore; null offline / tests).
  final SeasonPassSource? seasonPassSource;

  /// Season Pass: the server's season doc, claims and the premium purchase.
  late final SeasonPassController seasonPass = SeasonPassController(
    config: e.seasonPass,
    clock: e.charmBoard.clock,
    source: seasonPassSource,
    uid: () => accountUid,
    api: () => signedIn ? walletApi : null,
    now: _now,
    onSkins: addServerSkins,
  );

  /// The Season Pass screen is up (over the shop, like the notebook).
  bool seasonPassShown = false;

  void openSeasonPass() {
    if (seasonPassShown) return;
    seasonPassShown = true;
    unawaited(seasonPass.load());
    sounds.effect('popup_open');
    _changed();
  }

  void closeSeasonPass() {
    if (!seasonPassShown) return;
    seasonPassShown = false;
    sounds.effect('popup_close');
    _changed();
  }

  /// The session clock (tests pass one).
  DateTime clockNow() => _now();

  /// Sets a one-time flag in the save now and in the morning copy.
  void editSave(void Function(GameState st) edit) {
    edit(state);
    _patchMorning(edit);
    _changed();
  }

  /// Where the per-account block list and chat "rules accepted" live
  /// (player_prefs/{uid}; null offline and in most tests = on the device).
  final AccountPrefsSource? accountPrefsSource;

  late final AccountPrefsController prefs = AccountPrefsController(
    this,
    source: accountPrefsSource,
  );

  /// The device store (account_prefs.dart reads the old device lists).
  ProgressStore get progressStore => _store;

  /// Khung avatar (spec 3): what this player owns and wears, other
  /// players' frames, the picker sheet.
  late final AvatarFramesController frames = AvatarFramesController(
    this,
    source: avatarFrameSource,
    now: _now,
  );

  /// Tin thế giới (spec 5): messages, sending, report and block.
  late final WorldChatController chat = WorldChatController(
    this,
    source: worldChatSource,
    now: _now,
  );

  /// The Mị lực board: reading, publishing, where this player stands.
  late final CharmBoardController board = CharmBoardController(
    this,
    source: charmBoard,
    now: _now,
  );

  /// Bảng xếp hạng Đánh giá, the second tab of the board screen (read only).
  late final RatingBoardController ratingBoard = RatingBoardController(
    this,
    source: ratingBoardSource,
    now: _now,
  );

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

  /// The player closed the guest strip with its X (kept on this device).
  bool _guestBannerDismissed;

  /// The one-time "cài game về máy" card. Web only.
  bool _installOfferSeen;
  bool installOfferOpen = false;

  /// Amber strip under the coin bar while playing as a guest. Hidden for
  /// good on this device once the player closes it.
  bool get showGuestBanner =>
      cloudAccountOffered &&
      !signedIn &&
      !accountOpening &&
      !_guestBannerDismissed;

  /// X on the guest strip: hides it now and remembers it on this device.
  void dismissGuestBanner() {
    if (_guestBannerDismissed) return;
    _guestBannerDismissed = true;
    _pendingSaves = _pendingSaves.then(
      (_) => _store.saveGuestBannerDismissed(),
    );
    notifyListeners();
  }

  /// Summary of day 1, 3, 5, 7 or 9, or entering a shop already on day 2+.
  void considerInstallOffer() {
    if (installOfferOpen ||
        !installOfferDue(
          web: kIsWeb,
          installed: homeScreenInstalled,
          alreadySeen: _installOfferSeen,
          day: state.day,
          dayJustEnded: state.phase == DayPhase.summary,
        )) {
      return;
    }
    _installOfferSeen = true;
    installOfferOpen = true;
    _pendingSaves = _pendingSaves.then((_) => _store.saveInstallOfferSeen());
    _changed();
  }

  void closeInstallOffer() {
    if (!installOfferOpen) return;
    installOfferOpen = false;
    _changed();
  }

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

  /// Hồ sơ tiệm of your own shop, opened from the HUD avatar (Phú spec 1);
  /// the day clock waits while it is open, like Cài đặt.
  bool ownProfileOpen = false;

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

  @override
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

  /// Hoa sắp héo: today's clearance buyers (shop clock seconds).
  bool _clearanceRolled = false;
  List<double> _clearanceBuyers = [];

  /// Hoa khô: today's "Kệ hoa khô" buyers (shop clock seconds).
  bool _shelfRolled = false;
  List<double> _shelfBuyers = [];

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

  /// Stats of the pots on the bar and the display shelf (`pots[].stats`,
  /// summed). Pots in the cupboard add nothing.
  PotShelfStats get potShelf => potShelfStats(e, state);

  /// Owns a pot that pays money at close (income, tip or online-order
  /// stat) but none of them sits on the shelf: the day summary shows
  /// `summary.pot_bonus.empty`.
  bool get ownsStatPot {
    const money = [
      PotStat.incomeBonus,
      PotStat.tipBonus,
      PotStat.onlineOrderBonus,
    ];
    final shelf = potShelf;
    if (shelf.incomeBonus + shelf.tipBonus + shelf.onlineOrderBonus > 0) {
      return false;
    }
    return e.pots.any(
      (p) =>
          (state.potCounts[p.id] ?? 0) > 0 &&
          money.any((k) => (p.stats[k] ?? 0) > 0),
    );
  }

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

  // -- Thời tiết (thoi_tiet_block.json) ------------------------------------

  WeatherRules get weatherRules => data.weather;

  /// [day]'s weather for this save: hash(saveSeed, day, 'weather'), so a
  /// reload or a replayed morning never re-rolls. Null when off.
  WeatherType? weatherOn(int day) => weatherRules.pick(state.saveSeed, day);

  WeatherType? get weatherToday => weatherOn(state.day);

  /// Today's clamped multiplier for [key] ([WeatherFactor]).
  double weatherFactor(String key) => weatherRules.factor(weatherToday, key);

  /// Today's tallies for the end-of-day weather lines.
  WeatherDay weatherDay = WeatherDay();

  /// The shop-open banner text while it shows (`hienThi.banner*`).
  String? weatherBanner;
  double _weatherBannerLeft = 0;

  String flowerNameVi(String id) {
    for (final f in e.flowers) {
      if (f.id == id) return f.nameVi;
    }
    return id;
  }

  /// `{anhHuong}` for today.
  String weatherEffectToday() {
    final t = weatherToday;
    if (t == null) return '';
    return weatherEffectText(weatherRules, t, owned, flowerNameVi);
  }

  /// Tonight's freshness change from today's weather.
  NightWilt get weatherNight => nightWilt(
    weatherFactor(WeatherFactor.wilt),
    state.freshnessDebt,
    state.saveSeed,
    state.day,
  );

  /// The end-of-day weather lines (weather_summary_*), empty when off.
  List<String> weatherSummary() {
    final t = weatherToday;
    if (t == null) return const [];
    var stems = 0;
    for (final b in state.stock) {
      stems += b.count;
    }
    return weatherSummaryLines(
      weatherRules,
      t,
      weatherDay,
      night: weatherNight,
      stemsInStock: stems,
      owned: owned,
      name: flowerNameVi,
    );
  }

  /// Species weights for a walk-in's order (`apply.demandBoost`).
  Map<String, double>? get _weatherBoost {
    final t = weatherToday;
    if (t == null || t.boostFlowers.isEmpty) return null;
    return {for (final id in t.boostFlowers) id: t.speciesWeight};
  }

  void setWeatherFxOff(bool off) {
    if (state.weatherFxOff == off) return;
    state.weatherFxOff = off;
    sounds.effect('toggle');
    _patchMorning((cp) => cp.weatherFxOff = off);
    _changed();
  }

  void _showWeatherBanner() {
    final t = weatherToday;
    final h = weatherRules.display;
    if (t == null || (t.isNormal && h.hideOnNormal)) return;
    if (weatherDay.bannersShown >= h.bannerPerDay) return;
    final text = weatherRules.t('weather_banner_${t.id}');
    if (text.isEmpty) return;
    weatherDay.bannersShown++;
    weatherBanner = text;
    _weatherBannerLeft = h.bannerSeconds;
  }

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
      saveSeed: _newSaveSeed(),
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
    weatherDay = WeatherDay();
    weatherBanner = null;
    _weatherBannerLeft = 0;
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
    resetWiltingDay(this);
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

  // -- removed Tin tức (kept in the account's save) ------------------------

  /// Notice ids this account removed, on any device.
  @override
  Set<String> get hiddenNotices => {...state.hiddenNotices};

  @override
  int get hiddenNoticeCount => state.hiddenNotices.length;

  /// Remembers [ids] as removed in the save, so they stay removed on every
  /// device of the account. Saved like the other settings (morning save and
  /// cloud). Only a signed-in game has a save, a guest keeps them in memory.
  @override
  void hideNotices(Iterable<String> ids) {
    final fresh = [
      for (final id in ids)
        if (id.isNotEmpty && !state.hiddenNotices.contains(id)) id,
    ];
    if (fresh.isEmpty) return;
    state.hiddenNotices = lastHiddenNotices([...state.hiddenNotices, ...fresh]);
    _patchMorning((cp) {
      cp.hiddenNotices = lastHiddenNotices([...cp.hiddenNotices, ...fresh]);
    });
  }

  /// After a morning was picked: the removed notices of the cloud copy, of this
  /// device's copy and of what was in memory are all kept (they only grow).
  /// True when the cloud copy lacks some, so it needs an upload.
  bool _mergeHiddenNotices({
    required GameState? cloud,
    required List<String> others,
  }) {
    final inCloud = {...?cloud?.hiddenNotices};
    final merged = lastHiddenNotices([
      ...?cloud?.hiddenNotices,
      ...others,
      ...state.hiddenNotices,
    ]);
    final have = {...state.hiddenNotices};
    if (merged.length != have.length || !merged.every(have.contains)) {
      state.hiddenNotices = merged;
      _patchMorning((cp) => cp.hiddenNotices = merged);
    }
    return merged.any((id) => !inCloud.contains(id));
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
    if (!data.wordFilter.allowsShopName(name)) {
      nameError = shopNameRefused;
      sounds.effect('error');
      _changed();
      return false;
    }
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
    considerInstallOffer();
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
    // Hồ sơ and Cài đặt never stack (Phú spec 4).
    ownProfileOpen = false;
    avatarPickerOpen = false;
    sounds.effect('popup_open');
    _changed();
  }

  void resumeFromPause() {
    paused = false;
    pauseMenuOpen = false;
    ownProfileOpen = false;
    avatarPickerOpen = false;
    tutorialViewStep = 0;
    sounds.effect('popup_close');
    _changed();
  }

  /// HUD avatar: your Hồ sơ when signed in; signed out it opens Cài đặt,
  /// where the sign-in buttons are (the profile lives on the account).
  void openOwnProfile() {
    if (!signedIn) {
      openPause();
      return;
    }
    paused = true;
    pauseMenuOpen = false;
    ownProfileOpen = true;
    sounds.effect('popup_open');
    _changed();
  }

  void closeOwnProfile() {
    if (!ownProfileOpen) return;
    ownProfileOpen = false;
    avatarPickerOpen = false;
    paused = false;
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

  void setGachaIconHidden(bool hidden) {
    if (state.gachaIconHidden == hidden) return;
    state.gachaIconHidden = hidden;
    sounds.effect('toggle');
    _patchMorning((cp) => cp.gachaIconHidden = hidden);
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

  /// The portrait other players see on the public boards (Mị lực, supporters):
  /// the same pointer `player_avatars/{uid}.path` keeps. A preset is its id; an
  /// uploaded photo is its public URL with the revision (so a new upload shows
  /// at once); the Google photo is its URL; '' while that is not known.
  String get publishedAvatar {
    final id = state.ownerAvatar;
    if (id == 'google') return accountPhotoUrl ?? '';
    if (isUploadedAvatar(id)) {
      final rev = state.ownerAvatarRev;
      return storageAvatarUrl(id, rev: rev > 0 ? rev : null) ?? id;
    }
    return id;
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
    if (!data.wordFilter.allowsShopName(name)) return;
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

  /// iOS shows Apple and Google together (guideline 4.8). Other platforms
  /// go straight to Google.
  bool signInChooserOpen = false;

  Future<void> signIn() async {
    if (!cloudAccountOffered) return;
    if (isIosApp) {
      if (authBusy || _joining || signedIn) return;
      signInChooserOpen = true;
      _changed();
      return;
    }
    await signInWithGoogle();
  }

  void closeSignInChooser() {
    if (!signInChooserOpen) return;
    signInChooserOpen = false;
    _changed();
  }

  Future<void> signInWithGoogle() => _signInAccount(account.signIn);

  Future<void> signInWithApple() =>
      _signInAccount(account.signInWithApple, quietCancel: true);

  Future<void> _signInAccount(
    Future<AccountProfile?> Function() request, {
    bool quietCancel = false,
  }) async {
    if (authBusy || _joining) return;
    closeSignInChooser();
    _joining = true;
    authBusy = true;
    authError = null;
    accountNotice = null;
    seatLost = false;
    _changed();
    try {
      await account.useLastingLogin();
      final profile = await request();
      if (profile == null) {
        if (!quietCancel) {
          authError = 'Chưa đăng nhập được, thử lại nhé.';
          sounds.effect('error');
        }
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
    // The morning below is ONE of cached / cloud, so the removed notices of the
    // other would be lost with it: they are merged back after the pick.
    final hiddenBefore = [...state.hiddenNotices];
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
    final hiddenToUpload = _mergeHiddenNotices(
      cloud: cloud?.state,
      others: [...?cached?.hiddenNotices, ...hiddenBefore],
    );
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
    if (hiddenToUpload && hasSave) {
      final copy = GameState.decode(_checkpoint);
      if (copy != null) _pushCloud(copy);
    }
    _syncProfile();
    _avatarRestore = _restoreOrPublishAvatar();
    accountNotice = announce ? notice : null;
    // The server wallet first, so its one-time seed reads the cloud save
    // before any gift below adds Pha lê.
    await syncWallet();
    if (hasSave) {
      await _applyCloudGrant();
      await _applyCloudGift();
    }
    await _claimHeldShopName();
    // An App Store purchase paid while signed out (or before a crash) is
    // credited to the account that just opened.
    unawaited(drainApplePurchases());
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
    final changed = accountUid != profile.uid;
    accountUid = profile.uid;
    accountEmail = profile.email;
    accountName = profile.name;
    accountPhotoUrl = profile.photoUrl;
    authError = null;
    if (changed) {
      unawaited(frames.refresh());
      unawaited(prefs.switchTo(profile.uid));
    }
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
    _fitSaveSeed();
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

  // -- Xóa tài khoản và dữ liệu (chu_ung_dung_v1.md §1-4) ---------------------

  /// The confirmation dialog is open, over Cài đặt.
  bool deleteAccountOpen = false;

  /// The server call is running: no button works and the dialog stays.
  bool deleteBusy = false;

  /// Why the last try did not finish; null while nothing failed.
  DeleteFailure? deleteFailure;

  /// The account is gone and this device is cleaned: "Đã xóa xong".
  bool deleteDone = false;

  /// A `partial` failure: the server deleted only part of it, so nothing may
  /// write the account again. The player retries, emails, or closes (which
  /// signs out).
  bool _deleteHalf = false;

  /// Opens the confirmation. Only a signed-in player has anything to delete.
  void openDeleteAccount() {
    if (!signedIn || deleteBusy || _leaving) return;
    deleteAccountOpen = true;
    deleteFailure = null;
    _changed();
  }

  /// "Giữ tài khoản". Not while the call runs. After a half-done deletion the
  /// account cannot be played any more, so closing signs out.
  void closeDeleteAccount() {
    if (deleteBusy) return;
    final half = _deleteHalf;
    deleteAccountOpen = false;
    deleteFailure = null;
    _deleteHalf = false;
    _changed();
    if (half) signOut();
  }

  void closeDeleteDone() {
    if (!deleteDone) return;
    deleteDone = false;
    _changed();
  }

  /// Deletes the signed-in account on the server, then signs out, clears this
  /// device's copy and goes back to the title. Returns null on success, else
  /// the failure (also in [deleteFailure]). Safe to call again after a failure.
  Future<DeleteFailure?> deleteAccount() async {
    if (!signedIn || deleteBusy || _leaving) return DeleteFailure.generic;
    final uid = accountUid!;
    deleteBusy = true;
    deleteFailure = null;
    // Nothing may write the account while it is being deleted, or it would
    // come back: the save, the board row, the portrait, the seat.
    final hadUploads = _uploads;
    _uploads = false;
    _discardLocal = true;
    _seatEpoch++;
    account.stopWatchingSeat();
    account.bindSeat(null);
    _changed();
    DeleteFailure? failure;
    try {
      // Writes already on their way land before the delete, not after it.
      for (final pending in [_pendingSaves, _avatarWrites]) {
        try {
          await pending.timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
      await account.deleteAccount();
    } on DeleteAccountException catch (e) {
      failure = e.failure;
    } catch (_) {
      failure = DeleteFailure.generic;
    }
    if (failure == null) {
      await _leaveAccount(release: false);
      try {
        await _store.removeAccount(uid);
      } catch (_) {}
      deleteBusy = false;
      _deleteHalf = false;
      deleteAccountOpen = false;
      deleteDone = true;
      _changed();
      return null;
    }
    deleteBusy = false;
    deleteFailure = failure;
    if (failure == DeleteFailure.partial) {
      _deleteHalf = true;
    } else {
      // Nothing was deleted (or we cannot tell): the account plays on.
      _uploads = hadUploads;
      _discardLocal = false;
      account.bindSeat(tabId);
      account.watchSeat(_onSeat);
    }
    sounds.effect('error');
    _changed();
    return failure;
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
    frames.reset();
    vip.reset();
    unawaited(prefs.switchTo(null));
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
    board.dispose();
    ratingBoard.dispose();
    chat.dispose();
    frames.dispose();
    super.dispose();
  }

  /// Installs [cloud] as the morning. An uploaded photo on [cached], this
  /// account's own copy on this device, is kept. Nothing is uploaded here:
  /// the cloud is written by the next save while playing.
  Future<void> _adoptCloud(CloudRecord cloud, GameState? cached) async {
    final cloudAvatar = cloud.state.ownerAvatar;
    state = cloud.state;
    keepUploadedAvatar(state, cached);
    _fitSaveSeed();
    _fitLifetimeGreat();
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
    int? rank,
  }) {
    final granted = applyRewards(state, bundle, economy: e).granted;
    // A pet item from the season reward (with the player's [rank]) or from a
    // mystery visitor gets its receipt popup (P4); other sources just fill
    // the store room.
    if (source == RewardSource.mysteryCustomer ||
        (source == RewardSource.mailbox && rank != null)) {
      for (final item in granted.items) {
        if (item.kind != RewardKind.petItem || item.id == null) continue;
        petItemGifts.add(
          PetItemGift(
            itemId: item.id!,
            kind: source == RewardSource.mailbox
                ? PetItemGiftKind.rank
                : PetItemGiftKind.mystery,
            rank: rank,
            extras: [
              for (final x in granted.items)
                if (x.kind != RewardKind.petItem) x,
            ],
          ),
        );
      }
    }
    mark?.call(state);
    if (source.persistNow) {
      _patchMorning((cp) {
        applyRewards(cp, granted, economy: e);
        mark?.call(cp);
      });
      _changed();
    }
    // Pha lê (and gift cards) from a gift the app opened itself: the server
    // checks it and credits the wallet; the local add above is only shown
    // until the answer replaces it. Mailbox gifts are credited by
    // walletClaimMail before [grantRewards] runs.
    final earn = _walletEarnSource(source);
    if (earn != null &&
        usesServerWallet &&
        (granted.amountOf(RewardKind.phaLe) > 0 ||
            granted.amountOf(RewardKind.ticket) > 0)) {
      unawaited(walletEarn(earn));
    }
    return granted;
  }

  static String? _walletEarnSource(RewardSource source) => switch (source) {
    RewardSource.loginReward => 'login',
    RewardSource.rewardedAd => 'ad',
    RewardSource.giftcode => 'giftcode',
    RewardSource.adminGift => 'adminGift',
    _ => null,
  };

  // ---- server wallet (functions/wallet.js) --------------------------------

  /// The wallet callables. Null (tests, no Firebase): Pha lê stays local,
  /// as before the server wallet.
  WalletApi? walletApi;

  /// What the server last said: Pha lê, Thẻ gacha per pot, pity, week.
  WalletView? wallet;

  /// Signed in with a wallet API: every Pha lê spend goes to the server.
  bool get usesServerWallet => walletApi != null && signedIn;

  /// Calls one wallet function and shows the balance it returns. Throws
  /// [WalletException]; any failure also re-reads the wallet.
  Future<Map<String, Object?>> _walletCall(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    final api = walletApi;
    if (api == null || !signedIn) {
      throw const WalletException('sign-in-required');
    }
    try {
      final raw = await api.call(name, data);
      _applyWallet(WalletView.fromJson(raw));
      return raw;
    } on WalletException {
      if (name != 'walletSync') unawaited(syncWallet());
      rethrow;
    }
  }

  /// The save's Pha lê becomes the server's balance (day + morning copy).
  void _applyWallet(WalletView view) {
    // A call that came back without VIP (an older server) keeps the last one.
    wallet = view.vip == null && wallet?.vip != null
        ? view.withVip(wallet!.vip!)
        : view;
    unawaited(vip.onStatus(wallet!.vip));
    _dropLockedVipPots();
    if (state.phaLe != view.phaLe) {
      state.phaLe = view.phaLe;
      _patchMorning((cp) => cp.phaLe = view.phaLe);
    }
    _changed();
  }

  /// The VIP status a VIP call answered (vipHallHide), into [wallet].
  void applyVipStatus(VipStatus v) {
    final w = wallet;
    if (w == null) return;
    wallet = w.withVip(v);
    _dropLockedVipPots();
    _changed();
  }

  /// Reads the wallet (the first call seeds it from the cloud save).
  /// Errors are swallowed: the next call tries again.
  Future<WalletView?> syncWallet() async {
    if (!usesServerWallet) return null;
    try {
      await _walletCall('walletSync', {'gameDay': state.day});
    } catch (_) {}
    // The shop bar's Season Pass button and its dot follow the server doc.
    if (seasonPassSource != null) unawaited(seasonPass.load());
    return wallet;
  }

  /// Asks the server to credit what the app just granted itself ([source]
  /// of functions/wallet.js earn: login, ad, giftcode, adminGift,
  /// collection, resale). A refusal leaves the server balance.
  Future<void> walletEarn(String source, {String? ref}) async {
    if (!usesServerWallet) return;
    try {
      await _walletCall('walletEarn', {'source': source, 'ref': ?ref});
    } catch (_) {}
  }

  /// Hộp thư claim of a mail with Pha lê or Thẻ gacha: the server flips the
  /// claimed mark and credits the wallet in one transaction; then [grant]
  /// adds the rest of the gift to the save.
  Future<MailClaimResult> walletClaimMail(
    String mailId,
    void Function() grant,
  ) async {
    try {
      final raw = await _walletCall('walletClaimMail', {'mailId': mailId});
      if (raw['status'] == 'already') return MailClaimResult.already;
      final before = wallet;
      grant();
      // grant() added the Pha lê locally once more: the server number wins.
      if (before != null) _applyWallet(before);
      return MailClaimResult.claimed;
    } on WalletException catch (e) {
      return switch (e.code) {
        'already' => MailClaimResult.already,
        'expired' || 'missing' || 'not-yours' => MailClaimResult.refused,
        _ => MailClaimResult.failed,
      };
    }
  }

  /// Pays [price] Pha lê for one shop item on the server, then runs [local]
  /// (the old local purchase, which takes the same price from the save).
  Future<bool> _payPhaLe(
    String kind,
    String id,
    int price,
    bool Function() local,
  ) async {
    if (state.phaLe < price) return false;
    final WalletView paid;
    try {
      await _walletCall('phaleBuy', {'kind': kind, 'id': id});
      paid = wallet!;
    } catch (_) {
      return false;
    }
    state.phaLe = paid.phaLe + price;
    final ok = local();
    _applyWallet(paid);
    return ok;
  }

  /// Records one xu pet or pet item on the server (coinBuy: the server takes
  /// the price from the save it last checked, so Mị lực can count it), then
  /// runs [local], which takes the same xu from the save. A refusal buys
  /// nothing.
  Future<bool> _payCoins(String kind, String id, bool Function() local) async {
    try {
      await _walletCall('coinBuy', {'kind': kind, 'id': id});
    } catch (_) {
      return false;
    }
    return local();
  }

  /// [buyPot] with a Pha lê pot paid on the server first.
  Future<bool> buyPotPaid(String id) async {
    final pot = e.pot(id);
    if (!pot.paysPhaLe || !usesServerWallet) return buyPot(id);
    if (!pot.purchasable) return false;
    return _payPhaLe('pot', id, pot.cost, () => buyPot(id));
  }

  /// [buyPet] paid on the server first: Pha lê (phaleBuy) or xu (coinBuy).
  Future<bool> buyPetPaid(String id) async {
    final pet = e.pet(id);
    if (pet == null || !usesServerWallet) return buyPet(id);
    if (!petShopOpen || state.ownsPet(id) || petShortfall(pet) > 0) {
      return false;
    }
    if (!pet.paysPhaLe) return _payCoins('pet', id, () => buyPet(id));
    return _payPhaLe('pet', id, pet.price, () => buyPet(id));
  }

  /// [confirmPetItemBuy] paid on the server first: Pha lê or xu (coinBuy).
  Future<PetItemTrade> confirmPetItemBuyPaid() async {
    final id = petItemBuyId;
    final def = id == null ? null : e.petItem(id);
    if (def == null || !usesServerWallet) {
      return confirmPetItemBuy();
    }
    if (!petShopOpen) return confirmPetItemBuy();
    if (petItemOwned(id!) >= maxGiftCount || petItemShortfall(def) > 0) {
      return confirmPetItemBuy();
    }
    var res = PetItemTrade.short;
    bool local() {
      petItemBuyId = id;
      res = confirmPetItemBuy();
      return res == PetItemTrade.bought;
    }

    if (def.paysPhaLe) {
      await _payPhaLe('petItem', id, def.price, local);
    } else {
      await _payCoins('petItem', id, local);
    }
    petItemBuyId = null;
    _changed();
    return res;
  }

  /// [exchangePhaLeForXuShort] with the Pha lê taken on the server first.
  Future<bool> exchangePhaLeForXuShortPaid() async {
    if (!usesServerWallet) return exchangePhaLeForXuShort();
    final short = xuShort;
    if (short == null || short.need <= 0) return false;
    final cost = phaLeCostForMissingXu(short.need);
    if (state.phaLe < cost) return false;
    try {
      await _walletCall('phaleExchange', {
        'packs': exchangePacksForMissingXu(short.need),
      });
    } catch (_) {
      return false;
    }
    final paid = wallet!;
    state.phaLe = paid.phaLe + cost;
    final ok = exchangePhaLeForXuShort();
    _applyWallet(paid);
    return ok;
  }

  /// Buys [count] Thẻ gacha of this week's pot (gachaBuyCards). With Pha
  /// lê the server checks and takes it. With xu the price follows the game
  /// day and the xu comes out of the save here: xu is not on the server, so
  /// only the daily cap (`gacha.ticketPrice.maxCoinTicketsPerDay`) is
  /// enforced there. Throws [WalletException] (`limit`, `balance`, ...).
  Future<WalletView> buyGachaCards({
    required int count,
    required bool withPhaLe,
  }) async {
    if (!usesServerWallet) throw const WalletException('sign-in-required');
    final day = state.day;
    if (!withPhaLe) {
      final cost = e.gacha.ticketCoinsOnDay(day) * count;
      if (cost <= 0) throw const WalletException('bad');
      if (state.money < cost) throw const WalletException('balance');
    }
    final raw = await _walletCall('gachaBuyCards', {
      'currency': withPhaLe ? 'phaLe' : 'coins',
      'count': count,
      'gameDay': day,
    });
    final paid = raw['paid'];
    final coins = paid is Map && paid['coins'] is num
        ? (paid['coins'] as num).toInt()
        : 0;
    if (coins > 0) {
      state.money -= coins;
      _patchMorning((cp) {
        cp.money -= coins;
        if (cp.money < 0) cp.money = 0;
      });
      _changed();
    }
    return wallet!;
  }

  /// Spins [count] (1 or 10) cards of this week's pot (gachaSpin). The
  /// rewards arrive as one Hộp thư mail; returns the server's answer
  /// (`results`, `mailId`, `resetFrom`, the wallet). UI is task 8.
  Future<Map<String, Object?>> spinGacha({int count = 1}) =>
      _walletCall('gachaSpin', {'count': count});

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
    if (!supportersEnabled) return; // hidden, see platform_flags.dart
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

  /// Holiday for the market poster: (holiday, days until). On a holiday
  /// the days still to come of that same holiday are not "upcoming"; Tết
  /// keeps its poster on its own days with 0 = mùng 1, -1 = mùng 2, ...
  (HolidayDef, int)? get posterHoliday {
    final today = holidayToday;
    if (today != null) {
      if (today.id == 'tet') {
        return (today, -e.holidayOffsetFor(today, state.day));
      }
    }
    final next = e.upcomingHoliday(state.day, e.posterDaysBefore);
    if (next != null && identical(next.$1, today)) return null;
    return next;
  }

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

  /// Market price of one bundle today, less the shelf's `marketDiscount`.
  int bundlePrice(FlowerDef f) {
    final base = marketBundlePrice(
      e,
      f,
      state.day,
      state.saveSeed,
      weather: weatherFactor(WeatherFactor.market),
    );
    final off = potShelf.marketDiscount;
    if (off <= 0) return base;
    return (base * (1 - off.clamp(0.0, 1.0))).round();
  }

  /// Today's market price against yesterday's; null on day 1.
  PriceChange? priceChange(FlowerDef f) => priceChangeFromYesterday(
    e,
    f,
    state.day,
    state.saveSeed,
    weather: (d) => weatherRules.factor(weatherOn(d), WeatherFactor.market),
  );

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
        weatherFactor(WeatherFactor.customer) *
        e.preHolidayCustomerFactor(state.day) *
        priceCustomerFactor(e, priceMultiplier);
  }

  void openShop() {
    if (state.phase != DayPhase.preparing) return;
    pendingPlacePotId = null;
    pendingPlaceBar = null;
    cancelUnboughtPreorders(this);
    state.phase = DayPhase.open;
    state.elapsed = 0;
    ratingBoard.dayOpened();
    dispatchPacked(this, 0);
    state.pendingArrivals = scheduleArrivals(
      e,
      poisson(expectedCustomers, rng),
      rng,
    );
    _planRegulars(state.pendingArrivals.length);
    _showWeatherBanner();
    sounds.effect('shop_open');
    // Day 10, 20, 30…; other days the income-slot pet may bring one. No
    // roll without such a pet, so the day's dice stay as they were.
    // Pots on the shelf add `mysteryChance` (absolute).
    final mysteryOdds = petEffects.mysteryChance + potShelf.mysteryChance;
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
    if (_weatherBannerLeft > 0) {
      _weatherBannerLeft -= dt;
      if (_weatherBannerLeft <= 0) {
        weatherBanner = null;
        structural = true;
      }
    }
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
        if (tickClearance(this)) structural = true;
        if (tickDriedShelf(this)) structural = true;
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
    if (!tutorial && !mysterious && _spawnRegular()) {
      weatherDay.customers++;
      weatherDay.lastHadLine = false;
      return;
    }
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
            speciesBoost: _weatherBoost,
          );
    if (request == null) return;
    if (mysterious) _mysteryLeft = false;
    weatherDay.customers++;
    final weatherLine = tutorial || mysterious
        ? null
        : pickWeatherLine(
            weatherRules,
            weatherToday,
            weatherDay,
            rng,
            requested: request.stems.keys,
            name: flowerNameVi,
          );
    final line =
        weatherLine ??
        pickOrderLine(
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
            (1 + petEffects.patienceBonus + potShelf.patienceBonus) *
            pricePatienceFactor(e, priceMultiplier),
        walkIn: e.walkInSeconds,
        mysterious: mysterious,
      )..patienceLocked = tutorial,
    );
  }

  // -- Sổ tay khách quen (khach_quen_block.json) --------------------------

  RegularsCatalog get regulars => data.regulars;

  /// Arrival index (0-based, strangers and regulars) to today's regular.
  final Map<int, PlannedRegular> _regularAt = {};
  int _arrivalIndex = 0;

  bool get notebookUnlocked =>
      notebookOpen(regulars, day: state.day, great: state.lifetimeGreat);

  RegularProgress regularProgress(String id) =>
      state.regulars.putIfAbsent(id, RegularProgress.new);

  /// A save from before the notebook has no `lifetimeGreat`
  /// (`bonusExtra.lifetimeGreatMigration`): the save keeps no per-day
  /// greatCount history (only today's metrics), so it gets the block's number.
  void _fitLifetimeGreat() {
    if (!state.lifetimeGreatMissing) return;
    state.lifetimeGreatMissing = false;
    state.lifetimeGreat = max(
      state.lifetimeGreat,
      regulars.lifetimeGreatForOldSaves,
    );
  }

  /// Bonus of a regular's visit (`bonusExtra`); none for a stranger.
  ({double match, double tipMult}) regularBonusFor(Customer c) =>
      c.regularId == null
      ? (match: 0.0, tipMult: 1.0)
      : regularBonus(regulars, retry: c.regularRetry);

  /// Invitations, missed holidays (block `regularMorning`) for today.
  void _regularsMorning() {
    if (!notebookUnlocked) return;
    for (final def in regulars.customers) {
      final p = state.regulars[def.id];
      if (p == null && def.minGameDay > state.day) continue;
      regularMorning(
        regulars,
        e,
        def,
        regularProgress(def.id),
        day: state.day,
        great: state.lifetimeGreat,
        owned: owned,
      );
    }
  }

  /// Picks today's regulars and the arrivals they take over.
  void _planRegulars(int arrivals) {
    _regularAt.clear();
    _arrivalIndex = 0;
    final plan = planRegularDay(
      regulars,
      e,
      state.regulars,
      day: state.day,
      great: state.lifetimeGreat,
      owned: owned,
      arrivals: arrivals,
      rng: rng,
    );
    final slots = [for (var i = 0; i < arrivals; i++) i]..shuffle(rng);
    for (var k = 0; k < plan.length && k < slots.length; k++) {
      _regularAt[slots[k]] = plan[k];
    }
  }

  /// Puts today's regular for this arrival in the queue. False = a stranger
  /// comes instead. A regular whose flowers are sold out tries the next
  /// arrival.
  bool _spawnRegular() {
    final index = _arrivalIndex++;
    final plan = _regularAt.remove(index);
    if (plan == null) return false;
    final def = regulars.byId(plan.id);
    if (def == null || queue.any((c) => c.regularId == def.id)) return false;
    final visit = plan.step == null ? null : def.visit(plan.step!);
    final request = requestForRegular(
      e,
      owned: owned,
      shelf: {for (final f in e.flowers) f.id: stockAvailable(f.id)},
      rng: rng,
      species: visit?.species ?? def.favoriteFlowerIds,
      occasionId: visit?.orderOccasion,
    );
    if (request == null) {
      final later = [
        for (final i in state.pendingArrivals.indexed) index + 1 + i.$1,
      ].where((i) => !_regularAt.containsKey(i));
      if (later.isNotEmpty) _regularAt[later.first] = plan;
      return false;
    }
    final line = visit != null
        ? visit.order
        : pickOrderLine(
            data.orders,
            occasionId: request.occasionId,
            holidayId: holidayToday?.id,
            rng: rng,
            recent: state.recentOrderLines,
          );
    final fx = effects;
    queue.add(
      Customer(
        id: _nextCustomerId++,
        name: def.name,
        avatarId: regularAvatarId(def.id),
        request: request,
        requestLine: line,
        patienceMax:
            e.patienceSeconds *
            fx.patienceMultiplier *
            (1 + petEffects.patienceBonus + potShelf.patienceBonus) *
            pricePatienceFactor(e, priceMultiplier),
        walkIn: e.walkInSeconds,
        regularId: def.id,
        regularStep: visit?.step,
        regularRetry: visit != null && regularProgress(def.id).retries > 0,
      ),
    );
    return true;
  }

  /// A served or departed regular moves the story on (block
  /// `failureHandling`). Toasts per so_tay_strings.json.
  void _regularVisitEnded(
    Customer c, {
    required int stars,
    required bool left,
  }) {
    final id = c.regularId;
    if (id == null) return;
    final def = regulars.byId(id);
    if (def == null) return;
    final out = recordRegularVisit(
      regulars,
      regularProgress(id),
      step: c.regularStep,
      stars: stars,
      left: left,
      day: state.day,
    );
    final t = regulars.t;
    switch (out) {
      case RegularOutcome.becameRegular:
        showNotice(
          t.ui('becameRegularToast', {'name': def.name}),
          quiet: true,
          seconds: 3,
        );
      case RegularOutcome.letter:
      case RegularOutcome.poorEnding:
        showNotice(
          t.ui('newLetterToast', {'name': def.name}),
          quiet: true,
          seconds: 3,
        );
      case RegularOutcome.retry:
      case RegularOutcome.none:
        break;
    }
  }

  /// Notebook badge (§3): unread letters and new invitations.
  int get notebookBadgeCount =>
      notebookUnlocked ? notebookBadge(state.regulars) : 0;

  /// Opening a letter (§5.2 "Chưa đọc"): kept in the morning save too.
  void readLetter(String id, int step) {
    final p = state.regulars[id];
    if (p == null || !p.unread.remove(step)) return;
    PlayAnalytics.letterOpen(id, step);
    _patchMorning((cp) => cp.regulars[id]?.unread.remove(step));
    _changed();
  }

  /// The invitation line was seen in the regular's page.
  void seeInvite(String id) {
    final p = state.regulars[id];
    if (p == null || !p.inviteUnseen) return;
    p.inviteUnseen = false;
    _patchMorning((cp) => cp.regulars[id]?.inviteUnseen = false);
    _changed();
  }

  /// "Mời ghé lại" (block `afterMaxRetries`): free, the step opens again.
  bool inviteRegularAgain(String id) {
    final def = regulars.byId(id);
    final p = state.regulars[id];
    if (def == null || p == null) return false;
    if (!inviteAgain(def, p)) return false;
    final step = nextVisit(def, p)?.step;
    if (step != null) PlayAnalytics.inviteAgain(id, step);
    _patchMorning((cp) {
      final q = cp.regulars[id];
      if (q != null) inviteAgain(def, q);
    });
    showNotice(
      regulars.t.ui('inviteBack.toast', {'name': def.name}),
      quiet: true,
    );
    _changed();
    return true;
  }

  // ---- Sổ tay khách quen screens (spec §4–§5) ----------------------------

  /// The notebook screen is up (over the shop, like the charm board).
  bool notebookShown = false;

  /// List tab: `all`, `regular` or `locked` (so_tay_strings `tabs`).
  String notebookTab = 'all';

  /// The regular whose page is open; null = the list.
  String? notebookDetailId;

  /// The letter open over the regular's page.
  int? letterShownStep;

  /// Great bouquets still missing before the notebook opens.
  int get notebookGreatLeft =>
      max(0, regulars.notebookMinLifetimeGreat - state.lifetimeGreat);

  /// "Mở sổ" on the unlock popup: seen for good, then the notebook.
  void openNotebookFromIntro() {
    state.notebookIntroSeen = true;
    _patchMorning((cp) => cp.notebookIntroSeen = true);
    if (popups.isNotEmpty && popups.first is NotebookPopup) {
      popups.removeAt(0);
    }
    openNotebook();
  }

  void openNotebook() {
    if (!notebookUnlocked) return;
    notebookShown = true;
    notebookDetailId = null;
    letterShownStep = null;
    PlayAnalytics.notebookOpen();
    sounds.effect('popup_open');
    _changed();
  }

  /// Back: the letter, then the regular's page, then the screen.
  void closeNotebook() {
    if (letterShownStep != null) {
      letterShownStep = null;
    } else if (notebookDetailId != null) {
      notebookDetailId = null;
    } else {
      notebookShown = false;
      sounds.effect('popup_close');
    }
    _changed();
  }

  void selectNotebookTab(String tab) {
    notebookTab = tab;
    _changed();
  }

  void openRegularCard(String id) {
    if (regulars.byId(id) == null) return;
    notebookDetailId = id;
    letterShownStep = null;
    PlayAnalytics.regularCardOpen(id);
    seeInvite(id);
    _changed();
  }

  void openLetter(int step) {
    final id = notebookDetailId;
    if (id == null) return;
    letterShownStep = step;
    readLetter(id, step);
    sounds.effect('popup_open');
    _changed();
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
    _regularVisitEnded(c, stars: stars ?? 0, left: true);
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
  /// The shelf's `wrapSpeedBonus` shortens it further.
  double get wrapAnimationSeconds =>
      e.wrapAnimationSeconds *
      (1 - effects.wrapTimeReduction) *
      (1 - potShelf.wrapSpeedBonus.clamp(0.0, 0.9));

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
    final match = withMatchBonus(
      e,
      scoreBouquet(e, c.request, bouquet),
      regularBonusFor(c).match,
    );
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

  /// {xu}: the tip above what the same sale pays without weather; {soCanh}
  /// for the demand line: favoured stems sold.
  void _noteWeatherSale(
    Bouquet bouquet,
    int price,
    Tier tier,
    bool fast,
    bool wrapHit,
    int tip,
    Customer c,
  ) {
    final t = weatherToday;
    if (t == null) return;
    final plain = computePayment(
      e,
      price: price,
      tier: tier,
      fastService: fast,
      wrapHit: wrapHit,
      holidayTipMultiplier: holidayToday?.tipMultiplier ?? 1.0,
      occasionTipMultiplier:
          e.occasion(c.request.occasionId).tipMultiplier *
          regularBonusFor(c).tipMult,
    ).tip;
    if (tip > plain) weatherDay.tipExtra += tip - plain;
    for (final entry in bouquet.counts.entries) {
      if (t.boostFlowers.contains(entry.key)) {
        weatherDay.demandSold += entry.value;
      }
    }
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
      holidayTipMultiplier:
          (holidayToday?.tipMultiplier ?? 1.0) *
          weatherFactor(WeatherFactor.tip),
      occasionTipMultiplier:
          occasion.tipMultiplier * regularBonusFor(c).tipMult,
      noteTip: cardNoteTip(e, occasionId: occasion.id, note: cardText),
    );
    _noteWeatherSale(bouquet, price, tier, fast, wrapHit, payment.tip, c);
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
    if (tier == Tier.great) {
      m.greatCount++;
      state.lifetimeGreat++;
    }
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
    _regularVisitEnded(c, stars: review.stars, left: false);
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
    if (c.mysterious) {
      final drop = rollMysteryItem();
      if (drop != null) {
        grantRewards(
          RewardBundle([RewardItem.petItem(drop.id)]),
          source: RewardSource.mysteryCustomer,
        );
      }
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
    petSlotsOpen = false;
    charmBoardOpen = false;
    if (screen == Screen.pets) {
      _changed();
      return;
    }
    openPets();
  }

  /// The pet the room shows. Only the room changes: which pet earns or
  /// competes is set in the slot picker ([placePetInSlot]).
  void useRoomPet(String id) {
    if (!state.ownsPet(id)) return;
    petRoomId = id;
    sounds.effect('ui_tap');
    _changed();
  }

  // ---------------------------------------------------------------------
  // Pet slots (SPEC_chon_thu_o.md): "Thu nhập" and "Mị lực"
  // ---------------------------------------------------------------------

  /// The slot picker is open.
  bool petSlotsOpen = false;

  /// The Xếp hạng Mị lực screen, on top of the slot picker.
  bool charmBoardOpen = false;

  void openCharmBoard() {
    if (!petsUnlocked) return;
    charmBoardOpen = true;
    ratingBoard.showCharm();
    sounds.effect('popup_open');
    _changed();
    board.open();
  }

  /// "Xếp hạng" on Màn Đánh giá: the board screen on its Đánh giá tab (spec
  /// 2.2). Needs no pet, unlike the Mị lực tab.
  void openRatingBoard() {
    if (!ratingBoard.enabled) return;
    charmBoardOpen = true;
    board.rewardsOpen = false;
    board.profile = null;
    sounds.effect('popup_open');
    _changed();
    ratingBoard.showTab();
  }

  /// A tab of the board screen: [ratingTab] or Mị lực.
  void selectBoardTab({required bool ratingTab}) {
    if (ratingTab == ratingBoard.tab) return;
    if (ratingTab) {
      board.rewardsOpen = false;
      board.profile = null;
      board.hiddenListOpen = false;
      ratingBoard.showTab();
    } else {
      ratingBoard.showCharm();
      board.open();
    }
    _changed();
  }

  void closeCharmBoard() {
    if (!charmBoardOpen) return;
    charmBoardOpen = false;
    board.rewardsOpen = false;
    board.profile = null;
    ratingBoard.closeSheets();
    sounds.effect('popup_close');
    _changed();
  }

  /// "Chọn thú" on the board: back to the slot picker with the Mị lực slot
  /// chosen.
  void pickCharmPet() {
    charmBoardOpen = false;
    board.profile = null;
    openPetSlots(select: petSlotCharm);
  }

  /// `income`, `charm` or null: the slot the next tap on a pet fills.
  String? petSlotSelected;

  /// Pet id in [slot], or null when it is empty.
  String? petInSlot(String slot) =>
      slot == petSlotCharm ? state.petCharm : state.petIncome;

  /// The first empty slot, Thu nhập before Mị lực.
  String? get firstEmptyPetSlot {
    for (final slot in petSlotIds) {
      if (petInSlot(slot) == null) return slot;
    }
    return null;
  }

  /// Opens the picker. The first empty slot is selected; with both full
  /// nothing is, unless [select] names a slot (a tap on a chip).
  void openPetSlots({String? select}) {
    if (!petsUnlocked) return;
    petCatalogOpen = false;
    skinPicker = null;
    petSlotsOpen = true;
    petSlotSelected = select != null && petSlotIds.contains(select)
        ? select
        : firstEmptyPetSlot;
    sounds.effect('popup_open');
    _changed();
  }

  void closePetSlots() {
    if (!petSlotsOpen) return;
    petSlotsOpen = false;
    charmBoardOpen = false;
    petSlotSelected = null;
    sounds.effect('popup_close');
    _changed();
  }

  /// A tap on a slot selects it; a second tap lets go.
  void selectPetSlot(String slot) {
    if (!petSlotIds.contains(slot)) return;
    petSlotSelected = petSlotSelected == slot ? null : slot;
    sounds.effect('ui_tap');
    _changed();
  }

  /// A tap on an owned pet (spec §5). Fills the selected slot, replacing
  /// what is there without asking, and saves at once. With no slot selected
  /// the first empty one is used; with none empty the player is asked to
  /// pick a slot. A pet may sit in both slots.
  PetSlotPlacement placePetInSlot(String id) {
    if (!state.ownsPet(id)) {
      return const PetSlotPlacement(PetSlotResult.notOwned);
    }
    var slot = petSlotSelected;
    if (slot == null) {
      slot = firstEmptyPetSlot;
      if (slot == null) {
        return const PetSlotPlacement(PetSlotResult.pickSlot);
      }
    }
    if (petInSlot(slot) == id) {
      return PetSlotPlacement(PetSlotResult.already, slot: slot);
    }
    if (slot == petSlotCharm) {
      state.petCharm = id;
    } else {
      state.petIncome = id;
    }
    // Next: the other slot if it is empty, else nothing is selected.
    final other = slot == petSlotCharm ? petSlotIncome : petSlotCharm;
    petSlotSelected = petInSlot(other) == null ? other : null;
    _patchPet();
    sounds.effect('popup_open');
    _changed();
    return PetSlotPlacement(PetSlotResult.placed, slot: slot);
  }

  /// The × on a slot: empties it and selects it.
  void clearPetSlot(String slot) {
    if (!petSlotIds.contains(slot) || petInSlot(slot) == null) return;
    if (slot == petSlotCharm) {
      state.petCharm = null;
    } else {
      state.petIncome = null;
    }
    petSlotSelected = slot;
    _patchPet();
    sounds.effect('ui_tap');
    _changed();
  }

  /// Mị lực of an owned pet (stage and, later, what it wears). 0 when the
  /// pet is not owned.
  int petCharmOf(String id) {
    final owned = state.ownedPet(id);
    final def = e.pet(id);
    if (owned == null || def == null) return 0;
    return petAndItemsCharm(e, def, owned);
  }

  /// The row this player would publish to the Mị lực board, or null when
  /// not signed in. Nothing sends it yet: when to publish is undecided.
  CharmBoardEntry? charmBoardEntry({
    required String displayName,
    String avatar = '',
  }) {
    final uid = accountUid;
    if (uid == null) return null;
    return CharmBoardEntry.forPlayer(
      uid: uid,
      displayName: displayName,
      avatar: avatar,
      charm: charmScore,
    );
  }

  // ---- pet items (data model only: no catalog, no way to get them yet) ----

  /// Copies of [itemId] the player owns.
  int petItemOwned(String itemId) => state.petItems[itemId] ?? 0;

  /// Copies of [itemId] worn right now, by any pet.
  int petItemWorn(String itemId) {
    var n = 0;
    for (final pet in state.pets) {
      for (final id in pet.worn.values) {
        if (id == itemId) n++;
      }
    }
    return n;
  }

  /// Xu or Pha lê still missing for [itemId] (0 when it can be bought).
  int petItemShortfall(PetItemDef item) {
    final have = item.paysPhaLe ? state.phaLe : state.money;
    return have >= item.price ? 0 : item.price - have;
  }

  /// What selling one copy of [itemId] pays, in the item's own currency.
  int petItemSellPrice(String itemId) {
    final def = e.petItem(itemId);
    return def == null ? 0 : petItemSellValue(def, e.petItemResaleRate);
  }

  /// Buys one more copy. There is no limit on copies (up to 99, the most a
  /// gift carries); each worn by one pet at a time. Closed hours only.
  PetItemTrade buyPetItem(String itemId) {
    final def = e.petItem(itemId);
    if (def == null) return PetItemTrade.unknownItem;
    if (!petShopOpen) return PetItemTrade.shopOpen;
    if (petItemOwned(itemId) >= maxGiftCount) return PetItemTrade.noCopies;
    if (petItemShortfall(def) > 0) return PetItemTrade.short;
    if (def.paysPhaLe) {
      state.phaLe -= def.price;
    } else {
      state.money -= def.price;
    }
    state.petItems[itemId] = petItemOwned(itemId) + 1;
    _patchPet(
      moneyDelta: def.paysPhaLe ? 0 : -def.price,
      phaLeDelta: def.paysPhaLe ? -def.price : 0,
    );
    sounds.effect('market_buy');
    _changed();
    return PetItemTrade.bought;
  }

  /// Sells one copy that is not worn for 30% of the price (`petItems.
  /// sellRate`), in the item's currency. A copy from the mystery visitor
  /// sells for the same, since the price is the item's own.
  PetItemTrade sellPetItem(String itemId) {
    final def = e.petItem(itemId);
    if (def == null) return PetItemTrade.unknownItem;
    if (!petShopOpen) return PetItemTrade.shopOpen;
    final owned = petItemOwned(itemId);
    if (owned <= 0) return PetItemTrade.noCopies;
    if (owned - petItemWorn(itemId) <= 0) return PetItemTrade.allWorn;
    final value = petItemSellValue(def, e.petItemResaleRate);
    if (owned == 1) {
      state.petItems.remove(itemId);
    } else {
      state.petItems[itemId] = owned - 1;
    }
    if (def.paysPhaLe) {
      state.phaLe += value;
    } else {
      state.money += value;
    }
    _patchPet(
      moneyDelta: def.paysPhaLe ? 0 : value,
      phaLeDelta: def.paysPhaLe ? value : 0,
    );
    if (def.paysPhaLe) unawaited(walletEarn('resale', ref: itemId));
    sounds.effect('market_buy');
    _changed();
    return PetItemTrade.sold;
  }

  /// Mị lực the worn items of [petId] add (0 for a pet that is not owned).
  int petItemCharm(String petId) {
    final owned = state.ownedPet(petId);
    if (owned == null) return 0;
    return wornItemsCharm(owned.worn, e.petItemRules, e.petItem);
  }

  /// Puts [itemId] on [petId], in the slot the item is made for. It replaces
  /// what is worn there; a copy worn by another pet has to be taken off first.
  PetItemResult wearPetItem(String petId, String itemId) {
    final pet = state.ownedPet(petId);
    if (pet == null) return PetItemResult.notOwned;
    final def = e.petItem(itemId);
    if (def == null || !e.petItemRules.slots.contains(def.slot)) {
      return PetItemResult.unknownItem;
    }
    if (pet.worn[def.slot] == itemId) return PetItemResult.already;
    if (petItemOwned(itemId) - petItemWorn(itemId) <= 0) {
      return PetItemResult.noneLeft;
    }
    pet.worn[def.slot] = itemId;
    _patchPet();
    _changed();
    return PetItemResult.worn;
  }

  /// Takes off whatever [petId] wears in [slot]. False when nothing was there.
  bool unwearPetItem(String petId, String slot) {
    final pet = state.ownedPet(petId);
    if (pet == null || pet.worn.remove(slot) == null) return false;
    _patchPet();
    _changed();
    return true;
  }

  // ---- the pet room: item picker, item shop, received items ----

  /// The slot the item picker (P2) is open for, or null.
  String? petItemPickSlot;

  /// The item whose detail block the picker shows.
  String? petItemPickDetail;

  /// The item the sell confirm (P2c) asks about.
  String? petItemSellId;

  /// The item the buy confirm (P3b, P3c) asks about.
  String? petItemBuyId;

  /// The item shop (P3) is open, on tab [petItemShopTab] (a slot name).
  bool petItemShopOpen = false;

  /// Tiệm Trang Trí over the current screen: [skinGroupShop] or
  /// [skinGroupRoom], null when closed ([openDecorate]).
  String? decorateGroup;

  // ---- Pha lê shop (real money, SePay transfer) ---------------------------

  /// The payment server door. Null = the flag `phaLeShop.open` decides:
  /// closed ("Sắp mở"), or the labelled demo gateway when the flag is on and
  /// no real one was set. Set it before the shop is first opened.
  PhaleGateway? phaleGateway;

  /// The real SePay gateway, built by main when online. Used only while the
  /// flag `phaLeShop.open` is on; with the flag off the shop stays closed.
  PhaleGateway? phaleLiveGateway;

  /// Claims the credit mail of a paid order (main binds it to the mailbox)
  /// and returns the new Pha lê balance, or null if it could not claim yet.
  Future<int?> Function(PhaleOrder order)? phaleClaim;

  /// App Store purchases. Null in tests and on web/Android.
  PhaleIap? phaleIap;
  ApplePhaleClient? applePhaleClient;
  PhaleShopController? _phaleShop;

  /// iOS: App Store prices by pack id, loaded when the shop opens. A pack
  /// without one shows no price (never the VND list price).
  Map<String, String> applePrices = const {};
  var _draining = false;

  /// Ask the server for the order status on a timer while the transfer screen
  /// is up (tests turn it off and call PhaleShopController.poll).
  bool phaleAutoPoll = true;

  PhaleShopController get phaleShop {
    final made = _phaleShop;
    if (made != null) return made;
    final c = PhaleShopController(
      config: e.phaLeShop,
      gateway:
          phaleGateway ??
          (e.phaLeShop.open
              ? (phaleLiveGateway ?? DemoPhaleGateway(config: e.phaLeShop))
              : const ClosedPhaleGateway()),
      signedIn: () => signedIn,
      autoPoll: phaleAutoPoll,
      onPaid: (o) async => phaleClaim == null ? null : phaleClaim!(o),
    );
    c.addListener(_changed);
    return _phaleShop = c;
  }

  /// The Pha lê shop (S1) is up over whatever screen opened it.
  bool phaleShopOpen = false;

  /// Rewarded-ad popup. Null when it is closed. Android and iOS only.
  RewardedAdKind? rewardedAd;

  /// Quà miễn phí, opened from the Giỏ. Android and iOS only.
  bool freeRewardOpen = false;

  void openFreeReward() {
    if (!rewardedAdsOffered || tutorialActive) return;
    freeRewardOpen = true;
    sounds.effect('popup_open');
    _changed();
  }

  void closeFreeReward() {
    if (!freeRewardOpen) return;
    freeRewardOpen = false;
    sounds.effect('popup_close');
    _changed();
  }

  void openRewardedAd(RewardedAdKind kind, {String place = 'entry'}) {
    rewardedAd = kind;
    PlayAnalytics.rewardedEntryTap(kind.name, place: place);
    sounds.effect('popup_open');
    _changed();
  }

  void closeRewardedAd() {
    if (rewardedAd == null) return;
    rewardedAd = null;
    sounds.effect('popup_close');
    _changed();
  }

  /// "Thiếu N Pha lê" popup (S4b), over any buy popup.
  PhaleShort? phaleShort;

  /// iOS: App Store sheet, then the server writes the Pha lê mail.
  /// Web and Android keep [PhaleShopController.confirmBuy] (bank transfer).
  Future<void> buyPhaleWithApple() async {
    if (!phaLeUsesAppleIap || !phaLeTopUpOffered) return;
    final shop = _phaleShop;
    final pack = shop?.pack;
    if (shop == null || pack == null) return;
    if (shop.step == PhaleStep.creating) return;
    final iap = phaleIap;
    final client = applePhaleClient;
    if (iap == null || client == null) {
      shop.showCreateFailed();
      return;
    }
    shop.showCreating();
    PhaleIapPurchase? purchase;
    try {
      final uid = accountUid;
      purchase = await iap.buy(
        pack.id,
        accountToken: uid == null ? null : appAccountTokenFor(uid),
      );
      final token = await account.idToken();
      if (token == null || token.isEmpty) throw PhaleIapUnavailable();
      final credit = await client.credit(
        idToken: token,
        signedTransaction: purchase.jws,
      );
      await purchase.finish();
      iap.forget(purchase);
      final paid = PhaleOrder(
        orderId: credit.transactionId,
        packId: credit.packId,
        amount: pack.priceVnd,
        crystals: credit.phaLe,
        bonusPercent: pack.bonusPercent,
        bank: 'App Store',
        accountNo: '',
        accountName: '',
        transferContent: credit.transactionId,
        expiresAt: DateTime.now(),
        status: PhaleOrderStatus.paid,
        crystalsGranted: credit.phaLe,
        mailId: credit.mailId,
      );
      shop.showPaid(paid);
      final claim = phaleClaim;
      if (claim != null) {
        final balance = await claim(paid);
        if (balance != null && shop.order?.orderId == paid.orderId) {
          shop.showPaid(paid.copyWith(newBalance: balance));
        }
      }
    } on PhaleIapCancelled {
      if (shop.step == PhaleStep.creating) shop.retry();
    } on ApplePhaleException catch (e) {
      final paid = purchase;
      var refused = false;
      if (e.finishPurchase && paid != null) {
        refused = true;
        await paid.finish();
        iap.forget(paid);
      }
      if (shop.step == PhaleStep.creating || shop.step == PhaleStep.confirm) {
        shop.showCreateFailed(refused: refused);
      }
    } catch (_) {
      if (shop.step == PhaleStep.creating || shop.step == PhaleStep.confirm) {
        shop.showCreateFailed();
      }
    }
  }

  /// iOS: sends every paid but uncredited App Store purchase (StoreKit gives
  /// unfinished ones back at launch) to the server, then finishes it. Runs
  /// at startup, after sign-in and when the app comes back. A purchase the
  /// server will never credit (another account, refunded) is finished too;
  /// a network or server failure leaves it for the next run.
  Future<void> drainApplePurchases() async {
    final iap = phaleIap;
    final client = applePhaleClient;
    if (!phaLeUsesAppleIap || iap == null || client == null) return;
    if (_draining || !signedIn) return;
    _draining = true;
    var credited = 0;
    try {
      for (final purchase in iap.pending) {
        final token = await account.idToken();
        if (token == null || token.isEmpty) return;
        try {
          await client.credit(idToken: token, signedTransaction: purchase.jws);
          credited++;
        } on ApplePhaleException catch (e) {
          if (!e.finishPurchase) continue;
        }
        await purchase.finish();
        iap.forget(purchase);
      }
    } catch (_) {
      // Tried again on the next run.
    } finally {
      _draining = false;
      if (credited > 0) {
        showNotice(
          'Đã nhận giao dịch App Store. Pha lê đang chờ trong Hộp thư.',
          quiet: true,
          seconds: 4,
        );
      }
    }
  }

  /// iOS: App Store prices for the shop cards ([applePrices]).
  Future<void> loadApplePrices() async {
    final iap = phaleIap;
    if (!phaLeUsesAppleIap || iap == null || applePrices.isNotEmpty) return;
    try {
      final found = await iap.prices(e.phaLeShop.packs.map((p) => p.id));
      if (found.isEmpty) return;
      applePrices = found;
      _changed();
    } catch (_) {
      // Cards keep showing no price.
    }
  }

  /// Opens S1; [need] and [name] add the "Cần thêm N Pha lê để mua …" banner.
  void openPhaleShop({int? need, String? name}) {
    if (!phaLeTopUpOffered) return; // top-up closed, see platform_flags.dart
    phaleShort = null;
    phaleShop.start(need: need, name: name);
    unawaited(loadApplePrices());
    phaleShopOpen = true;
    sounds.effect('popup_open');
    _changed();
  }

  void closePhaleShop() {
    if (!phaleShopOpen) return;
    phaleShopOpen = false;
    _phaleShop?.leave();
    sounds.effect('popup_close');
    _changed();
  }

  /// A buy was refused for lack of Pha lê: asks to top up (S4b).
  void askPhaleShort(String name, int price) {
    phaleShort = PhaleShort(name: name, price: price, have: state.phaLe);
    _changed();
  }

  void closePhaleShort() {
    if (phaleShort == null) return;
    phaleShort = null;
    _changed();
  }

  /// "Thiếu xu" popup: đổi Pha lê (web + Android), quảng cáo + nạp (Android).
  XuShort? xuShort;

  void askXuShort(String name, int price) {
    xuShort = XuShort(name: name, price: price, have: state.money);
    sounds.effect('popup_open');
    _changed();
  }

  void closeXuShort() {
    if (xuShort == null) return;
    xuShort = null;
    sounds.effect('popup_close');
    _changed();
  }

  void _refreshXuShort() {
    final short = xuShort;
    if (short == null) return;
    xuShort = XuShort(name: short.name, price: short.price, have: state.money);
  }

  /// Spends Pha lê for enough 1M-xu packs to cover the current shortfall.
  bool exchangePhaLeForXuShort() {
    final short = xuShort;
    if (short == null || short.need <= 0) return false;
    final cost = phaLeCostForMissingXu(short.need);
    if (state.phaLe < cost) return false;
    final packs = exchangePacksForMissingXu(short.need);
    final gain = xuFromExchangePacks(packs);
    state.phaLe -= cost;
    state.money += gain;
    _patchPet(phaLeDelta: -cost, moneyDelta: gain);
    _refreshXuShort();
    sounds.effect('market_buy');
    _changed();
    return true;
  }

  String petItemShopTab = 'neck';

  /// The item the shop was opened for (a price chip of the picker): its row is
  /// scrolled into view and outlined. Cleared on another tab or on leaving.
  String? petItemShopFocus;

  /// Items that arrived as a gift and have not been shown yet (P4).
  final List<PetItemGift> petItemGifts = [];

  /// The first received item waiting for its popup.
  PetItemGift? get petItemGift =>
      petItemGifts.isEmpty ? null : petItemGifts.first;

  /// Owned and worn copies of [itemId].
  PetItemCounts petItemCounts(String itemId) =>
      PetItemCounts(owned: petItemOwned(itemId), worn: petItemWorn(itemId));

  /// The items made for [slot], in the file's order (cheapest tier first).
  List<PetItemDef> petItemsOfSlot(String slot) => [
    for (final item in e.petItems)
      if (item.slot == slot) item,
  ];

  /// The name of another pet that wears [itemId], or null.
  String? petItemWornBy(String itemId, {String? except}) {
    for (final pet in state.pets) {
      if (pet.id == except) continue;
      if (pet.worn.values.contains(itemId)) return petName(pet.id);
    }
    return null;
  }

  /// What the card of [item] shows for [petId].
  PetItemCardState petItemCardState(String petId, PetItemDef item) {
    final pet = state.ownedPet(petId);
    final counts = petItemCounts(item.id);
    if (counts.owned <= 0) {
      return petItemShortfall(item) > 0
          ? PetItemCardState.short
          : PetItemCardState.canPay;
    }
    if (pet != null && pet.worn[item.slot] == item.id) {
      return PetItemCardState.worn;
    }
    return counts.spare > 0
        ? PetItemCardState.inStock
        : PetItemCardState.elsewhere;
  }

  /// Mị lực of [petId] if [itemId] were worn in its slot (null [itemId]:
  /// if the slot [slot] were empty). The preview chip of the picker.
  int petCharmWith(String petId, {required String slot, String? itemId}) {
    final owned = state.ownedPet(petId);
    final def = e.pet(petId);
    if (owned == null || def == null) return 0;
    final worn = {...owned.worn};
    if (itemId == null) {
      worn.remove(slot);
    } else {
      worn[slot] = itemId;
    }
    return clampCharmPart(
          petCharmScore(def, owned.stage, multipliers: e.charmStageMultiplier),
          e.charmRules.petMax,
        ) +
        clampCharmPart(
          wornItemsCharm(worn, e.petItemRules, e.petItem),
          e.charmRules.petItemsMax,
        );
  }

  /// Opens the picker of [slot] for the pet in the room. The detail block
  /// starts on what the pet wears there, else on a copy in the store room,
  /// else on the first item the player owns.
  bool openPetItemPicker(String slot) {
    final pet = roomPet;
    if (pet == null || !e.petItemRules.slots.contains(slot)) return false;
    petItemPickSlot = slot;
    petItemSellId = null;
    String? detail = pet.worn[slot];
    detail ??= [
      for (final item in petItemsOfSlot(slot))
        if (petItemCounts(item.id).spare > 0) item.id,
    ].firstOrNull;
    detail ??= [
      for (final item in petItemsOfSlot(slot))
        if (petItemOwned(item.id) > 0) item.id,
    ].firstOrNull;
    petItemPickDetail = detail;
    sounds.effect('popup_open');
    _changed();
    return true;
  }

  void closePetItemPicker() {
    if (petItemPickSlot == null) return;
    petItemPickSlot = null;
    petItemPickDetail = null;
    petItemSellId = null;
    sounds.effect('popup_close');
    _changed();
  }

  void selectPetItemDetail(String itemId) {
    if (e.petItem(itemId) == null) return;
    petItemPickDetail = itemId;
    sounds.effect('ui_tap');
    _changed();
  }

  /// Wears [itemId] on the pet in the room ("Đeo").
  PetItemResult wearPetItemOnRoomPet(String itemId) {
    final pet = roomPet;
    if (pet == null) return PetItemResult.notOwned;
    final res = wearPetItem(pet.id, itemId);
    if (res == PetItemResult.worn) sounds.effect('ui_tap');
    return res;
  }

  /// "Gỡ đồ": takes off what the room pet wears in [slot].
  bool unwearRoomPetSlot(String slot) {
    final pet = roomPet;
    if (pet == null) return false;
    final done = unwearPetItem(pet.id, slot);
    if (done) sounds.effect('ui_tap');
    return done;
  }

  /// Asks before selling a copy (P2c). Only a copy in the store room can be
  /// sold; a worn one has to come off first.
  bool openPetItemSell(String itemId) {
    if (e.petItem(itemId) == null || petItemCounts(itemId).spare <= 0) {
      return false;
    }
    petItemSellId = itemId;
    sounds.effect('popup_open');
    _changed();
    return true;
  }

  void closePetItemSell() {
    if (petItemSellId == null) return;
    petItemSellId = null;
    sounds.effect('popup_close');
    _changed();
  }

  /// "Bán +{số tiền}" in the confirm: sells one spare copy.
  PetItemTrade confirmPetItemSell() {
    final id = petItemSellId;
    if (id == null) return PetItemTrade.unknownItem;
    final res = sellPetItem(id);
    petItemSellId = null;
    _changed();
    return res;
  }

  /// Opens the item shop (P3) on the tab of [slot] (or the last one).
  void openPetItemShop({String? slot, String? focus}) {
    if (!petsUnlocked) return;
    if (slot != null && e.petItemRules.slots.contains(slot)) {
      petItemShopTab = slot;
    } else if (!e.petItemRules.slots.contains(petItemShopTab)) {
      petItemShopTab = e.petItemRules.slots.first;
    }
    petItemPickSlot = null;
    petItemPickDetail = null;
    petItemSellId = null;
    petItemBuyId = null;
    petItemShopFocus = focus;
    petItemShopOpen = true;
    sounds.effect('popup_open');
    _changed();
  }

  /// A price chip of the picker: the shop on the item's tab, the row in view,
  /// and the buy confirm when the player can pay and the shop serves nobody.
  bool openPetItemShopFor(String itemId) {
    final item = e.petItem(itemId);
    if (item == null || !petsUnlocked) return false;
    openPetItemShop(slot: item.slot, focus: itemId);
    if (petShopOpen && petItemShortfall(item) == 0) {
      petItemBuyId = itemId;
      _changed();
    }
    return true;
  }

  void closePetItemShop() {
    if (!petItemShopOpen) return;
    petItemShopOpen = false;
    petItemShopFocus = null;
    petItemBuyId = null;
    sounds.effect('popup_close');
    _changed();
  }

  void selectPetItemShopTab(String slot) {
    if (!e.petItemRules.slots.contains(slot) || slot == petItemShopTab) return;
    petItemShopTab = slot;
    petItemShopFocus = null;
    sounds.effect('ui_tap');
    _changed();
  }

  /// A price button was tapped: asks before buying (P3b, P3c).
  bool openPetItemBuy(String itemId) {
    if (e.petItem(itemId) == null) return false;
    petItemBuyId = itemId;
    sounds.effect('popup_open');
    _changed();
    return true;
  }

  void closePetItemBuy() {
    if (petItemBuyId == null) return;
    petItemBuyId = null;
    sounds.effect('popup_close');
    _changed();
  }

  /// "Mua {giá}" in the confirm. The copy goes to the store room; it is
  /// never worn by itself.
  PetItemTrade confirmPetItemBuy() {
    final id = petItemBuyId;
    if (id == null) return PetItemTrade.unknownItem;
    final res = buyPetItem(id);
    petItemBuyId = null;
    _changed();
    return res;
  }

  /// The arrows of the room: the next (or previous) owned pet.
  void stepRoomPet(int direction) {
    final pets = state.pets;
    final current = roomPet;
    if (pets.length < 2 || current == null) return;
    final i = pets.indexWhere((p) => p.id == current.id);
    final next = pets[((i < 0 ? 0 : i) + direction) % pets.length];
    useRoomPet(next.id);
  }

  /// "Giữ" / "Để sau" on a received-item popup.
  void closePetItemGift() {
    if (petItemGifts.isEmpty) return;
    petItemGifts.removeAt(0);
    sounds.effect('popup_close');
    _changed();
  }

  /// "Vào phòng pet" on a received-item popup: the room of the pet in the
  /// Mị lực slot, else the one the room last showed.
  void petItemGiftToRoom() {
    final gift = petItemGift;
    if (gift == null) return;
    petItemGifts.removeAt(0);
    final id = state.petCharm ?? roomPet?.id;
    if (id != null && state.ownsPet(id)) {
      openPetRoom(id);
    } else {
      _changed();
    }
  }

  /// "Bán bản thừa" on the duplicate popup (P4c): sells one spare copy at
  /// once, with no second confirm. The toast text is the caller's.
  PetItemTrade sellPetItemGiftSpare() {
    final gift = petItemGift;
    if (gift == null) return PetItemTrade.unknownItem;
    final res = sellPetItem(gift.itemId);
    if (res == PetItemTrade.sold) petItemGifts.removeAt(0);
    _changed();
    return res;
  }

  /// The item a mystery visitor leaves besides the usual gift, or null.
  /// `petItems.mysteryGuestDrop` gives one chance per tier; one roll decides
  /// among them (the rarest tier first), so at most one item comes, then the
  /// item is picked at random inside the tier. May repeat an owned item.
  PetItemDef? rollMysteryItem() {
    final drops = e.petItemMysteryDrop;
    if (drops.isEmpty) return null;
    var r = rng.nextDouble();
    for (final tier in PetItemTier.values.reversed) {
      final p = drops[tier];
      if (p == null) continue;
      if (r < p) {
        final pool = [
          for (final item in e.petItems)
            if (item.tier == tier) item,
        ];
        return pool.isEmpty ? null : pool[rng.nextInt(pool.length)];
      }
      r -= p;
    }
    return null;
  }

  /// Mị lực this player brings to the board: the charm-slot pet, the items
  /// it wears and every owned pot type once, each part under its
  /// `charm.partMax` ([recomputeCharm]). 0 with an empty slot.
  int get charmScore => recomputeCharm(state, e);

  void closePets() {
    petItemShopOpen = false;
    petItemShopFocus = null;
    petItemBuyId = null;
    petItemPickSlot = null;
    petItemPickDetail = null;
    petItemSellId = null;
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
    if (!state.petSeats.contains(seatDefaultSkin)) {
      state.petSeats.add(seatDefaultSkin);
    }
    state.petSeat ??= seatDefaultSkin;
    if (!state.petBowls.contains(bowlDefaultSkin)) {
      state.petBowls.add(bowlDefaultSkin);
    }
    state.petBowl ??= bowlDefaultSkin;
  }

  void _patchPet({int moneyDelta = 0, int phaLeDelta = 0}) {
    _patchMorning((cp) {
      if (moneyDelta != 0) cp.money += moneyDelta;
      if (phaLeDelta != 0) cp.phaLe += phaLeDelta;
      cp.pets = [for (final pet in state.pets) pet.copy()];
      cp.petItems = {...state.petItems};
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

  /// Price of pet food [id] in xu (economy.json `petFood`), or null.
  int? treatPrice(String id) => e.petFoodPrices[id];

  /// Buys one biscuit or drop. Same closed-shop rule as [buyPet], except
  /// [anyTime]: the pet room's out-of-food popup buys a biscuit while the
  /// shop is open too (Phú, 26/10).
  bool buyTreat(String id, {bool anyTime = false}) {
    final treat = petTreat(id);
    final price = treatPrice(id);
    final open = petShopOpen || (anyTime && id == giftBiscuit);
    if (treat == null || price == null || !open) return false;
    final have = switch (id) {
      giftBiscuit => state.biscuits,
      giftDrop => state.drops,
      _ => -1,
    };
    if (have < 0 || have >= maxGiftCount) return false;
    if (state.money < price) return false;
    state.money -= price;
    if (id == giftBiscuit) {
      state.biscuits += 1;
    } else {
      state.drops += 1;
    }
    _patchPet(moneyDelta: -price);
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

  /// Tiệm Chậu Hoa: the open tab (a pot `set`) and the pot the book sent us
  /// to (scrolled into view, gold border).
  String potShopTab = 'chomSao';
  String? potShopFocusId;

  /// Sổ sưu tầm: the open page and, on a detail page, the pot shown.
  String potBookTab = 'chomSao';
  String? potBookDetailId;

  /// Where Back goes from the shop and the book.
  final List<Screen> _potBackStack = [];

  /// Placing mode: the pot being placed, and the slot being looked at
  /// ([pendingPlaceBar] null means no slot chosen yet).
  String? pendingPlacePotId;
  bool? pendingPlaceBar;
  int pendingPlaceIndex = 0;

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
  /// VIP pots are listed too: locked ones say which tier gives them.
  bool potListed(PotDef pot) =>
      pot.unlimited ||
      pot.purchasable ||
      (pot.howVi?.isNotEmpty ?? false) ||
      isVipPot(pot.id) ||
      (state.potCounts[pot.id] ?? 0) > 0;

  /// A pot of economy.json vip.vipPots (Chậu Ngọc Bích, Chậu Hoàng Kim).
  bool isVipPot(String id) => e.vip.pots.containsKey(id);

  int potOwned(String id) {
    final pot = e.pot(id);
    if (pot.unlimited) return 99;
    // One copy while the server's VIP tier gives it; a copy in potCounts
    // (an edited save, a stray gift) does not count.
    if (isVipPot(id)) return vip.potUnlocked(id) ? 1 : 0;
    return state.potCounts[id] ?? 0;
  }

  /// Slots holding a pot other than the free bucket, of
  /// `potStatsRules.shelfSlots` (Nhất `pot.detail.shelf_count` {used}).
  int get shelfUsed => [
    for (final id in [...state.barPots, ...state.displayPots])
      if (!(e.potOrNull(id)?.unlimited ?? true)) id,
  ].length;

  /// Slots on the shelf: `potStatsRules.shelfSlots`, else the save's slots.
  int get shelfSlots {
    final n = e.potStatsRules.shelfSlots;
    return n > 0 ? n : state.barPots.length + state.displayPots.length;
  }

  /// "Cất vào tủ": the open slot goes back to the free bucket and the pot
  /// to the cupboard.
  bool storePot() {
    final bar = potPickerBar;
    if (bar == null) return false;
    final index = potPickerIndex;
    final slots = bar ? state.barPots : state.displayPots;
    if (index < 0 || index >= slots.length) return false;
    if (e.potOrNull(slots[index])?.unlimited ?? true) return false;
    slots[index] = defaultPotId;
    _patchMorning((cp) {
      final saved = bar ? cp.barPots : cp.displayPots;
      if (index < saved.length) saved[index] = defaultPotId;
    });
    sounds.effect('ui_tap');
    _changed();
    return true;
  }

  /// After the server's VIP answer: a VIP pot the tier no longer gives
  /// leaves the shelf (its slot gets the free bucket). Nothing happens
  /// before the server answered, so a slow start keeps the shelf as saved.
  void _dropLockedVipPots() {
    if (vip.status == null) return;
    bool locked(String id) => isVipPot(id) && !vip.potUnlocked(id);
    var changed = false;
    for (final slots in [state.barPots, state.displayPots]) {
      for (var i = 0; i < slots.length; i++) {
        if (locked(slots[i])) {
          slots[i] = defaultPotId;
          changed = true;
        }
      }
    }
    if (!changed) return;
    _patchMorning((cp) {
      for (final slots in [cp.barPots, cp.displayPots]) {
        for (var i = 0; i < slots.length; i++) {
          if (locked(slots[i])) slots[i] = defaultPotId;
        }
      }
    });
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

  /// Buys one more copy, as many as the player likes, each at the listed price.
  /// The morning save keeps the pot and the spent money.
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
      // Pots on the shelf: a share of the takings, of the tips and of the
      // online orders (`incomeBonus`, `tipBonus`, `onlineOrderBonus`).
      final pots = potShelf;
      m.potBonus =
          (takings * pots.incomeBonus +
                  m.tipIncome * pots.tipBonus +
                  m.onlineIncome * pots.onlineOrderBonus)
              .round();
      m.fixedCosts = e.fixedCostsTotal + effects.dailyCosts + m.shipperWages;
      state.money += rewards + m.petBonus + m.potBonus - m.fixedCosts;
      m.settled = true;
    }
    state.phase = DayPhase.summary;
    screen = Screen.summary;
    if (ending) ratingBoard.dayClosed();
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
    if (ending && notebookUnlocked && !state.notebookIntroSeen) {
      _pushPopup(const NotebookPopup());
    }
    if (ending) considerInstallOffer();
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

  /// Shelf pots with `wiltSaveChance`: each stem has that chance to skip
  /// tonight's freshness tick. The stems that skip are split off into their
  /// own batch, returned so the tick passes them by. No roll (and no change
  /// to the day's dice) without such a pot.
  Set<StockBatch> _wiltSaved() {
    final chance = potShelf.wiltSaveChance.clamp(0.0, 1.0);
    if (chance <= 0) return const {};
    final kept = <StockBatch>{};
    for (final b in [...state.stock]) {
      var saved = 0;
      for (var i = 0; i < b.count; i++) {
        if (rng.nextDouble() < chance) saved++;
      }
      if (saved == 0) continue;
      if (saved == b.count) {
        kept.add(b);
        continue;
      }
      b.count -= saved;
      final part = StockBatch(
        flowerId: b.flowerId,
        count: saved,
        freshnessLeft: b.freshnessLeft,
      );
      state.stock.insert(state.stock.indexOf(b) + 1, part);
      kept.add(part);
    }
    return kept;
  }

  /// "Sang ngày mới": freshness tick, next day, market.
  void startNextDay() {
    if (state.phase != DayPhase.summary) return;
    if (strayCatOffer) chooseStrayCat(false);
    rememberDayRevenue(this);
    applyMorningEvent(this);
    var discarded = false;
    var warning = false;
    final kept = _wiltSaved();
    final night = weatherNight;
    state.freshnessDebt = night.debt;
    for (final b in [...state.stock]) {
      if (kept.contains(b)) continue;
      if (night.skip) continue;
      b.freshnessLeft -= 1 + night.extra;
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
    dryingMorning(this);
    state.day++;
    _startDay();
    _regularsMorning();
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
