import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/main.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ShopGame> mount(
    WidgetTester tester,
    ShopGame game, {
    Size view = const Size(390, 844),
  }) async {
    tester.view.physicalSize = view;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(ShopApp(game: game));
    await tester.pump();
    expect(game.isLoaded, isTrue);
    return game;
  }

  Future<void> tapCenter(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(GameWidget<ShopGame>)));
    // Flame's multi-tap recognizer keeps a short timer after pointer-up.
    await tester.pump(const Duration(milliseconds: 50));
  }

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('tap increments the placeholder counter and saves it', (
    tester,
  ) async {
    final backing = <String, String>{
      ProgressStore.storageKey: const GameState(day: 4).encode(),
    };
    final game = ShopGame(store: ProgressStore.memory(backing));
    addTearDown(game.pauseEngine);

    await mount(tester, game);
    expect(game.state, const GameState(day: 4));
    expect(game.statusText, ShopGame.labelFor(const GameState(day: 4)));

    await tapCenter(tester);
    await game.pendingSaves;

    expect(game.state.tapCount, 1);
    expect(game.state.money, 0);
    expect(game.state.day, 4);
    expect(await ProgressStore.memory(backing).load(), game.state);

    final phoneViewport = game.camera.viewport.size.clone();
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();

    expect(game.camera.viewport.virtualSize.x, ShopGame.logicalWidth);
    expect(game.camera.viewport.virtualSize.y, ShopGame.logicalHeight);
    expect(game.camera.viewport.size, isNot(phoneViewport));

    await tapCenter(tester);
    await game.pendingSaves;
    expect(game.state.tapCount, 2);
  });

  testWidgets('a new game restores the saved placeholder taps', (tester) async {
    final backing = <String, String>{};
    final first = ShopGame(store: ProgressStore.memory(backing));
    addTearDown(first.pauseEngine);
    await mount(tester, first);

    await tapCenter(tester);
    await tapCenter(tester);
    await first.pendingSaves;
    expect(first.state.tapCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());

    final second = ShopGame(store: ProgressStore.memory(backing));
    addTearDown(second.pauseEngine);
    await mount(tester, second);
    expect(second.state, const GameState(tapCount: 2));
    expect(second.statusText, contains('placeholder taps: 2'));
  });

  testWidgets('default app restores shared preferences', (tester) async {
    SharedPreferences.setMockInitialValues({
      ProgressStore.storageKey: const GameState(tapCount: 7).encode(),
    });

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ShopApp());
    await tester.pump();

    final game = tester
        .widget<GameWidget<ShopGame>>(find.byType(GameWidget<ShopGame>))
        .game!;
    addTearDown(game.pauseEngine);

    expect(game.isLoaded, isTrue);
    expect(game.state.tapCount, 7);
    expect(game.state.money, 0);
    expect(game.state.day, 0);
  });
}
