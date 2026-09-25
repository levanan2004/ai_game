import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const saved = GameState(money: 0, day: 1, tapCount: 6);

  test('memory store persists and restores JSON', () async {
    final backing = <String, String>{};
    final store = ProgressStore.memory(backing);

    expect(await store.load(), GameState.initial);

    await store.save(saved);
    expect(backing[ProgressStore.storageKey], saved.encode());
    expect(await ProgressStore.memory(backing).load(), saved);
  });

  test('memory store ignores corrupt JSON', () async {
    final store = ProgressStore.memory({ProgressStore.storageKey: 'not-json'});

    expect(await store.load(), GameState.initial);
  });

  test(
    'persistent store round-trips and falls back when missing or corrupt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final created = await ProgressStore.persistent();
      expect(await created.load(), GameState.initial);

      await created.save(saved);
      expect(
        await ProgressStore.persistent().then((store) => store.load()),
        saved,
      );

      SharedPreferences.setMockInitialValues({
        ProgressStore.storageKey: '{"money":1,"day":',
      });
      expect(
        await ProgressStore.persistent().then((store) => store.load()),
        GameState.initial,
      );

      SharedPreferences.setMockInitialValues({});
      expect(
        await ProgressStore.persistent().then((store) => store.load()),
        GameState.initial,
      );
    },
  );
}
