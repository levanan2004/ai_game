// Tin tuc removed in one place stays removed: after a restart of the same
// browser, in another browser (empty local list) and on another device of the
// account (the save carries the ids). Root cause of the bug: the removed ids
// lived only in the browser's local storage.
import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/game_notice.dart';
import 'package:ai_game/logic/notice_feed.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

GameNotice _n(String id) =>
    GameNotice(id: id, title: 'Tin $id', body: 'Noi dung $id', createdAt: null);

class _Board implements NoticeBoard {
  _Board(this.items);
  final List<GameNotice> items;
  @override
  Future<List<GameNotice>> published() async => items;
}

/// One fake browser: the same map across restarts, a new map = a new browser.
class _Browser {
  final data = <String, String>{};
  NoticeSeen seen() => NoticeSeen(
    read: (k) async => data[k],
    write: (k, v) async => data[k] = v,
  );
}

NoticeFeed _feed(_Browser b, {dynamic account}) => NoticeFeed(
  board: _Board([_n('a'), _n('b'), _n('c')]),
  seen: b.seen(),
  account: account,
);

GameState _save() => newSession().state;

List<String> _ids(NoticeFeed f) => [for (final n in f.visible) n.id];

void main() {
  _liveTests();
  test('a removed notice stays removed after the browser restarts', () async {
    final browser = _Browser();
    final feed = _feed(browser);
    await feed.start();
    expect(_ids(feed), ['a', 'b', 'c']);
    await feed.dismiss('b');
    expect(_ids(feed), ['a', 'c']);
    feed.dispose();

    final again = _feed(browser);
    await again.start();
    expect(_ids(again), ['a', 'c']);
    again.dispose();
  });

  test('removing while the stored list is still loading is not lost', () async {
    final browser = _Browser();
    final first = _feed(browser);
    await first.start();
    await first.dismiss('a');
    first.dispose();

    final feed = _feed(browser);
    // start() reads the stored list; the user removes another meanwhile.
    final starting = feed.start();
    await feed.dismiss('c');
    await starting;
    expect(_ids(feed), ['b']);
  });

  test(
    'signed in: the account save keeps it, another browser sees it gone',
    () async {
      final s = newSession()..accountUid = 'me';
      final feed = _feed(_Browser(), account: s);
      await feed.start();
      await feed.dismiss('b');
      expect(s.state.hiddenNotices, ['b']);

      // Another device: the save travels (encode/decode = the cloud copy), the
      // browser there has an empty local list.
      final other = newSession(saved: GameState.decode(s.state.encode()))
        ..accountUid = 'me';
      final feed2 = _feed(_Browser(), account: other);
      await feed2.start();
      expect(_ids(feed2), ['a', 'c']);
    },
  );

  test('a guest keeps it in the browser only; the save is untouched', () async {
    final s = newSession();
    final feed = _feed(_Browser(), account: s);
    await feed.start();
    await feed.dismiss('a');
    expect(_ids(feed), ['b', 'c']);
    expect(s.state.hiddenNotices, isEmpty);
  });

  test(
    'notices removed while signed out move into the account on sign-in',
    () async {
      final browser = _Browser();
      final s = newSession();
      final feed = _feed(browser, account: s);
      await feed.start();
      await feed.dismiss('a'); // guest
      s.accountUid = 'me'; // signs in later
      await feed.refresh();
      expect(s.state.hiddenNotices, ['a']);
    },
  );

  test(
    'the account list arriving later hides the notice and tells the UI',
    () async {
      final s = newSession()..accountUid = 'me';
      final feed = _feed(_Browser(), account: s);
      await feed.start();
      var told = 0;
      feed.addListener(() => told++);
      expect(_ids(feed), ['a', 'b', 'c']);
      // The cloud save is adopted with c removed on another device.
      s.state.hiddenNotices = ['c'];
      s.notifyListeners();
      expect(told, 1);
      expect(_ids(feed), ['a', 'b']);
      // Further notifications that change nothing stay quiet.
      s.notifyListeners();
      expect(told, 1);
    },
  );

  group('the save', () {
    test('hiddenNotices round-trips and is left out when empty', () {
      final s = _save();
      expect(s.encode(), isNot(contains('hiddenNotices')));
      s.hiddenNotices = ['x', 'y'];
      expect(GameState.decode(s.encode())!.hiddenNotices, ['x', 'y']);
    });

    test('an old save without the field loads as empty', () {
      expect(GameState.decode(_save().encode())!.hiddenNotices, isEmpty);
    });

    test('junk and repeats are dropped, the newest $maxHiddenNotices kept', () {
      expect(lastHiddenNotices(['a', 'a', 'b']), ['a', 'b']);
      final many = [for (var i = 0; i < maxHiddenNotices + 5; i++) 'n$i'];
      final kept = lastHiddenNotices(many);
      expect(kept.length, maxHiddenNotices);
      expect(kept.first, 'n5');
      expect(kept.last, 'n${maxHiddenNotices + 4}');
      final s = _save()..hiddenNotices = ['ok'];
      final json = s.encode().replaceFirst('["ok"]', '["ok", 3, "", null]');
      expect(GameState.decode(json)!.hiddenNotices, ['ok']);
    });

    test('hideNotices updates the save once per id', () {
      final s = newSession()..accountUid = 'me';
      s.hideNotices(['a', 'b']);
      s.hideNotices(['b', 'c', '']);
      expect(s.state.hiddenNotices, ['a', 'b', 'c']);
      expect(s.hiddenNoticeCount, 3);
    });
  });
}

// ---------------------------------------------------------------------------
// The live report: two announcements removed, back after reloading the site.
// Real-looking Firestore ids and the kinds of the two notices An removed.

