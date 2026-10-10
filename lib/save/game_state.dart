import 'dart:convert';

import '../logic/goals.dart';

/// One pet the shop owns: its stage and feeding bar. The id is a
/// `pets.list` id in economy.json (`meo`, `ca_chep`, …).
class OwnedPet {
  OwnedPet({
    required this.id,
    this.stage = 0,
    this.progress = 0,
    this.fedDay = 0,
    Map<String, String>? worn,
  }) : worn = worn ?? {};

  final String id;

  /// 0 ấu thú, 1 lớn, 2 trưởng thành.
  int stage;

  /// 0..100. Giọt hoa spend a full bar and raise [stage].
  int progress;

  /// Last morning it was fed. Earlier than the day means it is hungry.
  int fedDay;

  /// Equip slot (`neck`, `head`, `accessory`) to the item worn there. Items
  /// only add Mị lực; see data/pet_items.dart.
  Map<String, String> worn;

  OwnedPet copy() => OwnedPet(
    id: id,
    stage: stage,
    progress: progress,
    fedDay: fedDay,
    worn: Map.of(worn),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    if (stage > 0) 'stage': stage,
    if (progress > 0) 'progress': progress,
    if (fedDay > 0) 'fedDay': fedDay,
    if (worn.isNotEmpty) 'worn': worn,
  };

