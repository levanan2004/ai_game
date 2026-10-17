import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/rating_board.dart';
import 'shop_session.dart';

/// Where the board stands in its season.
enum RatingPhase {
  /// Before the first season with this board ("Bảng Đánh giá mở từ mùa…").
  notStarted,
  running,
  ended,
}

/// What the board itself is doing.
enum RatingLoad { idle, loading, ready, error }

/// The pinned "Hạng của bạn" card.
enum RatingMe {
  guest,

  /// Fewer than {rating_min} reviews counted this season (or no row).
  underMin,

  /// On the board with a rank.
  ranked,

  /// Over the minimum, not in the 100 rows read ("100+").
  outside,
}

/// Bảng xếp hạng Đánh giá for one player: which tab of the Bảng xếp hạng
/// screen is shown, the top rows (cached for `refreshMinutes`) and the
/// player's own row. Read only: scores are counted by the server from the
/// cloud save (functions/rating_board.js), never by this app.
class RatingBoardController extends ChangeNotifier {
  RatingBoardController(
    this._s, {
    required this.source,
    required DateTime Function() now,
  }) : _now = now;

  final ShopSession _s;
  final RatingBoardSource? source;
  final DateTime Function() _now;

  /// A pull-to-refresh may not hit the server more often than this.
  static const fetchGap = Duration(seconds: 30);

  RatingBoardConfig get config => _s.e.ratingBoard;

  /// The tab control shows (the block is in economy.json).
  bool get enabled => config.enabled;

  /// The Đánh giá tab is chosen (else Mị lực).
  bool tab = false;

  RatingLoad load = RatingLoad.idle;
  List<RatingRow> rows = const [];
  RatingEntry? mine;
  DateTime? fetchedAt;
  DateTime? _tried;
  String? _uid;

  /// Sheets on the tab.
  bool howOpen = false;
  bool rewardsOpen = false;

  /// The row whose profile card is open.
  RatingRow? profile;

  RatingPhase get phase {
    final start = config.seasonStart;
    final end = config.seasonEnd;
    final now = _now();
    if (start == null || now.isBefore(start)) return RatingPhase.notStarted;
    if (end != null && !now.isBefore(end)) return RatingPhase.ended;
    return RatingPhase.running;
  }

  /// Time to the end of the season (zero once over).
  Duration get seasonLeft {
    final end = config.seasonEnd;
    if (end == null) return Duration.zero;
    final left = end.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  RatingMe get me {
    if (!_s.signedIn) return RatingMe.guest;
    final m = mine;
    if (m == null || m.v < config.minToRank || m.sortKey <= 0) {
      return RatingMe.underMin;
    }
    return myRank == null ? RatingMe.outside : RatingMe.ranked;
  }

  int? get myRank {
    final uid = _s.accountUid;
    for (final r in rows) {
      if (r.entry.uid == uid) return r.rank;
    }
    return null;
  }

  /// {k} of "cần thêm {k} đánh giá trong mùa này".
  int get reviewsToRank => (config.minToRank - (mine?.v ?? 0)).clamp(
    1,
    config.minToRank,
  );

  bool get _fresh =>
      fetchedAt != null && _now().difference(fetchedAt!) < config.refreshEvery;

  /// Shows the Đánh giá tab and reads it.
  Future<void> showTab() async {
    tab = true;
    notifyListeners();
    await refresh();
  }

  /// Back to the Mị lực tab.
  void showCharm() {
    tab = false;
    closeSheets();
  }

  void closeSheets() {
    howOpen = false;
    rewardsOpen = false;
    profile = null;
    notifyListeners();
  }

  void openHow() {
    howOpen = true;
    notifyListeners();
  }

  void openRewards() {
    rewardsOpen = true;
    notifyListeners();
  }

  void openProfile(RatingRow row) {
    profile = row;
    notifyListeners();
  }

  /// Reads the top rows and the player's own row. [force] is
  /// pull-to-refresh: it skips the cache but not the 30-second gap.
  Future<void> refresh({bool force = false}) async {
    final src = source;
    if (!enabled || src == null || !_s.signedIn) return;
    if (phase == RatingPhase.notStarted || load == RatingLoad.loading) return;
    final uid = _s.accountUid!;
    if (uid != _uid) {
      // Another account on this device: nothing of the last one stays.
      _uid = uid;
      rows = const [];
      mine = null;
      fetchedAt = null;
      _tried = null;
      load = RatingLoad.idle;
    }
    final now = _now();
    if (!force && _fresh && load == RatingLoad.ready) return;
    if (force &&
        load != RatingLoad.error &&
        _tried != null &&
        now.difference(_tried!) < fetchGap) {
      return;
    }
    _tried = now;
    load = RatingLoad.loading;
    notifyListeners();
    try {
      final period = config.periodKey;
      final got = await src.top(period: period, limit: config.limit);
      RatingEntry? own;
      for (final r in got) {
        if (r.entry.uid == uid) own = r.entry;
      }
      own ??= await src.entry(period: period, uid: uid);
      if (_s.accountUid != uid) return;
      rows = got;
      mine = own;
      fetchedAt = _now();
      load = RatingLoad.ready;
      unawaited(_s.frames.prefetch([for (final r in got) r.entry.uid]));
    } catch (_) {
      load = rows.isEmpty ? RatingLoad.error : RatingLoad.ready;
    }
    notifyListeners();
  }

  /// A shop's row for the profile card: from the rows read, else the server.
  Future<RatingEntry?> entryOf(String uid) async {
    for (final r in rows) {
      if (r.entry.uid == uid) return r.entry;
    }
    if (uid == _s.accountUid && mine != null) return mine;
    final src = source;
    if (!enabled || src == null || !_s.signedIn) return null;
    try {
      return await src.entry(period: config.periodKey, uid: uid);
    } catch (_) {
      return null;
    }
  }
}
