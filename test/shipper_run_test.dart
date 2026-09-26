import 'package:ai_game/logic/bouquet.dart';
import 'package:ai_game/logic/delivery.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Fills the open draft with [r] and wraps it. False when it cannot wrap.
bool _makeBouquet(ShopSession s, BouquetRequest r) {
  s.resetDraft();
  r.stems.forEach((id, n) {
    for (var i = 0; i < n; i++) {
      s.addStem(id);
    }
  });
  for (var i = 0; r.fillerId != null && i < r.fillerCount; i++) {
    s.addStem(r.fillerId!);
  }
  if (s.draft.stems.isEmpty) {
    for (final f in s.unlockedFlowers) {
      if (s.addStem(f.id)) break;
    }
  }
  s.selectPaper(s.owned.contains(r.paperId) ? r.paperId : 'kraft');
  if (s.owned.contains(r.ribbonId)) s.selectRibbon(r.ribbonId);
  if (s.beginWrap() == null) return false;
  s.finishWrap(hit: true);
  return true;
}

void _packOrder(ShopSession s, OnlineOrder o) {
  s.openOnlineOrder(o.id);
  if (s.tableOrder != o) return;
  _makeBouquet(s, o.request);
  s.showShopAfterOnlinePack();
  if (s.screen == Screen.table && s.tableOrder == null) {
    s.showShopAfterOnlinePack();
  }
}

void _missedOrderTest() {
  test('an accepted order never packed is missed at close with one star', () {
    final s = newSession(seed: 3);
    finishDayAndCommit(s);
    finishDayAndCommit(s);
    expect(s.state.day, 3);
    if (s.screen == Screen.preorders) s.leavePreorderBoard();
    s.state.money = 1000000;
    expect(s.hireShipper('bike'), isTrue);
    finishDayAndCommit(s);
    if (s.screen == Screen.preorders) s.leavePreorderBoard();
    stockAndOpen(s);
    final o = s.debugIncoming(
      const BouquetRequest(
        occasionId: 'birthday',
        stems: {'rose': 1},
        paperId: 'kraft',
        ribbonId: 'twine',
      ),
    );
    expect(s.acceptSameDay(o), isTrue);
    final reviewsBefore = s.state.reviews.length;
    final moneyBefore = s.state.metrics.onlineIncome;
    s.state.pendingArrivals.clear();
    for (var i = 0; i < 20000 && s.state.phase != DayPhase.summary; i++) {
      s.tick(0.1);
      while (s.popups.isNotEmpty) {
        s.closePopup();
      }
    }
    expect(o.status, OrderStatus.missed);
    expect(s.state.metrics.onlineIncome, moneyBefore);
    expect(s.state.metrics.onlineMissed, 1);
    final r = s.state.reviews.skip(reviewsBefore).last;
    expect(r.stars, 1);
    expect(s.stockAvailable('rose'), greaterThan(0), reason: 'stem released');
  });
}

/// Twelve days with shippers: hire the bike on day 3, then accept every
/// preorder the board marks on time and every same-day order in stock,
/// pack them, and let the auto-assign send them out.
void main() {
  _missedOrderTest();

  test('shippers deliver online orders over twelve days', () async {
    final backing = <String, String>{};
    final s = newSession(backing: backing, seed: 11);
    final lines = <String>[];
    var delivered = 0;

    for (var day = 1; day <= 12; day++) {
      expect(s.state.day, day);
      while (s.popups.isNotEmpty) {
        s.closePopup();
      }

      // Morning board.
      final board = <OnlineOrder>[];
      if (s.screen == Screen.preorders) {
        for (final o in [...s.onlineOrders]) {
          if (o.kind == OrderKind.preorder && o.status == OrderStatus.offered) {
            board.add(o);
            if (s.orderOnTime(o)) s.acceptPreorder(o);
          }
        }
        s.leavePreorderBoard();
      }
      expect(s.screen, Screen.market);

      // Hire or upgrade shippers while cash stays above 700k.
      for (final sh in s.e.delivery.shippers) {
        final offer = s.shipperOfferFor(sh.id);
        if (offer.canBuy && s.state.money - offer.cost > 700000) {
          expect(s.hireShipper(sh.id), isTrue);
        }
      }

      for (final f in s.unlockedFlowers) {
        if (s.canAddBundle(f.id)) s.addBundle(f.id);
      }
      final startMoney = s.state.money;
      s.buyAndGoToShop();

      // Untimed prep: pack accepted preorders.
      for (final o in [...s.onlineOrders]) {
        if (o.kind == OrderKind.preorder && o.status == OrderStatus.accepted) {
          _packOrder(s, o);
          expect(o.status, isNot(OrderStatus.accepted), reason: 'day $day');
        }
      }
      s.openShop();

      var t = 0.0;
      var walkIns = 0;
      while (s.state.phase == DayPhase.open && t < 2000) {
        s.tick(0.1);
        t += 0.1;
        while (s.popups.isNotEmpty) {
          s.closePopup();
        }
        if (s.lastDelivery != null) s.closeDeliveryPopup();
        if (s.paused || s.screen != Screen.shop) continue;
        for (final o in [...s.onlineOrders]) {
          if (o.kind == OrderKind.sameday && o.status == OrderStatus.offered) {
            s.acceptSameDay(o);
          }
        }
        final pending = s.onlineOrders
            .where((o) => o.status == OrderStatus.accepted)
            .toList();
        if (pending.isNotEmpty) {
          _packOrder(s, pending.first);
          continue;
        }
        if (s.nextForPlayer != null) {
          s.openTable();
          final c = s.tableCustomer;
          if (c != null && _makeBouquet(s, c.request)) walkIns++;
          if (s.lastDelivery != null) s.closeDeliveryPopup();
        }
      }
      expect(s.state.phase, DayPhase.summary, reason: 'day $day never closed');

      int count(OrderStatus st) =>
          s.onlineOrders.where((o) => o.status == st).length;
      final done = s.onlineOrders
          .where((o) => o.status == OrderStatus.done && !o.late)
          .length;
      final late = s.onlineOrders
          .where((o) => o.status == OrderStatus.done && o.late)
          .length;
      delivered += done;
      final m = s.state.metrics;
      lines.add(
        'Ngày $day: shipper ${s.state.shipperLevels}, '
        'bảng sáng ${board.length}, '
        'online ${s.onlineOrders.length} (đúng giờ $done, trễ $late, '
        'lỡ ${count(OrderStatus.missed)}, huỷ ${count(OrderStatus.cancelled)}, '
        'còn chạy ${count(OrderStatus.dispatched)}), '
        'khách lẻ $walkIns, thu online ${m.onlineIncome ~/ 1000}k, '
        'lương ${m.shipperWages ~/ 1000}k, lãi ${m.profit ~/ 1000}k, '
        'tiền ${startMoney ~/ 1000}k -> ${s.state.money ~/ 1000}k, '
        'sao ${s.rating.average.toStringAsFixed(1)}',
      );

      for (final o in s.onlineOrders) {
        expect(
          o.status,
          isNot(anyOf(OrderStatus.accepted, OrderStatus.packed)),
          reason: 'day $day: order ${o.id} left hanging',
        );
      }
      s.startNextDay();
      expect(s.state.stock.every((b) => b.count > 0), isTrue);
    }

    expect(delivered, greaterThan(0));
    await s.pendingSaves;
    final saved = GameState.decode(backing.values.first)!;
    expect(saved.shipperLevels, s.state.shipperLevels);
    // ignore: avoid_print
    print(lines.join('\n'));
  });
}
