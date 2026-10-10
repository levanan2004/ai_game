import 'package:ai_game/logic/format.dart';
import 'package:ai_game/logic/rating.dart';
import 'package:ai_game/save/game_state.dart';
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

  test('average matches the stars the bars count', () {
    final r = summarizeRatings(
      [5, 4, 2],
      window: e.ratingWindow,
      fallback: e.startRating,
    );
    expect(r.average, closeTo(11 / 3, 1e-9));
    expect(r.count, 3);
    expect(r.distribution[5], 1);
    expect(r.distribution[4], 1);
    expect(r.distribution[2], 1);
    expect(formatRating(r.average), '3,7');
  });

  test('one review is the shop score', () {
    final r = summarizeRatings(
      [2],
      window: e.ratingWindow,
      fallback: e.startRating,
    );
    expect(r.average, 2);
    expect(r.count, 1);
    expect(r.distribution[2], 1);
    expect(r.distribution[4], 0);
    expect(formatRating(r.average), '2,0');
  });

  test('five 5-star reviews score 5.0, not the opening 4.0', () {
    final r = summarizeRatings(
      [5, 5, 5, 5, 5],
      window: e.ratingWindow,
      fallback: e.startRating,
    );
    expect(r.average, 5);
    expect(r.count, 5);
    expect(r.distribution[5], 5);
    expect(r.distribution[4], 0);
    expect(formatRating(r.average), '5,0');
  });

  test('day 1: 6 unserved customers rate 2.0; walkedPast adds no review', () {
    final s = newSession();
    expect(s.state.day, 1);
    expect(s.state.reviews, isEmpty);
    stockAndOpen(s);
    s.state.pendingArrivals.clear();

    final stars = s.e.reviewStars['leftUnserved'];
    expect(stars, isNotNull);
    expect(s.e.reviewStars['walkedPast'], isNull);
    const left = 6;
    for (var i = 0; i < left; i++) {
      s.state.pendingArrivals = [s.state.elapsed];
      s.tick(0.05);
      final c = s.queue.last;
      c.walkIn = 0;
      c.patienceLeft = 0.01;
      s.state.pendingArrivals.clear();
      s.tick(0.05);
      expect(s.queue.contains(c), isFalse);
    }

    expect(s.state.reviews, hasLength(left));
    expect(
      s.state.reviews.every(
        (r) => r.outcome == 'leftUnserved' && r.stars == stars,
      ),
      isTrue,
    );
    expect(s.state.phase, DayPhase.open);

    expect(s.rating.average, stars);
    expect(s.rating.count, left);
    expect(s.rating.distribution[stars], left);
    expect(s.rating.distribution[4], 0);

    final cap = s.effects.counterSlots + s.effects.maxQueue;
    s.state.pendingArrivals = List.filled(
      cap + 3,
      s.state.elapsed,
      growable: true,
    );
    s.tick(0.05);
    expect(s.queue, hasLength(cap));
    expect(s.state.reviews, hasLength(left));
    expect(s.rating.average, stars);
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
