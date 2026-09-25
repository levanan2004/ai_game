import 'dart:io';
import 'dart:math';

import 'package:ai_game/data/game_data.dart';
import 'package:ai_game/logic/bouquet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';

/// The real data files shipped in assets/data.
GameData loadTestData() => GameData.fromJsonStrings(
  economy: File('assets/data/economy.json').readAsStringSync(),
  reviews: File('assets/data/reviews.json').readAsStringSync(),
  orders: File('assets/data/orders.json').readAsStringSync(),
);

ShopSession newSession({
  Map<String, String>? backing,
  GameState? saved,
  int seed = 1,
}) {
  return ShopSession(
    data: loadTestData(),
    store: ProgressStore.memory(backing ?? {}),
    saved: saved,
    random: Random(seed),
  );
}

var _uid = 0;

Bouquet bouquetOf(
  Map<String, int> stems, {
  String? paper,
  String? ribbon,
  int freshness = 3,
}) {
  final b = Bouquet(paperId: paper, ribbonId: ribbon);
  for (final e in stems.entries) {
    for (var i = 0; i < e.value; i++) {
      b.stems.add(Stem(uid: _uid++, flowerId: e.key, freshnessLeft: freshness));
    }
  }
  return b;
}

/// Buys one bundle of every unlocked flower, opens the shop.
void stockAndOpen(ShopSession s) {
  for (final f in s.unlockedFlowers) {
    s.addBundle(f.id);
  }
  s.buyAndGoToShop();
  s.openShop();
}

/// Runs the clock until a customer has walked in.
Customer waitForCustomer(ShopSession s, {double maxSeconds = 400}) {
  var t = 0.0;
  while (s.nextForPlayer == null && t < maxSeconds) {
    s.tick(0.1);
    t += 0.1;
  }
  return s.nextForPlayer!;
}
