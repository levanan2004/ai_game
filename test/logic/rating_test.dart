import 'package:ai_game/logic/format.dart';
import 'package:ai_game/logic/rating.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = loadTestData().economy;

  test('no reviews -> start rating', () {
    final r = summarizeRatings(
      [],
      window: e.ratingWindow,
      fallback: e.startRating,
    );
    expect(r.average, e.startRating);
    expect(r.count, 0);
  });

  test('average and distribution use only the last ratingWindow reviews', () {
    final stars = [...List.filled(10, 1), ...List.filled(e.ratingWindow, 5)];
    final r = summarizeRatings(
      stars,
      window: e.ratingWindow,
      fallback: e.startRating,
    );
    expect(r.average, 5.0);
    expect(r.count, e.ratingWindow);
    expect(r.distribution[5], e.ratingWindow);
    expect(r.distribution[1], 0);
  });

  test('mixed window average pads missing slots with the start rating', () {
    final r = summarizeRatings(
      [5, 4, 2],
      window: e.ratingWindow,
      fallback: e.startRating,
    );
    final padded = (11 + e.startRating * (e.ratingWindow - 3)) / e.ratingWindow;
    expect(r.average, closeTo(padded, 1e-9));
    expect(r.count, 3);
    expect(r.distribution[5], 1);
    expect(r.distribution[4], 1);
    expect(r.distribution[2], 1);
  });

  test('one review does not replace the start rating', () {
    final r = summarizeRatings(
      [2],
      window: e.ratingWindow,
      fallback: e.startRating,
    );
    final padded = (2 + e.startRating * (e.ratingWindow - 1)) / e.ratingWindow;
    expect(r.average, closeTo(padded, 1e-9));
    expect(r.average, isNot(closeTo(2, 0.05)));
    expect(r.count, 1);
    // Padding slots are not stored reviews.
    expect(r.distribution[2], 1);
    expect(r.distribution[4], 0);
    expect(formatRating(r.average), '3,9');
  });

  test('ratingFactor is linear between whole stars', () {
    expect(e.ratingFactorFor(4), e.ratingFactor[4]);
    expect(
      e.ratingFactorFor(4.5),
      closeTo((e.ratingFactor[4]! + e.ratingFactor[5]!) / 2, 1e-9),
    );
  });

  test('money format matches the mockups', () {
    expect(formatK(1250000), '1.250k');
    expect(formatK(24000), '24k');
    expect(formatK(18400), '18,4k');
    expect(formatK(-384000), '-384k');
    expect(formatSignedK(3000), '+3k');
  });
}
