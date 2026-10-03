import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/cloud_merge.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

GameState _day(int day) {
  final state = newSession().state;
  state.day = day;
  return state;
}

class _Cloud extends OfflineAccount {
  _Cloud(this.cloud);

  GameState? cloud;
  var pushed = 0;
  var failPull = false;

  @override
  Future<AccountProfile?> signIn() async =>
      const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');

  @override
  Future<CloudRecord?> pull() async {
    if (failPull) throw StateError('offline');
    final saved = cloud;
    if (saved == null) return null;
    return CloudRecord(state: GameState.decode(saved.encode())!);
  }

  @override
  Future<void> push(GameState state) async {
    pushed++;
    cloud = GameState.decode(state.encode());
  }
}

GameState? _slot(Map<String, String> backing, String key) =>
    GameState.decode(backing[key]);

void main() {
  test(
    'day 56 account, logged out, guest day 2, sign in again: day 56',
    () async {
      final account = _Cloud(_day(56));
      final backing = <String, String>{};
      final s = newSession(account: account, backing: backing);
      await s.signIn();
      expect(s.state.day, 56);
      await s.signOut();
      expect(s.signedIn, isFalse);

      // Guest plays on the website up to day 2.
      s.startNewGame();
      await s.pendingSaves;
      finishDayAndCommit(s);
      await s.pendingSaves;
      expect(s.state.day, 2);
      expect(_slot(backing, ProgressStore.storageKey)!.day, 2);

      await s.signIn();
      await s.pendingSaves;
      expect(s.signedIn, isTrue);
      expect(s.state.day, 56);
      expect(account.cloud!.day, 56);
      expect(account.pushed, 0);
      expect(_slot(backing, ProgressStore.storageKey)!.day, 2);
      expect(_slot(backing, ProgressStore.storageKey)!.accountUid, isNull);
    },
  );

  test(
    'day 56 cloud and guest day 2: loads 56, guest slot untouched',
    () async {
      final guest = _day(2);
      final backing = {ProgressStore.storageKey: guest.encode()};
      final account = _Cloud(_day(56));
      final s = newSession(account: account, backing: backing, saved: guest);
      await s.signIn();
      await s.pendingSaves;
      expect(s.signedIn, isTrue);
      expect(s.state.day, 56);
      expect(s.state.accountUid, 'u1');
      expect(s.screen, Screen.title);
      expect(s.accountNotice, accountLoadedNotice(56));
      expect(
        s.accountNotice,
        'Chào mừng chủ tiệm quay lại! Tiệm đang ở ngày 56.',
      );
      expect(account.pushed, 0);
      expect(account.cloud!.day, 56);
      expect(backing[ProgressStore.storageKey], guest.encode());
      expect(_slot(backing, ProgressStore.accountKey('u1'))!.day, 56);
    },
  );

  test(
    'empty cloud and guest day 2: account starts fresh, nothing uploaded',
    () async {
      final guest = _day(2)..shopName = 'Hoa Khách';
      final backing = {ProgressStore.storageKey: guest.encode()};
      final account = _Cloud(null);
      final s = newSession(account: account, backing: backing, saved: guest);
      await s.signIn();
      await s.pendingSaves;
      expect(s.signedIn, isTrue);
      expect(s.state.day, 1);
      expect(s.state.shopName, isNull);
      expect(s.hasSave, isFalse);
      expect(s.screen, Screen.title);
      expect(s.accountNotice, newAccountNotice);
      expect(account.pushed, 0);
      expect(account.cloud, isNull);
      expect(backing[ProgressStore.storageKey], guest.encode());
      expect(backing.containsKey(ProgressStore.accountKey('u1')), isFalse);
    },
  );

  test(
    'sign out returns to the guest save; signing back in loads the account',
    () async {
      final guest = _day(3);
      final backing = {ProgressStore.storageKey: guest.encode()};
      final account = _Cloud(_day(56));
      final s = newSession(account: account, backing: backing, saved: guest);
      await s.signIn();
      expect(s.state.day, 56);
      await s.signOut();
      expect(s.signedIn, isFalse);
      expect(s.state.day, 3);
      expect(s.hasSave, isTrue);
      expect(s.state.accountUid, isNull);
      await s.signIn();
      expect(s.state.day, 56);
      expect(account.pushed, 0);
      expect(backing[ProgressStore.storageKey], guest.encode());
    },
  );

  test(
    'saves while signed in write the cloud and the account slot only',
    () async {
      final backing = <String, String>{};
      final account = _Cloud(null);
      final s = newSession(account: account, backing: backing);
      await s.signIn();
      s.startNewGame();
      await s.pendingSaves;
      expect(account.pushed, 1);
      expect(account.cloud!.day, 1);
      finishDayAndCommit(s);
      await s.pendingSaves;
      expect(s.state.day, 2);
      expect(account.cloud!.day, 2);
      expect(account.cloud!.accountUid, 'u1');
      expect(_slot(backing, ProgressStore.accountKey('u1'))!.day, 2);
      expect(backing.containsKey(ProgressStore.storageKey), isFalse);

      await s.signOut();
      final pushed = account.pushed;
      s.startNewGame();
      await s.pendingSaves;
      expect(account.pushed, pushed);
      expect(account.cloud!.day, 2);
      expect(_slot(backing, ProgressStore.storageKey)!.day, 1);
    },
  );

  test(
    'a cloud that cannot be read keeps the guest game and writes nothing',
    () async {
      final guest = _day(2);
      final backing = {ProgressStore.storageKey: guest.encode()};
      final account = _Cloud(_day(56))..failPull = true;
      final s = newSession(account: account, backing: backing, saved: guest);
      await s.signIn();
      await s.pendingSaves;
      expect(s.signedIn, isFalse);
      expect(s.authError, accountPullFailedNotice);
      expect(s.state.day, 2);
      expect(account.pushed, 0);
      expect(account.cloud!.day, 56);
      expect(backing[ProgressStore.storageKey], guest.encode());
    },
  );

  test(
    'an old single save tagged with an account moves off the guest slot',
    () async {
      final tagged = _day(9)..accountUid = 'u1';
      final backing = {ProgressStore.storageKey: tagged.encode()};
      final store = ProgressStore.memory(backing);
      await store.moveAccountSaveOffGuest();
      expect(backing.containsKey(ProgressStore.storageKey), isFalse);
      expect(_slot(backing, ProgressStore.accountKey('u1'))!.day, 9);

      final untagged = _day(4);
      final guestOnly = {ProgressStore.storageKey: untagged.encode()};
      await ProgressStore.memory(guestOnly).moveAccountSaveOffGuest();
      expect(guestOnly[ProgressStore.storageKey], untagged.encode());
      expect(guestOnly.length, 1);
    },
  );

  test(
    'a moved save does not replace one already in the account slot',
    () async {
      final tagged = _day(9)..accountUid = 'u1';
      final newer = _day(20)..accountUid = 'u1';
      final backing = {
        ProgressStore.storageKey: tagged.encode(),
        ProgressStore.accountKey('u1'): newer.encode(),
      };
      await ProgressStore.memory(backing).moveAccountSaveOffGuest();
      expect(backing.containsKey(ProgressStore.storageKey), isFalse);
      expect(_slot(backing, ProgressStore.accountKey('u1'))!.day, 20);
    },
  );

  test('a reload waits for the restored login before resuming', () async {
    final account = _Restoring(_day(56));
    final s = newSession(account: account);
    await s.resumeAccount();
    expect(s.signedIn, isTrue);
    expect(s.state.day, 56);
    expect(account.pushed, 0);
  });
}

class _Restoring extends _Cloud {
  _Restoring(super.cloud);

  @override
  AccountProfile? currentProfile() => null;

  @override
  Future<AccountProfile?> restoreProfile() async {
    await Future<void>.delayed(Duration.zero);
    return const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');
  }
}
