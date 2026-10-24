import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

CharmBoardRow _row(String uid) => CharmBoardRow(
  3,
  CharmBoardEntry.forPlayer(uid: uid, displayName: 'Hoa Lan', charm: 200),
);

void main() {
  test('the hidden list round-trips and survives bad data', () async {
    final backing = <String, String>{};
    final store = ProgressStore.memory(backing);
    expect(await store.loadHiddenPlayers(), isEmpty);
    await store.saveHiddenPlayers({'p1': 'Hoa Lan', 'p2': 'Tiệm Cúc'});
    expect(
      backing[ProgressStore.hiddenPlayersKey],
      '{"p1":"Hoa Lan","p2":"Tiệm Cúc"}',
    );
    expect(await store.loadHiddenPlayers(), {
      'p1': 'Hoa Lan',
      'p2': 'Tiệm Cúc',
    });
    backing[ProgressStore.hiddenPlayersKey] = 'not json';
    expect(await store.loadHiddenPlayers(), isEmpty);
    backing[ProgressStore.hiddenPlayersKey] = '["p1"]';
    expect(await store.loadHiddenPlayers(), isEmpty);
    // A missing name still hides the uid.
    backing[ProgressStore.hiddenPlayersKey] = '{"a":1}';
    expect(await store.loadHiddenPlayers(), {'a': ''});
  });

  test('hide from the open profile, saved on the device; unhide', () async {
    final backing = <String, String>{};
    final store = ProgressStore.memory(backing);
    final s = newSession(store: store)..accountUid = 'me';
    await s.board.useHiddenPlayers(store);
    s.board.openProfile(_row('p1'));
    s.board.openReport();
    expect(await s.board.hideProfile(), 'Hoa Lan');
    expect(s.board.isHidden('p1'), isTrue);
    expect(s.board.profile, isNull);
    expect(s.board.reportOpen, isFalse);
    expect(await store.loadHiddenPlayers(), {'p1': 'Hoa Lan'});

    // A new session on the same device reads it back.
    final again = newSession(store: store)..accountUid = 'me';
    await again.board.useHiddenPlayers(store);
    expect(again.board.isHidden('p1'), isTrue);
    // Its profile does not open: the "Người chơi đã ẩn" list does.
    again.board.openProfile(_row('p1'));
    expect(again.board.profile, isNull);
    expect(again.board.hiddenListOpen, isTrue);

    await again.board.unhide('p1');
    expect(again.board.isHidden('p1'), isFalse);
    expect(await store.loadHiddenPlayers(), isEmpty);
  });

  test('your own row and a guest cannot hide', () async {
    final store = ProgressStore.memory({});
    final s = newSession(store: store)..accountUid = 'me';
    await s.board.useHiddenPlayers(store);
    s.board.openProfile(_row('me'));
    expect(await s.board.hideProfile(), isNull);
    expect(s.board.hidden, isEmpty);
    // Even a stored own uid is never treated as hidden.
    s.board.hidden = {'me': 'Tôi'};
    expect(s.board.isHidden('me'), isFalse);

    final guest = newSession(store: store);
    guest.board.openProfile(_row('p1'));
    expect(await guest.board.hideProfile(), isNull);
  });
}
