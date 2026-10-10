import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_notice.dart';

/// The signed-in account's own list of removed notices (its save). It is what
/// makes a removed notice stay removed on another device or browser; the
/// browser's own list ([NoticeSeen.hidden]) covers guests and the time before
/// the account loads.
abstract interface class NoticeAccount implements Listenable {
  bool get signedIn;

  /// Cheap to read on every notification (the feed compares it).
  int get hiddenNoticeCount;

  Set<String> get hiddenNotices;

  void hideNotices(Iterable<String> ids);
}

/// Which announcements this browser has opened, and which it has removed.
///
/// Kept off the game save, so signing out does not mark them all unread
/// and a new game does not wipe the list. A removed notice is remembered here
/// (this browser) AND in the account's save ([NoticeAccount]) when signed in,
/// so it does not come back on the next device. It is never deleted for anyone
/// else.
class NoticeSeen {
  NoticeSeen({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
    Set<String>? initial,
    Set<String>? hidden,
  }) : _read = read,
       _write = write,
       ids = {...?initial},
       hidden = {...?hidden};

  static const storageKey = 'ai_game.seen_notices';
  static const hiddenKey = 'ai_game.hidden_notices';

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;
  Set<String> ids;
  Set<String> hidden;

  factory NoticeSeen.memory([Set<String>? initial]) {
    final data = <String, String>{};
    return NoticeSeen(
      read: (key) async => data[key],
      write: (key, value) async => data[key] = value,
      initial: initial,
    );
  }

  static Future<NoticeSeen> persistent() async {
    final prefs = await SharedPreferences.getInstance();
    return NoticeSeen(
      read: (key) async => prefs.getString(key),
      write: (key, value) async {
        await prefs.setString(key, value);
      },
    );
  }

  Future<void> load() async {
    final seen = await _readIds(storageKey);
    final gone = await _readIds(hiddenKey);
    // Merge, do not replace: a notice opened or removed while this read was
    // still running must not be lost.
    if (seen != null) ids = {...seen, ...ids};
    if (gone != null) hidden = {...gone, ...hidden};
  }

  Future<Set<String>?> _readIds(String key) async {
    final raw = await _read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return {
          for (final id in decoded)
            if (id is String) id,
        };
      }
    } catch (_) {}
    return null;
  }

  // Both saves add to what is stored instead of overwriting it: the lists only
  // grow, and a write made before load() finished (or by a second tab) must not
  // drop ids it never read.
  Future<void> save(Set<String> next) async {
    ids = {...?await _readIds(storageKey), ...next};
    await _write(storageKey, jsonEncode(ids.toList()));
  }

  Future<void> saveHidden() async {
    hidden = {...?await _readIds(hiddenKey), ...hidden};
    await _write(hiddenKey, jsonEncode(hidden.toList()));
  }
}

/// Published notices plus which ones this browser has opened.
class NoticeFeed extends ChangeNotifier {
  NoticeFeed({
    required NoticeBoard board,
    required NoticeSeen seen,
    List<GameNotice>? initial,
    NoticeAccount? account,
  }) : _board = board,
       _seen = seen,
       notices = [...?initial] {
    attachAccount(account);
  }

  final NoticeBoard _board;
  final NoticeSeen _seen;
  NoticeAccount? _account;
  var _accountCount = 0;

  /// Connects the account's save (main does it once the session exists). The
  /// feed re-reads the list when it grows, e.g. when the cloud save arrives
  /// with notices removed on another device.
  void attachAccount(NoticeAccount? account) {
    _account?.removeListener(_accountChanged);
    _account = account;
    _accountCount = account?.hiddenNoticeCount ?? 0;
    account?.addListener(_accountChanged);
  }

  void _accountChanged() {
    final n = _account?.hiddenNoticeCount ?? 0;
    if (n == _accountCount) return;
    _accountCount = n;
    if (!_gone) notifyListeners();
  }

  bool _isHidden(String id) =>
      _seen.hidden.contains(id) ||
      (_account?.hiddenNotices.contains(id) ?? false);

  List<GameNotice> notices;
  var open = false;
  String? detailId;
  var _gone = false;

  List<GameNotice> get visible => [
    for (final notice in notices)
      if (!_isHidden(notice.id)) notice,
  ];

  int get unread => visible.where((n) => !_seen.ids.contains(n.id)).length;

  bool seen(String id) => _seen.ids.contains(id);

  GameNotice? get detail {
    final id = detailId;
    if (id == null) return null;
    for (final notice in notices) {
      if (notice.id == id) return notice;
    }
    return null;
  }

  /// Loads seen ids, then the board. Failures leave the game playable.
  Future<void> start() async {
    await _seen.load();
    await refresh();
  }

  Future<void> refresh() async {
    _carryToAccount();
    try {
      final list = await _board.published();
      if (_gone) return;
      notices = list;
    } catch (_) {}
    if (_gone) return;
    notifyListeners();
  }

  void toggle() {
    open = !open;
    detailId = null;
    notifyListeners();
    if (open) refresh();
  }

  void close() {
    open = false;
    detailId = null;
    notifyListeners();
  }

  void showList() {
    detailId = null;
    notifyListeners();
  }

  Future<void> openDetail(String id) async {
    detailId = id;
    final added = _seen.ids.add(id);
    notifyListeners();
    if (!added) return;
    try {
      await _seen.save(_seen.ids);
    } catch (_) {}
  }

  /// Notices removed in this browser before the account kept the list (or while
  /// signed out) move into the account's save once it is signed in.
  void _carryToAccount() {
    final a = _account;
    if (a == null || !a.signedIn || _seen.hidden.isEmpty) return;
    final have = a.hiddenNotices;
    final missing = _seen.hidden.where((id) => !have.contains(id));
    if (missing.isNotEmpty) a.hideNotices(missing);
    _accountCount = a.hiddenNoticeCount;
  }

  /// Removes the notice here and, signed in, for the whole account.
  Future<void> dismiss(String id) async {
    if (detailId == id) detailId = null;
    final added = _seen.hidden.add(id);
    final a = _account;
    if (a != null && a.signedIn) {
      a.hideNotices([id]);
      _accountCount = a.hiddenNoticeCount;
    }
    notifyListeners();
    if (!added) return;
    try {
      await _seen.saveHidden();
    } catch (_) {}
  }

  @override
  void dispose() {
    _gone = true;
    _account?.removeListener(_accountChanged);
    super.dispose();
  }
}
