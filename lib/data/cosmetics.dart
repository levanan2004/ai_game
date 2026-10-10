/// Flavor text for shop cosmetics (`assets/data/cosmetics.json`).
///
/// Prices and slot rules stay in economy.json. [kind] is `pot` for now.
/// Later entries can be `shelf`, `bar`, `counter`, `background`, `hanging`.
class CosmeticEntry {
  const CosmeticEntry({
    required this.id,
    required this.kind,
    required this.nameVi,
    required this.description,
  });

  final String id;
  final String kind;
  final String nameVi;
  final String description;
}

class CosmeticCatalog {
  const CosmeticCatalog(this.items);

  final List<CosmeticEntry> items;

  factory CosmeticCatalog.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    if (raw is! List) {
      throw FormatException('cosmetics.json: missing "items"');
    }
    final items = <CosmeticEntry>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) {
        throw FormatException('cosmetics.json: items[$i] is not an object');
      }
      items.add(
        CosmeticEntry(
          id: _str(item, 'id', i),
          kind: _str(item, 'kind', i),
          nameVi: _str(item, 'nameVi', i),
          description: _str(item, 'description', i),
        ),
      );
    }
    return CosmeticCatalog(items);
  }

  CosmeticEntry? find(String id, {String kind = 'pot'}) {
    for (final item in items) {
      if (item.id == id && item.kind == kind) return item;
    }
    return null;
  }

  String description(String id, {String kind = 'pot'}) =>
      find(id, kind: kind)?.description ?? '';
}

String _str(Map<String, dynamic> j, String key, int index) {
  final v = j[key];
  if (v is! String || v.isEmpty) {
    throw FormatException('cosmetics.json: items[$index] missing "$key"');
  }
  return v;
}
