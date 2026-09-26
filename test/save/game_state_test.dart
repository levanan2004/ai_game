import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encode and decode round-trip', () {
    final s = newSession();
    s.addBundle('rose');
    s.buyAndGoToShop();
    final encoded = s.state.encode();
    final back = GameState.decode(encoded)!;
    expect(back.encode(), encoded);
    expect(back.phase, DayPhase.preparing);
    expect(back.stock.single.flowerId, 'rose');
  });

  test('missing, corrupt or old skeleton saves start a new game', () {
    expect(GameState.decode(null), isNull);
    expect(GameState.decode(''), isNull);
    expect(GameState.decode('{'), isNull);
    expect(GameState.decode('[]'), isNull);
    // The PR #1 placeholder format.
    expect(GameState.decode('{"money":0,"day":0,"tapCount":3}'), isNull);
  });

  test('persistent store round-trips through shared preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.persistent();
    expect(await store.load(), isNull);
    final s = newSession();
    await store.save(s.state);
    final back = await (await ProgressStore.persistent()).load();
    expect(back!.money, s.state.money);
  });
}
