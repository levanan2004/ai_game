/// What a customer asks for.
class BouquetRequest {
  const BouquetRequest({
    required this.occasionId,
    required this.stems,
    required this.paperId,
    required this.ribbonId,
    this.fillerId,
    this.fillerCount = 0,
  });

  final String occasionId;

  /// Requested main species (filler excluded) to stem count, in display order.
  final Map<String, int> stems;

  /// Filler the customer explicitly wished for (e.g. "baby x2"), or null.
  final String? fillerId;
  final int fillerCount;
  final String paperId;
  final String ribbonId;

  /// Requested stem total of the main species (filler excluded).
  int get total => stems.values.fold(0, (a, b) => a + b);

  /// R in the species rule: main species plus the filler if asked for.
  Set<String> get requestedSpecies => {...stems.keys, ?fillerId};

  /// The species with the most stems (shown in the short queue bubble).
  String get mainSpecies =>
      stems.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  Map<String, Object?> toJson() => {
    'occasionId': occasionId,
    'stems': stems,
    'fillerId': fillerId,
    'fillerCount': fillerCount,
    'paperId': paperId,
    'ribbonId': ribbonId,
  };
}

/// One stem in a bouquet, taken from stock with its freshness.
class Stem {
  const Stem({
    required this.uid,
    required this.flowerId,
    required this.freshnessLeft,
  });

  final int uid;
  final String flowerId;
  final int freshnessLeft;
}

/// The bouquet the player is building.
class Bouquet {
  Bouquet({List<Stem>? stems, this.paperId, this.ribbonId})
    : stems = stems ?? [];

  final List<Stem> stems;
  String? paperId;
  String? ribbonId;

  bool get isEmpty => stems.isEmpty;

  /// Species to stem count, in the order species were first added.
  Map<String, int> get counts {
    final out = <String, int>{};
    for (final s in stems) {
      out[s.flowerId] = (out[s.flowerId] ?? 0) + 1;
    }
    return out;
  }
}
