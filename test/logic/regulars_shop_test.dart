import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  /// Day 3 with 3 great bouquets: the notebook and Minh Khoa's first visit
  /// open (khach_quen_block.json).
  ShopSession dayThree({int seed = 7}) {
    final s = newSession(seed: seed);
    s.state
      ..day = 3
      ..lifetimeGreat = 3;
    for (final f in s.unlockedFlowers) {
      if (s.canAddBundle(f.id)) s.addBundle(f.id);
    }
    s.buyAndGoToShop();
    s.openShop();
    return s;
  }

  Customer? waitForRegular(ShopSession s) {
    for (var t = 0.0; t < 400 && s.state.phase == DayPhase.open; t += 0.1) {
      if (s.eventOffer != null) s.chooseEvent(s.eventOffer!.choices.last.id);
      for (final c in s.queue) {
        if (c.regularId != null && c.arrived) return c;
      }
      s.tick(0.1);
      // Strangers are not served here: keep the queue from filling up.
      for (final c in [...s.queue]) {
        if (c.regularId == null) c.patienceLeft = 0;
      }
    }
    return null;
  }

  test('Minh Khoa comes in on day 3 with his confession order', () {
    final s = dayThree();
    expect(s.notebookUnlocked, isTrue);
    final c = waitForRegular(s);
    expect(c, isNotNull);
    expect(c!.regularId, 'anh_minh_khoa');
    expect(c.regularStep, 1);
    expect(c.name, 'Minh Khoa');
    expect(c.avatarId, 'regulars/anh_minh_khoa');
    final visit = s.regulars.byId('anh_minh_khoa')!.visit(1)!;
    expect(c.requestLine, visit.order);
    expect(c.request.occasionId, 'confession');
    expect(c.request.stems.keys.toSet(), {'rose'});
  });

  test('a great bouquet makes him a regular with an unread letter', () {
    final s = dayThree();
    final c = waitForRegular(s)!;
    while (!identical(s.nextForPlayer, c)) {
      s.queue.remove(s.nextForPlayer);
    }
    s.openTable();
    expect(identical(s.tableCustomer, c), isTrue);
    c.request.stems.forEach((id, n) {
      for (var i = 0; i < n; i++) {
        s.addStem(id);
      }
    });
    if (c.request.fillerId != null) {
      for (var i = 0; i < c.request.fillerCount; i++) {
        s.addStem(c.request.fillerId!);
      }
    }
    s.selectPaper(c.request.paperId);
    s.selectRibbon(c.request.ribbonId);
    s.beginWrap();
    final res = s.finishWrap(hit: true)!;
    final p = s.state.regulars['anh_minh_khoa']!;
    expect(p.stepsDone[1], res.review.stars);
    expect(res.review.stars, greaterThanOrEqualTo(4));
    expect(p.unread, [1]);
    expect(p.lastVisitDay, 3);
    expect(s.notebookBadgeCount, 1);
    expect(s.shopNotice, 'Minh Khoa đã thành khách quen của tiệm!');
    s.readLetter('anh_minh_khoa', 1);
    expect(s.notebookBadgeCount, 0);
  });

  test('a regular who leaves unserved comes back after the retry gap', () {
    final s = dayThree();
    final c = waitForRegular(s)!;
    c.patienceLeft = 0;
    s.tick(0.1);
    final p = s.state.regulars['anh_minh_khoa']!;
    expect(p.stepsDone, isEmpty);
    expect(p.retries, 0);
    expect(p.retryAfterDay, 3 + s.regulars.retryGapDays);
  });

  test('no regulars before the notebook opens', () {
    final s = newSession(seed: 7);
    for (final f in s.unlockedFlowers) {
      if (s.canAddBundle(f.id)) s.addBundle(f.id);
    }
    s.buyAndGoToShop();
    s.openShop();
    expect(s.notebookUnlocked, isFalse);
    expect(waitForRegular(s), isNull);
  });

  test('great bouquets count toward lifetimeGreat', () {
    final s = dayThree();
    final before = s.state.lifetimeGreat;
    final c = waitForRegular(s)!;
    while (!identical(s.nextForPlayer, c)) {
      s.queue.remove(s.nextForPlayer);
    }
    s.openTable();
    c.request.stems.forEach((id, n) {
      for (var i = 0; i < n; i++) {
        s.addStem(id);
      }
    });
    if (c.request.fillerId != null) {
      for (var i = 0; i < c.request.fillerCount; i++) {
        s.addStem(c.request.fillerId!);
      }
    }
    s.selectPaper(c.request.paperId);
    s.selectRibbon(c.request.ribbonId);
    s.beginWrap();
    final res = s.finishWrap(hit: true)!;
    expect(
      s.state.lifetimeGreat,
      before + (res.review.outcome == 'great' ? 1 : 0),
    );
  });
}
