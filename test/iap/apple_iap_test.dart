import 'dart:async';
import 'dart:convert';

import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/iap/apple_phale_client.dart';
import 'package:ai_game/iap/phale_iap.dart';
import 'package:ai_game/iap/phale_products.dart';
import 'package:ai_game/logic/platform_flags.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../helpers.dart';

/// StoreKit stand-in: the test pushes purchases into [purchaseStream].
class _Store implements InAppPurchase {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];
  PurchaseParam? bought;
  var prices = <String, String>{};

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      for (final id in identifiers)
        if (prices[id] != null)
          ProductDetails(
            id: id,
            title: id,
            description: '',
            price: prices[id]!,
            rawPrice: 1,
            currencyCode: 'VND',
          ),
    ],
    notFoundIDs: const [],
  );

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    bought = purchaseParam;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase.verificationData.serverVerificationData);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurchaseDetails _paid(String packId, String jws) => PurchaseDetails(
  productID: phaleProductId(packId),
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: jws,
    source: 'app_store',
  ),
  transactionDate: null,
  status: PurchaseStatus.purchased,
)..pendingCompletePurchase = true;

class _Signed extends OfflineAccount {
  const _Signed();

  @override
  Future<String?> idToken() async => 'token';
}

/// The callable answers [answers] in turn: a mail, or an error body.
ApplePhaleClient _client(List<http.Response> answers, List<String> sent) =>
    ApplePhaleClient(
      baseUrl: 'https://example.test',
      client: MockClient((req) async {
        final body = jsonDecode(req.body) as Map;
        sent.add((body['data'] as Map)['signedTransaction'] as String);
        return answers.removeAt(0);
      }),
    );

http.Response _ok(String txn) => http.Response(
  jsonEncode({
    'result': {
      'mailId': 'phale_iap_$txn',
      'phaLe': 550,
      'transactionId': txn,
      'packId': 'pack_50k',
    },
  }),
  200,
);

http.Response _refused(String code) => http.Response(
  jsonEncode({
    'error': {'status': 'FAILED_PRECONDITION', 'message': code},
  }),
  400,
);

void main() {
  tearDown(() => iosAppOverride = null);

  test('appAccountTokenFor is the same UUID v5 as the server', () {
    // functions/apple_iap.test.js TOKEN_VECTOR (and Python uuid.uuid5).
    expect(
      appAccountTokenFor('rFdE3O7LLBZIu0msxtvGktXmfJp1'),
      '45cbd7d0-0f71-5c14-a789-00b6fc52d4b7',
    );
    expect(appAccountTokenFor('u1'), isNot(appAccountTokenFor('u2')));
  });

  test(
    'the client keeps the reason of a refusal that will not change',
    () async {
      final sent = <String>[];
      final c = _client([
        _refused('owner'),
        _refused('revoked'),
        _refused('account'),
        http.Response('{}', 500),
      ], sent);
      Future<ApplePhaleException> refusal() async {
        try {
          await c.credit(idToken: 't', signedTransaction: 'jws');
        } on ApplePhaleException catch (e) {
          return e;
        }
        throw StateError('no exception');
      }

      final owner = await refusal();
      expect((owner.code, owner.finishPurchase), ('owner', true));
      final revoked = await refusal();
      expect((revoked.code, revoked.finishPurchase), ('revoked', true));
      final account = await refusal();
      expect((account.code, account.finishPurchase), ('account', false));
      final server = await refusal();
      expect((server.code, server.finishPurchase), ('server', false));
    },
  );

  test(
    'a buy sends the account token and App Store prices come by pack',
    () async {
      final store = _Store()..prices = {phaleProductId('pack_10k'): '25.000 ₫'};
      final iap = PhaleIap(store: store);
      expect(await iap.prices(['pack_10k', 'pack_20k']), {
        'pack_10k': '25.000 ₫',
      });
      final buying = iap.buy(
        'pack_10k',
        accountToken: appAccountTokenFor('u1'),
      );
      await pumpEventQueue();
      expect(store.bought!.applicationUserName, appAccountTokenFor('u1'));
      store.events.add([_paid('pack_10k', 'jws-new')]);
      expect((await buying).jws, 'jws-new');
      expect(iap.pending, isEmpty);
    },
  );

  group('drainApplePurchases', () {
    Future<(ShopSession, _Store, PhaleIap)> setUp(
      List<http.Response> answers,
      List<String> sent,
    ) async {
      iosAppOverride = true;
      final s = newSession(account: const _Signed());
      s.accountUid = 'u1';
      final store = _Store();
      final iap = PhaleIap(store: store);
      await iap.start();
      s.phaleIap = iap;
      s.applePhaleClient = _client(answers, sent);
      return (s, store, iap);
    }

    test(
      'a purchase StoreKit gives back at launch is credited, then finished',
      () async {
        final sent = <String>[];
        final (s, store, iap) = await setUp([_ok('1'), _ok('2')], sent);
        final seen = <String>[];
        iap.unclaimed.listen((p) => seen.add(p.jws));
        store.events.add([
          _paid('pack_50k', 'jws1'),
          _paid('pack_10k', 'jws2'),
        ]);
        await pumpEventQueue();
        expect(seen, ['jws1', 'jws2']);
        expect(iap.pending, hasLength(2));
        await s.drainApplePurchases();
        expect(sent, ['jws1', 'jws2']);
        expect(store.completed, ['jws1', 'jws2']);
        expect(iap.pending, isEmpty);
      },
    );

    test(
      'a refused purchase is finished, a server failure is kept for later',
      () async {
        final sent = <String>[];
        final (s, store, iap) = await setUp([
          _refused('owner'),
          http.Response('{}', 503),
        ], sent);
        store.events.add([
          _paid('pack_50k', 'used'),
          _paid('pack_10k', 'later'),
        ]);
        await pumpEventQueue();
        await s.drainApplePurchases();
        expect(store.completed, ['used']);
        expect(iap.pending.map((p) => p.jws), ['later']);
      },
    );

    test('signed out or not iOS: nothing is sent', () async {
      final sent = <String>[];
      final (s, store, iap) = await setUp([_ok('1')], sent);
      store.events.add([_paid('pack_50k', 'jws1')]);
      await pumpEventQueue();
      s.accountUid = null;
      await s.drainApplePurchases();
      iosAppOverride = false;
      s.accountUid = 'u1';
      await s.drainApplePurchases();
      expect(sent, isEmpty);
      expect(iap.pending, hasLength(1));
    });
  });
}
