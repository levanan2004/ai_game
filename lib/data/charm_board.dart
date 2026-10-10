/// Bảng xếp hạng Mị lực: the data layer only (no screen, no rewards yet).
///
/// Firestore shape, one document per player per period:
///
///     charm_board/{periodKey}/entries/{uid}
///       uid         string   same as the document id and request.auth.uid
///       displayName string   1..40 characters (rules allow 80)
///       avatar      string   pointer to the portrait, same kind of value
///                            as `player_avatars/{uid}.path`; '' for none
///       charm       int      [charmBoardMinCharm]..[charmBoardMaxCharm]
///       petId       string   the pet in the Mị lực slot ('' when unknown)
///       stage       int      0..2 growth stage of that pet
///       worn        map      slot (neck/head/accessory) -> item id; what the
///                            profile shows and what a server recompute checks
///       updatedAt   timestamp server time of the write
///       reachedAt   timestamp server time the player first held THIS charm
///                            (kept while charm is unchanged): the tie-break,
///                            whoever got there first ranks higher
///
/// The period is the path segment, so a new season or week starts an empty
/// board by changing ONE value: `leaderboard.periodKey` in economy.json.
/// The board shows the top [charmBoardTopLimit] by `charm`, highest first.
/// Keep every number here in step with the `charm_board` block in
/// firestore.rules (a test reads the rules file and checks them).
library;

/// Rules reject a charm above this: the most a player can reach is an adult
/// Kim long 2 x 150 + 3 legendary items 3 x 100 = 600 (Hà Phương, approved).
const charmBoardMaxCharm = 600;

/// A player appears on the board from this Mị lực. Below it the row is not
/// written (and an older row is taken off). `leaderboard.minCharmToRank` in
/// economy.json is the same number; the rules hard-code it.
const charmBoardMinCharm = 20;

/// The board reads this many entries at most (rules refuse a bigger limit).
const charmBoardTopLimit = 100;

/// Rules refuse a second write of the same entry sooner than this.
const charmBoardMinGap = Duration(seconds: 30);

/// The three equip slots a profile shows (same ids as the pet items).
const charmBoardSlots = ['neck', 'head', 'accessory'];

/// Longest display name the client sends (rules allow up to 80).
const charmBoardNameMax = 40;

/// Used when the account has no name at all.
const charmBoardFallbackName = 'Chủ tiệm';

final _periodKey = RegExp(r'^[a-z0-9][a-z0-9_-]{0,23}$');

/// A period key is a short lowercase id such as `season-1` or `w2026-41`.
/// Same pattern as `periodKeyOk` in firestore.rules.
bool isValidPeriodKey(String key) => _periodKey.hasMatch(key);

/// One line of the reward table: ranks [rankFrom]..[rankTo] each get this.
/// [itemTier] is a [PetItemTier] key ('' for no item).
class CharmBoardReward {
  const CharmBoardReward({
    required this.rankFrom,
    required this.rankTo,
    this.phaLe = 0,
    this.giotHoa = 0,
    this.itemTier = '',
  });

  final int rankFrom;
  final int rankTo;
  final int phaLe;
  final int giotHoa;
  final String itemTier;

  bool covers(int rank) => rank >= rankFrom && rank <= rankTo;

  static CharmBoardReward? fromJson(Object? json) {
    if (json is! Map) return null;
    final from = json['rankFrom'];
    final to = json['rankTo'];
    if (from is! num || to is! num || from < 1 || to < from) return null;
    int n(String k) =>
        json[k] is num && (json[k] as num) > 0 ? (json[k] as num).toInt() : 0;
    final tier = json['petItemRarity'];
    return CharmBoardReward(
      rankFrom: from.toInt(),
      rankTo: to.toInt(),
      phaLe: n('phaLe'),
      giotHoa: n('giotHoa'),
      itemTier: tier is String ? tier : '',
    );
  }
}

/// `leaderboard` in economy.json.
class CharmBoardConfig {
  const CharmBoardConfig({
    this.periodKey = 'season-1',
    this.limit = charmBoardTopLimit,
    this.minCharm = charmBoardMinCharm,
    this.cycleDays = 28,
    this.refreshMinutes = 15,
    this.seasonStart,
    this.rewards = const [],
  });

  static const defaults = CharmBoardConfig();

  /// The single place that says which board is live. Weekly or per season is
  /// not decided; both are just a different value here.
  final String periodKey;

  /// How many rows a read asks for (never above [charmBoardTopLimit]).
  final int limit;

  /// Mị lực needed to be on the board.
  final int minCharm;

  /// Length of one season in days (28 = 4 weeks, approved).
  final int cycleDays;

  /// A player's score goes up, and the board is read again, at most this
  /// often (approved: 15 minutes). The note under the board says the same.
  final int refreshMinutes;

  Duration get refreshEvery => Duration(minutes: refreshMinutes);

