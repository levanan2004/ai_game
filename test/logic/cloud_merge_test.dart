import 'dart:async';
import 'dart:typed_data';

import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/avatar_jpeg.dart';
import 'package:ai_game/logic/cloud_merge.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/supporters.dart';
import 'package:ai_game/logic/xu_grant.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

import '../helpers.dart';

GameState _day(int day) {
  final state = newSession(guestSaves: false).state;
  state.day = day;
  return state;
}

class _MemoryAccount extends OfflineAccount {
  _MemoryAccount(this.cloud);

  GameState? cloud;
  var pushed = 0;
  var pulls = 0;

  @override
  Future<CloudRecord?> pull() async {
    pulls++;
    final saved = cloud;
    if (saved == null) return null;
    return CloudRecord(state: saved, updatedAt: DateTime.utc(2026, 1, 2));
  }

  @override
  Future<void> push(GameState state) async {
    pushed++;
    cloud = GameState.decode(state.encode());
  }

  @override
  Future<AccountProfile?> signIn() async {
    return const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');
  }

  var uploads = 0;

  @override
  Future<String?> uploadAvatar(Uint8List jpeg) async {
    uploads++;
    return 'users/u1/avatar.jpg';
  }
}

class _GrantAccount extends _MemoryAccount {
  _GrantAccount(super.cloud, this.grant);

  final XuGrant grant;

  @override
  Future<XuGrant?> pullGrant() async => grant;
}

