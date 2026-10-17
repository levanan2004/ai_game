import 'dart:convert';

import 'package:crypto/crypto.dart';

/// App Store consumable ids. Create one product per pack in App Store
/// Connect, type Consumable, with this exact product id.
const phaleIapPrefix = 'com.tiemhoasommai.game.phale.';

String phaleProductId(String packId) => '$phaleIapPrefix$packId';

/// `pack_10k` from `com.tiemhoasommai.game.phale.pack_10k`, or null.
String? phalePackIdOf(String productId) {
  if (!productId.startsWith(phaleIapPrefix)) return null;
  final id = productId.substring(phaleIapPrefix.length);
  return id.isEmpty ? null : id;
}

/// Same namespace as ACCOUNT_TOKEN_NAMESPACE in functions/apple_iap.js.
const _accountTokenNamespace = 'a7c1e2b4-5d6f-4a89-b0c1-d2e3f4a5b6c7';

/// StoreKit appAccountToken of [uid]: a name-based UUID (version 5, SHA-1),
/// so the signed transaction names the account that paid and the server can
/// refuse it for any other account.
String appAccountTokenFor(String uid) {
  final ns = _accountTokenNamespace.replaceAll('-', '');
  final bytes = [
    for (var i = 0; i < ns.length; i += 2)
      int.parse(ns.substring(i, i + 2), radix: 16),
    ...utf8.encode(uid),
  ];
  final h = sha1.convert(bytes).bytes.sublist(0, 16);
  h[6] = (h[6] & 0x0f) | 0x50;
  h[8] = (h[8] & 0x3f) | 0x80;
  final x = h.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${x.substring(0, 8)}-${x.substring(8, 12)}-${x.substring(12, 16)}-'
      '${x.substring(16, 20)}-${x.substring(20)}';
}
