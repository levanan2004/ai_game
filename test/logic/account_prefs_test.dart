import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/data/firestore_account_prefs.dart';
import 'package:ai_game/logic/account_prefs.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Signs in as [uid] with no cloud save.
class _Account extends OfflineAccount {
  _Account(this.uid);

  final String uid;

  @override
  Future<AccountProfile?> signIn() async =>
      AccountProfile(uid: uid, email: '$uid@example.com', name: uid);
}

void main() {
  ({ShopSession s, MemoryAccountPrefs server, Map<String, String> backing})
  rig({Map<String, String>? backing}) {
    final b = backing ?? <String, String>{};
    final server = MemoryAccountPrefs();
    final store = ProgressStore.memory(b);
    final s = newSession(store: store, accountPrefs: server);
    return (s: s, server: server, backing: b);
  }

  Future<void> signIn(ShopSession s, String uid) async {
    s.accountUid = uid;
    await s.prefs.switchTo(uid);
  }

  test('first sign-in moves the device list and "rules accepted" to the '
      'account and clears the device', () async {
    final r = rig(
      backing: {
        ProgressStore.hiddenPlayersKey: '{"p1":"Tiệm Lan"}',
        ProgressStore.chatRulesKey: 'true',
      },
    );
    await r.s.board.useHiddenPlayers(r.s.progressStore);
    await r.s.chat.useStore(r.s.progressStore);
    expect(r.s.board.hidden, {'p1': 'Tiệm Lan'});
    await signIn(r.s, 'u1');
    final saved = r.server.docs['u1']!;
    expect(saved.blocked, {'p1': 'Tiệm Lan'});
    expect(saved.chatRulesAccepted, isTrue);
    expect(r.backing[ProgressStore.chatRulesKey], isNull);
    expect(await r.s.progressStore.loadHiddenPlayers(), isEmpty);
    expect(r.s.board.hidden, {'p1': 'Tiệm Lan'});
    expect(r.s.chat.rulesAccepted, isTrue);
    expect(r.s.prefs.onServer, isTrue);
  });

  test('an account that already has a list keeps it, plus the device one',
      () async {
    final r = rig(backing: {ProgressStore.hiddenPlayersKey: '{"p2":"Cúc"}'});
    r.server.docs['u1'] = const AccountPrefs(
      blocked: {'p1': 'Lan'},
      chatRulesAccepted: true,
    );
    await signIn(r.s, 'u1');
    expect(r.server.docs['u1']!.blocked, {'p1': 'Lan', 'p2': 'Cúc'});
    expect(r.s.chat.rulesAccepted, isTrue);
    expect(r.s.board.isHidden('p2'), isTrue);
  });

  test('nothing on the device: no write, the account list shows', () async {
    final r = rig();
    r.server.docs['u1'] = const AccountPrefs(blocked: {'p1': 'Lan'});
    await signIn(r.s, 'u1');
    expect(r.server.saves, 0);
    expect(r.s.board.hidden, {'p1': 'Lan'});
    expect(r.s.chat.rulesAccepted, isFalse);
  });

  test('signed in: block, unblock and the rules popup save to the account, '
      'not the device', () async {
    final r = rig();
    await r.s.board.useHiddenPlayers(r.s.progressStore);
    await r.s.chat.useStore(r.s.progressStore);
    await signIn(r.s, 'u1');
    expect(await r.s.board.hidePlayer('p1', 'Lan'), isTrue);
    await r.s.chat.acceptRules();
    expect(r.server.docs['u1']!.blocked, {'p1': 'Lan'});
    expect(r.server.docs['u1']!.chatRulesAccepted, isTrue);
    expect(r.backing[ProgressStore.hiddenPlayersKey], isNull);
    expect(r.backing[ProgressStore.chatRulesKey], isNull);
    await r.s.board.unhide('p1');
    expect(r.server.docs['u1']!.blocked, isEmpty);
  });

  test('another account on the same device starts with its own lists',
      () async {
    final r = rig();
    await signIn(r.s, 'u1');
    await r.s.board.hidePlayer('p1', 'Lan');
    await r.s.chat.acceptRules();
    // Sign out: the device lists (empty), then a second account.
    r.s.accountUid = null;
    await r.s.prefs.switchTo(null);
    expect(r.s.board.hidden, isEmpty);
    expect(r.s.chat.rulesAccepted, isFalse);
    await signIn(r.s, 'u2');
    expect(r.s.board.hidden, isEmpty);
    expect(r.s.chat.rulesAccepted, isFalse);
    expect(r.server.docs['u2'], isNull);
    // Back to the first: its list again.
    await signIn(r.s, 'u1');
    expect(r.s.board.hidden, {'p1': 'Lan'});
    expect(r.s.chat.rulesAccepted, isTrue);
  });

  test('server unreachable: the device lists stay, saved on the device, and '
      'move on the next sign-in', () async {
    final r = rig(backing: {ProgressStore.hiddenPlayersKey: '{"p1":"Lan"}'});
    r.server.fail = true;
    await signIn(r.s, 'u1');
    expect(r.s.prefs.onServer, isFalse);
    expect(r.s.board.hidden, {'p1': 'Lan'});
    await r.s.board.useHiddenPlayers(r.s.progressStore);
    await r.s.board.hidePlayer('p2', 'Cúc');
    expect(await r.s.progressStore.loadHiddenPlayers(), {
      'p1': 'Lan',
      'p2': 'Cúc',
    });
    r.server.fail = false;
    await r.s.prefs.switchTo('u1');
    expect(r.server.docs['u1']!.blocked, {'p1': 'Lan', 'p2': 'Cúc'});
    expect(await r.s.progressStore.loadHiddenPlayers(), isEmpty);
  });

  test('the real sign-in and sign-out switch the lists', () async {
    final b = <String, String>{ProgressStore.chatRulesKey: 'true'};
    final server = MemoryAccountPrefs();
    final s = newSession(
      store: ProgressStore.memory(b),
      accountPrefs: server,
      account: _Account('u9'),
      guestSaves: false,
    );
    await s.signIn();
    await s.prefs.pending;
    expect(s.accountUid, 'u9');
    expect(server.docs['u9']!.chatRulesAccepted, isTrue);
    expect(b[ProgressStore.chatRulesKey], isNull);
    await s.signOut();
    await s.prefs.pending;
    expect(s.chat.rulesAccepted, isFalse);
  });

  test('no server (offline build): the device lists as before', () async {
    final b = <String, String>{};
    final s = newSession(store: ProgressStore.memory(b));
    await s.board.useHiddenPlayers(s.progressStore);
    s.accountUid = 'u1';
    await s.board.hidePlayer('p1', 'Lan');
    expect(b[ProgressStore.hiddenPlayersKey], '{"p1":"Lan"}');
    expect(s.prefs.onServer, isFalse);
  });

  test('player_prefs doc: bad fields read as empty; the newest 500 kept', () {
    final p = readAccountPrefs({
      'blocked': {'p1': 'Lan', '': 'x', 'p2': 3},
      'chatRulesV1': 'yes',
    });
    expect(p.blocked, {'p1': 'Lan', 'p2': ''});
    expect(p.chatRulesAccepted, isFalse);
    expect(readAccountPrefs({}).isEmpty, isTrue);
    final many = {for (var i = 0; i < 503; i++) 'u$i': 'T$i'};
    final kept = AccountPrefs.capped(many);
    expect(kept.length, AccountPrefs.maxBlocked);
    expect(kept.keys.first, 'u3');
    expect(kept.keys.last, 'u502');
  });
}
