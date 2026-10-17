import 'dart:math' as math;

import 'charm_board.dart' show isValidPeriodKey;

/// Bảng xếp hạng Đánh giá (spec Phú mục 2, block `ratingBoard` of Hà
/// Phương in economy.json). The score is counted on the server
/// (functions/rating_board.js) from the cloud save; the app only reads
/// `rating_board/{periodKey}` and its `entries`, and the rules refuse every
/// write from a client.

/// One reward line of the board (`ratingBoard.rewards`).
class RatingBoardReward {
  const RatingBoardReward({
    required this.rankFrom,
    required this.rankTo,
    this.phaLe = 0,
    this.giotHoa = 0,
    this.coins = 0,
    this.badge = '',
  });

  final int rankFrom;
  final int rankTo;
  final int phaLe;
  final int giotHoa;
  final int coins;

  /// "Tiệm 5 sao mùa" for #1 (shown nowhere yet).
  final String badge;

  bool covers(int rank) => rank >= rankFrom && rank <= rankTo;

  static RatingBoardReward? fromJson(Object? json) {
    if (json is! Map) return null;
    final from = json['rankFrom'];
    final to = json['rankTo'];
    if (from is! num || to is! num || from < 1 || to < from) return null;
    int n(String k) =>
        json[k] is num && (json[k] as num) > 0 ? (json[k] as num).toInt() : 0;
    final badge = json['badge'];
    return RatingBoardReward(
      rankFrom: from.toInt(),
      rankTo: to.toInt(),
      phaLe: n('phaLe'),
      giotHoa: n('giotHoa'),
      coins: n('coins'),
      badge: badge is String ? badge : '',
    );
  }
}

/// `ratingBoard` in economy.json. [enabled] is false when the block is
/// missing or has no valid period/start: no tab is shown then.
class RatingBoardConfig {
  const RatingBoardConfig({
    this.enabled = false,
    this.periodKey = 'rating-1',
    this.seasonNumber = 0,
    this.seasonStart,
    this.cycleDays = 28,
    this.refreshMinutes = 15,
    this.m = 100,
    this.cFallback = 4.0,
    this.minToRank = 50,
    this.limit = 100,
    this.rewards = const [],
  });

  static const disabled = RatingBoardConfig();

  final bool enabled;
  final String periodKey;

  /// "mùa {so_mua}" of `board.rating.not_started` and the reward mail.
  final int seasonNumber;

  /// First moment of the season (00:00 Vietnam time) as a UTC instant.
  final DateTime? seasonStart;
  final int cycleDays;
  final int refreshMinutes;

  /// The weight of the server average (`m`, 100).
  final int m;

  /// `C` until the server has enough reviews ({rating_c}, 4,0).
  final double cFallback;

  /// {rating_min}: reviews this season to be on the board (50).
  final int minToRank;

  /// Rows read ({board_size}, top 100; the rules refuse more).
  final int limit;
  final List<RatingBoardReward> rewards;

  DateTime? get seasonEnd => seasonStart?.add(Duration(days: cycleDays));
  Duration get refreshEvery => Duration(minutes: refreshMinutes);

  RatingBoardReward? rewardFor(int rank) {
    for (final r in rewards) {
      if (r.covers(rank)) return r;
    }
    return null;
  }

  factory RatingBoardConfig.fromJson(Object? json) {
    if (json is! Map) return disabled;
    final key = json['periodKey'];
    final start = json['seasonStart'];
    DateTime? startAt;
    if (start is String) {
      final d = DateTime.tryParse(start);
      if (d != null) {
        startAt = DateTime.utc(
          d.year,
          d.month,
          d.day,
        ).subtract(const Duration(hours: 7));
      }
    }
    if (key is! String || !isValidPeriodKey(key) || startAt == null) {
      return disabled;
    }
    int whole(Object? v, int dflt, {int min = 1}) =>
        v is num && v >= min ? v.toInt() : dflt;
    final c = json['C'];
    final fallback = c is Map ? c['fallback'] : null;
    final raw = json['rewards'];
    return RatingBoardConfig(
      enabled: true,
      periodKey: key,
      seasonNumber: whole(json['seasonNumber'], 0, min: 0),
      seasonStart: startAt,
      cycleDays: whole(json['cycleDays'], 28),
      refreshMinutes: whole(json['refreshMinutes'], 15),
      m: whole(json['m'], 100),
      cFallback: fallback is num && fallback > 0 ? fallback.toDouble() : 4.0,
      minToRank: whole(json['minRatingsToRank'], 50),
      limit: math.min(100, whole(json['topLimit'], 100)),
      rewards: [
        if (raw is List)
          for (final r in raw) ?RatingBoardReward.fromJson(r),
      ],
    );
  }
}

