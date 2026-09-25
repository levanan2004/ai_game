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
  });

  final int day;
  final String customerName;
  final int avatarId;
  final String occasionId;
  final int stars;
  final String comment;

  /// great, okay, unhappy, leftUnserved or onlineMissed.
  final String outcome;
  final Map<String, int> stems;
  final String? paperId;
  final String? ribbonId;

  Map<String, Object?> toJson() => {
    'day': day,
    'customerName': customerName,
    'avatarId': avatarId,
    'occasionId': occasionId,
    'stars': stars,
    'comment': comment,
    'outcome': outcome,
    'bouquet': {'stems': stems, 'paperId': paperId, 'ribbonId': ribbonId},
  };

  static ReviewRecord fromJson(Map<String, dynamic> j) {
    final b = (j['bouquet'] as Map<String, dynamic>?) ?? const {};
    return ReviewRecord(
      day: (j['day'] as num).toInt(),
      customerName: j['customerName'] as String,
      avatarId: (j['avatarId'] as num).toInt(),
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
    );
  }
}

/// Where the day loop is: market -> preparing -> open -> summary.
enum DayPhase { market, preparing, open, summary }

/// Everything saved between sessions (browser localStorage on web).
///
/// Customers standing in the queue are not saved: after a reload during an
/// open day, the clock and remaining arrivals resume with an empty queue.
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
  }) : pendingArrivals = pendingArrivals ?? [],
       recentOrderLines = recentOrderLines ?? [],
       upgradeLevels = upgradeLevels ?? {},
       unlockedItems = unlockedItems ?? [];

  /// Bump when the format changes; older saves start a new game.
  static const schemaVersion = 2;

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
  };

  String encode() => jsonEncode(toJson());

  /// Missing, corrupt, or older-format data returns null (= new game).
  static GameState? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return null;
      if (j['version'] != schemaVersion) return null;
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
      );
    } catch (_) {
      return null;
    }
  }
}