  /// First moment of the season, Vietnam time, as a UTC instant. Null means
  /// no clock is shown. A season ends [cycleDays] days later, at the stroke
  /// of Monday 00:00 (Sunday 23:59 is the last minute).
  final DateTime? seasonStart;

  final List<CharmBoardReward> rewards;

  /// When the season is over (the instant it flips to ended).
  DateTime? get seasonEnd => seasonStart?.add(Duration(days: cycleDays));

  /// Reward line for [rank], or null for a rank with none.
  CharmBoardReward? rewardFor(int rank) {
    for (final r in rewards) {
      if (r.covers(rank)) return r;
    }
    return null;
  }

  factory CharmBoardConfig.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final key = json['periodKey'];
    final limit = json['topLimit'] ?? json['topShown'];
    final min = json['minCharmToRank'];
    final days = json['cycleDays'];
    final start = json['seasonStart'];
    DateTime? startAt;
    if (start is String) {
      // 'YYYY-MM-DD' is a day in Vietnam (UTC+7).
      final d = DateTime.tryParse(start);
      if (d != null) {
        startAt = DateTime.utc(
          d.year,
          d.month,
          d.day,
        ).subtract(const Duration(hours: 7));
      }
    }
    final rawRewards = json['rewards'];
    return CharmBoardConfig(
      periodKey: key is String && isValidPeriodKey(key)
          ? key
          : defaults.periodKey,
      limit: limit is num && limit >= 1
          ? limit.toInt().clamp(1, charmBoardTopLimit)
          : defaults.limit,
      minCharm: min is num && min >= 1
          ? min.toInt().clamp(1, charmBoardMaxCharm)
          : defaults.minCharm,
      cycleDays: days is num && days >= 1 ? days.toInt() : defaults.cycleDays,
      refreshMinutes:
          json['refreshMinutes'] is num && json['refreshMinutes'] >= 1
          ? (json['refreshMinutes'] as num).toInt()
          : defaults.refreshMinutes,
      seasonStart: startAt,
      rewards: [
        if (rawRewards is List)
          for (final r in rawRewards) ?CharmBoardReward.fromJson(r),
      ],
    );
  }
}

/// One player's row.
class CharmBoardEntry {
  const CharmBoardEntry({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.charm,
    this.petId = '',
    this.stage = 0,
    this.worn = const {},
    this.updatedAt,
    this.reachedAt,
  });

  /// Builds the row a player publishes: name trimmed and cut to
  /// [charmBoardNameMax] characters (a name made of spaces falls back to
  /// [charmBoardFallbackName]), charm kept inside 0..[charmBoardMaxCharm].
  factory CharmBoardEntry.forPlayer({
    required String uid,
    required String displayName,
    String avatar = '',
    required int charm,
    String petId = '',
    int stage = 0,
    Map<String, String> worn = const {},
  }) {
    final runes = displayName.trim().runes.take(charmBoardNameMax).toList();
    final name = String.fromCharCodes(runes).trim();
    return CharmBoardEntry(
      uid: uid,
      displayName: name.isEmpty ? charmBoardFallbackName : name,
      avatar: avatar.length > 500 ? '' : avatar,
      charm: charm.clamp(0, charmBoardMaxCharm),
      petId: petId.length > 40 ? '' : petId,
      stage: stage.clamp(0, 2),
      worn: {
        for (final e in worn.entries)
          if (charmBoardSlots.contains(e.key) &&
              e.value.isNotEmpty &&
              e.value.length <= 40)
            e.key: e.value,
      },
    );
  }

  /// Whether this row may be written to the board.
  bool get ranked => charm >= charmBoardMinCharm;

  final String uid;
  final String displayName;
  final String avatar;
  final int charm;
  final String petId;
  final int stage;
  final Map<String, String> worn;

  /// Server time of the last write; null on a row not yet written.
  final DateTime? updatedAt;

  /// When this charm was first reached (server time); the tie-break.
  final DateTime? reachedAt;

  /// The same row with the times a source sets.
  CharmBoardEntry withTimes({DateTime? updatedAt, DateTime? reachedAt}) =>
      CharmBoardEntry(
        uid: uid,
        displayName: displayName,
        avatar: avatar,
        charm: charm,
        petId: petId,
        stage: stage,
        worn: worn,
        updatedAt: updatedAt ?? this.updatedAt,
        reachedAt: reachedAt ?? this.reachedAt,
      );

  /// Same row content (the times and the uid aside): nothing to publish.
  bool sameContent(CharmBoardEntry o) =>
      displayName == o.displayName &&
      avatar == o.avatar &&
      charm == o.charm &&
      petId == o.petId &&
      stage == o.stage &&
      _sameMap(worn, o.worn);