/// One shop's row, as the server wrote it.
class RatingEntry {
  const RatingEntry({
    required this.uid,
    required this.displayName,
    this.avatar = '',
    required this.v,
    required this.sum,
    required this.score,
    required this.sortKey,
    this.reachedAt,
  });

  final String uid;
  final String displayName;

  /// Built-in avatar path (player_avatars), '' for the initial.
  final String avatar;

  /// Reviews counted this season.
  final int v;

  /// Sum of their stars.
  final int sum;

  /// Weighted score (server, with the season C).
  final double score;

  /// score rounded to 3 decimals, then v: what the board is ordered by.
  /// 0 = under the minimum, not on the board.
  final int sortKey;

  /// When this sortKey was first reached (the last tie-break).
  final DateTime? reachedAt;

  static RatingEntry? fromMap(
    String uid,
    Map<String, Object?> m, {
    DateTime? reachedAt,
  }) {
    final v = m['v'];
    final sum = m['sum'];
    final score = m['score'];
    final key = m['sortKey'];
    if (v is! num || sum is! num || score is! num || key is! num) return null;
    final name = m['displayName'];
    final avatar = m['avatar'];
    return RatingEntry(
      uid: uid,
      displayName: name is String && name.isNotEmpty ? name : 'Chủ tiệm',
      avatar: avatar is String ? avatar : '',
      v: v.toInt(),
      sum: sum.toInt(),
      score: score.toDouble(),
      sortKey: key.toInt(),
      reachedAt: reachedAt,
    );
  }
}

/// A ranked row.
class RatingRow {
  const RatingRow(this.rank, this.entry);

  final int rank;
  final RatingEntry entry;
}

/// Orders server rows: sortKey (score to 3 decimals, then reviews), then
/// who reached it first. Rows under the minimum (sortKey 0) are dropped.
List<RatingRow> rankRatingBoard(Iterable<RatingEntry> rows, {int limit = 100}) {
  final list = [
    for (final r in rows)
      if (r.sortKey > 0) r,
  ];
  final far = DateTime.utc(9999);
  list.sort((a, b) {
    final k = b.sortKey.compareTo(a.sortKey);
    if (k != 0) return k;
    final t = (a.reachedAt ?? far).compareTo(b.reachedAt ?? far);
    return t != 0 ? t : a.uid.compareTo(b.uid);
  });
  return [
    for (var i = 0; i < list.length && i < limit; i++) RatingRow(i + 1, list[i]),
  ];
}

/// Where the board lives (Firestore in firestore_rating_board.dart). Read
/// only: there is no write, the server is the only writer.
abstract class RatingBoardSource {
  Future<List<RatingRow>> top({required String period, int limit = 100});

  /// One shop's row (null when it has none this season).
  Future<RatingEntry?> entry({required String period, required String uid});
}

/// In memory (tests, offline). [rows] stands in for what the server wrote.
class MemoryRatingBoard implements RatingBoardSource {
  MemoryRatingBoard({Map<String, Map<String, RatingEntry>>? rows})
    : rows = rows ?? {};

  final Map<String, Map<String, RatingEntry>> rows;
  int reads = 0;
  bool fail = false;

  void put(String period, RatingEntry e) =>
      rows.putIfAbsent(period, () => {})[e.uid] = e;

  @override
  Future<List<RatingRow>> top({required String period, int limit = 100}) async {
    reads++;
    if (fail) throw StateError('offline');
    if (limit > 100) throw ArgumentError('at most 100 rows');
    return rankRatingBoard(rows[period]?.values ?? const [], limit: limit);
  }

  @override
  Future<RatingEntry?> entry({
    required String period,
    required String uid,
  }) async {
    if (fail) throw StateError('offline');
    return rows[period]?[uid];
  }
}

/// "4,72": two decimals, Vietnamese comma (spec 2.3, Nhất 3b).
String ratingScoreText(double score) =>
    score.toStringAsFixed(2).replaceAll('.', ',');