void main() {
  test('day 2 or a joined stamp means the account already played', () {
    expect(accountAlreadyPlayed(day: 1, joined: false), isFalse);
    expect(accountAlreadyPlayed(day: 2, joined: false), isTrue);
    expect(accountAlreadyPlayed(day: 15, joined: false), isTrue);
    expect(accountAlreadyPlayed(day: null, joined: true), isTrue);
    expect(accountAlreadyPlayed(day: null, joined: false), isFalse);
  });

  test(
    'signing in to an empty cloud starts fresh and uploads nothing',
    () async {
      final account = _MemoryAccount(null);
      final s = newSession(guestSaves: false, account: account);
      s.startNewGame();
      await s.pendingSaves;
      await s.signIn();
      expect(s.signedIn, isTrue);
      expect(s.accountEmail, 'an@example.com');
      expect(s.state.day, 1);
      expect(s.hasSave, isFalse);
      expect(account.pushed, 0);
      expect(account.cloud, isNull);
      s.startNewGame();
      await s.pendingSaves;
      expect(account.pushed, 1);
      expect(account.cloud!.day, 1);
      expect(account.cloud!.accountUid, 'u1');
      expect(s.lastSavedAt, isNotNull);
    },
  );

  test('signing in adopts a cloud save that is further along', () async {
    final cloud = _day(6);
    cloud.shopName = 'Hoa Ơi';
    final account = _MemoryAccount(cloud);
    final backing = <String, String>{};
    final s = newSession(guestSaves: false, account: account, backing: backing);
    s.startNewGame();
    await s.pendingSaves;
    expect(s.state.day, 1);
    await s.signIn();
    expect(s.state.day, 6);
    expect(s.state.shopName, 'Hoa Ơi');
    expect(s.screen, Screen.title);
    expect(account.pushed, 0);
    final stored = GameState.decode(backing[ProgressStore.accountKey('u1')]);
    expect(stored!.day, 6);
    expect(stored.shopName, 'Hoa Ơi');
    expect(stored.accountUid, 'u1');
    // Guest play is not saved.
    expect(backing.containsKey(ProgressStore.storageKey), isFalse);
  });

  test('another account does not inherit a further local morning', () async {
    final cloud = _day(12);
    final account = _MemoryAccount(cloud);
    final local = _day(15);
    local.accountUid = 'other';
    final s = newSession(guestSaves: false, account: account, saved: local);
    await s.signIn();
    expect(s.state.day, 12);
    expect(s.state.accountUid, 'u1');
    expect(account.pushed, 0);
    expect(account.cloud!.day, 12);
  });

  test('another account with no cloud save starts a new morning', () async {
    final account = _MemoryAccount(null);
    final local = _day(15);
    local.accountUid = 'other';
    final s = newSession(guestSaves: false, account: account, saved: local);
    await s.signIn();
    expect(s.state.day, 1);
    expect(s.state.accountUid, 'u1');
    expect(account.pushed, 0);
    expect(account.cloud, isNull);
  });

  test(
    'signing in uses the cloud morning even when the local day is further',
    () async {
      final cloud = _day(12);
      final account = _MemoryAccount(cloud);
      final local = _day(15);
      local.accountUid = 'u1';
      final s = newSession(guestSaves: false, account: account, saved: local);
      await s.signIn();
      expect(s.state.day, 12);
      expect(account.pushed, 0);
      expect(account.cloud!.day, 12);
    },
  );

  test('signing out starts an unsaved guest game and keeps terms', () async {
    final guest = _day(3);
    final backing = <String, String>{
      ProgressStore.storageKey: guest.encode(),
      ProgressStore.termsKey: 'agreed',
    };
    final account = _MemoryAccount(_day(15));
    final s = newSession(
      guestSaves: false,
      backing: backing,
      saved: guest,
      account: account,
    );
    await s.signIn();
    expect(s.state.day, 15);
    await s.signOut();
    expect(s.signedIn, isFalse);
    expect(s.hasSave, isFalse);
    expect(s.state.day, 1);
    // The old guest slot is left as it was.
    expect(backing[ProgressStore.storageKey], guest.encode());
    expect(GameState.decode(backing[ProgressStore.accountKey('u1')])!.day, 15);
    expect(backing[ProgressStore.termsKey], 'agreed');
    expect(account.pushed, 0);
  });

  test('a failed cloud pull leaves the local game alone', () async {
    final s = newSession(guestSaves: false, account: _ThrowingAccount());
    s.startNewGame();
    await s.pendingSaves;
    final day = s.state.day;
    await s.signIn();
    expect(s.authError, 'Chưa đăng nhập được, thử lại nhé.');
    expect(s.signedIn, isFalse);
    expect(s.state.day, day);
  });

  test('avatar upload is a 128 jpeg at quality 85, under 512KB', () {
    final src = im.Image(width: 400, height: 180);
    im.fill(src, color: im.ColorRgb8(200, 80, 90));
    final jpeg = squareAvatarJpeg(im.encodePng(src));
    expect(jpeg, isNotNull);
    expect(jpeg!.length, lessThan(512 * 1024));
    expect(jpeg.length, lessThan(20 * 1024));
    final back = im.decodeJpg(jpeg)!;
    expect(back.width, 128);
    expect(back.height, 128);
  });

  test(
    'a failed avatar upload shows the error and clears the spinner',
    () async {
      final s = newSession(guestSaves: false, account: _UploadFail());
      s.applySignedIn(
        const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An'),
      );
      final pending = s.uploadOwnerPhoto();
      expect(s.uploadBusy, isTrue);
      await pending;
      expect(s.uploadBusy, isFalse);
      expect(s.uploadError, 'Chưa tải ảnh lên được, thử lại nhé.');
      expect(s.state.ownerAvatar, GameState.defaultOwnerAvatar);
    },
  );

  test(
    'an uploaded photo cached for the account survives the cloud morning',
    () async {
      final cloud = _day(6);
      cloud.ownerAvatar = GameState.defaultOwnerAvatar;
      final account = _MemoryAccount(cloud);
      final cached = _day(3)
        ..accountUid = 'u1'
        ..ownerAvatar = 'users/u1/avatar.jpg';
      final backing = {ProgressStore.accountKey('u1'): cached.encode()};
      final s = newSession(
        guestSaves: false,
        account: account,
        backing: backing,
      );
      await s.signIn();
      expect(s.state.day, 6);
      expect(s.state.ownerAvatar, 'users/u1/avatar.jpg');
      expect(account.uploads, 0);
      expect(account.pushed, 0);
    },
  );

  test('a guest photo is not carried into the account', () async {
    final cloud = _day(6);
    cloud.ownerAvatar = GameState.defaultOwnerAvatar;
    final account = _MemoryAccount(cloud);
    final s = newSession(guestSaves: false, account: account);
    s.startNewGame();
    s.setOwnerAvatar('users/u1/avatar.jpg');
    await s.pendingSaves;
    await s.signIn();
    expect(s.state.day, 6);
    expect(s.state.ownerAvatar, GameState.defaultOwnerAvatar);
    expect(account.pushed, 0);
  });

  test(
    'signing in does not copy the default portrait over an upload',
    () async {
      final account = _MemoryAccount(null);
      final board = _Board();
      final s = newSession(
        guestSaves: false,
        account: account,
        playerDirectory: board,
      );
      s.applySignedIn(
        const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An'),
      );
      await s.pendingAvatarWrites;
      expect(account.uploads, 0);
      expect(board.published, isNull);
      expect(s.state.ownerAvatar, GameState.defaultOwnerAvatar);
    },
  );

  test(
    'a published upload is restored when the save still has the default',
    () async {
      final account = _MemoryAccount(null);
      final board = _Board()..pointer = 'users/u1/avatar.jpg';
      final s = newSession(
        guestSaves: false,
        account: account,
        playerDirectory: board,
      );
      s.applySignedIn(
        const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An'),
      );
      await s.pendingAvatarWrites;
      expect(s.state.ownerAvatar, 'users/u1/avatar.jpg');
      expect(account.uploads, 0);
      expect(board.published, 'users/u1/avatar.jpg');
    },
  );

  test('uploading again refreshes the same storage path', () async {
    final account = _UploadOk();
    final s = newSession(guestSaves: false, account: account);
    s.applySignedIn(
      const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An'),
    );
    await s.uploadOwnerPhoto();
    final rev = s.state.ownerAvatarRev;
    expect(s.state.ownerAvatar, 'users/u1/avatar.jpg');
    expect(rev, greaterThan(0));
    await s.uploadOwnerPhoto();
    expect(s.state.ownerAvatar, 'users/u1/avatar.jpg');
    expect(s.state.ownerAvatarRev, greaterThan(rev));
    expect(account.uploads, 2);
  });

  test('a grant is added once and does not lower the day', () async {
    final cloud = _day(4);
    final before = cloud.money;
    final account = _GrantAccount(
      cloud,
      const XuGrant(id: 'g1', money: 50000, day: 2),
    );
    final s = newSession(guestSaves: false, account: account);
    await s.signIn();
    expect(s.state.money, before + 50000);
    expect(s.state.day, 4);
    expect(s.state.appliedGrantId, 'g1');
    expect(account.cloud!.money, before + 50000);
    expect(account.cloud!.appliedGrantId, 'g1');

    await s.signOut();
    await s.signIn();
    expect(s.state.money, before + 50000);
    expect(s.state.day, 4);
  });

  test('a higher grant day raises the morning without adding money', () async {
    final cloud = _day(2);
    final before = cloud.money;
    final account = _GrantAccount(
      cloud,
      const XuGrant(id: 'g2', money: 0, day: 9),
    );
    final s = newSession(guestSaves: false, account: account);
    await s.signIn();
    expect(s.state.day, 9);
    expect(s.state.money, before);
    expect(account.cloud!.day, 9);
    expect(account.cloud!.appliedGrantId, 'g2');
  });

  test('a second tab takes the seat at once and the first leaves', () async {
    final hub = _SeatHub();
    final account = _HubAccount(null, hub);
    final first = newSession(
      guestSaves: false,
      account: account,
      tabId: 'tab-alpha',
    );
    await first.signIn();
    expect(first.signedIn, isTrue);
    expect(hub.holder, 'tab-alpha');
    expect(account.pushed, 0);
    first.startNewGame();
    await first.pendingSaves;
    expect(account.pushed, 1);

    final second = newSession(
      guestSaves: false,
      account: account,
      tabId: 'tab-bravo',
      saved: _day(9),
    );
    await second.signIn();
    await first.pendingAuth;
    expect(second.signedIn, isTrue);
    expect(second.seatLost, isFalse);
    expect(second.state.day, 1);
    expect(hub.holder, 'tab-bravo');
    // The kicked tab keeps the account and pauses; no guest day 1.
    expect(first.signedIn, isTrue);
    expect(first.seatLost, isTrue);
    expect(first.paused, isTrue);
    expect(first.hasSave, isTrue);
    expect(first.canWriteAccount, isFalse);
    expect(account.cloud!.day, 1);
    expect(account.pushed, 1);
    expect(account.released, 0);
    // The login is shared with the new tab, so the kicked tab keeps it.
    expect(account.signedOut, 0);
  });

  test(
    'a kicked tab drops its queued upload and keeps the local slot',
    () async {
      final hub = _SeatHub();
      final account = _HubAccount(null, hub);
      final backing = <String, String>{};
      final first = newSession(
        guestSaves: false,
        account: account,
        tabId: 'tab-alpha',
        backing: backing,
      );
      await first.signIn();
      first.startNewGame();
      // Another device takes the seat before the upload leaves the queue.
      await account.takeSeat('tab-device');
      await first.pendingAuth;
      await first.pendingSaves;
      expect(account.pushed, 0);
      expect(account.cloud, isNull);
      expect(first.signedIn, isTrue);
      expect(first.seatLost, isTrue);
      expect(backing.containsKey(ProgressStore.accountKey('u1')), isTrue);
      first.state.money += 1000;
      first.startNewGame();
      await first.pendingSaves;
      expect(account.pushed, 0);
      expect(first.seatLost, isTrue);
    },
  );

  test('a kicked tab that reloads takes the seat back', () async {
    final hub = _SeatHub()..holder = 'tab-bravo';
    final account = _HubAccount(_day(4), hub);
    final reloaded = newSession(
      guestSaves: false,
      account: account,
      tabId: 'tab-alpha',
    );
    await reloaded.resumeAccount();
    expect(reloaded.signedIn, isTrue);
    expect(reloaded.state.day, 4);
    expect(hub.holder, 'tab-alpha');
  });

  test('the tab that already holds the seat keeps its local morning', () async {
    final hub = _SeatHub()..holder = 'tab-alpha';
    final account = _HubAccount(_day(10), hub);
    final local = _day(15)..accountUid = 'u1';
    final backing = {ProgressStore.accountKey('u1'): local.encode()};
    final s = newSession(
      guestSaves: false,
      account: account,
      tabId: 'tab-alpha',
      backing: backing,
    );
    await s.signIn();
    expect(s.signedIn, isTrue);
    expect(s.state.day, 15);
    expect(account.pushed, 0);
    expect(account.pulls, 1);
    expect(account.cloud!.day, 10);
  });

  test(
    'a seat reload does not keep a local morning behind the cloud',
    () async {
      final hub = _SeatHub()..holder = 'tab-alpha';
      final account = _HubAccount(_day(15), hub);
      final local = _day(1)..accountUid = 'u1';
      final backing = {ProgressStore.accountKey('u1'): local.encode()};
      final s = newSession(
        guestSaves: false,
        account: account,
        tabId: 'tab-alpha',
        backing: backing,
      );
      await s.signIn();
      expect(s.state.day, 15);
      expect(account.pushed, 0);
      expect(account.cloud!.day, 15);
      expect(
        GameState.decode(backing[ProgressStore.accountKey('u1')])!.day,
        15,
      );
    },
  );

  test(
    'a published photo during sign-in does not upload the guest morning',
    () async {
      final cloud = _day(15);
      final account = _LatePull(cloud);
      final board = _Board()..pointer = 'users/u1/avatar.jpg';
      final s = newSession(
        guestSaves: false,
        account: account,
        playerDirectory: board,
      );
      s.startNewGame();
      await s.pendingSaves;
      final entered = s.signIn();
      await Future<void>.delayed(Duration.zero);
      expect(s.state.ownerAvatar, GameState.defaultOwnerAvatar);
      account.ready.complete();
      await entered;
      await s.pendingAvatarWrites;
      await s.pendingSaves;
      expect(s.state.day, 15);
      expect(s.state.ownerAvatar, 'users/u1/avatar.jpg');
      expect(account.cloud!.day, 15);
    },
  );

  test('signing out releases the seat', () async {
    final hub = _SeatHub();
    final account = _HubAccount(null, hub);
    final s = newSession(
      guestSaves: false,
      account: account,
      tabId: 'tab-alpha',
    );
    s.startNewGame();
    await s.pendingSaves;
    await s.signIn();
    await s.signOut();
    expect(s.signedIn, isFalse);
    expect(hub.holder, isNull);
    expect(account.released, 1);
  });
}

