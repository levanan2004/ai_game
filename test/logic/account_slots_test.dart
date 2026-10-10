import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/cloud_merge.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/save_status.dart';
import 'package:ai_game/ui/seat_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _an = AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');

GameState _day(int day, {String? uid}) {
  final state = newSession().state;
  state.day = day;
  state.accountUid = uid;
  return state;
}

/// The game's real rule: guest play is not saved.
ShopSession _session({
  Map<String, String>? backing,
  GameState? saved,
  AccountGateway? account,
  String? tabId,
  AccountProfile? lastAccount,
}) {
  final store = ProgressStore.memory(backing ?? {});
  if (lastAccount != null) store.useAccount(lastAccount.uid);
  return newSession(
    store: store,
    saved: saved,
    account: account,
    tabId: tabId,
    lastAccount: lastAccount,
    guestSaves: false,
  );
}

class _Cloud extends OfflineAccount {
  _Cloud(this.cloud);

  GameState? cloud;
  var pushed = 0;
  var failPulls = 0;
  var restoreFailures = 0;
  var restoreCalls = 0;
  bool loggedIn = true;
  String? holder;
  void Function(String?)? watcher;

  @override
  AccountProfile? currentProfile() => loggedIn ? _an : null;

  @override
  Future<AccountProfile?> signIn() async {
    loggedIn = true;
    return _an;
  }

  @override
  Future<AccountProfile?> restoreProfile() async {
    restoreCalls++;
    if (restoreFailures > 0) {
      restoreFailures--;
      throw StateError('slow');
    }
    return loggedIn ? _an : null;
  }

  @override
  Future<CloudRecord?> pull() async {
    if (failPulls > 0) {
      failPulls--;
      throw StateError('offline');
    }
    final saved = cloud;
    if (saved == null) return null;
    return CloudRecord(state: GameState.decode(saved.encode())!);
  }

  @override
  Future<void> push(GameState state) async {
    pushed++;
    cloud = GameState.decode(state.encode());
  }

  @override
  Future<String?> seatHolder() async => holder;

  @override
  Future<void> takeSeat(String tabId) async {
    holder = tabId;
    watcher?.call(holder);
  }

  @override
  void watchSeat(void Function(String? holderId) onChange) {
    watcher = onChange;
    onChange(holder);
  }

  @override
  void stopWatchingSeat() => watcher = null;

  /// Another tab or device opens the account.
  void takenElsewhere() {
    holder = 'tab-elsewhere';
    watcher?.call(holder);
  }
}

GameState? _slot(Map<String, String> backing, String key) =>
    GameState.decode(backing[key]);

