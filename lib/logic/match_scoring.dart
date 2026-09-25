import '../data/economy.dart';
import 'bouquet.dart';

enum Tier { unhappy, okay, great }

/// Result of `matchScoring` for one bouquet against one request.
class MatchResult {
  const MatchResult({
    required this.score,
    required this.species,
    required this.stemCount,
    required this.paper,
    required this.ribbon,
    required this.wiltPenaltyApplied,
    required this.tier,
    required this.mismatchReason,
  });

  /// Final match 0..1.
  final double score;
  final double species;
  final double stemCount;
  final double paper;
  final double ribbon;
  final bool wiltPenaltyApplied;
  final Tier tier;

  /// `species`, `stems` or `wrapping` (reviews.json `selection.mismatchReason`),
  /// or null when no part lost at least 0.1.
  final String? mismatchReason;
}

Tier tierFor(Economy e, double match) {
  if (match >= e.greatThreshold) return Tier.great;
  if (match >= e.okayThreshold) return Tier.okay;
  return Tier.unhappy;
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// Minimum lost points for a part to be a review mismatch reason
/// (reviews.json `selection.mismatchReason`: "ít nhất 0.1 điểm").
/// TODO(Hà Phương): the 0.1 lives only in prose; add a numeric key.
const double mismatchReasonMinLoss = 0.1;

MatchResult scoreBouquet(Economy e, BouquetRequest request, Bouquet bouquet) {
  final occasion = e.occasion(request.occasionId);
  final r = request.requestedSpecies;

  // U: used species. Filler is ignored when allowed and not asked for.
  final used = <String>{};
  for (final s in bouquet.stems) {
    final id = s.flowerId;
    if (e.isFiller(id) && occasion.fillerAllowed && !r.contains(id)) continue;
    used.add(id);
  }
  final hit = used.intersection(r).length;
  final wrong = used.difference(r).length;
  final species = r.isEmpty
      ? 0.0
      : _clamp01(hit / r.length - e.wrongSpeciesPenalty * wrong);

  // Stem count: stems of requested main species vs the requested total.
  var mainStems = 0;
  for (final s in bouquet.stems) {
    if (request.stems.containsKey(s.flowerId)) mainStems++;
  }
  final diff = (mainStems - request.total).abs();
  final stemCount = e.creditByDifference[diff] ?? 0.0;

  double choice(ChoiceScores sc, String? chosen, String wanted, List<String> ok) {
    if (chosen == null) return sc.other;
    if (chosen == wanted) return sc.exact;
    if (ok.contains(chosen)) return sc.otherAccepted;
    return sc.other;
  }

  final paper = choice(
    e.paperScores,
    bouquet.paperId,
    request.paperId,
    occasion.papers,
  );
  final ribbon = choice(
    e.ribbonScores,
    bouquet.ribbonId,
    request.ribbonId,
    occasion.ribbons,
  );

  final wilting = bouquet.stems.any((s) => s.freshnessLeft <= 1);
  var score =
      e.weightSpecies * species +
      e.weightStemCount * stemCount +
      e.weightPaper * paper +
      e.weightRibbon * ribbon;
  if (wilting) score -= e.wiltingPenalty;
  score = _clamp01(score);
  // Keep 1.0 exact despite float sums (0.5+0.2+0.15+0.15).
  score = (score * 1e9).roundToDouble() / 1e9;

  final losses = <String, double>{
    'species': e.weightSpecies * (1 - species),
    'stems': e.weightStemCount * (1 - stemCount),
    'wrapping': e.weightPaper * (1 - paper) + e.weightRibbon * (1 - ribbon),
  };
  String? reason;
  var worst = 0.0;
  for (final entry in losses.entries) {
    if (entry.value > worst + 1e-9) {
      worst = entry.value;
      reason = entry.key;
    }
  }
  if (worst < mismatchReasonMinLoss - 1e-9) reason = null;

  return MatchResult(
    score: score,
    species: species,
    stemCount: stemCount,
    paper: paper,
    ribbon: ribbon,
    wiltPenaltyApplied: wilting,
    tier: tierFor(e, score),
    mismatchReason: reason,
  );
}