class _SeatHub {
  String? holder;
  final List<void Function(String?)> watchers = [];

  void emit() {
    for (final watcher in [...watchers]) {
      watcher(holder);
    }
  }
}

class _HubAccount extends _MemoryAccount {
  _HubAccount(super.cloud, this.hub);

  final _SeatHub hub;
  void Function(String?)? mine;
  var released = 0;
  var signedOut = 0;

  @override
  Future<String?> seatHolder() async => hub.holder;

  @override
  Future<AccountProfile?> restoreProfile() => signIn();

  @override
  Future<void> takeSeat(String tabId) async {
    hub.holder = tabId;
    hub.emit();
  }

  @override
  Future<void> releaseSeat(String tabId) async {
    if (hub.holder != tabId) return;
    hub.holder = null;
    released++;
    hub.emit();
  }

  @override
  void watchSeat(void Function(String? holderId) onChange) {
    mine = onChange;
    hub.watchers.add(onChange);
    onChange(hub.holder);
  }

  @override
  void stopWatchingSeat() {
    final callback = mine;
    if (callback != null) hub.watchers.remove(callback);
    mine = null;
  }

  @override
  Future<void> signOut() async {
    signedOut++;
  }
}

class _LatePull extends _MemoryAccount {
  _LatePull(super.cloud);

