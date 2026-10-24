import 'dart:convert';

import 'package:ai_game/logic/garden.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void openYard(ShopSession s) {
  s.state.day = s.e.gardenOpenDay;
}

/// Gives one shovel and tills [index]. The yard must already be open.
void tillBed(ShopSession s, [int index = 0]) {
  openYard(s);
  s.state.shovels += 1;
  expect(s.tillPlot(index), isTrue);
}

void main() {
  test('every flower has a seed, and beds start dry', () {
    final s = newSession();
    expect(s.e.gardenPlotCount, 4);
    expect(s.e.gardenOpenDay, 20);
    expect(s.e.pricesOpenDay, 10);
    expect(s.e.shovelPrice, 25000);
    expect(s.e.gardenPlotPrice(4), 80000);
    expect(s.e.gardenPlotPrice(5), 100000);
    expect(s.e.gardenPlotPrice(19), 380000);
    expect(s.state.plots, hasLength(4));
    expect(s.state.plots.every((p) => !p.tilled), isTrue);
    for (final f in s.e.flowers) {
      expect(s.e.gardenSeed(f.id), isNotNull, reason: f.id);
    }
    expect(s.e.gardenSeed('daisy')!.stepMinutes, 20);
    expect(s.e.gardenSeed('rose')!.stepMinutes, 30);
    expect(s.e.gardenSeed('lily')!.stepMinutes, 180);
    expect(s.e.gardenSeed('orchid')!.stepMinutes, 360);
  });

  test('two on-time waterings bloom, then the harvest enters the stock', () {
    var now = DateTime.utc(2026, 9, 30, 8);
    final s = newSession(now: () => now);
    tillBed(s);
    expect(s.buySeed('daisy'), isTrue);
    expect(s.seedCount('daisy'), 1);
    expect(s.plantPlot(0, 'daisy'), isTrue);
    expect(s.seedCount('daisy'), 0);
    expect(s.gardenView(0).phase, GardenPhase.sprout);
    expect(s.gardenView(0).thirsty, isFalse);
    expect(s.waterPlot(0), isFalse);

    now = now.add(const Duration(minutes: 20));
    expect(s.gardenView(0).thirsty, isTrue);
    expect(s.waterPlot(0), isTrue);
    expect(s.gardenView(0).phase, GardenPhase.leaf);

    now = now.add(const Duration(minutes: 20));
    expect(s.waterPlot(0), isTrue);
    expect(s.gardenView(0).phase, GardenPhase.bloom);
    expect(s.harvestPlot(0), isTrue);
    expect(s.state.stock.single.flowerId, 'daisy');
    expect(s.state.stock.single.count, 4);
    expect(
      s.state.stock.single.freshnessLeft,
      s.fullFreshness(s.e.flower('daisy')),
    );
    expect(s.gardenView(0).phase, GardenPhase.empty);
  });

  test('a missed watering wilts the plant and clearing frees the bed', () {
    var now = DateTime.utc(2026, 9, 30, 8);
    final s = newSession(now: () => now);
    tillBed(s);
    s.buySeed('baby');
    s.plantPlot(0, 'baby');
    now = now.add(const Duration(minutes: 15));
    expect(s.gardenView(0).thirsty, isTrue);
    now = now.add(const Duration(minutes: 15));
    expect(s.gardenView(0).phase, GardenPhase.wilted);
    expect(s.waterPlot(0), isFalse);
    expect(s.clearPlot(0), isTrue);
    expect(s.gardenView(0).phase, GardenPhase.empty);
    expect(s.state.plots.first.tilled, isTrue);
  });

  test(
    'a dry bed takes one shovel, and a seed stays after leaving mid-day',
    () {
      final backing = <String, String>{};
      final s = newSession(backing: backing);
      s.startNewGame();
      openYard(s);
      final before = s.state.money;
      expect(s.tillPlot(1), isFalse);
      expect(s.buyShovel(), isTrue);
      expect(s.tillPlot(1), isTrue);
      expect(s.tillPlot(1), isFalse);
      expect(s.shovelCount, 0);
      expect(s.buySeed('rose'), isTrue);
      expect(s.state.money, before - s.e.shovelPrice - 8000);
      s.backToTitle();
      expect(s.state.plots[1].tilled, isTrue);
      expect(s.seedCount('rose'), 1);
      expect(s.shovelCount, 0);
      expect(s.state.money, before - s.e.shovelPrice - 8000);
    },
  );

  test('the doors being open blocks watering', () {
    var now = DateTime.utc(2026, 9, 30, 8);
    final s = newSession(seed: 3, now: () => now);
    tillBed(s);
    s.buySeed('daisy');
    s.plantPlot(0, 'daisy');
    s.buyAndGoToShop();
    s.openShop();
    now = now.add(const Duration(minutes: 20));
    expect(s.canGarden, isFalse);
    expect(s.waterPlot(0), isFalse);
    s.openGarden();
    expect(s.screen, isNot(Screen.garden));
  });

  test('an old save without a garden grows four beds', () {
    final s = newSession();
    final j = s.state.toJson()
      ..remove('plots')
      ..remove('seeds');
    final raw = jsonEncode(j);
    final back = GameState.decode(raw)!;
    expect(back.plots, isEmpty);
    expect(back.seeds, isEmpty);
    final again = newSession(saved: back);
    expect(again.state.plots, hasLength(4));
    expect(again.state.plots.first.tilled, isFalse);
    expect(again.gardenView(0).phase, GardenPhase.locked);
    expect(GameState.decode(raw)!.encode(), isNotEmpty);
  });

  test('a bought seed is still in the morning save after a reload', () async {
    final backing = <String, String>{};
    final s = newSession(backing: backing);
    s.startNewGame();
    await s.pendingSaves;
    expect(s.buySeed('rose'), isTrue);
    await s.pendingSaves;
    final raw = backing[ProgressStore.storageKey];
    final loaded = newSession(saved: GameState.decode(raw));
    expect(loaded.seedCount('rose'), 1);
    expect(loaded.state.money, s.state.money);
  });

  test('prices, the yard, and extra beds open on their mornings', () {
    final s = newSession();
    s.state.day = 9;
    s.openPrices();
    expect(s.screen, isNot(Screen.prices));
    s.state.day = 10;
    s.openPrices();
    expect(s.screen, Screen.prices);

    s.state.day = 19;
    s.openGarden();
    expect(s.screen, isNot(Screen.garden));
    expect(s.buyPlot(), isFalse);

    s.state.day = 20;
    s.openGarden();
    expect(s.screen, Screen.garden);
    expect(s.buyPlot(), isFalse);
    s.closeGarden();

    s.state.day = 30;
    final before = s.state.money;
    expect(s.buyPlot(), isTrue);
    expect(s.state.plots, hasLength(5));
    expect(s.state.plots.last.tilled, isFalse);
    expect(s.state.money, before - 80000);
    expect(s.buyPlot(), isTrue);
    expect(s.state.plots, hasLength(6));
    expect(s.state.money, before - 80000 - 100000);
  });
}
