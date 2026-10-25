import 'dart:async';

import 'shop_session.dart';

/// The block list ("Chặn" in Tin thế giới = "Ẩn người chơi này" on the
/// boards) and "rules accepted" of the chat, kept per account on the server
/// (player_prefs/{uid}, only the owner reads or writes it; deleteAccount
/// removes it). Signed out, or with no server, they stay on the device as
/// before. The first sign-in on a device moves the device values into the
/// account and clears them from the device.
class AccountPrefs {
  const AccountPrefs({this.blocked = const {}, this.chatRulesAccepted = false});

  /// uid -> shop name when blocked, oldest first.
  final Map<String, String> blocked;
  final bool chatRulesAccepted;

  /// firestore.rules caps the map; the oldest are dropped past it.
  static const maxBlocked = 500;

  bool get isEmpty => blocked.isEmpty && !chatRulesAccepted;

  /// The newest [maxBlocked] of [blocked].
  static Map<String, String> capped(Map<String, String> blocked) {
    if (blocked.length <= maxBlocked) return blocked;
    final keep = blocked.entries.skip(blocked.length - maxBlocked);
    return {for (final e in keep) e.key: e.value};
  }

  /// Both lists together: a uid blocked in either stays blocked; accepted
  /// in either stays accepted.
  AccountPrefs mergedWith(AccountPrefs other) => AccountPrefs(
    blocked: capped({...blocked, ...other.blocked}),
    chatRulesAccepted: chatRulesAccepted || other.chatRulesAccepted,
  );
}

/// Where an account's prefs live (Firestore; a memory one in tests).
abstract class AccountPrefsSource {
  /// Null when the account has none yet. Throws when it cannot read.
  Future<AccountPrefs?> load(String uid);

  Future<void> save(String uid, AccountPrefs prefs);
}

class MemoryAccountPrefs implements AccountPrefsSource {
  final docs = <String, AccountPrefs>{};

  /// Every call throws while set (tests).
  bool fail = false;
  int saves = 0;

  @override
  Future<AccountPrefs?> load(String uid) async {
    if (fail) throw StateError('offline');
    return docs[uid];
  }

  @override
  Future<void> save(String uid, AccountPrefs prefs) async {
    if (fail) throw StateError('offline');
    saves++;
    docs[uid] = AccountPrefs(
      blocked: Map.of(prefs.blocked),
      chatRulesAccepted: prefs.chatRulesAccepted,
    );
  }
}

/// Switches the board's block list and the chat's "rules accepted" between
/// the device and the signed-in account.
class AccountPrefsController {
  AccountPrefsController(this._s, {this.source});

  final ShopSession _s;
  final AccountPrefsSource? source;

  /// The account whose server prefs are in force (loaded, migrated).
  String? _uid;

  /// Changes are saved to the account (else to the device).
  bool get onServer => source != null && _uid != null && _uid == _s.accountUid;

  /// A signed-in account with a server: the device copy must not replace
  /// what [switchTo] loads.
  bool get ownsLists => source != null && _s.accountUid != null;

  /// The last [switchTo]; tests await it.
  Future<void> pending = Future.value();

  /// Called when the signed-in account changes ([uid] null = signed out).
  Future<void> switchTo(String? uid) => pending = _switch(uid);

  Future<void> _switch(String? uid) async {
    final src = source;
    if (src == null) return;
    _uid = null;
    final local = await _readLocal();
    // Never show the previous account's list while this one loads.
    _apply(local);
    if (uid == null) return;
    AccountPrefs? server;
    try {
      server = await src.load(uid);
    } catch (_) {
      // Offline: the device lists for now, saved on the device; they move
      // to the account on the next sign-in.
      return;
    }
    if (_s.accountUid != uid) return;
    var prefs = server ?? const AccountPrefs();
    if (!local.isEmpty) {
      prefs = prefs.mergedWith(local);
      try {
        await src.save(uid, prefs);
      } catch (_) {
        if (_s.accountUid == uid) _apply(prefs);
        return;
      }
      await _clearLocal();
    }
    if (_s.accountUid != uid) return;
    _uid = uid;
    _apply(prefs);
  }

  /// Saves the current lists to the account. False when not on the server
  /// (the caller keeps the device copy).
  Future<bool> save() async {
    final src = source;
    final uid = _uid;
    if (src == null || uid == null || !onServer) return false;
    try {
      await src.save(
        uid,
        AccountPrefs(
          blocked: AccountPrefs.capped(_s.board.hidden),
          chatRulesAccepted: _s.chat.rulesAccepted,
        ),
      );
    } catch (_) {}
    return true;
  }

  Future<AccountPrefs> _readLocal() async {
    final store = _s.progressStore;
    var blocked = const <String, String>{};
    var accepted = false;
    try {
      blocked = await store.loadHiddenPlayers();
    } catch (_) {}
    try {
      accepted = await store.loadChatRulesAccepted();
    } catch (_) {}
    return AccountPrefs(blocked: blocked, chatRulesAccepted: accepted);
  }

  Future<void> _clearLocal() async {
    final store = _s.progressStore;
    try {
      await store.saveHiddenPlayers(const {});
      await store.clearChatRulesAccepted();
    } catch (_) {}
  }

  void _apply(AccountPrefs p) {
    _s.board.applyHidden(p.blocked);
    _s.chat.applyRulesAccepted(p.chatRulesAccepted);
  }
}
