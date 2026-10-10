/// Bảng xếp hạng Mị lực: the data layer only (no screen, no rewards yet).
///
/// Firestore shape, one document per player per period:
///
///     charm_board/{periodKey}/entries/{uid}
///       uid         string   same as the document id and request.auth.uid
///       displayName string   1..40 characters (rules allow 80)
///       avatar      string   pointer to the portrait, same kind of value
///                            as `player_avatars/{uid}.path`; '' for none
///       charm       int      0..[charmBoardMaxCharm]
///       updatedAt   timestamp server time of the write
///
/// The period is the path segment, so a new season or week starts an empty
/// board by changing ONE value: `leaderboard.periodKey` in economy.json.
/// The board shows the top [charmBoardTopLimit] by `charm`, highest first.
/// Keep every number here in step with the `charm_board` block in
/// firestore.rules (a test reads the rules file and checks them).
library;

/// Rules reject a charm above this. The most a player can reach today is
/// 2 x 150 + 3 x 100 = 600; the rest is room for new pets and items.
const charmBoardMaxCharm = 2000;

/// The board reads this many entries at most (rules refuse a bigger limit).
const charmBoardTopLimit = 100;

/// Rules refuse a second write of the same entry sooner than this.
const charmBoardMinGap = Duration(seconds: 30);

/// Longest display name the client sends (rules allow up to 80).
const charmBoardNameMax = 40;

/// Used when the account has no name at all.
const charmBoardFallbackName = 'Chủ tiệm';

final _periodKey = RegExp(r'^[a-z0-9][a-z0-9_-]{0,23}$');

/// A period key is a short lowercase id such as `season-1` or `w2026-41`.
/// Same pattern as `periodKeyOk` in firestore.rules.
bool isValidPeriodKey(String key) => _periodKey.hasMatch(key);

/// `leaderboard` in economy.json.
class CharmBoardConfig {
  const CharmBoardConfig({
    this.periodKey = 'season-1',
    this.limit = charmBoardTopLimit,
  });

  static const defaults = CharmBoardConfig();

  /// The single place that says which board is live. Weekly or per season is
  /// not decided; both are just a different value here.
  final String periodKey;

  /// How many rows a read asks for (never above [charmBoardTopLimit]).
  final int limit;

  factory CharmBoardConfig.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final key = json['periodKey'];
    final limit = json['topLimit'];
    return CharmBoardConfig(
      periodKey: key is String && isValidPeriodKey(key)
          ? key
          : defaults.periodKey,
      limit: limit is num && limit >= 1
          ? limit.toInt().clamp(1, charmBoardTopLimit)
          : defaults.limit,
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
    this.updatedAt,
  });

  /// Builds the row a player publishes: name trimmed and cut to
  /// [charmBoardNameMax] characters (a name made of spaces falls back to
  /// [charmBoardFallbackName]), charm kept inside 0..[charmBoardMaxCharm].
  factory CharmBoardEntry.forPlayer({
    required String uid,
    required String displayName,
    String avatar = '',
    required int charm,
  }) {
    final runes = displayName.trim().runes.take(charmBoardNameMax).toList();
    final name = String.fromCharCodes(runes).trim();
    return CharmBoardEntry(
      uid: uid,
      displayName: name.isEmpty ? charmBoardFallbackName : name,
      avatar: avatar.length > 500 ? '' : avatar,
      charm: charm.clamp(0, charmBoardMaxCharm),
    );
  }

  final String uid;
  final String displayName;
  final String avatar;
  final int charm;

  /// Server time of the last write; null on a row not yet written.
  final DateTime? updatedAt;

  /// The fields a client writes. `updatedAt` is the server timestamp, which
  /// the Firestore source adds; it is not part of this map.
  Map<String, Object> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'avatar': avatar,
    'charm': charm,
  };

  /// A stored row. [docId] is the uid. Null when it has no usable charm.
  static CharmBoardEntry? fromMap(
    String docId,
    Map<String, Object?> data, {
    DateTime? updatedAt,
  }) {
    final charm = data['charm'];
    if (docId.isEmpty || charm is! num || charm < 0) return null;
    final name = data['displayName'];
    final avatar = data['avatar'];
    return CharmBoardEntry(
      uid: docId,
      displayName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : charmBoardFallbackName,
      avatar: avatar is String ? avatar : '',
      charm: charm.toInt().clamp(0, charmBoardMaxCharm),
      updatedAt: updatedAt,
    );
  }
}

/// A row with its place on the board.
class CharmBoardRow {
  const CharmBoardRow(this.rank, this.entry);

  /// 1 is the top.
  final int rank;
  final CharmBoardEntry entry;
}

/// Orders [entries]: highest charm first; equal charm goes to whoever reached
/// it first (older `updatedAt`; a row with no time comes last), then by uid so
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
      final at = a.updatedAt;
      final bt = b.updatedAt;
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
        entry.charm < 0 ||
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
    rows[entry.uid] = CharmBoardEntry(
      uid: entry.uid,
      displayName: entry.displayName,
      avatar: entry.avatar,
      charm: entry.charm,
      updatedAt: now,
    );
  }

  @override
  Future<void> remove({required String period, required String uid}) async {
    _periods[period]?.remove(uid);
  }
}
