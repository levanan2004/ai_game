import 'dart:math';

import 'package:ai_game/logic/review_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final texts = loadTestData().reviews;

  test('never repeats one of the last noRepeatLast sentences', () {
    final rng = Random(7);
    final recent = <String>[];
    for (var i = 0; i < 300; i++) {
      final outcome = ['great', 'okay', 'unhappy', 'leftUnserved'][i % 4];
      final s = pickReviewComment(
        texts,
        outcome: outcome,
        occasionId: 'birthday',
        rng: rng,
        recent: recent,
        mismatchReason: i.isEven ? 'species' : null,
      );
      final window = recent.length > texts.noRepeatLast
          ? recent.sublist(recent.length - texts.noRepeatLast)
          : recent;
      expect(window.contains(s), isFalse, reason: 'repeated "$s" at $i');
      recent.add(s);
    }
  });

  test('every picked sentence comes from the outcome bucket', () {
    final rng = Random(1);
    final o = texts.outcomes['great']!;
    final all = {
      ...o.generic,
      for (final l in o.byOccasion.values) ...l,
      for (final l in o.byHoliday.values) ...l,
    };
    for (var i = 0; i < 50; i++) {
      final s = pickReviewComment(
        texts,
        outcome: 'great',
        occasionId: 'confession',
        holidayId: 'valentine',
        rng: rng,
        recent: const [],
      );
      expect(all.contains(s), isTrue);
    }
  });

  test('mismatch reason sentences are used for okay/unhappy', () {
    final rng = Random(2);
    final reasons = texts.outcomes['unhappy']!.byReason['stems']!.toSet();
    var hits = 0;
    for (var i = 0; i < 100; i++) {
      final s = pickReviewComment(
        texts,
        outcome: 'unhappy',
        occasionId: 'thanks',
        mismatchReason: 'stems',
        rng: rng,
        recent: const [],
      );
      if (reasons.contains(s)) hits++;
    }
    // reasonChance is 0.7 in reviews.json.
    expect(hits, greaterThan(50));
  });

  test('falls back to generic when the chosen pool is exhausted', () {
    final o = texts.outcomes['okay']!;
    final blocked = o.byReason['wrapping']!;
    final s = pickReviewComment(
      texts,
      outcome: 'okay',
      occasionId: 'thanks',
      mismatchReason: 'wrapping',
      rng: Random(0),
      recent: blocked,
    );
    expect(blocked.contains(s), isFalse);
    expect(s, isNotEmpty);
  });
}