  final ready = Completer<void>();

  @override
  Future<CloudRecord?> pull() async {
    pulls++;
    await ready.future;
    final saved = cloud;
    if (saved == null) return null;
    return CloudRecord(
      state: GameState.decode(saved.encode())!,
      updatedAt: DateTime.utc(2026, 1, 2),
    );
  }
}

class _ThrowingAccount extends OfflineAccount {
  @override
  Future<AccountProfile?> signIn() async {
    throw StateError('offline');
  }
}

class _UploadFail extends OfflineAccount {
  @override
  Future<Uint8List?> pickAvatarJpeg() async => Uint8List.fromList([1, 2, 3]);

  @override
  Future<String?> uploadAvatar(Uint8List jpeg) async {
    throw StateError('offline');
  }
}

class _UploadOk extends OfflineAccount {
  var uploads = 0;

  @override
  Future<Uint8List?> pickAvatarJpeg() async => Uint8List.fromList([1, 2, 3]);

  @override
  Future<String?> uploadAvatar(Uint8List jpeg) async {
    uploads++;
    return 'users/u1/avatar.jpg';
  }
}

class _Board extends NoPlayerDirectory {
  String? pointer;
  String? published;

  @override
  Future<String?> publishedAvatar(String uid) async => pointer;

  @override
  Future<void> publishAvatar({
    required String uid,
    required String path,
    required int rev,
  }) async {
    published = path;
  }
}