  static OwnedPet? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    int n(String k) => raw[k] is num ? (raw[k] as num).toInt() : 0;
    return OwnedPet(
      id: id,
      stage: n('stage').clamp(0, 2),
      progress: n('progress').clamp(0, 100),
      fedDay: n('fedDay'),
      worn: {
        for (final e in ((raw['worn'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
    );
  }
}

/// The cat's pet id. Matches `giftCat` in logic/pet.dart.
/// Most removed-notice ids one save keeps (the newest win; the board never
/// shows more than a few dozen notices).
const maxHiddenNotices = 200;

/// The newest [maxHiddenNotices] of [ids] (oldest first), without repeats.
List<String> lastHiddenNotices(Iterable<String> ids) {
  final list = ids.toSet().toList();
  return list.length <= maxHiddenNotices
      ? list
      : list.sublist(list.length - maxHiddenNotices);
}

const catPetId = 'meo';

/// A group of stems of one flower bought on the same morning.
class StockBatch {
  StockBatch({
    required this.flowerId,
    required this.count,
    required this.freshnessLeft,
  });

  final String flowerId;
  int count;

  /// Days left before the stems wilt (1 = last fresh day).
  int freshnessLeft;

  Map<String, Object?> toJson() => {
    'flowerId': flowerId,
    'count': count,
    'freshnessLeft': freshnessLeft,
  };

  static StockBatch fromJson(Map<String, dynamic> j) => StockBatch(
    flowerId: j['flowerId'] as String,
    count: (j['count'] as num).toInt(),
    freshnessLeft: (j['freshnessLeft'] as num).toInt(),
  );
}

/// One saved customer review (spec_danh_gia.md "Dữ liệu mỗi nhận xét").
class ReviewRecord {
  const ReviewRecord({
    required this.day,
    required this.customerName,
    required this.avatarId,
    required this.occasionId,
    required this.stars,
    required this.comment,
    required this.outcome,
    this.stems = const {},
    this.paperId,
    this.ribbonId,
    this.online = false,
    this.deliveryIssue,
    this.replyText,
    this.customerReply,
    this.starRaised = false,
    this.byStaff = false,
    this.cardText,
  });

  final int day;
  final String customerName;
  final String avatarId;
  final String occasionId;
  final int stars;
  final String comment;

  /// great, okay, unhappy, leftUnserved or onlineMissed.
  final String outcome;
  final Map<String, int> stems;
  final String? paperId;
  final String? ribbonId;

  /// Online-order review (chip "Đơn online" instead of the occasion).
  final bool online;

  /// `late` ("Giao trễ") or `missed` ("Lỡ đơn"). Null for an on-time order.
  final String? deliveryIssue;

  /// Owner reply, at most 80 characters. Null until the player sends one.
  final String? replyText;

  /// What the customer wrote back after [replyText]. Null until then.
  final String? customerReply;

  /// The reply was an untouched sorry or improve suggestion and added 1 star.
  final bool starRaised;

  /// The florist (staff level 2) wrapped this bouquet, not the player.
  final bool byStaff;

  /// Note written on the bouquet. Null when the player skipped the card.
  final String? cardText;

  ReviewRecord copyWith({
    String? replyText,
    String? customerReply,
    int? stars,
    bool? starRaised,
  }) => ReviewRecord(
    day: day,
    customerName: customerName,
    avatarId: avatarId,
    occasionId: occasionId,
    stars: stars ?? this.stars,
    comment: comment,
    outcome: outcome,
    stems: stems,
    paperId: paperId,
    ribbonId: ribbonId,
    online: online,
    deliveryIssue: deliveryIssue,
    replyText: replyText ?? this.replyText,
    customerReply: customerReply ?? this.customerReply,
    starRaised: starRaised ?? this.starRaised,
    byStaff: byStaff,
    cardText: cardText,
  );

  Map<String, Object?> toJson() => {
    'day': day,
    'customerName': customerName,
    'avatarId': avatarId,
    'occasionId': occasionId,
    'stars': stars,
    'comment': comment,
    'outcome': outcome,
    'bouquet': {'stems': stems, 'paperId': paperId, 'ribbonId': ribbonId},
    'online': online,
    'deliveryIssue': deliveryIssue,
    if (replyText != null) 'replyText': replyText,
    if (customerReply != null) 'customerReply': customerReply,
    if (starRaised) 'starRaised': true,
    if (byStaff) 'byStaff': true,
    if (cardText != null) 'cardText': cardText,
  };

  static ReviewRecord fromJson(Map<String, dynamic> j) {
    final b = (j['bouquet'] as Map<String, dynamic>?) ?? const {};
    return ReviewRecord(
      day: (j['day'] as num).toInt(),
      customerName: j['customerName'] as String,
      // Older saves stored a number; those fall back to the placeholder.
      avatarId: j['avatarId'] is String ? j['avatarId'] as String : '',
      occasionId: j['occasionId'] as String,
      stars: (j['stars'] as num).toInt(),
      comment: j['comment'] as String,
      outcome: j['outcome'] as String,
      stems: {
        for (final e in ((b['stems'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      paperId: b['paperId'] as String?,
      ribbonId: b['ribbonId'] as String?,
      online: j['online'] == true,
      deliveryIssue: j['deliveryIssue'] as String?,
      replyText: j['replyText'] as String?,
      customerReply: j['customerReply'] as String?,
      starRaised: j['starRaised'] == true,
      byStaff: j['byStaff'] == true,
      cardText: j['cardText'] as String?,
    );
  }
}

/// Horizontal bar across the shop, and the wooden display stand.
const barPotSlots = 5;
const displayPotSlots = 6;
const defaultPotId = 'sage';

/// A slot list of [length], missing entries filled with the free bucket.
List<String> fillPotSlots(List<String>? raw, int length) {
  final out = <String>[...?raw];
  while (out.length < length) {
    out.add(defaultPotId);
  }
  if (out.length > length) out.removeRange(length, out.length);
  return out;
}

/// Where the day loop is: market -> preparing -> open -> summary.
enum DayPhase { market, preparing, open, summary }

/// One garden bed. An empty [flowerId] is bare soil. [stage] 0 is the sprout,
/// 1 the leafy plant, 2 a bloom ready to cut. [nextAtMs] is when the next
/// watering comes due, in epoch milliseconds.
class GardenPlot {
  GardenPlot({
    this.tilled = false,
    this.flowerId,
    this.stage = 0,
    this.nextAtMs = 0,
  });

  bool tilled;
  String? flowerId;
  int stage;
  int nextAtMs;

  GardenPlot copy() => GardenPlot(
    tilled: tilled,
    flowerId: flowerId,
    stage: stage,
    nextAtMs: nextAtMs,
  );

  Map<String, Object?> toJson() => {
    'tilled': tilled,
    if (flowerId != null) 'flowerId': flowerId,
    if (stage != 0) 'stage': stage,
    if (nextAtMs != 0) 'nextAtMs': nextAtMs,
  };

  static GardenPlot fromJson(Map<String, dynamic> j) => GardenPlot(
    tilled: j['tilled'] == true,
    flowerId: j['flowerId'] as String?,
    stage: (j['stage'] as num?)?.toInt() ?? 0,
    nextAtMs: (j['nextAtMs'] as num?)?.toInt() ?? 0,
  );
}

/// [count] dry beds. Each one needs a shovel before it can be planted.
List<GardenPlot> freshGardenPlots(int count) => [
  for (var i = 0; i < count; i++) GardenPlot(),
];

/// Everything saved between sessions (browser localStorage on web).
///
/// Progress is committed only at day boundaries (spec_popup_va_mo_dau.md
/// "Tiến độ lưu tới sáng nay"): the save is always a start-of-day state in
/// the market phase. Leaving mid-day replays the day from that morning.
class GameState {
  GameState({
    required this.money,
    required this.day,
    required this.lifetimeBouquetsSold,
    required this.stock,
    required this.reviews,
    required this.goals,
    required this.metrics,
    required this.phase,
    this.elapsed = 0,
    List<double>? pendingArrivals,
    List<String>? recentOrderLines,
    Map<String, int>? upgradeLevels,
    List<String>? unlockedItems,
    this.adsDaysLeft = 0,
    this.tutorialDone = false,
    this.reviewIntroSeen = false,
    this.rankSeen = 1,
    Map<String, int>? shipperLevels,
    this.ordersFromDay = 0,
    this.musicOn = true,
    this.sfxOn = true,
    this.ownerAvatar = defaultOwnerAvatar,
    this.ownerAvatarRev = 0,
    this.shopName,
    this.priceMultiplier = 1,
    this.shovels = 0,
    this.earlyClosesInARow = 0,
    bool hasCat = false,
    int petStage = 0,
    int petProgress = 0,
    int petFedDay = 0,
    List<OwnedPet>? pets,
    this.petIncome,
    this.petCharm,
    this.biscuits = 0,
    this.drops = 0,
    this.stones = 0,
    this.phaLe = 0,
    List<String>? petSeats,
    List<String>? petBowls,
    this.petSeat,
    this.petBowl,
    this.appliedGiftId,
    this.strayCatSeen = false,
    Map<String, int>? seeds,
    List<GardenPlot>? plots,
    Map<String, int>? potCounts,
    Map<String, int>? petItems,
    List<String>? potShopSeenIds,
    List<String>? hiddenNotices,
    this.potShopHintShown = false,
    List<String>? claimedSets,
    List<String>? barPots,
    List<String>? displayPots,
    List<int>? recentRevenue,
    this.lastBadEventDay = 0,
    this.accountUid,
    this.appliedGrantId,
  }) : pendingArrivals = pendingArrivals ?? [],
       seeds = seeds ?? {},
       plots = plots ?? [],
       potCounts = potCounts ?? {},
       petItems = petItems ?? {},
       potShopSeenIds = potShopSeenIds ?? [],
       hiddenNotices = hiddenNotices ?? [],
       claimedSets = claimedSets ?? [],
       barPots = fillPotSlots(barPots, barPotSlots),
       displayPots = fillPotSlots(displayPots, displayPotSlots),
       recentOrderLines = recentOrderLines ?? [],
       upgradeLevels = upgradeLevels ?? {},
       unlockedItems = unlockedItems ?? [],
       shipperLevels = shipperLevels ?? {},
       recentRevenue = recentRevenue ?? [],
       petSeats = petSeats ?? [],
       petBowls = petBowls ?? [],
       pets = pets ?? [] {
    // Older saves only knew the cat: it becomes an owned pet in both slots.
    if (hasCat && ownedPet(catPetId) == null) {
      this.pets.add(
        OwnedPet(
          id: catPetId,
          stage: petStage.clamp(0, 2),
          progress: petProgress.clamp(0, 100),
          fedDay: petFedDay,
        ),
      );
      petIncome ??= catPetId;
      petCharm ??= catPetId;
    }
    _fillSlots();
  }

  /// Bump when the format changes. Version 2 saves still load; a missing
  /// [shopName] means the title screen asks once. Anything older starts over.
  static const schemaVersion = 3;

  /// spec_danh_gia.md: keep at most 50 reviews in the browser save.
  static const maxSavedReviews = 50;

  int money;
  int day;
  int lifetimeBouquetsSold;
  List<StockBatch> stock;

  /// Oldest first.
  List<ReviewRecord> reviews;
  List<DailyGoal> goals;
  DayMetrics metrics;
  DayPhase phase;

  /// Real seconds since the shop opened today.
  double elapsed;

  /// Arrival times (seconds since opening) not yet spawned today.
  List<double> pendingArrivals;

  /// Recently used request lines, for orders.json `noRepeatLast`.
  List<String> recentOrderLines;

  /// Upgrade id to owned level (missing = not owned).
  Map<String, int> upgradeLevels;

  /// Flower, paper and ribbon ids unlocked (start items included).
  List<String> unlockedItems;

  /// Days of the consumable ad left, today included (0 = not running).
  int adsDaysLeft;

  /// First-day tutorial finished or skipped (spec_popup_va_mo_dau.md §6).
  bool tutorialDone;

  /// The full review card has been shown once. Later sales use a short line.
  bool reviewIntroSeen;

  /// Highest shop rank already celebrated with the rank-up popup.
  int rankSeen;

  /// Shipper id to owned level (missing or 0 = not hired). Level 1 is the hire.
  Map<String, int> shipperLevels;

  /// First morning online orders appear. 0 = no shipper hired yet.
  int ordersFromDay;

  /// Background music switch (spec_cai_dat.md). Default on.
  bool musicOn;

  /// Effect switch under the music switch. Default on; ambience counts.
  bool sfxOn;

  /// Preset id, `google`, or a Storage path from "Tải ảnh lên".
  String ownerAvatar;

  /// Cache-buster for an uploaded photo. 0 for presets.
  int ownerAvatarRev;

  /// Null on a save from before naming existed. The title screen asks once.
  String? shopName;

  /// Walk-in price level from Giá bán. 1 is the normal price. Old saves
  /// omit it and stay at 1.
  double priceMultiplier;

  /// Seed packets waiting to be planted, keyed by flower id.
  Map<String, int> seeds;

  /// Shovels waiting to turn a dry bed into fresh soil.
  int shovels;

  /// Days closed before the clock hit closing time, in a row. Two means the
  /// next open day must stay until closing time.
  int earlyClosesInARow;

  /// Pets the shop owns, in the order they arrived.
  List<OwnedPet> pets;

  /// Pet in the "Thu nhập" slot: only its abilities work.
  String? petIncome;

  /// Pet in the "Mị lực" slot (the charm board, later). May be the same
  /// pet as [petIncome].
  String? petCharm;

  OwnedPet? ownedPet(String id) {
    for (final pet in pets) {
      if (pet.id == id) return pet;
    }
    return null;
  }

  bool ownsPet(String id) => ownedPet(id) != null;

  /// Adds a pet at ấu thú. The very first pet takes both slots; after that
  /// the player decides in the slot picker, so a slot emptied on purpose
  /// stays empty. Returns false when it is already owned.
  bool addPet(String id, {int fedDay = 0}) {
    if (ownsPet(id)) return false;
    final first = pets.isEmpty;
    pets.add(OwnedPet(id: id, fedDay: fedDay));
    _fillSlots();
    if (first) {
      petIncome ??= id;
      petCharm ??= id;
    }
    return true;
  }

  /// Slots pointing at a pet no longer owned are cleared.
  void _fillSlots() {
    if (petIncome != null && !ownsPet(petIncome!)) petIncome = null;
    if (petCharm != null && !ownsPet(petCharm!)) petCharm = null;
  }

  OwnedPet? get _cat => ownedPet(catPetId);

  /// The cream cat. False until a gift, the day-5 stray, or a purchase.
  bool get hasCat => _cat != null;
  set hasCat(bool value) {
    if (value) {
      addPet(catPetId);
    } else {
      pets.removeWhere((p) => p.id == catPetId);
      _fillSlots();
    }
  }

  /// The cat's stage: 0 ấu thú, 1 lớn, 2 trưởng thành. 0 without a cat.
  int get petStage => _cat?.stage ?? 0;
  set petStage(int value) => _cat?.stage = value;

  /// The cat's bar, 0..100.
  int get petProgress => _cat?.progress ?? 0;
  set petProgress(int value) => _cat?.progress = value;

  /// Last morning the cat was fed.
  int get petFedDay => _cat?.fedDay ?? 0;
  set petFedDay(int value) => _cat?.fedDay = value;

  /// Bánh mật waiting to be eaten.
  int biscuits;

  /// Giọt hoa. Gifts and the mysterious guest both add these. Breakthrough
  /// spends them: 10, then 100. [stones] is an older save of the same thing.
  int drops;

  /// Older saves stored giọt hoa here. Counted with [drops] and folded in
  /// on the next breakthrough.
  int stones;

  /// Seat skins the player owns.
  List<String> petSeats;

  /// Bowl skins the player owns.
  List<String> petBowls;

  /// Seat on the floor. Null until the first cushion arrives.
  String? petSeat;

  /// Bowl on the floor. Null until the first bowl arrives.
  String? petBowl;

  /// Last gift shipment already added. The same id does nothing again.
  String? appliedGiftId;

  /// Pha lê held. Only rewards add it (no shop yet). Old saves load 0.
  int phaLe;

  /// The day-5 stray kitten was already accepted or turned away.
  bool strayCatSeen;

  /// Garden beds. An old save leaves this empty; the session fills it.
  List<GardenPlot> plots;

  /// Pot id to copies bought. The free sage bucket is not stored here.
  Map<String, int> potCounts;

  /// Pet item id to copies owned (worn or not). Nothing hands items out yet.
  Map<String, int> petItems;

  /// Pots on sale the player has already seen in Tiệm Chậu Hoa. A pot on
  /// sale that is not here lights the red dot on the "Chậu hoa" tab.
  List<String> potShopSeenIds;

  /// Tin tức the player removed (notice ids, oldest first, at most
  /// [maxHiddenNotices]). Kept in the save so a removed notice stays removed on
  /// every device of the account, not only in this browser.
  List<String> hiddenNotices;

  /// The one-time reminder about Tiệm Chậu Hoa (hint box or Tổng kết card)
  /// has been shown, or the player found the shop by themselves.
  bool potShopHintShown;

  /// Pot collections (`potCollections` ids) whose reward was claimed.
  List<String> claimedSets;

  /// Pot id in each of the 5 horizontal-bar slots.
  List<String> barPots;

  /// Pot id in each of the 6 display-shelf slots.
  List<String> displayPots;

  /// Revenue of the last three open days, oldest first. Event prices use this.
  List<int> recentRevenue;

  /// Day number of the last bad event. 0 means none yet.
  int lastBadEventDay;

  /// Google account this morning belongs to. Null until someone signs in.
  String? accountUid;

  /// Last compensation id already added into [money]. A repeat of the same
  /// id does nothing, so a later login cannot pay it twice.
  String? appliedGrantId;

  static const defaultOwnerAvatar = 'minh_anh';

  void addReview(ReviewRecord r) {
    reviews.add(r);
    if (reviews.length > maxSavedReviews) {
      reviews.removeRange(0, reviews.length - maxSavedReviews);
    }
  }

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'money': money,
    'day': day,
    'lifetimeBouquetsSold': lifetimeBouquetsSold,
    'stock': [for (final s in stock) s.toJson()],
    'reviews': [for (final r in reviews) r.toJson()],
    'goals': [for (final g in goals) g.toJson()],
    'metrics': metrics.toJson(),
    'phase': phase.name,
    'elapsed': elapsed,
    'pendingArrivals': pendingArrivals,
    'recentOrderLines': recentOrderLines,
    'upgradeLevels': upgradeLevels,
    'unlockedItems': unlockedItems,
    'adsDaysLeft': adsDaysLeft,
    'tutorialDone': tutorialDone,
    'reviewIntroSeen': reviewIntroSeen,
    'rankSeen': rankSeen,
    'shipperLevels': shipperLevels,
    'ordersFromDay': ordersFromDay,
    'musicOn': musicOn,
    'sfxOn': sfxOn,
    'ownerAvatar': ownerAvatar,
    'ownerAvatarRev': ownerAvatarRev,
    if (shopName != null) 'shopName': shopName,
    'priceMultiplier': priceMultiplier,
    if (seeds.isNotEmpty) 'seeds': seeds,
    if (shovels > 0) 'shovels': shovels,
    if (earlyClosesInARow > 0) 'earlyClosesInARow': earlyClosesInARow,
    if (pets.isNotEmpty) 'pets': [for (final p in pets) p.toJson()],
    if (petIncome != null) 'petIncome': petIncome,
    if (petCharm != null) 'petCharm': petCharm,
    // The cat also keeps its old keys so an older build still finds it.
    if (hasCat) 'hasCat': true,
    if (petStage > 0) 'petStage': petStage,
    if (petProgress > 0) 'petProgress': petProgress,
    if (petFedDay > 0) 'petFedDay': petFedDay,
    if (biscuits > 0) 'biscuits': biscuits,
    if (drops > 0) 'drops': drops,
    if (stones > 0) 'stones': stones,
    if (phaLe > 0) 'phaLe': phaLe,
    if (petSeats.isNotEmpty) 'petSeats': petSeats,
    if (petBowls.isNotEmpty) 'petBowls': petBowls,
    if (petSeat != null) 'petSeat': petSeat,
    if (petBowl != null) 'petBowl': petBowl,
    if (appliedGiftId != null) 'appliedGiftId': appliedGiftId,
    if (strayCatSeen) 'strayCatSeen': true,
    'plots': [for (final p in plots) p.toJson()],
    if (potCounts.isNotEmpty) 'potCounts': potCounts,
    if (petItems.isNotEmpty) 'petItems': petItems,
    if (potShopSeenIds.isNotEmpty) 'potShopSeenIds': potShopSeenIds,
    if (hiddenNotices.isNotEmpty) 'hiddenNotices': hiddenNotices,
    if (potShopHintShown) 'potShopHintShown': true,
    if (claimedSets.isNotEmpty) 'claimedSets': claimedSets,
    'barPots': barPots,
    'displayPots': displayPots,
    if (recentRevenue.isNotEmpty) 'recentRevenue': recentRevenue,
    if (lastBadEventDay > 0) 'lastBadEventDay': lastBadEventDay,
    if (accountUid != null) 'accountUid': accountUid,
    if (appliedGrantId != null) 'appliedGrantId': appliedGrantId,
  };

  String encode() => jsonEncode(toJson());

  /// Missing, corrupt, or older-format data returns null (= new game).
  static GameState? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return null;
      final version = j['version'];
      if (version != 2 && version != schemaVersion) return null;
      return GameState(
        money: (j['money'] as num).toInt(),
        day: (j['day'] as num).toInt(),
        lifetimeBouquetsSold: (j['lifetimeBouquetsSold'] as num).toInt(),
        stock: [
          for (final s in j['stock'] as List)
            StockBatch.fromJson(s as Map<String, dynamic>),
        ],
        reviews: [
          for (final r in j['reviews'] as List)
            ReviewRecord.fromJson(r as Map<String, dynamic>),
        ],
        goals: [
          for (final g in j['goals'] as List)
            DailyGoal.fromJson(g as Map<String, dynamic>),
        ],
        metrics: DayMetrics.fromJson(j['metrics'] as Map<String, dynamic>),
        phase: DayPhase.values.byName(j['phase'] as String),
        elapsed: (j['elapsed'] as num).toDouble(),
        pendingArrivals: [
          for (final t in j['pendingArrivals'] as List) (t as num).toDouble(),
        ],
        recentOrderLines: (j['recentOrderLines'] as List).cast<String>(),
        upgradeLevels: {
          for (final e in (j['upgradeLevels'] as Map).entries)
            e.key as String: (e.value as num).toInt(),
        },
        unlockedItems: (j['unlockedItems'] as List).cast<String>(),
        adsDaysLeft: (j['adsDaysLeft'] as num).toInt(),
        tutorialDone: j['tutorialDone'] == true,
        reviewIntroSeen: j['reviewIntroSeen'] == true,
        rankSeen: (j['rankSeen'] as num?)?.toInt() ?? 1,
        shipperLevels: {
          for (final e in ((j['shipperLevels'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        ordersFromDay: (j['ordersFromDay'] as num?)?.toInt() ?? 0,
        musicOn: j['musicOn'] != false,
        sfxOn: j['sfxOn'] != false,
        ownerAvatar:
            j['ownerAvatar'] is String &&
                (j['ownerAvatar'] as String).isNotEmpty
            ? j['ownerAvatar'] as String
            : defaultOwnerAvatar,
        ownerAvatarRev: (j['ownerAvatarRev'] as num?)?.toInt() ?? 0,
        potCounts: {
          for (final e in ((j['potCounts'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        petItems: {
          for (final e in ((j['petItems'] as Map?) ?? const {}).entries)
            if (e.key is String && e.value is num && (e.value as num) > 0)
              e.key as String: (e.value as num).toInt(),
        },
        potShopSeenIds: [
          for (final id in (j['potShopSeenIds'] as List?) ?? const [])
            if (id is String) id,
        ],
        hiddenNotices: lastHiddenNotices([
          for (final id in (j['hiddenNotices'] as List?) ?? const [])
            if (id is String && id.isNotEmpty && id.length <= 80) id,
        ]),
        potShopHintShown: j['potShopHintShown'] == true,
        claimedSets: [
          for (final id in (j['claimedSets'] as List?) ?? const [])
            if (id is String) id,
        ],
        barPots: (j['barPots'] as List?)?.cast<String>(),
        displayPots: (j['displayPots'] as List?)?.cast<String>(),
        recentRevenue: [
          for (final n in (j['recentRevenue'] as List?) ?? const [])
            (n as num).toInt(),
        ],
        lastBadEventDay: (j['lastBadEventDay'] as num?)?.toInt() ?? 0,
        accountUid:
            j['accountUid'] is String && (j['accountUid'] as String).isNotEmpty
            ? j['accountUid'] as String
            : null,
        appliedGrantId:
            j['appliedGrantId'] is String &&
                (j['appliedGrantId'] as String).isNotEmpty
            ? j['appliedGrantId'] as String
            : null,
        shopName:
            j['shopName'] is String && (j['shopName'] as String).isNotEmpty
            ? j['shopName'] as String
            : null,
        priceMultiplier: (j['priceMultiplier'] as num?)?.toDouble() ?? 1,
        shovels: (j['shovels'] as num?)?.toInt() ?? 0,
        earlyClosesInARow: (j['earlyClosesInARow'] as num?)?.toInt() ?? 0,
        // `pets` wins; a save without it migrates the cat (hasCat).
        pets: j['pets'] is List
            ? [for (final p in j['pets'] as List) ?OwnedPet.fromJson(p)]
            : null,
        hasCat: j['pets'] is! List && j['hasCat'] == true,
        petStage: (j['petStage'] as num?)?.toInt() ?? 0,
        petProgress: (j['petProgress'] as num?)?.toInt() ?? 0,
        petFedDay: (j['petFedDay'] as num?)?.toInt() ?? 0,
        petIncome: j['petIncome'] is String ? j['petIncome'] as String : null,
        petCharm: j['petCharm'] is String ? j['petCharm'] as String : null,
        biscuits: (j['biscuits'] as num?)?.toInt() ?? 0,
        drops: (j['drops'] as num?)?.toInt() ?? 0,
        stones: (j['stones'] as num?)?.toInt() ?? 0,
        phaLe: j['phaLe'] is num && (j['phaLe'] as num) > 0
            ? (j['phaLe'] as num).toInt()
            : 0,
        petSeats: [
          for (final id in (j['petSeats'] as List?) ?? const [])
            if (id is String) id,
        ],
        petBowls: [
          for (final id in (j['petBowls'] as List?) ?? const [])
            if (id is String) id,
        ],
        petSeat: j['petSeat'] is String && (j['petSeat'] as String).isNotEmpty
            ? j['petSeat'] as String
            : null,
        petBowl: j['petBowl'] is String && (j['petBowl'] as String).isNotEmpty
            ? j['petBowl'] as String
            : null,
        appliedGiftId:
            j['appliedGiftId'] is String &&
                (j['appliedGiftId'] as String).isNotEmpty
            ? j['appliedGiftId'] as String
            : null,
        strayCatSeen: j['strayCatSeen'] == true,
        seeds: {
          for (final e in ((j['seeds'] as Map?) ?? const {}).entries)
            if ((e.value as num).toInt() > 0)
              e.key as String: (e.value as num).toInt(),
        },
        plots: [
          for (final p in (j['plots'] as List?) ?? const [])
            GardenPlot.fromJson(p as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}
