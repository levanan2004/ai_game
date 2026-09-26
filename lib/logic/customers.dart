import 'dart:math';

import '../data/economy.dart';
import 'bouquet.dart';
import 'goals.dart';

/// Values that economy.json only states in prose (`_occasionNote`).
/// TODO(Hà Phương): give these numeric keys in economy.json.
abstract final class OccasionNoteValues {
  /// "The request picks 1-2 species".
  static const maxSpeciesPerRequest = 2;

  /// "If fillerAllowed, 50% of requests add 'baby x2' as a wish."
  static const fillerWishChance = 0.5;
  static const fillerWishStems = 2;

  /// "(fallback rose/daisy)", "(fallback kraft/twine)".
  static const fallbackSpecies = ['rose', 'daisy'];
  static const fallbackPaper = 'kraft';
  static const fallbackRibbon = 'twine';
}

/// Occasions that can spawn with the owned items (`unlockWhen`).
List<OccasionDef> unlockedOccasions(Economy e, Set<String> owned) => [
  for (final o in e.occasions)
    if (o.unlockWhen == null || owned.contains(o.unlockWhen)) o,
];

/// Builds a request following economy.json `_occasionNote`.
BouquetRequest generateRequest(
  Economy e, {
  required Set<String> owned,
  required Random rng,
  List<int>? stemTotalRange,
}) {
  final occs = unlockedOccasions(e, owned);
  final occ = weightedPick(occs, (o) => o.weight, rng);

  var species = [
    for (final s in occ.species)
      if (owned.contains(s)) s,
  ];
  if (species.isEmpty) species = [...OccasionNoteValues.fallbackSpecies];
  species.shuffle(rng);

  int total;
  if (stemTotalRange != null && stemTotalRange.length >= 2) {
    final lo = stemTotalRange[0];
    final hi = stemTotalRange[1];
    total = lo + rng.nextInt(hi - lo + 1);
  } else if (occ.stemOptions != null && occ.stemOptions!.isNotEmpty) {
    total = occ.stemOptions![rng.nextInt(occ.stemOptions!.length)];
  } else {
    final lo = occ.stemRange![0];
    final hi = occ.stemRange![1];
    total = lo + rng.nextInt(hi - lo + 1);
  }

  String? filler;
  var fillerCount = 0;
  final fillerId = e.fillerSpecies.isEmpty ? null : e.fillerSpecies.first;
  if (occ.fillerAllowed &&
      fillerId != null &&
      owned.contains(fillerId) &&
      rng.nextDouble() < OccasionNoteValues.fillerWishChance) {
    filler = fillerId;
    fillerCount = OccasionNoteValues.fillerWishStems;
  }
  if (total + fillerCount > e.maxStems) total = e.maxStems - fillerCount;
  if (total < 1) total = 1;

  var k = 1 + rng.nextInt(OccasionNoteValues.maxSpeciesPerRequest);
  if (k > species.length) k = species.length;
  if (k > total) k = total;
  final stems = <String, int>{};
  if (k == 1) {
    stems[species[0]] = total;
  } else {
    final first = 1 + rng.nextInt(total - 1);
    stems[species[0]] = first;
    stems[species[1]] = total - first;
  }

  String pick(List<String> options, String fallback) {
    final ok = [
      for (final o in options)
        if (owned.contains(o)) o,
    ];
    return ok.isEmpty ? fallback : ok[rng.nextInt(ok.length)];
  }

  return BouquetRequest(
    occasionId: occ.id,
    stems: stems,
    fillerId: filler,
    fillerCount: fillerCount,
    paperId: pick(occ.papers, OccasionNoteValues.fallbackPaper),
    ribbonId: pick(occ.ribbons, OccasionNoteValues.fallbackRibbon),
  );
}

/// Poisson sample (Knuth), fine for the small means used here.
int poisson(double lambda, Random rng) {
  if (lambda <= 0) return 0;
  final l = exp(-lambda);
  var k = 0;
  var p = 1.0;
  do {
    k++;
    p *= rng.nextDouble();
  } while (p > l);
  return k - 1;
}

/// Arrival times (seconds since opening), spread by `arrivalWeightsByHour`.
List<double> scheduleArrivals(Economy e, int count, Random rng) {
  final hours = e.arrivalWeightsByHour.keys.toList()..sort();
  final out = <double>[];
  for (var i = 0; i < count; i++) {
    final h = weightedPick(hours, (h) => e.arrivalWeightsByHour[h]!, rng);
    final t = ((h - e.openHour) + rng.nextDouble()) * e.secondsPerHour;
    out.add(t.clamp(0, e.dayRealSeconds - 1).toDouble());
  }
  out.sort();
  return out;
}

/// Tutorial order (spec_popup_va_mo_dau.md §6): an easy request that only
/// uses the `start` flowers, paper and ribbon, and never asks for more
/// stems than are in [stock] (flower id to stems).
BouquetRequest easyRequest(
  Economy e, {
  required Map<String, int> stock,
  required Random rng,
}) {
  bool has(String id) => (stock[id] ?? 0) > 0;
  var flowers = {
    for (final f in e.unlockedFlowers)
      if (has(f) && !e.isFiller(f)) f,
  };
  if (flowers.isEmpty) {
    flowers = {
      for (final f in e.unlockedFlowers)
        if (has(f)) f,
    };
  }
  if (flowers.isEmpty) flowers = {...e.unlockedFlowers};
  final base = generateRequest(
    e,
    owned: {...flowers, ...e.unlockedPapers, ...e.unlockedRibbons},
    rng: rng,
  );
  var main = base.mainSpecies;
  if (!flowers.contains(main)) {
    main = flowers.reduce((a, b) => (stock[a] ?? 0) >= (stock[b] ?? 0) ? a : b);
  }
  final have = stock[main] ?? 0;
  final n = have > 0 && have < base.total ? have : base.total;
  return BouquetRequest(
    occasionId: base.occasionId,
    stems: {main: n < 1 ? 1 : n},
    paperId: e.unlockedPapers.first,
    ribbonId: e.unlockedRibbons.first,
  );
}
