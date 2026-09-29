import 'dart:convert';

import '../logic/goals.dart';

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
    Map<String, int>? potCounts,
    List<String>? barPots,
    List<String>? displayPots,
  }) : pendingArrivals = pendingArrivals ?? [],
       potCounts = potCounts ?? {},
       barPots = fillPotSlots(barPots, barPotSlots),
       displayPots = fillPotSlots(displayPots, displayPotSlots),
       recentOrderLines = recentOrderLines ?? [],
       upgradeLevels = upgradeLevels ?? {},
       unlockedItems = unlockedItems ?? [],
       shipperLevels = shipperLevels ?? {};

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

  /// Pot id to copies bought. The free sage bucket is not stored here.
  Map<String, int> potCounts;

  /// Pot id in each of the 5 horizontal-bar slots.
  List<String> barPots;

  /// Pot id in each of the 6 display-shelf slots.
  List<String> displayPots;

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
    if (potCounts.isNotEmpty) 'potCounts': potCounts,
    'barPots': barPots,
    'displayPots': displayPots,
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
        barPots: (j['barPots'] as List?)?.cast<String>(),
        displayPots: (j['displayPots'] as List?)?.cast<String>(),
        shopName:
            j['shopName'] is String && (j['shopName'] as String).isNotEmpty
            ? j['shopName'] as String
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}
