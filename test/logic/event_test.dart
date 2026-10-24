import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('day 1 does not open an event', () {
    final s = newSession();
    s.state.tutorialDone = true;
    stockAndOpen(s);
    for (var i = 0; i < 2500; i++) {
      s.tick(0.1);
    }
    expect(s.eventOffer, isNull);
  });

  test('a rain tarp costs money and a skip does not', () {
    final s = newSession();
    s.state.tutorialDone = true;
    s.state.day = 5;
    stockAndOpen(s);
    final before = s.state.money;
    s.presentEvent('rain');
    s.chooseEvent('tarp');
    expect(s.eventOffer, isNull);
    expect(s.state.money, lessThan(before));

    final quiet = newSession();
    quiet.state.tutorialDone = true;
    quiet.state.day = 5;
    stockAndOpen(quiet);
    final cash = quiet.state.money;
    quiet.presentEvent('rain');
    quiet.chooseEvent('skip');
    expect(quiet.state.money, cash);
  });

  test('lending flowers to the grandma is paid back the next morning', () {
    final s = newSession();
    s.state.tutorialDone = true;
    s.state.day = 5;
    stockAndOpen(s);
    s.presentEvent('grandma');
    s.chooseEvent('lend');
    expect(s.eventOffer, isNull);
    s.state.pendingArrivals.clear();
    for (var i = 0; i < 20000 && s.state.phase != DayPhase.summary; i++) {
      if (s.eventOffer != null) {
        s.chooseEvent(s.eventOffer!.choices.last.id);
      }
      s.tick(0.5);
    }
    final before = s.state.money;
    s.startNextDay();
    expect(s.state.money, greaterThan(before));
    expect(s.state.reviews.any((r) => r.customerName == 'Bà Năm'), isTrue);
  });

  test('the mouse eats the oldest stems, and a grown cat saves most', () {
    final bare = newSession();
    bare.state.day = 20;
    final id = bare.unlockedFlowers.first.id;
    bare.state.stock.add(StockBatch(flowerId: id, count: 80, freshnessLeft: 1));
    bare.presentEvent('mouse');
    expect(bare.eventOffer?.title, 'Chuột gặm hoa');
    expect(80 - bare.stockCount(id), 8);
    expect(bare.state.lastBadEventDay, 20);
    bare.chooseEvent('ok');
    expect(bare.eventOffer, isNull);

    final cat = newSession();
    cat.state.day = 20;
    cat.state.hasCat = true;
    cat.state.petStage = 2;
    cat.state.stock.add(StockBatch(flowerId: id, count: 80, freshnessLeft: 1));
    cat.presentEvent('mouse');
    // Stage 2: caught half the time, else 20% of the 8 aimed stems.
    expect(80 - cat.stockCount(id), lessThanOrEqualTo(1));
    expect(cat.eventOffer!.body, contains('Mèo'));
  });
}
