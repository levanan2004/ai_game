import 'package:ai_game/data/season_clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  // Mị lực season 1: Mon 12/10/2026 0h VN -> Sun 08/11 23:59 VN.
  final s1 = DateTime.utc(2026, 10, 11, 17);
  final clock = SeasonClock(firstPeriod: 'season-1', firstStart: s1);

  test('season 1 ends Sun 08/11 23:59 VN; 28-day seasons chain after it', () {
    expect(clock.at(s1).period, 'season-1');
    final end1 = DateTime.utc(2026, 11, 8, 17); // Mon 09/11 00:00 VN
    expect(clock.at(s1).end, end1);
    expect(
      clock.at(end1.subtract(const Duration(seconds: 1))).period,
      'season-1',
    );
    expect(clock.at(end1).period, 'season-2');
    expect(clock.at(end1).number, 2);
    expect(clock.at(end1).end, DateTime.utc(2026, 12, 6, 17));
    expect(clock.at(DateTime.utc(2027, 1, 3, 17)).period, 'season-4');
    expect(clock.previous(end1)!.period, 'season-1');
    expect(clock.previous(s1), isNull);
    // Before the first season: the first one, not started.
    expect(clock.at(DateTime.utc(2026, 10, 1)).period, 'season-1');
  });

  test('a later first season (rating-2) and keys off the clock', () {
    final r = SeasonClock(
      firstPeriod: 'rating-2',
      firstStart: DateTime.utc(2026, 11, 8, 17),
    );
    expect(r.at(DateTime.utc(2026, 11, 1)).number, 2);
    expect(r.at(DateTime.utc(2026, 12, 6, 17)).period, 'rating-3');
    expect(seasonEndOf(r, 'rating-3'), DateTime.utc(2027, 1, 3, 17));
    expect(seasonEndOf(r, 'rating-1'), isNull);
    expect(seasonEndOf(r, 'season-3'), isNull);
    expect(seasonEndOf(null, 'rating-3'), isNull);
    final fixed = SeasonClock(firstPeriod: 'mua', firstStart: s1);
    expect(fixed.at(DateTime.utc(2027)).period, 'mua');
  });

  test('economy.json: the Mị lực board keys follow the clock', () {
    final c = loadTestData().economy.charmBoard;
    expect(c.periodKey, 'season-1');
    expect(c.periodAt(DateTime.utc(2026, 11, 8, 16, 59)), 'season-1');
    expect(c.periodAt(DateTime.utc(2026, 11, 8, 17)), 'season-2');
    expect(c.endOf('season-1'), DateTime.utc(2026, 11, 8, 17));
    expect(c.endOf('season-2'), DateTime.utc(2026, 12, 6, 17));
  });

  test(
    'closing lock: economy.json ratingBoard.season.lockMinutesAfterClose',
    () {
      final end1 = DateTime.utc(2026, 11, 8, 17);
      const hour = Duration(minutes: 60);
      expect(clock.closing(end1, hour)!.period, 'season-1');
      expect(
        clock.closing(end1.add(const Duration(minutes: 59)), hour)!.period,
        'season-1',
      );
      expect(clock.closing(end1.add(hour), hour), isNull);
      expect(clock.closing(end1, Duration.zero), isNull);
      expect(
        clock.closing(end1.subtract(const Duration(minutes: 1)), hour),
        isNull,
      );
      expect(
        seasonLockMinutes({
          'season': {'lockMinutesAfterClose': 15},
        }),
        15,
      );
      expect(seasonLockMinutes({'season': <String, Object?>{}}), 0);
      expect(seasonLockMinutes(null), 0);
      // Both boards read the same value from economy.json (60).
      final e = loadTestData().economy;
      expect(e.ratingBoard.lockMinutes, 60);
      expect(e.charmBoard.lockMinutes, 60);
      expect(e.charmBoard.lockAfterClose, hour);
    },
  );
}
