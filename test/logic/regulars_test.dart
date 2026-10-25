import 'package:ai_game/data/regulars.dart';
import 'package:ai_game/logic/regulars.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final data = loadTestData();
  final cat = data.regulars;
  final e = data.economy;
  RegularDef def(String id) => cat.byId(id)!;

  test('the ten regulars join block and stories by id and step', () {
    expect(cat.customers.length, 10);
    final days = [for (final c in cat.customers) c.minGameDay];
    expect(days, [...days]..sort());
    final khoa = def('anh_minh_khoa');
    expect(khoa.name, 'Minh Khoa');
    expect(khoa.visits.map((v) => v.sourceOccasion), [
      'confession',
      '14/2',
      'wedding',
    ]);
    expect(khoa.visits[1].holiday, 'valentine');
    expect(khoa.visits[2].announceDaysBefore, 3);
    expect(khoa.visits[0].order, startsWith('Chị ơi'));
    expect(cat.notebookMinGameDay, 3);
    expect(cat.notebookMinLifetimeGreat, 3);
    expect(cat.t.ui('title'), 'Sổ tay khách quen');
    expect(cat.t.occasion('14/2'), 'Valentine');
    final flowers = {for (final f in e.flowers) f.id};
    for (final c in cat.customers) {
      expect(c.favoriteFlowerIds.every(flowers.contains), isTrue, reason: c.id);
    }
  });

  test('hydrangea and peony replace the stand-in favourites', () {
    expect(def('chi_ngoc').favoriteFlowerIds, ['hydrangea']);
    expect(def('chi_my').favoriteFlowerIds, ['peony']);
    expect(def('ong_phuc').favoriteFlowerIds, ['peony']);
  });

  test('progress survives the save', () {
    final p = RegularProgress(
      stepsDone: {1: 5, 2: RegularProgress.poorEnding},
      unread: [2],
      retries: 1,
      doneDay: {1: 3, 2: 9},
      lastVisitDay: 9,
      scheduledDay: 14,
    );
    final back = RegularProgress.fromJson(p.toJson());
    expect(back.stepsDone, {1: 5, 2: 'poorEnding'});
    expect(back.unread, [2]);
    expect(back.retries, 1);
    expect(back.doneDay, {1: 3, 2: 9});
    expect(back.lastVisitDay, 9);
    expect(back.scheduledDay, 14);
    final s = newSession().state
      ..regulars = {'anh_minh_khoa': p}
      ..lifetimeGreat = 7
      ..notebookIntroSeen = true;
    final again = GameState.decode(s.encode())!;
    expect(again.regulars['anh_minh_khoa']!.stepsDone, {1: 5, 2: 'poorEnding'});
    expect(again.lifetimeGreat, 7);
    expect(again.notebookIntroSeen, isTrue);
  });

  test('notebook opens at the block day and great count', () {
    expect(notebookOpen(cat, day: 2, great: 9), isFalse);
    expect(notebookOpen(cat, day: 3, great: 2), isFalse);
    expect(notebookOpen(cat, day: 3, great: 3), isTrue);
  });

  test('hearts are round(5 * done / visits), poor endings do not count', () {
    final khoa = def('anh_minh_khoa');
    expect(heartsOf(cat, khoa, RegularProgress()), 0);
    expect(heartsOf(cat, khoa, RegularProgress(stepsDone: {1: 4})), 2);
    expect(
      heartsOf(
        cat,
        khoa,
        RegularProgress(stepsDone: {1: 5, 2: RegularProgress.skipped}),
      ),
      2,
    );
    expect(heartsOf(cat, khoa, RegularProgress(stepsDone: {1: 5, 2: 5})), 3);
    expect(
      heartsOf(cat, khoa, RegularProgress(stepsDone: {1: 5, 2: 5, 3: 4})),
      5,
    );
    // Step 1 failed for good: not a regular yet, no hearts.
    expect(
      heartsOf(
        cat,
        khoa,
        RegularProgress(stepsDone: {1: RegularProgress.poorEnding, 2: 5}),
      ),
      0,
    );
  });

  test('a story step: unhappy tries, then a poor ending', () {
    final p = RegularProgress();
    var out = recordRegularVisit(cat, p, step: 1, stars: 2, left: true, day: 3);
    expect(out, RegularOutcome.none);
    expect(p.retries, 0);
    expect(p.retryAfterDay, 3 + cat.retryGapDays);
    for (var k = 0; k < cat.maxRetries; k++) {
      out = recordRegularVisit(cat, p, step: 1, stars: 3, left: false, day: 5);
      expect(out, RegularOutcome.retry);
    }
    out = recordRegularVisit(cat, p, step: 1, stars: 3, left: false, day: 9);
    expect(out, RegularOutcome.poorEnding);
    expect(p.stepsDone[1], RegularProgress.poorEnding);
    expect(p.unread, [1]);
    expect(inviteAgain(def('anh_minh_khoa'), p), isTrue);
    expect(p.stepsDone, isEmpty);
    out = recordRegularVisit(cat, p, step: 1, stars: 5, left: false, day: 12);
    expect(out, RegularOutcome.becameRegular);
    expect(isRegular(cat, p), isTrue);
  });

  test(
    'Minh Khoa: first visit, Valentine after the gap, then an invitation',
    () {
      final khoa = def('anh_minh_khoa');
      final p = RegularProgress();
      final owned = {'rose', 'tulip'};
      VisitKind? due(int day) =>
          storyDue(cat, e, khoa, p, day: day, great: 3, owned: owned);
      expect(due(2), isNull);
      expect(due(3), VisitKind.normal);
      recordRegularVisit(cat, p, step: 1, stars: 5, left: false, day: 3);
      // Valentine is day 7 of each 42-day year; minGapDays 10 skips year 1.
      expect(due(7), isNull);
      expect(due(49), VisitKind.special);
      recordRegularVisit(cat, p, step: 2, stars: 4, left: false, day: 49);
      // Wedding needs lily, then an invitation announceDaysBefore ahead.
      expect(
        regularMorning(cat, e, khoa, p, day: 63, great: 3, owned: owned),
        isFalse,
      );
      owned.add('lily');
      expect(
        regularMorning(cat, e, khoa, p, day: 63, great: 3, owned: owned),
        isTrue,
      );
      expect(p.scheduledDay, 66);
      expect(due(65), isNull);
      expect(due(66), VisitKind.special);
    },
  );

  test('a missed holiday step is skipped after the retry window', () {
    final tuan = def('ban_tuan');
    final p = RegularProgress(stepsDone: {1: 5}, doneDay: {1: 5});
    final owned = <String>{};
    // women_0803 is day 14; minGapDays 5 from day 5 is fine.
    regularMorning(cat, e, tuan, p, day: 14, great: 9, owned: owned);
    expect(p.holidayDueDay, 14);
    expect(
      storyDue(cat, e, tuan, p, day: 16, great: 9, owned: owned),
      VisitKind.special,
    );
    regularMorning(
      cat,
      e,
      tuan,
      p,
      day: 15 + cat.holidayRetryWindowDays,
      great: 9,
      owned: owned,
    );
    expect(p.stepsDone[2], RegularProgress.skipped);
    expect(nextVisit(tuan, p)!.step, 3);
  });
}
