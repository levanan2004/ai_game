import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('economy, reviews and orders parse', () {
    final d = loadTestData();
    final e = d.economy;
    expect(e.maxStems, greaterThan(0));
    expect(
      e.weightSpecies + e.weightStemCount + e.weightPaper + e.weightRibbon,
      closeTo(1, 1e-9),
    );
    expect(e.upgrades, isNotEmpty);
    for (final o in ['great', 'okay', 'unhappy', 'leftUnserved']) {
      expect(d.reviews.outcomes[o]!.generic, isNotEmpty, reason: o);
    }
    expect(d.orders.customerNames, isNotEmpty);
    for (final o in e.occasions) {
      expect(d.orders.byOccasion[o.id], isNotEmpty, reason: o.id);
    }
  });

  test('every review sentence respects maxChars', () {
    final r = loadTestData().reviews;
    for (final o in r.outcomes.values) {
      for (final s in [
        ...o.generic,
        for (final l in o.byReason.values) ...l,
        for (final l in o.byOccasion.values) ...l,
        for (final l in o.byHoliday.values) ...l,
      ]) {
        expect(s.length, lessThanOrEqualTo(r.maxChars), reason: s);
      }
    }
  });
}