void main() {
  group('pickMorning', () {
    test('the cloud wins over this device', () {
      expect(
        pickMorning(keepLocal: false, cached: _day(40), cloud: _day(30)),
        MorningPick.cloud,
      );
      expect(
        pickMorning(keepLocal: false, cached: _day(4), cloud: _day(30)),
        MorningPick.cloud,
      );
    });

    test('a same-tab reload keeps its copy at the same or a later day', () {
      expect(
        pickMorning(keepLocal: true, cached: _day(30), cloud: _day(30)),
        MorningPick.cached,
      );
      expect(
        pickMorning(keepLocal: true, cached: _day(31), cloud: _day(30)),
        MorningPick.cached,
      );
      expect(
        pickMorning(keepLocal: true, cached: _day(4), cloud: _day(30)),
        MorningPick.cloud,
      );
    });

    test('an empty cloud uses the account copy before starting fresh', () {
      expect(
        pickMorning(keepLocal: false, cached: _day(9), cloud: null),
        MorningPick.cached,
      );
      expect(
        pickMorning(keepLocal: false, cached: null, cloud: null),
        MorningPick.fresh,
      );
    });

    test('a lower day never replaces the cloud without Chơi mới', () {
      expect(
        mayReplaceCloud(cloudDay: 30, nextDay: 4, allowLower: false),
        isFalse,
      );
      expect(
        mayReplaceCloud(cloudDay: 30, nextDay: 1, allowLower: true),
        isTrue,
      );
      expect(
        mayReplaceCloud(cloudDay: 30, nextDay: 31, allowLower: false),
        isTrue,
      );
      expect(
        mayReplaceCloud(cloudDay: 0, nextDay: 1, allowLower: false),
        isTrue,
      );
    });
  });

  test('guest play is not saved anywhere', () async {
    final backing = <String, String>{};
    final s = _session(backing: backing);
    s.startNewGame();
    finishDayAndCommit(s);
    await s.pendingSaves;
    expect(s.state.day, 2);
    expect(s.hasSave, isTrue);
    expect(
      backing.keys.where((k) => k.startsWith('ai_game.progress')),
      isEmpty,
    );
    expect(s.showGuestBanner, isTrue);
    expect(s.saveLabel, 'Đang chơi thử, tiến độ không được lưu');
  });

  test('the old guest slot is ignored and left untouched', () async {
    final old = _day(30).encode();
    final backing = {ProgressStore.legacyGuestKey: old};
    final account = _Cloud(null);
    final s = _session(backing: backing, account: account);
    s.startNewGame();
    await s.pendingSaves;
    await s.signIn();
    await s.pendingSaves;
    expect(s.state.day, 1);
    expect(account.pushed, 0);
    await s.signOut();
    expect(s.state.day, 1);
    expect(backing[ProgressStore.legacyGuestKey], old);
  });

  test('signing in loads the cloud and remembers the account', () async {
    final backing = <String, String>{};
    final account = _Cloud(_day(30));
    final s = _session(backing: backing, account: account);
    await s.signIn();
    await s.pendingSaves;
    expect(s.state.day, 30);
    expect(s.saveLabel, 'Tài khoản: An');
    expect(s.showGuestBanner, isFalse);
    expect(_slot(backing, ProgressStore.accountKey('u1'))!.day, 30);
    final last = await ProgressStore.memory(backing).loadLastAccount();
    expect(last!.uid, 'u1');
    expect(last.name, 'An');
  });

  test(
    'report scenario A: kicked by another tab, the game pauses on day 30 '
    'instead of a guest day 1, and reopening loads the newest cloud',
    () async {
      final backing = <String, String>{};
      final account = _Cloud(_day(30));
      final s = _session(backing: backing, account: account, tabId: 'tab-a');
      await s.signIn();
      s.continueGame();
      await s.pendingSaves;
      account.takenElsewhere();
      expect(s.seatLost, isTrue);
      expect(s.paused, isTrue);
      expect(s.signedIn, isTrue);
      expect(s.state.day, 30);
      expect(s.canWriteAccount, isFalse);
      // Nothing from this tab reaches the account or the shared slot.
      final slot = backing[ProgressStore.accountKey('u1')];
      s.setMusic(false);
      await s.pendingSaves;
      expect(account.pushed, 0);
      expect(backing[ProgressStore.accountKey('u1')], slot);

      // The other device played on to day 33.
      account.cloud = _day(33);
      await s.reopenHere();
      expect(s.seatLost, isFalse);
      expect(s.paused, isFalse);
      expect(account.holder, 'tab-a');
      expect(s.state.day, 33);
      expect(s.screen, Screen.title);
      // Kicked again later: the watcher is live again.
      account.takenElsewhere();
      expect(s.seatLost, isTrue);
    },
  );

  test('report scenario B: a reload with a slow login keeps trying on the '
      'account copy and never shows a guest day 1', () async {
    final backing = {
      ProgressStore.accountKey('u1'): _day(30, uid: 'u1').encode(),
    };
    final account = _Cloud(_day(30))
      ..restoreFailures = 3
      ..holder = 'tab-a';
    final store = ProgressStore.memory(backing)..useAccount('u1');
    final saved = await store.load();
    final s = _session(
      backing: backing,
      saved: saved,
      account: account,
      tabId: 'tab-a',
      lastAccount: _an,
    );
    expect(s.accountOpening, isTrue);
    expect(s.state.day, 30);
    expect(s.showGuestBanner, isFalse);
    expect(s.saveLabel, 'Đang mở tiệm...');
    await s.resumeAccount();
    expect(account.restoreCalls, 4);
    expect(s.signedIn, isTrue);
    expect(s.accountOpening, isFalse);
    expect(s.state.day, 30);
    expect(account.pushed, 0);
  });

  test(
    'an unreadable cloud on reload is retried, not treated as empty',
    () async {
      final backing = {
        ProgressStore.accountKey('u1'): _day(12, uid: 'u1').encode(),
      };
      final account = _Cloud(_day(30))..failPulls = 2;
      final s = _session(
        backing: backing,
        saved: _day(12, uid: 'u1'),
        account: account,
        lastAccount: _an,
      );
      await s.resumeAccount();
      expect(s.signedIn, isTrue);
      expect(s.state.day, 30);
      expect(account.pushed, 0);
      expect(account.cloud!.day, 30);
    },
  );

  test(
    'a login that is gone ends the wait: unsaved guest, copy kept',
    () async {
      final copy = _day(30, uid: 'u1').encode();
      final backing = {
        ProgressStore.accountKey('u1'): copy,
        ProgressStore.lastAccountKey: '{"uid":"u1","email":"an@example.com"}',
      };
      final account = _Cloud(_day(30))..loggedIn = false;
      final s = _session(
        backing: backing,
        saved: GameState.decode(copy),
        account: account,
        lastAccount: _an,
      );
      await s.resumeAccount();
      await s.pendingSaves;
      expect(s.signedIn, isFalse);
      expect(s.accountOpening, isFalse);
      expect(s.authError, loginExpiredNotice);
      expect(s.state.day, 1);
      expect(s.hasSave, isFalse);
      expect(backing[ProgressStore.accountKey('u1')], copy);
      expect(backing.containsKey(ProgressStore.lastAccountKey), isFalse);
      // Guest play from here is not saved over the account copy.
      s.startNewGame();
      await s.pendingSaves;
      expect(backing[ProgressStore.accountKey('u1')], copy);
    },
  );

  test('a lower day is not uploaded over a higher cloud day', () async {
    final account = _Cloud(_day(30));
    final s = _session(account: account);
    await s.signIn();
    s.continueGame();
    // Something put an earlier morning in play (e.g. an old copy).
    s.state.day = 3;
    finishDayAndCommit(s);
    await s.pendingSaves;
    expect(s.blockedLowerPushes, 1);
    expect(account.pushed, 0);
    expect(account.cloud!.day, 30);

    // A confirmed "Chơi mới" may start over.
    s.startNewGame();
    await s.pendingSaves;
    expect(account.cloud!.day, 1);
    expect(s.cloudDay, 1);
  });

  test('an empty cloud uses the account copy on this device', () async {
    final backing = {
      ProgressStore.accountKey('u1'): _day(9, uid: 'u1').encode(),
    };
    final account = _Cloud(null);
    final s = _session(backing: backing, account: account);
    await s.signIn();
    expect(s.state.day, 9);
    expect(s.hasSave, isTrue);
    s.continueGame();
    finishDayAndCommit(s);
    await s.pendingSaves;
    expect(account.cloud!.day, 10);
  });

  test(
    'signing out goes to an unsaved guest game and forgets the account',
    () async {
      final backing = <String, String>{};
      final account = _Cloud(_day(30));
      final s = _session(backing: backing, account: account);
      await s.signIn();
      await s.pendingSaves;
      await s.signOut();
      expect(s.signedIn, isFalse);
      expect(s.state.day, 1);
      expect(s.hasSave, isFalse);
      expect(backing.containsKey(ProgressStore.lastAccountKey), isFalse);
      expect(_slot(backing, ProgressStore.accountKey('u1'))!.day, 30);
    },
  );

  test('a reload waits for the restored login before resuming', () async {
    final account = _Cloud(_day(56));
    final s = _session(account: account);
    await s.resumeAccount();
    expect(s.signedIn, isTrue);
    expect(s.state.day, 56);
    expect(account.pushed, 0);
  });

  testWidgets('seat-lost card: title, reopen button, backdrop does not close', (
    tester,
  ) async {
    final s = _session(tabId: 'tab-alpha')..seatLost = true;
    await tester.pumpWidget(MaterialApp(home: SeatLostPopup(session: s)));
    expect(find.text('Tiệm đang được mở ở nơi khác.'), findsOneWidget);
    expect(find.text('Mở lại tiệm ở đây'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(s.seatLost, isTrue);
  });

  testWidgets('guest strip wraps to two lines at 360 dp', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 360,
            child: GuestStrip(onSignIn: () => taps++),
          ),
        ),
      ),
    );
    expect(find.text('Đang chơi thử, tiến độ không được lưu'), findsOneWidget);
    final h = tester.getSize(find.byKey(const Key('save-guest-strip'))).height;
    expect(h, greaterThanOrEqualTo(42));
    expect(h, lessThanOrEqualTo(56));
    await tester.tap(find.byKey(const Key('save-guest-sign-in')));
    expect(taps, 1);
  });

  testWidgets('account pill shows the name and opens Cài đặt', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: AccountPill(label: 'Tài khoản: An Lê', onTap: () => taps++),
        ),
      ),
    );
    expect(find.text('Tài khoản: An Lê'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-account-pill')));
    expect(taps, 1);
  });
}
