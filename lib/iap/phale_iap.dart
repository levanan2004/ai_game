import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'phale_products.dart';

/// The player closed the App Store sheet.
class PhaleIapCancelled implements Exception {}

/// StoreKit could not start, or the product is missing in App Store Connect.
class PhaleIapUnavailable implements Exception {}

/// A finished App Store purchase, still uncredited until the server accepts
/// [jws]. Call [finish] only after that, so a crash can be retried.
class PhaleIapPurchase {
  PhaleIapPurchase({
    required this.productId,
    required this.jws,
    required this.finish,
  });

  final String productId;
  final String jws;
  final Future<void> Function() finish;
}

/// Consumable Pha lê packs through StoreKit. The app never adds Pha lê
/// itself: the signed transaction goes to the server, which writes the mail.
class PhaleIap {
  PhaleIap({InAppPurchase? store}) : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;
  final Map<String, Completer<PhaleIapPurchase>> _waiting = {};
  final Map<String, PhaleIapPurchase> _ready = {};
  final _unclaimed = StreamController<PhaleIapPurchase>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  var _started = false;

  /// A paid purchase nobody is waiting for (StoreKit gives unfinished ones
  /// back at launch). ShopSession.drainApplePurchases sends it to the server.
  Stream<PhaleIapPurchase> get unclaimed => _unclaimed.stream;

  /// Paid purchases not credited yet, one per product.
  List<PhaleIapPurchase> get pending => List.of(_ready.values);

  /// Drops [purchase] from [pending] once it is credited and finished.
  void forget(PhaleIapPurchase purchase) {
    if (identical(_ready[purchase.productId], purchase)) {
      _ready.remove(purchase.productId);
    }
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = _store.purchaseStream.listen(_onPurchases, onError: (Object _) {});
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  /// App Store prices ("25.000 ₫", "$0.99") by pack id. Packs App Store
  /// Connect does not know are missing; an empty map when StoreKit is down.
  Future<Map<String, String>> prices(Iterable<String> packIds) async {
    if (!await _store.isAvailable()) return const {};
    final response = await _store.queryProductDetails({
      for (final id in packIds) phaleProductId(id),
    });
    return {
      for (final p in response.productDetails) ?phalePackIdOf(p.id): p.price,
    };
  }

  /// Shows the App Store payment sheet for [packId] (`pack_10k`, …).
  /// [accountToken] (appAccountTokenFor of the signed-in uid) goes into the
  /// signed transaction as appAccountToken.
  Future<PhaleIapPurchase> buy(String packId, {String? accountToken}) async {
    await start();
    if (!await _store.isAvailable()) throw PhaleIapUnavailable();
    final productId = phaleProductId(packId);
    final already = _ready.remove(productId);
    if (already != null) return already;
    final response = await _store.queryProductDetails({productId});
    if (response.productDetails.isEmpty) throw PhaleIapUnavailable();
    final pending = _waiting[productId];
    if (pending != null && !pending.isCompleted) {
      throw PhaleIapUnavailable();
    }
    final done = Completer<PhaleIapPurchase>();
    _waiting[productId] = done;
    final started = await _store.buyConsumable(
      // StoreKit 2 sends applicationUserName as appAccountToken (a UUID).
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.first,
        applicationUserName: accountToken,
      ),
    );
    if (!started) {
      _waiting.remove(productId);
      throw PhaleIapUnavailable();
    }
    return done.future;
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      final wait = _waiting[purchase.productID];
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            unawaited(_store.completePurchase(purchase));
          }
          if (wait != null && !wait.isCompleted) {
            wait.completeError(PhaleIapCancelled());
          }
          _waiting.remove(purchase.productID);
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            unawaited(_store.completePurchase(purchase));
          }
          if (wait != null && !wait.isCompleted) {
            wait.completeError(PhaleIapUnavailable());
          }
          _waiting.remove(purchase.productID);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final jws = purchase.verificationData.serverVerificationData;
          if (jws.isEmpty) {
            if (wait != null && !wait.isCompleted) {
              wait.completeError(PhaleIapUnavailable());
            }
            _waiting.remove(purchase.productID);
            break;
          }
          final result = PhaleIapPurchase(
            productId: purchase.productID,
            jws: jws,
            finish: () => _store.completePurchase(purchase),
          );
          if (wait != null && !wait.isCompleted) {
            wait.complete(result);
            _waiting.remove(purchase.productID);
          } else {
            // App restarted before the server was told: kept until
            // ShopSession.drainApplePurchases credits it (or the next buy
            // of this pack sends it instead of charging again).
            _ready[purchase.productID] = result;
            _unclaimed.add(result);
          }
      }
    }
  }
}
