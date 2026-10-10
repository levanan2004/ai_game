import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  ShopSession opened() {
    final s = newSession(seed: 7);
    for (final f in s.unlockedFlowers) {
      if (s.canAddBundle(f.id)) s.addBundle(f.id);
    }
    s.buyAndGoToShop();
    s.openShop();
    return s;
  }

  test('kết thúc ngày goes to the summary even with customers waiting', () {
    final s = opened();
    waitForCustomer(s);
    expect(s.queue, isNotEmpty);
    s.closeEarly();
    expect(s.state.phase, DayPhase.summary);
    expect(s.queue, isEmpty);
  });

  test(
    'từ chối sends a customer home when the shelf cannot fill the order',
    () {
      final s = opened();
      waitForCustomer(s);
      s.openTable();
      expect(s.tableCustomer, isNotNull);
      s.state.stock.clear();
      expect(s.cannotFillCustomer, isTrue);
      final name = s.tableCustomer!.name;
      s.declineCustomer();
      expect(s.tableCustomer, isNull);
      expect(s.screen, Screen.shop);
      expect(s.state.reviews.last.customerName, name);
      expect(s.state.reviews.last.outcome, 'leftUnserved');
      expect(s.state.metrics.customersLeft, 1);
    },
  );

  test('the review card shows once, later sales are a short line', () {
    final s = opened();
    void sell() {
      waitForCustomer(s);
      s.openTable();
      final c = s.tableCustomer!;
      c.request.stems.forEach((id, n) {
        for (var i = 0; i < n; i++) {
          s.addStem(id);
        }
      });
      s.selectPaper('kraft');
      expect(s.beginWrap(), isNotNull, reason: c.requestLine);
      expect(s.finishWrap(hit: true), isNotNull);
    }

    sell();
    expect(s.lastDelivery, isNotNull);
    s.closeDeliveryPopup();
    expect(s.state.reviewIntroSeen, isTrue);

    sell();
    expect(s.lastDelivery, isNull);
    expect(s.screen, Screen.shop);
    expect(s.shopNotice, contains('Đánh giá'));
  });

  void nextMorning(ShopSession s) {
    s.startNextDay();
    s.buyAndGoToShop();
    s.openShop();
  }

  test('two early closes are allowed and the third day stays until close', () {
    final s = opened();
    expect(s.state.encode(), isNot(contains('earlyClosesInARow')));
    expect(GameState.decode(s.state.encode())!.earlyClosesInARow, 0);

    s.closeEarly();
    expect(s.state.earlyClosesInARow, 1);
    nextMorning(s);
    expect(GameState.decode(s.state.encode())!.earlyClosesInARow, 1);

    s.closeEarly();
    expect(s.state.earlyClosesInARow, 2);
    nextMorning(s);
    expect(s.mustPlayUntilClose, isTrue);
    s.closeEarly();
    expect(s.state.phase, DayPhase.open);
    expect(s.shopNotice, ShopSession.playUntilCloseHint);

    s.state.elapsed = s.e.dayRealSeconds;
    expect(s.afterClose, isTrue);
    expect(s.mustPlayUntilClose, isFalse);
    s.closeEarly();
    expect(s.state.phase, DayPhase.summary);
    expect(s.state.earlyClosesInARow, 0);

    nextMorning(s);
    s.closeEarly();
    expect(s.state.phase, DayPhase.summary);
    expect(s.state.earlyClosesInARow, 1);
  });
}
