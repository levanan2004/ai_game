import 'dart:convert';

import 'package:ai_game/logic/payment.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('a dearer price thins the crowd and shortens patience', () {
    final s = newSession(seed: 2);
    final crowd = s.expectedCustomers;
    s.setPriceMultiplier(1.5);
    expect(s.priceMultiplier, 1.5);
    expect(s.expectedCustomers, closeTo(crowd * 0.6, 1e-9));
    for (final f in s.unlockedFlowers) {
      s.addBundle(f.id);
    }
    s.buyAndGoToShop();
    s.openShop();
    final c = waitForCustomer(s);
    expect(
      c.patienceMax,
      closeTo(s.e.patienceSeconds * pricePatienceFactor(s.e, 1.5), 1e-6),
    );
    s.setPriceMultiplier(0.8);
    expect(s.priceMultiplier, 1.5);
  });

  test('a cheaper price brings a few more customers', () {
    final s = newSession(seed: 2);
    final crowd = s.expectedCustomers;
    s.setPriceMultiplier(0.8);
    expect(s.expectedCustomers, closeTo(crowd * 1.08, 1e-9));
    expect(pricePatienceFactor(s.e, s.priceMultiplier), 1);
  });

  test('an old save without a price stays at the normal price', () {
    final s = newSession();
    final j = s.state.toJson()..remove('priceMultiplier');
    final back = GameState.decode(jsonEncode(j))!;
    expect(back.priceMultiplier, 1);
  });
}