const _findDonors = 'q7Ls0Yw3NfT2xKbVu8cA'; // "Tìm người đã ủng hộ [...]" 03/10
const _compForm = 'Zp4mRd9HvJ1eGoQ6tYzB'; // "[Form] Quà đền bù" 30/09

GameNotice _live(String id, String title, NoticeKind kind) => GameNotice(
  id: id,
  title: title,
  body: 'Noi dung',
  kind: kind,
  createdAt: null,
);

final _liveBoard = [
  _live(
    _findDonors,
    'Tìm người đã ủng hộ [hết hạn gửi thông tin 09/10]',
    NoticeKind.form,
  ),
  _live(_compForm, '[Form] Quà đền bù', NoticeKind.form),
  _live('Ab12Cd34Ef56Gh78Ij90', 'Chào mừng', NoticeKind.read),
];

class _Cloud extends OfflineAccount {
  _Cloud(this.cloud);
  GameState? cloud;
  var pushed = 0;

  @override
  Future<CloudRecord?> pull() async => cloud == null
      ? null
      : CloudRecord(state: cloud!, updatedAt: DateTime.utc(2026, 1, 2));

  @override
  Future<void> push(GameState state) async {
    pushed++;
    cloud = GameState.decode(state.encode());
  }

  @override
  Future<String?> seatHolder() async => 'tab-1'; // a reload of the seat tab

  @override
  Future<AccountProfile?> restoreProfile() async =>
      const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');

  @override
  Future<AccountProfile?> signIn() async =>
      const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');
}

GameState _cloudDay(int day, {List<String> hidden = const []}) {
  final s = newSession(guestSaves: false).state;
  s.day = day;
  s.hiddenNotices = [...hidden];
  return s;
}

NoticeFeed _liveFeed(_Browser b, ShopSession s) =>
    NoticeFeed(board: _Board(_liveBoard), seen: b.seen(), account: s);

List<String> _liveIds(NoticeFeed f) => [for (final n in f.visible) n.id];

void _liveTests() {
  group('the live report (removed notices came back)', () {
    test(
      'removed before the fix (only in this browser): sign-in moves them into '
      'the account and the cloud, so a new browser does not show them',
      () async {
        final browser = _Browser();
        // The old build had stored them only here.
        browser.data[NoticeSeen.hiddenKey] = '["$_findDonors","$_compForm"]';
        final account = _Cloud(_cloudDay(6));
        final s = newSession(guestSaves: false, account: account);
        final feed = _liveFeed(browser, s);
        await feed.start();
        await s.signIn();
        await s.pendingSaves;
        expect(s.state.hiddenNotices, containsAll([_findDonors, _compForm]));
        expect(
          account.cloud!.hiddenNotices,
          containsAll([_findDonors, _compForm]),
        );
        expect(_liveIds(feed), ['Ab12Cd34Ef56Gh78Ij90']);

        // Another browser / cleared site data: nothing local, the account
        // alone hides them.
        final s2 = newSession(
          guestSaves: false,
          account: _Cloud(account.cloud),
        );
        final feed2 = _liveFeed(_Browser(), s2);
        await feed2.start();
        await s2.signIn();
        await s2.pendingSaves;
        expect(_liveIds(feed2), ['Ab12Cd34Ef56Gh78Ij90']);
      },
    );

    test('removed while playing: the cloud save has them at once', () async {
      final account = _Cloud(_cloudDay(6));
      final s = newSession(guestSaves: false, account: account);
      final feed = _liveFeed(_Browser(), s);
      await feed.start();
      await s.signIn();
      await s.pendingSaves;
      await feed.dismiss(_findDonors);
      await feed.dismiss(_compForm);
      await s.pendingSaves;
      expect(account.cloud!.hiddenNotices, [_findDonors, _compForm]);

      final s2 = newSession(guestSaves: false, account: _Cloud(account.cloud));
      final feed2 = _liveFeed(_Browser(), s2);
      await feed2.start();
      await s2.signIn();
      expect(_liveIds(feed2), ['Ab12Cd34Ef56Gh78Ij90']);
    });

    test("this device's morning wins over an older cloud copy: the ids removed "
        'on another device are not lost with it', () async {
      final account = _Cloud(_cloudDay(6, hidden: [_findDonors]));
      final local = _cloudDay(9, hidden: [_compForm])..accountUid = 'u1';
      final s = newSession(
        guestSaves: false,
        account: account,
        backing: {ProgressStore.accountKey('u1'): local.encode()},
        tabId: 'tab-1',
      );
      final feed = _liveFeed(_Browser(), s);
      await feed.start();
      await s.resumeAccount();
      await s.pendingSaves;
      expect(s.state.day, 9);
      expect(s.state.hiddenNotices, unorderedEquals([_findDonors, _compForm]));
      expect(
        account.cloud!.hiddenNotices,
        unorderedEquals([_findDonors, _compForm]),
      );
      expect(_liveIds(feed), ['Ab12Cd34Ef56Gh78Ij90']);
    });

    test(
      'the cloud morning wins: ids removed on this browser are kept',
      () async {
        final browser = _Browser();
        browser.data[NoticeSeen.hiddenKey] = '["$_compForm"]';
        final account = _Cloud(_cloudDay(6, hidden: [_findDonors]));
        final s = newSession(guestSaves: false, account: account);
        final feed = _liveFeed(browser, s);
        await feed.start();
        await s.signIn();
        await s.pendingSaves;
        expect(
          s.state.hiddenNotices,
          unorderedEquals([_findDonors, _compForm]),
        );
        expect(account.cloud!.hiddenNotices, contains(_compForm));
        expect(_liveIds(feed), ['Ab12Cd34Ef56Gh78Ij90']);
      },
    );
  });
}