  /// The fields a client writes. `updatedAt` is the server timestamp, which
  /// the Firestore source adds; it is not part of this map.
  Map<String, Object> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'avatar': avatar,
    'charm': charm,
    'petId': petId,
    'stage': stage,
    'worn': worn,
  };

  /// A stored row. [docId] is the uid. Null when it has no usable charm.
  static CharmBoardEntry? fromMap(
    String docId,
    Map<String, Object?> data, {
    DateTime? updatedAt,
    DateTime? reachedAt,
  }) {
    final charm = data['charm'];
    if (docId.isEmpty || charm is! num || charm < charmBoardMinCharm) {
      return null;
    }
    final name = data['displayName'];
    final avatar = data['avatar'];
    final petId = data['petId'];
    final stage = data['stage'];
    final worn = data['worn'];
    return CharmBoardEntry(
      uid: docId,
      displayName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : charmBoardFallbackName,
      avatar: avatar is String ? avatar : '',
      charm: charm.toInt().clamp(0, charmBoardMaxCharm),
      petId: petId is String ? petId : '',
      stage: stage is num ? stage.toInt().clamp(0, 2) : 0,
      worn: {
        if (worn is Map)
          for (final e in worn.entries)
            if (charmBoardSlots.contains(e.key) && e.value is String)
              e.key as String: e.value as String,
      },
      updatedAt: updatedAt,
      reachedAt: reachedAt,
    );
  }
}

bool _sameMap(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

/// A row with its place on the board.
class CharmBoardRow {
  const CharmBoardRow(this.rank, this.entry);

  /// 1 is the top.
  final int rank;
  final CharmBoardEntry entry;
}

/// Orders [entries]: highest charm first; equal charm goes to whoever reached
/// it first (older `reachedAt`, else `updatedAt`; a row with no time comes
/// last), then by uid so
/// the order never flickers. Keeps the first [limit] and numbers them 1, 2, 3
/// (equal charm does not share a rank).
List<CharmBoardRow> rankCharmBoard(
  Iterable<CharmBoardEntry> entries, {
  int limit = charmBoardTopLimit,
}) {
  final sorted = entries.toList()
    ..sort((a, b) {
      final byCharm = b.charm.compareTo(a.charm);
      if (byCharm != 0) return byCharm;
      final at = a.reachedAt ?? a.updatedAt;
      final bt = b.reachedAt ?? b.updatedAt;
      if (at != null && bt != null) {
        final byTime = at.compareTo(bt);
        if (byTime != 0) return byTime;
      } else if (at != null) {
        return -1;
      } else if (bt != null) {
        return 1;
      }
      return a.uid.compareTo(b.uid);
    });
  final n = limit.clamp(0, charmBoardTopLimit);
  return [
    for (var i = 0; i < sorted.length && i < n; i++)
      CharmBoardRow(i + 1, sorted[i]),
  ];
}

/// Where the board lives. The Firestore version is in
/// firestore_charm_board.dart; [MemoryCharmBoard] is for tests and offline.
abstract class CharmBoardSource {
  /// The top [limit] rows of [period], best first.
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  });

  /// Writes the player's own row. The caller is the signed-in player.
  Future<void> publish({
    required String period,
    required CharmBoardEntry entry,
  });

  /// Takes the player's own row off the board.
  Future<void> remove({required String period, required String uid});
}

/// A board that keeps rows in memory and enforces the same limits as the
/// rules (valid period, charm cap, 30 s between two writes of one row).
class MemoryCharmBoard implements CharmBoardSource {
  MemoryCharmBoard({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, Map<String, CharmBoardEntry>> _periods = {};

  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) async {
    if (limit > charmBoardTopLimit) {
      throw ArgumentError('the board reads at most $charmBoardTopLimit rows');
    }
    return rankCharmBoard(_periods[period]?.values ?? const [], limit: limit);
  }

  @override
  Future<void> publish({
    required String period,
    required CharmBoardEntry entry,
  }) async {
    if (!isValidPeriodKey(period)) throw ArgumentError('bad period $period');
    if (entry.uid.isEmpty ||
        entry.charm < charmBoardMinCharm ||
        entry.charm > charmBoardMaxCharm) {
      throw ArgumentError('entry refused: ${entry.toMap()}');
    }
    final rows = _periods.putIfAbsent(period, () => {});
    final old = rows[entry.uid];
    final now = _now();
    if (old?.updatedAt != null &&
        now.difference(old!.updatedAt!) < charmBoardMinGap) {
      throw StateError('written again too soon');
    }
    rows[entry.uid] = entry.withTimes(
      updatedAt: now,
      // Held the same charm before: the first time stays.
      reachedAt: old != null && old.charm == entry.charm
          ? (old.reachedAt ?? old.updatedAt ?? now)
          : now,
    );
  }

  @override
  Future<void> remove({required String period, required String uid}) async {
    _periods[period]?.remove(uid);
  }
}
