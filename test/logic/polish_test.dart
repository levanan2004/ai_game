import 'package:ai_game/logic/goals.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('limit goal shows the cap, and a cross once it is broken', () {
    final g = DailyGoal(
      templateId: 'low_wilt',
      title: 'Héo không quá 3 cành',
      metric: 'stemsWilted',
      compare: '<=',
      target: 3,
      reward: 30000,
    );
    final m = DayMetrics();
    expect(g.isLimit, isTrue);
    expect(g.isDone(m), isTrue);
    expect(g.isExceeded(m), isFalse);
    expect(g.progressLabel(m), '0 / tối đa 3');
    m.stemsWilted = 3;
    expect(g.isExceeded(m), isFalse);
    expect(g.progressLabel(m), '3 / tối đa 3');
    m.stemsWilted = 4;
    expect(g.isDone(m), isFalse);
    expect(g.isExceeded(m), isTrue);
    expect(g.progressLabel(m), '4 / tối đa 3');
  });

  test('at-least goals keep the a/b label', () {
    final g = DailyGoal(
      templateId: 'sell_bouquets',
      title: 'Bán 5 bó hoa',
      metric: 'bouquetsSold',
      compare: '>=',
      target: 5,
      reward: 1,
    );
    final m = DayMetrics()..bouquetsSold = 2;
    expect(g.isLimit, isFalse);
    expect(g.isExceeded(m), isFalse);
    expect(g.progressLabel(m), '2/5');
  });

  test('closing time spawns nothing new; an empty queue ends the day', () {
    final s = newSession();
    stockAndOpen(s);
    s.queue.clear();
    final close = s.e.dayRealSeconds;
    s.state.elapsed = close - 1;
    s.state.pendingArrivals = [close - 0.4, close, close + 5];
    // Cross closeHour. Only the arrival strictly before it is spawned.
    s.tick(1.1);
    expect(s.clockText, 'Đóng cửa');
    expect(s.state.pendingArrivals, isEmpty);
    // Only the arrival strictly before closeHour is spawned.
    expect(s.queue.length, 1);
    expect(s.state.phase, DayPhase.open);
    expect(s.screen, Screen.shop);
    for (var i = 0; i < 400 && s.state.phase == DayPhase.open; i++) {
      s.tick(0.5);
    }
    expect(s.state.phase, DayPhase.summary);
    expect(s.screen, Screen.summary);
  });

  test('a customer already queued at closing can still be served', () {
    final s = newSession();
    stockAndOpen(s);
    final c = waitForCustomer(s);
    s.state.pendingArrivals = [s.e.dayRealSeconds + 1];
    s.state.elapsed = s.e.dayRealSeconds;
    s.tick(0.2);
    expect(s.clockText, 'Đóng cửa');
    expect(s.queue.contains(c), isTrue);
    expect(s.state.pendingArrivals, isEmpty);
    expect(s.state.phase, DayPhase.open);
    s.openTable();
    expect(s.tableCustomer, c);
    expect(s.screen, Screen.table);
  });

  test('shelf is empty only when every unlocked pot has no stems', () {
    final s = newSession();
    s.buyAndGoToShop();
    expect(s.shelfEmpty, isTrue);
    s.state.phase = DayPhase.market;
    s.addBundle('rose');
    s.buyAndGoToShop();
    expect(s.stockCount('rose'), greaterThan(0));
    expect(s.stockCount('daisy'), 0);
    expect(s.shelfEmpty, isFalse);
  });

  test('close early from an empty shelf goes to the summary', () {
    final s = newSession();
    s.buyAndGoToShop();
    s.openShop();
    expect(s.shelfEmpty, isTrue);
    s.state.pendingArrivals = [1, 2, 3];
    s.closeEarly();
    expect(s.state.phase, DayPhase.summary);
    expect(s.screen, Screen.summary);
    expect(s.queue, isEmpty);
    expect(s.state.pendingArrivals, isEmpty);
    expect(s.state.metrics.settled, isTrue);
  });

  test('opening the table again keeps the customer and the bouquet', () {
    final s = newSession();
    stockAndOpen(s);
    final c = waitForCustomer(s);
    s.state.pendingArrivals.clear();
    s.openTable();
    expect(s.addStem('rose'), isTrue);
    final stems = s.draft.stems.length;
    s.openTable();
    expect(s.tableCustomer?.id, c.id);
    expect(s.draft.stems.length, stems);
    expect(s.screen, Screen.table);
  });
}
