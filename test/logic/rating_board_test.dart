import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/rating_board.dart';
import 'package:ai_game/logic/rating_board_controller.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

RatingEntry entry(String uid, int v, double r, {DateTime? at}) {
  final score = (v * r + 100 * 4.0) / (v + 100);
  return RatingEntry(
    uid: uid,
    displayName: 'Tiệm $uid',
    v: v,
    sum: (v * r).round(),
    score: score,
    sortKey: v < 50 ? 0 : (score * 1000).round() * 10000 + v,
    reachedAt: at,
  );
}

class _Rig {
  _Rig({bool signedIn = true, DateTime? at}) {
    now = at ?? DateTime.utc(2026, 11, 12, 5);
    s = newSession(ratingBoard: board, now: () => now);
    if (signedIn) s.accountUid = 'me';
  }

  late DateTime now;
  final board = MemoryRatingBoard();
  late final ShopSession s;
  RatingBoardController get r => s.ratingBoard;
  String get period => s.ratingBoard.period;
}

void main() {
  group('economy.json ratingBoard (Hà Phương v2)', () {
    test(
      'rating-1 opens 24/10/2026 VN on the Mị lực clock, then season 2 from 09/11, m 100, C 4,0, 50 to rank, top 100',
      () {
        final c = loadTestData().economy.ratingBoard;
        expect(c.enabled, isTrue);
        expect(c.periodKey, 'rating-1');
        expect(c.seasonNumber, 1);
        expect(c.seasonStart, DateTime.utc(2026, 10, 11, 17));
        expect(c.opensAt, DateTime.utc(2026, 10, 23, 17));
        final s1 = c.seasonAt(DateTime.utc(2026, 10, 24, 15))!;
        expect(s1.period, 'rating-1');
        expect(c.startOf(s1), DateTime.utc(2026, 10, 23, 17));
        expect(s1.end, DateTime.utc(2026, 11, 8, 17)); // 23:59 08/11 VN
        final s2 = c.seasonAt(DateTime.utc(2026, 11, 10))!;
        expect(s2.period, 'rating-2');
        expect(s2.end, DateTime.utc(2026, 12, 6, 17));
        expect(c.minGameDaySeconds, 200);
        expect(c.m, 100);
        expect(c.cFallback, 4.0);
        expect(c.minToRank, 50);
        expect(c.limit, 100);
        expect(c.rewards.map((r) => '${r.rankFrom}-${r.rankTo}'), [
          '1-1',
          '2-2',
          '3-3',
          '4-10',
          '11-50',
          '51-100',
        ]);
        final first = c.rewards.first;
        expect([first.phaLe, first.giotHoa, first.coins], [200, 20, 10000000]);
        expect(
          [
            for (final r in c.rewards) [r.phaLe, r.giotHoa, r.coins],
          ],
          [
            [200, 20, 10000000],
            [140, 15, 7000000],
            [100, 10, 5000000],
            [60, 5, 3000000],
            [20, 0, 1000000],
            [0, 0, 500000],
          ],
        );
        expect(first.badge, 'Đệ Nhất Gói Hoa');
        expect(c.rewards.last.coins, 500000);
      },
    );

    test('shared clock: rating-3 from Mon 07/12 0h VN, rating-4 after', () {
      final c = loadTestData().economy.ratingBoard;
      final charm = loadTestData().economy.charmBoard;
      expect(c.periodAt(DateTime.utc(2026, 11, 8, 16, 59)), 'rating-1');
      expect(c.periodAt(DateTime.utc(2026, 11, 8, 17)), 'rating-2');
      expect(c.periodAt(DateTime.utc(2026, 12, 6, 17)), 'rating-3');
      expect(c.periodAt(DateTime.utc(2027, 1, 3, 17)), 'rating-4');
      // Both boards share every season start and end.
      expect(charm.seasonAt(c.seasonStart!)!.number, 1);
      expect(charm.seasonAt(c.seasonStart!)!.start, c.seasonStart);
      final s2 = DateTime.utc(2026, 11, 8, 17);
      expect(charm.seasonAt(s2)!.start, c.seasonAt(s2)!.start);
      expect(c.clock!.previous(DateTime.utc(2026, 12, 7))!.period, 'rating-2');
      expect(c.clock!.previous(DateTime.utc(2026, 11, 10))!.period, 'rating-1');
      expect(c.clock!.previous(DateTime.utc(2026, 10, 25)), isNull);
    });

    test('a missing or broken block turns the tab off', () {
      expect(RatingBoardConfig.fromJson(null).enabled, isFalse);
      expect(
        RatingBoardConfig.fromJson({
          'periodKey': 'Bad Key',
          'seasonStart': '2026-11-09',
        }).enabled,
        isFalse,
      );
      expect(
        RatingBoardConfig.fromJson({'periodKey': 'rating-2'}).enabled,
        isFalse,
      );
    });

    test('the app and the server read the same machine keys', () {
      final j =
          jsonDecode(File('assets/data/economy.json').readAsStringSync())
              as Map<String, dynamic>;
      final rb = j['ratingBoard'] as Map<String, dynamic>;
      for (final k in [
        'periodKey',
        'seasonStart',
        'cycleDays',
        'm',
        'C',
        'dailyCountedCap',
        'minRatingsToRank',
        'topLimit',
        'minGameDaySeconds',
        'maxReviewsPerGameDay',
        'seasonCountedCap',
        'rewards',
      ]) {
        expect(rb.containsKey(k), isTrue, reason: k);
      }
    });
  });

  group('ranking', () {
    test('sortKey first, then who reached it first; under 50 dropped', () {
      final t = DateTime.utc(2026, 11, 10);
      final rows = rankRatingBoard([
        entry('a', 60, 5.0, at: t.add(const Duration(hours: 2))),
        entry('b', 500, 4.9),
        entry('c', 3, 5.0),
        entry('d', 60, 5.0, at: t),
      ]);
      expect(rows.map((r) => r.entry.uid), ['b', 'd', 'a']);
      expect(rows.map((r) => r.rank), [1, 2, 3]);
    });

    test('score text: two decimals, Vietnamese comma', () {
      expect(ratingScoreText(4.375), '4,38');
      expect(ratingScoreText(4.0), '4,00');
    });
  });

  group('controller', () {
    test(
      'the closing lock (lockMinutesAfterClose 60): rating-2 frozen, then rating-3',
      () async {
        final end2 = DateTime.utc(2026, 12, 6, 17); // Mon 07/12 00:00 VN
        final g = _Rig(at: end2.add(const Duration(minutes: 59)));
        expect(g.s.e.ratingBoard.lockMinutes, 60);
        expect(g.r.phase, RatingPhase.ended);
        expect(g.r.period, 'rating-2');
        expect(g.r.seasonLeft, Duration.zero);
        g.now = end2.add(const Duration(minutes: 60));
        expect(g.r.phase, RatingPhase.running);
        expect(g.r.period, 'rating-3');
      },
    );

    test('before 24/10 the board is not open and nothing is read', () async {
      final g = _Rig(at: DateTime.utc(2026, 10, 20));
      expect(g.r.phase, RatingPhase.notStarted);
      await g.r.showTab();
      expect(g.board.reads, 0);
    });

    test('guest: no read, guest state', () async {
      final g = _Rig(signedIn: false);
      await g.r.showTab();
      expect(g.r.me, RatingMe.guest);
      expect(g.board.reads, 0);
    });

    test('ranked, under the minimum (k), 100+', () async {
      final g = _Rig();
      for (var i = 0; i < 5; i++) {
        g.board.put(g.period, entry('p$i', 100 + i, 4.8));
      }
      g.board.put(g.period, entry('me', 20, 5.0));
      await g.r.showTab();
      expect(g.r.load, RatingLoad.ready);
      expect(g.r.rows, hasLength(5));
      expect(g.r.me, RatingMe.underMin);
      expect(g.r.reviewsToRank, 30);

      final h = _Rig();
      h.board.put(h.period, entry('x', 80, 4.9));
      h.board.put(h.period, entry('me', 200, 4.7));
      await h.r.showTab();
      expect(h.r.me, RatingMe.ranked);
      expect(h.r.myRank, 1);

      final o = _Rig();
      for (var i = 0; i < 100; i++) {
        o.board.put(o.period, entry('p$i', 300, 4.9));
      }
      o.board.put(o.period, entry('me', 60, 4.0));
      await o.r.showTab();
      expect(o.r.rows, hasLength(100));
      expect(o.r.me, RatingMe.outside);
      expect(o.r.mine?.v, 60, reason: 'own row read on its own');
    });

    test('no row at all: needs the full {rating_min}', () async {
      final g = _Rig();
      await g.r.showTab();
      expect(g.r.me, RatingMe.underMin);
      expect(g.r.reviewsToRank, 50);
      expect(g.r.rows, isEmpty);
    });

    test('cached for 15 minutes; pull-to-refresh waits 30 s', () async {
      final g = _Rig();
      await g.r.showTab();
      await g.r.refresh();
      expect(g.board.reads, 1);
      await g.r.refresh(force: true);
      expect(g.board.reads, 1);
      g.now = g.now.add(const Duration(seconds: 31));
      await g.r.refresh(force: true);
      expect(g.board.reads, 2);
      g.now = g.now.add(const Duration(minutes: 16));
      await g.r.refresh();
      expect(g.board.reads, 3);
    });

    test(
      'a failed first read is an error; another account starts clean',
      () async {
        final g = _Rig();
        g.board.fail = true;
        await g.r.showTab();
        expect(g.r.load, RatingLoad.error);
        g.board.fail = false;
        g.board.put(g.period, entry('me', 70, 4.5));
        await g.r.refresh(force: true);
        expect(g.r.me, RatingMe.ranked);
        g.s.accountUid = 'other';
        await g.r.refresh();
        expect(g.r.mine, isNull);
        expect(g.r.me, RatingMe.underMin);
      },
    );

    test(
      'the season clock rolls over on its own: rating-3 from 07/12',
      () async {
        final g = _Rig(at: DateTime.utc(2026, 11, 20, 5));
        expect(g.r.phase, RatingPhase.running);
        expect(g.r.seasonLeft, const Duration(days: 16, hours: 12));
        g.board.put('rating-2', entry('me', 70, 4.5));
        await g.r.showTab();
        expect(g.r.me, RatingMe.ranked);
        // Mon 07/12 00:00 VN: rating-2 is frozen for the closing lock
        // (lockMinutesAfterClose 60), then rating-3 shows.
        g.now = DateTime.utc(2026, 12, 6, 17);
        expect(g.r.phase, RatingPhase.ended);
        expect(g.r.period, 'rating-2');
        g.now = DateTime.utc(2026, 12, 6, 18);
        expect(g.r.phase, RatingPhase.running);
        expect(g.r.period, 'rating-3');
        expect(g.r.season!.number, 3);
        expect(g.r.seasonLeft, const Duration(days: 27, hours: 23));
        await g.r.refresh();
        expect(g.r.mine, isNull, reason: 'a new season starts from zero');
        expect(g.r.me, RatingMe.underMin);
      },
    );

    test('champion: the paid #1 of the season before', () async {
      final g = _Rig(at: DateTime.utc(2026, 12, 10, 5));
      g.board.champions['rating-2'] = 'champ';
      await g.r.showTab();
      expect(g.r.championUid, 'champ');
      expect(g.r.isChampion('champ'), isTrue);
      expect(g.r.isChampion('me'), isFalse);
      final first = _Rig(at: DateTime.utc(2026, 10, 25));
      first.board.champions['rating-1'] = 'x';
      await first.r.showTab();
      expect(first.r.championUid, isNull, reason: 'no season before rating-1');
    });

    test('a game day under minGameDaySeconds is flagged for the summary', () {
      final g = _Rig();
      g.r.dayOpened();
      g.now = g.now.add(const Duration(seconds: 199));
      g.r.dayClosed();
      expect(g.r.shortDay, isTrue);
      g.r.dayOpened();
      g.now = g.now.add(const Duration(seconds: 200));
      g.r.dayClosed();
      expect(g.r.shortDay, isFalse);
      // Not while the board has not started, nor for a guest.
      final early = _Rig(at: DateTime.utc(2026, 10, 20));
      early.r.dayOpened();
      early.r.dayClosed();
      expect(early.r.shortDay, isFalse);
      final guest = _Rig(signedIn: false);
      guest.r.dayOpened();
      guest.r.dayClosed();
      expect(guest.r.shortDay, isFalse);
    });

    test('the profile card reads a row it did not list', () async {
      final g = _Rig();
      g.board.put(g.period, entry('far', 10, 5.0));
      expect((await g.r.entryOf('far'))?.v, 10);
      expect(await g.r.entryOf('nobody'), isNull);
    });

    test(
      'openRatingBoard opens the screen on the Đánh giá tab without a pet',
      () {
        final g = _Rig();
        expect(g.s.petsUnlocked, isFalse);
        g.s.openRatingBoard();
        expect(g.s.charmBoardOpen, isTrue);
        expect(g.r.tab, isTrue);
        g.s.selectBoardTab(ratingTab: false);
        expect(g.r.tab, isFalse);
        g.s.closeCharmBoard();
        expect(g.s.charmBoardOpen, isFalse);
      },
    );
  });
}
