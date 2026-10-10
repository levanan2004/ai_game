import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/phale_shop.dart';
import 'package:ai_game/logic/phale_shop_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// economy.json with the Pha lê shop flag switched [open].
String phaleEconomy({bool open = true}) {
  final j =
      jsonDecode(File('assets/data/economy.json').readAsStringSync())
          as Map<String, dynamic>;
  (j['phaLeShop'] as Map<String, dynamic>)['open'] = open;
  return jsonEncode(j);
}

PhaleShopConfig _config({bool open = true}) => PhaleShopConfig.fromJson(
  (jsonDecode(phaleEconomy(open: open)) as Map)['phaLeShop'],
);

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 10, 9);
  DateTime call() => now;
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));
}

PhaleShopController _controller(
  DemoPhaleGateway gateway,
  _Clock clock, {
  bool signedIn = true,
  bool open = true,
}) => PhaleShopController(
  config: _config(open: open),
  gateway: gateway,
  signedIn: () => signedIn,
  clock: clock.call,
  autoPoll: false,
);

void main() {
  group('the packs in economy.json', () {
    test('six packs, cheapest first, with the approved numbers', () {
      final cfg = loadTestData().economy.phaLeShop;
      expect(cfg.packs.map((p) => p.id), [
        'pack_10k',
        'pack_20k',
        'pack_50k',
        'pack_100k',
        'pack_200k',
        'pack_500k',
      ]);
      expect(cfg.packs.map((p) => p.priceVnd), [
        10000,
        20000,
        50000,
        100000,
        200000,
        500000,
      ]);
      expect(cfg.packs.map((p) => p.phaLe), [100, 210, 550, 1150, 2400, 6250]);
      expect(cfg.packs.map((p) => p.bonusPercent), [0, 5, 10, 15, 20, 25]);
      expect(cfg.packs.first.hasBonus, isFalse);
      expect(cfg.bestPackId, 'pack_100k');
    });

    // An opened the shop on 10/10/2026 for his test top-up. To close it again,
    // set phaLeShop.open=false in economy.json AND config/phaleShop.open=false
    // in Firestore, and flip this expectation back to isFalse.
    test('the shop ships open (test top-up, 10/10/2026)', () {
      expect(loadTestData().economy.phaLeShop.open, isTrue);
    });

    test('a broken block gives an empty, closed shop', () {
      final cfg = PhaleShopConfig.fromJson('nope');
      expect(cfg.packs, isEmpty);
      expect(cfg.open, isFalse);
    });
  });

  group('who can buy', () {
    test('a closed shop makes no order', () async {
      final gw = DemoPhaleGateway(config: _config());
      final c = _controller(gw, _Clock(), open: false);
      expect(c.pick('pack_10k'), PhaleBlock.closed);
      expect(c.step, PhaleStep.shop);
      await c.confirmBuy();
      expect(gw.orders, isEmpty);
    });

    test('a guest cannot buy', () async {
      final gw = DemoPhaleGateway(config: _config());
      final c = _controller(gw, _Clock(), signedIn: false);
      expect(c.canBuy, isFalse);
      expect(c.pick('pack_10k'), PhaleBlock.guest);
      await c.confirmBuy();
      expect(gw.orders, isEmpty);
    });

    test('the closed gateway fails every call', () async {
      const gw = ClosedPhaleGateway();
      await expectLater(
        gw.createOrder('pack_10k'),
        throwsA(isA<PhaleException>()),
      );
      await expectLater(gw.orderStatus('x'), throwsA(isA<PhaleException>()));
    });
  });

  group('the order flow', () {
    test('S1 → S2a → S2b → S6a with the server data', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      expect(c.pick('pack_50k'), PhaleBlock.none);
      expect(c.step, PhaleStep.confirm);
      expect(c.pack!.phaLe, 550);
      final done = c.confirmBuy();
      expect(c.step, PhaleStep.creating);
      await done;
      expect(c.step, PhaleStep.order);
      final o = c.order!;
      expect(o.amount, 50000);
      expect(o.crystals, 550);
      expect(o.demo, isTrue);
      expect(o.bank, contains('DEMO'));
      expect(o.transferContent, o.orderId);
      expect(c.remaining, const Duration(minutes: 15));
      expect(c.shownStatus, PhaleOrderStatus.pending);
    });

    test('Để sau and Thử lại', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call)
        ..offline = true;
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      c.later();
      expect(c.step, PhaleStep.shop);
      c.pick('pack_10k');
      await c.confirmBuy();
      expect(c.step, PhaleStep.createFailed);
      expect(c.order, isNull);
      c.retry();
      expect(c.step, PhaleStep.confirm);
      gw.offline = false;
      await c.confirmBuy();
      expect(c.step, PhaleStep.order);
    });

    test(
      'the countdown follows the SERVER clock, not the device clock',
      () async {
        final clock = _Clock();
        final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
        // The device clock runs 5 minutes behind the server.
        final device = _Clock()
          ..now = clock.now.subtract(const Duration(minutes: 5));
        final c = PhaleShopController(
          config: _config(),
          gateway: gw,
          signedIn: () => true,
          clock: device.call,
          autoPoll: false,
        );
        c.pick('pack_10k');
        await c.confirmBuy();
        expect(c.remaining, const Duration(minutes: 15));
        device.advance(60);
        expect(c.remaining, const Duration(minutes: 14));
      },
    );

    test('a pending order past expiresAt reads as expired', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      clock.advance(15 * 60 + 1);
      expect(c.remaining, Duration.zero);
      expect(c.shownStatus, PhaleOrderStatus.expired);
      expect(c.hasPending, isFalse);
      c.newOrder();
      expect(c.step, PhaleStep.confirm);
      expect(c.pack!.id, 'pack_10k');
      expect(c.order, isNull);
    });
  });

  group('Tôi đã chuyển and the server', () {
    test('it only asks the server; nothing is credited', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      final id = c.order!.orderId;
      final stillWaiting = await c.tapPaid();
      expect(stillWaiting, isTrue);
      expect(c.step, PhaleStep.order);
      expect(c.order!.status, PhaleOrderStatus.pending);
      expect(c.order!.crystalsGranted, isNull);
      expect(gw.orders[id]!.status, PhaleOrderStatus.pending);
    });

    test('taps closer than the gap are ignored', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      expect(await c.tapPaid(), isTrue);
      clock.advance(1);
      expect(await c.tapPaid(), isNull);
      clock.advance(_config().checkGapSeconds);
      expect(await c.tapPaid(), isTrue);
    });

    test('paid: the screen shows the SERVER numbers', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_50k');
      await c.confirmBuy();
      gw.force(
        c.order!.orderId,
        PhaleOrderStatus.paid,
        granted: 550,
        balance: 800,
      );
      await c.poll();
      expect(c.step, PhaleStep.done);
      expect(c.order!.crystalsGranted, 550);
      expect(c.order!.newBalance, 800);
      c.finish();
      expect(c.step, PhaleStep.shop);
      expect(c.order, isNull);
    });

    test('mismatch and cancelled by the server', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      gw.force(c.order!.orderId, PhaleOrderStatus.mismatch);
      await c.poll();
      expect(c.step, PhaleStep.order);
      expect(c.shownStatus, PhaleOrderStatus.mismatch);
      c.closeOrder();
      c.pick('pack_10k');
      await c.confirmBuy();
      gw.force(c.order!.orderId, PhaleOrderStatus.cancelled);
      await c.poll();
      expect(c.step, PhaleStep.cancelled);
    });

    test('losing the connection keeps the order and recovers', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      gw.offline = true;
      await c.poll();
      expect(c.offline, isTrue);
      expect(c.order, isNotNull);
      expect(c.step, PhaleStep.order);
      gw.offline = false;
      await c.poll();
      expect(c.offline, isFalse);
    });
  });

  group('cancel and come back', () {
    test('Hủy đơn always asks; Giữ đơn keeps it', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      c.askCancel();
      expect(c.step, PhaleStep.cancelAsk);
      c.keepOrder();
      expect(c.step, PhaleStep.order);
      expect(c.order, isNotNull);
    });

    test('a confirmed cancel kills the order on the server', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      final id = c.order!.orderId;
      c.askCancel();
      await c.confirmCancel();
      expect(c.step, PhaleStep.cancelled);
      expect(gw.orders[id]!.status, PhaleOrderStatus.cancelled);
      expect(c.order, isNull);
      c.newOrder();
      expect(c.step, PhaleStep.confirm);
      expect(c.pack!.id, 'pack_10k');
    });

    test('a cancel that cannot reach the server keeps the order', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      c.askCancel();
      gw.offline = true;
      await c.confirmCancel();
      expect(c.step, PhaleStep.order);
      expect(c.order, isNotNull);
      expect(c.offline, isTrue);
    });

    test('leaving does not cancel: the shop shows the waiting order', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      c.leave();
      expect(c.hasPending, isTrue);
      c.start();
      expect(c.hasPending, isTrue);
      expect(c.step, PhaleStep.shop);
      c.viewOrder();
      expect(c.step, PhaleStep.order);
      c.backToShop();
      expect(c.order, isNotNull);
    });

    test('a dead order is not offered again', () async {
      final clock = _Clock();
      final gw = DemoPhaleGateway(config: _config(), clock: clock.call);
      final c = _controller(gw, clock);
      c.pick('pack_10k');
      await c.confirmBuy();
      clock.advance(16 * 60);
      c.start();
      expect(c.order, isNull);
    });
  });
}
