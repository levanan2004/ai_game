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
