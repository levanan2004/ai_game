import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/account_gateway.dart';

import 'game_state.dart';
import 'terms_consent.dart';

/// JSON save/load for [GameState] and the terms consent.
///
/// [persistent] uses [SharedPreferences], which stores the strings in the
/// browser's localStorage on web and in the platform store on mobile.
class ProgressStore {
  ProgressStore({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
    required Future<void> Function(String key) remove,
  }) : _read = read,
       _write = write,
       _remove = remove;

  static const storageKey = 'ai_game.progress';

  /// Old guest slot. Guest play is no longer saved: the game neither reads
  /// nor writes this key, and data already there is left untouched (a
  /// one-time move into an account could read it later).
  static const legacyGuestKey = storageKey;

  /// Morning for one Google account. Only signed-in play is saved.
  static String accountKey(String uid) => '$storageKey.$uid';

  /// Kept apart from the progress so a new game never clears it.
  static const termsKey = 'tiemhoa.terms';

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;
  final Future<void> Function(String key) _remove;

  String _key = storageKey;

  /// Next [load] and [save] use this account's key.
  /// Null returns to the guest key.
  void useAccount(String? uid) {
    _key = (uid == null || uid.isEmpty) ? storageKey : accountKey(uid);
  }

  /// Uid whose slot [load] and [save] use now, or null on the guest key.
  String? get slotUid =>
      _key == storageKey ? null : _key.substring(storageKey.length + 1);

  /// In-memory store. [backing] is shared so a second store can restore it.
  factory ProgressStore.memory([Map<String, String>? backing]) {
    final data = backing ?? <String, String>{};
    return ProgressStore(
      read: (key) async => data[key],
      write: (key, value) async {
        data[key] = value;
      },
      remove: (key) async {
        data.remove(key);
      },
    );
  }

  static Future<ProgressStore> persistent() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore(
      read: (key) async => prefs.getString(key),
      write: (key, value) async {
        await prefs.setString(key, value);
      },
      remove: (key) async {
        await prefs.remove(key);
      },
    );
  }

  /// Null when nothing valid is saved (the caller starts a new game).
  Future<GameState?> load() async => GameState.decode(await _read(_key));

  Future<void> save(GameState state) => _write(_key, state.encode());

  /// Writes into [uid]'s slot (null: the guest key), whatever slot is in
  /// use when the queued write finally runs.
  Future<void> saveFor(String? uid, GameState state) => _write(
    (uid == null || uid.isEmpty) ? storageKey : accountKey(uid),
    state.encode(),
  );

  /// Account this browser opened last, so a reload loads that account's
  /// copy first instead of a guest morning. Cleared by "Đăng xuất".
  static const lastAccountKey = 'ai_game.last_account';

  Future<AccountProfile?> loadLastAccount() async {
    final raw = await _read(lastAccountKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final uid = j['uid'];
      if (uid is! String || uid.isEmpty) return null;
      final email = j['email'];
      final name = j['name'];
      return AccountProfile(
        uid: uid,
        email: email is String ? email : '',
        name: name is String && name.isNotEmpty ? name : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastAccount(AccountProfile profile) => _write(
    lastAccountKey,
    jsonEncode({
      'uid': profile.uid,
      'email': profile.email,
      if (profile.name != null) 'name': profile.name,
    }),
  );

  Future<void> clearLastAccount() => _remove(lastAccountKey);

  /// Null when the player has never agreed (or storage was cleared).
  Future<TermsConsent?> loadTerms() async =>
      TermsConsent.decode(await _read(termsKey));

  Future<void> saveTerms(TermsConsent terms) =>
      _write(termsKey, terms.encode());
}
