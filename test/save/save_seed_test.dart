import 'dart:convert';

import 'package:ai_game/logic/stable_hash.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('a new game gets its save seed once', () {
    final s = newSession(saveSeed: 777);
    expect(s.state.saveSeed, 777);
    // A new seed source does not change an existing save.
    final again = newSession(saved: s.state, saveSeed: 1);
    expect(again.state.saveSeed, 777);
  });

  test('saveSeed round-trips (local and cloud progress map)', () {
    final s = newSession(saveSeed: 123456789);
    final back = GameState.decode(s.state.encode())!;
    expect(back.saveSeed, 123456789);
    // Cloud stores state.toJson() as the progress map and decodes it back.
    final cloud = jsonDecode(jsonEncode(s.state.toJson()));
    expect((cloud as Map)['saveSeed'], 123456789);
    expect(GameState.decode(jsonEncode(cloud))!.saveSeed, 123456789);
  });

  test('an old save without a seed is backfilled, stable and saved', () async {
    final old = newSession().state.toJson()..remove('saveSeed');
    final raw = jsonEncode(old);
    expect(GameState.decode(raw)!.saveSeed, 0);
    final backing = <String, String>{};
    final a = newSession(saved: GameState.decode(raw), backing: backing);
    final b = newSession(saved: GameState.decode(raw));
    expect(a.state.saveSeed, isNot(0));
    expect(a.state.saveSeed, b.state.saveSeed);
    await pumpEventQueue();
    final stored = GameState.decode(backing[ProgressStore.storageKey]);
    expect(stored?.saveSeed, a.state.saveSeed);
  });

  test('fnv1a32 is stable', () {
    expect(fnv1a32(''), 0x811c9dc5);
    expect(fnv1a32('a|1|rose'), fnv1a32('a|1|rose'));
    expect(fnv1a32('a|1|rose'), isNot(fnv1a32('a|2|rose')));
  });
}
