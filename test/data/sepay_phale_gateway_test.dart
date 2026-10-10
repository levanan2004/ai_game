import 'dart:convert';

import 'package:ai_game/data/phale_shop.dart';
import 'package:ai_game/data/sepay_phale_gateway.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/phale_claim.dart';
import 'package:ai_game/logic/phale_shop_controller.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers.dart';
import '../logic/phale_shop_test.dart' show phaleEconomy;

const _base = 'https://fn.example';

Map<String, dynamic> _orderJson({
  String status = 'pending',
  Map<String, dynamic> extra = const {},
}) => {
  'orderId': 'THSMK7P2Q9XABC',
  'packId': 'pack_50k',
  'amount': 50000,
  'crystals': 550,
  'bonusPercent': 10,
  'bank': 'Vietcombank',
  'accountNo': '0123456789',
  'accountName': 'CONG TY TEST',
  'transferContent': 'THSMK7P2Q9XABC',
  'qrImageUrl': 'https://qr.sepay.vn/img?acc=0123456789',
  'expiresAt': '2026-10-20T08:15:00.000Z',
  'serverTime': '2026-10-20T08:00:00.000Z',
  'status': status,
  'crystalsGranted': null,
  'newBalance': null,
  'mailId': null,
  ...extra,
};

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

SepayPhaleGateway _gateway(
  MockClient client, {
  String? token = 'tok-1',
}) => SepayPhaleGateway(
  baseUrl: _base,
  idToken: () async => token,
  client: client,
);

class _Server implements MailService {
  final mails = <GameMail>[];
  final marks = <String, Map<String, MailState>>{};
  var claimCalls = 0;

  @override
  Future<List<GameMail>> inbox(String uid) async => [
    for (final m in mails)
      if (m.target == mailToAll || m.target == uid) m,
  ];

  @override
  Future<Map<String, MailState>> states(String uid) async => {...?marks[uid]};

  @override
  Future<void> markRead(String uid, String mailId) async {}

  @override
  Future<MailClaimResult> claim(String uid, String mailId) async {
    claimCalls++;
    final mine = marks.putIfAbsent(uid, () => {});
    if (mine[mailId]?.claimed == true) return MailClaimResult.already;
    mine[mailId] = const MailState(read: true, claimed: true);
    return MailClaimResult.claimed;
  }
}

