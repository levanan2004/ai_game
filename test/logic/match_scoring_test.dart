import 'package:ai_game/logic/bouquet.dart';
import 'package:ai_game/logic/match_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = loadTestData().economy;
  const req = BouquetRequest(
    occasionId: 'birthday',
    stems: {'rose': 3},
    paperId: 'kraft',
    ribbonId: 'twine',
  );

  test('exact bouquet scores 1.0 and is great', () {
    final m = scoreBouquet(e, req, bouquetOf({'rose': 3}, paper: 'kraft', ribbon: 'twine'));
    expect(m.score, 1.0);
    expect(m.tier, Tier.great);
    expect(m.mismatchReason, isNull);
  });

  test('filler is ignored unless asked for', () {
    final m = scoreBouquet(
      e,
      req,
      bouquetOf({'rose': 3, 'baby': 2}, paper: 'kraft', ribbon: 'twine'),
    );
    expect(m.species, 1.0);
    expect(m.score, 1.0);
  });

  test('filler wish counts as a requested species', () {
    const withFiller = BouquetRequest(
      occasionId: 'birthday',
      stems: {'rose': 3},
      fillerId: 'baby',
      fillerCount: 2,
      paperId: 'kraft',
      ribbonId: 'twine',
    );
    final without = scoreBouquet(
      e,
      withFiller,
      bouquetOf({'rose': 3}, paper: 'kraft', ribbon: 'twine'),
    );
    expect(without.species, closeTo(0.5, 1e-9));
    final withIt = scoreBouquet(
      e,
      withFiller,
      bouquetOf({'rose': 3, 'baby': 2}, paper: 'kraft', ribbon: 'twine'),
    );
    expect(withIt.species, 1.0);
  });

  test('wrong species is penalised by wrongSpeciesPenalty', () {
    final m = scoreBouquet(
      e,
      req,
      bouquetOf({'rose': 3, 'daisy': 1}, paper: 'kraft', ribbon: 'twine'),
    );
    expect(m.species, closeTo(1 - e.wrongSpeciesPenalty, 1e-9));
  });

  test('stem count credit follows creditByDifference, 3+ off is 0', () {
    double stems(int n) => scoreBouquet(
      e,
      req,
      bouquetOf({'rose': n}, paper: 'kraft', ribbon: 'twine'),
    ).stemCount;
    expect(stems(3), e.creditByDifference[0]);
    expect(stems(4), e.creditByDifference[1]);
    expect(stems(1), e.creditByDifference[2]);
    expect(stems(6), 0);
  });

  test('other paper accepted for the occasion scores otherAccepted', () {
    final m = scoreBouquet(e, req, bouquetOf({'rose': 3}, paper: 'mesh', ribbon: 'twine'));
    expect(m.paper, e.paperScores.otherAccepted);
    final none = scoreBouquet(e, req, bouquetOf({'rose': 3}, paper: 'kraft'));
    expect(none.ribbon, e.ribbonScores.other);
    final box = scoreBouquet(e, req, bouquetOf({'rose': 3}, paper: 'box', ribbon: 'twine'));
    expect(box.paper, e.paperScores.other);
  });

  test('a stem on its last fresh day subtracts wiltingPenalty', () {
    final m = scoreBouquet(
      e,
      req,
      bouquetOf({'rose': 3}, paper: 'kraft', ribbon: 'twine', freshness: 1),
    );
    expect(m.wiltPenaltyApplied, isTrue);
    expect(m.score, closeTo(1 - e.wiltingPenalty, 1e-9));
  });

  test('thresholds decide the tier and the mismatch reason', () {
    // Right flowers, wrong wrapping: 0.5 + 0.2 = 0.7 -> okay, reason wrapping.
    final m = scoreBouquet(e, req, bouquetOf({'rose': 3}, paper: 'box', ribbon: 'printed'));
    expect(m.score, closeTo(0.7, 1e-9));
    expect(m.tier, Tier.okay);
    expect(m.mismatchReason, 'wrapping');
    // Wrong species only.
    final w = scoreBouquet(e, req, bouquetOf({'daisy': 3}, paper: 'kraft', ribbon: 'twine'));
    expect(w.tier, Tier.unhappy);
    expect(w.mismatchReason, 'species');
    expect(tierFor(e, e.greatThreshold), Tier.great);
    expect(tierFor(e, e.okayThreshold), Tier.okay);
    expect(tierFor(e, e.okayThreshold - 0.01), Tier.unhappy);
  });
}
