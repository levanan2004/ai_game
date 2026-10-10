// Tin tuc removed in one place stays removed: after a restart of the same
// browser, in another browser (empty local list) and on another device of the
// account (the save carries the ids). Root cause of the bug: the removed ids
// lived only in the browser's local storage.
import 'package:ai_game/logic/game_notice.dart';
import 'package:ai_game/logic/notice_feed.dart';
import 'package:ai_game/save/game_state.dart';
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
