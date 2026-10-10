import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_notice.dart';

/// Which announcements this browser has opened, and which it has removed.
///
/// Kept off the game save, so signing out does not mark them all unread
/// and a new game does not wipe the list. Hiding one does not delete it
/// for anyone else.
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
    if (seen != null) ids = seen;
    if (gone != null) hidden = gone;
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

  Future<void> save(Set<String> next) {
    ids = {...next};
    return _write(storageKey, jsonEncode(ids.toList()));
  }

  Future<void> saveHidden() {
    return _write(hiddenKey, jsonEncode(hidden.toList()));
  }
}

/// Published notices plus which ones this browser has opened.
class NoticeFeed extends ChangeNotifier {
  NoticeFeed({
    required NoticeBoard board,
    required NoticeSeen seen,
    List<GameNotice>? initial,
  }) : _board = board,
       _seen = seen,
       notices = [...?initial];

  final NoticeBoard _board;
  final NoticeSeen _seen;

  List<GameNotice> notices;
  var open = false;
  String? detailId;
  var _gone = false;

  List<GameNotice> get visible => [
    for (final notice in notices)
      if (!_seen.hidden.contains(notice.id)) notice,
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

  /// Removes the notice from this browser only.
  Future<void> dismiss(String id) async {
    if (detailId == id) detailId = null;
    final added = _seen.hidden.add(id);
    notifyListeners();
    if (!added) return;
    try {
      await _seen.saveHidden();
    } catch (_) {}
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}
