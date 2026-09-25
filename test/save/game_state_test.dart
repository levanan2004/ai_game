import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const saved = GameState(money: 2, day: 3, tapCount: 4);

  test('encode and decode round-trip', () {
    expect(GameState.decode(saved.encode()), saved);
  });

  test('missing data restores the initial placeholder state', () {
    expect(GameState.decode(null), GameState.initial);
    expect(GameState.decode(''), GameState.initial);
    expect(GameState.decode('   '), GameState.initial);
  });

  test('corrupt data restores the initial placeholder state', () {
    expect(GameState.decode('{'), GameState.initial);
    expect(GameState.decode('[]'), GameState.initial);
    expect(GameState.decode('12'), GameState.initial);
    expect(GameState.decode('null'), GameState.initial);
    expect(
      GameState.decode('{"money":"no","day":1,"tapCount":2}'),
      GameState.initial,
    );
    expect(
      GameState.decode('{"money":1,"day":null,"tapCount":2}'),
      GameState.initial,
    );
  });

  test('omitted fields stay at the placeholder zero', () {
    expect(GameState.decode('{"tapCount":5}'), const GameState(tapCount: 5));
  });
}