void main() {
  group('SepayPhaleGateway (fake HTTP)', () {
    test('createOrder posts only the pack id, with the ID token', () async {
      late http.Request seen;
      final g = _gateway(
        MockClient((r) async {
          seen = r;
          return _ok(_orderJson());
        }),
      );
      final o = await g.createOrder('pack_50k');
      expect(seen.method, 'POST');
      expect(seen.url.toString(), '$_base/phaleCreateOrder');
      expect(seen.headers['authorization'], 'Bearer tok-1');
      // Nothing about money goes up: the server prices the pack itself.
      expect(jsonDecode(seen.body), {'packId': 'pack_50k'});
      expect(o.orderId, 'THSMK7P2Q9XABC');
      expect(o.amount, 50000);
      expect(o.crystals, 550);
      expect(o.bank, 'Vietcombank');
      expect(o.accountNo, '0123456789');
      expect(o.transferContent, 'THSMK7P2Q9XABC');
      expect(o.qrImageUrl, startsWith('https://qr.sepay.vn'));
      expect(o.expiresAt, DateTime.utc(2026, 10, 20, 8, 15));
      expect(o.serverTime, DateTime.utc(2026, 10, 20, 8));
      expect(o.status, PhaleOrderStatus.pending);
      expect(o.demo, isFalse);
    });

    test('orderStatus is a GET with the order id and reads the answer', () async {
      late http.Request seen;
      final g = _gateway(
        MockClient((r) async {
          seen = r;
          return _ok(
            _orderJson(
              status: 'paid',
              extra: {'crystalsGranted': 550, 'mailId': 'phale_THSMK7P2Q9XABC'},
            ),
          );
        }),
      );
      final o = await g.orderStatus('THSMK7P2Q9XABC');
      expect(seen.method, 'GET');
      expect(seen.url.path, '/phaleOrderStatus');
      expect(seen.url.queryParameters['orderId'], 'THSMK7P2Q9XABC');
      expect(o.status, PhaleOrderStatus.paid);
      expect(o.crystalsGranted, 550);
      expect(o.mailId, 'phale_THSMK7P2Q9XABC');
    });

    test('server status words map: mismatch, expired, cancelled', () async {
      for (final (word, want) in [
        ('mismatch', PhaleOrderStatus.mismatch),
        ('expired', PhaleOrderStatus.expired),
        ('cancelled', PhaleOrderStatus.cancelled),
      ]) {
        final g = _gateway(MockClient((_) async => _ok(_orderJson(status: word))));
        expect((await g.orderStatus('x')).status, want);
      }
    });

    test('cancelOrder posts the id', () async {
      late http.Request seen;
      final g = _gateway(
        MockClient((r) async {
          seen = r;
          return _ok(_orderJson(status: 'cancelled'));
        }),
      );
      await g.cancelOrder('THSMK7P2Q9XABC');
      expect(seen.url.path, '/phaleCancelOrder');
      expect(jsonDecode(seen.body), {'orderId': 'THSMK7P2Q9XABC'});
    });

    test('503 is the closed state, other errors are network', () async {
      Future<PhaleFailure> failure(int code) async {
        final g = _gateway(MockClient((_) async => http.Response('{}', code)));
        try {
          await g.createOrder('pack_50k');
        } on PhaleException catch (e) {
          return e.failure;
        }
        fail('no failure for $code');
      }

      expect(await failure(503), PhaleFailure.closed);
      for (final code in [400, 401, 404, 500]) {
        expect(await failure(code), PhaleFailure.network);
      }
    });

    test('a lost connection, a timeout, a bad body: network', () async {
      final lost = _gateway(MockClient((_) async => throw http.ClientException('x')));
      await expectLater(
        lost.orderStatus('x'),
        throwsA(isA<PhaleException>().having((e) => e.failure, 'f', PhaleFailure.network)),
      );
      final junk = _gateway(MockClient((_) async => http.Response('not json', 200)));
      await expectLater(junk.orderStatus('x'), throwsA(isA<PhaleException>()));
      final noField = _gateway(
        MockClient((_) async => _ok({..._orderJson()}..remove('amount'))),
      );
      await expectLater(noField.orderStatus('x'), throwsA(isA<PhaleException>()));
      final slow = SepayPhaleGateway(
        baseUrl: _base,
        idToken: () async => 't',
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) => Future.delayed(const Duration(seconds: 1), () => _ok(_orderJson()))),
      );
      await expectLater(slow.createOrder('pack_50k'), throwsA(isA<PhaleException>()));
    });

    test('signed out (no token): nothing is sent', () async {
      var calls = 0;
      final g = _gateway(
        MockClient((_) async {
          calls++;
          return _ok(_orderJson());
        }),
        token: null,
      );
      await expectLater(g.createOrder('pack_50k'), throwsA(isA<PhaleException>()));
      expect(calls, 0);
    });
  });

  group('a paid order reaches the wallet only through the mail claim', () {
    test('claimPhaleMail claims phale_{id} once and returns the balance', () async {
      final s = newSession();
      s.accountUid = 'me';
      final server = _Server()
        ..mails.add(
          GameMail(
            id: 'phale_THSMK7P2Q9XABC',
            title: 'Nap Pha le',
            body: 'ok',
            target: 'me',
            rewards: RewardBundle([const RewardItem.phaLe(550)]),
          ),
        );
      final feed = MailboxFeed(service: server);
      final before = s.state.phaLe;
      final order = PhaleOrder(
        orderId: 'THSMK7P2Q9XABC',
        packId: 'pack_50k',
        amount: 50000,
        crystals: 550,
        bonusPercent: 0,
        bank: 'b',
        accountNo: '1',
        accountName: 'n',
        transferContent: 'THSMK7P2Q9XABC',
        expiresAt: DateTime.utc(2026, 10, 20, 8, 15),
        status: PhaleOrderStatus.paid,
        mailId: 'phale_THSMK7P2Q9XABC',
      );
      expect(await claimPhaleMail(s, feed, order), before + 550);
      expect(s.state.phaLe, before + 550);
      // Asking again (a second poll, a second tab) adds nothing.
      expect(await claimPhaleMail(s, feed, order), before + 550);
      expect(s.state.phaLe, before + 550);
      expect(server.claimCalls, 1);
    });

    test('mail not there yet: nothing is added, balance unknown', () async {
      final s = newSession();
      s.accountUid = 'me';
      final feed = MailboxFeed(service: _Server());
      final order = PhaleOrder(
        orderId: 'A',
        packId: 'pack_50k',
        amount: 50000,
        crystals: 550,
        bonusPercent: 0,
        bank: 'b',
        accountNo: '1',
        accountName: 'n',
        transferContent: 'A',
        expiresAt: DateTime.utc(2026, 10, 20),
      );
      final before = s.state.phaLe;
      expect(await claimPhaleMail(s, feed, order), isNull);
      expect(s.state.phaLe, before);
    });

    test('the controller claims once when the server says paid', () async {
      var claims = 0;
      final cfg = PhaleShopConfig.fromJson(
        (jsonDecode(phaleEconomy()) as Map)['phaLeShop'],
      );
      final gateway = DemoPhaleGateway(config: cfg);
      final c = PhaleShopController(
        config: cfg,
        gateway: gateway,
        signedIn: () => true,
        autoPoll: false,
        onPaid: (o) async {
          claims++;
          return 1234;
        },
      );
      c.start();
      c.pick(cfg.packs.first.id);
      await c.confirmBuy();
      final id = c.order!.orderId;
      gateway.force(id, PhaleOrderStatus.paid, granted: cfg.packs.first.phaLe);
      await c.poll();
      await Future<void>.delayed(Duration.zero);
      expect(c.step, PhaleStep.done);
      expect(claims, 1);
      expect(c.order!.newBalance, 1234);
      await c.poll();
      expect(claims, 1);
      c.dispose();
    });
  });
}