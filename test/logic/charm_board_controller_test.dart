import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/charm_board_controller.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Counts reads and writes, and can be told to fail.
class _Spy extends MemoryCharmBoard {
  _Spy({super.now});

  int reads = 0;
  int writes = 0;
  int removes = 0;
  bool failReads = false;

  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) async {
    reads++;
    if (failReads) throw StateError('offline');
    return super.top(period: period, limit: limit);
  }

  @override
  Future<void> publish({
    required String period,
    required CharmBoardEntry entry,
  }) async {
    writes++;
    return super.publish(period: period, entry: entry);
  }

  @override
  Future<void> remove({required String period, required String uid}) async {
    removes++;
    return super.remove(period: period, uid: uid);
  }
}

class _Rig {
  _Rig({bool signedIn = true, String? pet}) {
    spy = _Spy(now: () => now);
    s = newSession(charmBoard: spy, now: () => now);
    if (signedIn) s.accountUid = 'me';
    s.state.shopName = 'Tiệm Hoa Sớm Mai';
    if (pet != null) {
      s.state.addPet(pet, fedDay: 1);
      s.state.petCharm = pet;
    }
  }

  var now = DateTime.utc(2026, 10, 14, 8);
  late final _Spy spy;
  late final ShopSession s;
  CharmBoardController get b => s.board;

  void wait(Duration d) => now = now.add(d);

  /// Another player's row, in the same board.
  Future<void> other(String uid, int charm) async {
    await spy.publish(
      period: s.e.charmBoard.periodKey,
      entry: CharmBoardEntry.forPlayer(
        uid: uid,
        displayName: uid,
        charm: charm,
      ),
    );
    spy.writes--;
  }
}

void main() {
  group('where the player stands', () {
    test('guest, no pet, under the minimum', () async {
      final guest = _Rig(signedIn: false, pet: 'ca_chep');
      expect(guest.b.me, BoardMe.guest);
      await guest.b.refresh();
      await guest.b.publishIfDue();
      expect(guest.spy.reads, 0);
      expect(guest.spy.writes, 0);

      final empty = _Rig();
      expect(empty.s.state.petCharm, isNull);
      expect(empty.b.me, BoardMe.noPet);

      final young = _Rig(pet: 'ca_chep');
      expect(young.s.charmScore, lessThan(20));
      expect(young.b.me, BoardMe.underMin);
    });

    test('ranked, pending, outside the top 100', () async {
      final r = _Rig(pet: 'kim_long');
      final mine = r.s.charmScore;
      expect(mine, greaterThanOrEqualTo(20));
      await r.b.refresh();
      expect(r.b.me, BoardMe.pending, reason: 'room on the board, no row yet');
      await r.b.publishIfDue();
      r.wait(const Duration(minutes: 16));
      await r.b.refresh();
      expect(r.b.me, BoardMe.ranked);
      expect(r.b.myRank, 1);

      // 100 players above me push me out.
      final full = _Rig(pet: 'kim_long');
      for (var i = 0; i < 100; i++) {
        await full.other('p$i', 590 + i % 10);
      }
      await full.b.refresh();
      expect(full.b.rows.length, 100);
      expect(full.b.me, BoardMe.outside);
      expect(full.b.outsideNeed, 590 - full.s.charmScore + 1);
    });
  });

  group('publishing: every 15 minutes, only when it changed', () {
    test('first publish, then quiet until 15 minutes and a change', () async {
      final r = _Rig(pet: 'kim_long');
      await r.b.publishIfDue();
      expect(r.spy.writes, 1);

      // A change inside the 15 minutes waits.
      r.s.state.ownedPet('kim_long')!.stage = 1;
      r.wait(const Duration(minutes: 5));
      await r.b.publishIfDue();
      expect(r.spy.writes, 1);

      // 15 minutes after the first try: the new content goes up.
      r.wait(const Duration(minutes: 10));
      await r.b.publishIfDue();
      expect(r.spy.writes, 2);
      final row = (await r.spy.top(period: r.s.e.charmBoard.periodKey)).single;
      expect(row.entry.petId, 'kim_long');
      expect(row.entry.stage, 1);
      expect(row.entry.displayName, 'Tiệm Hoa Sớm Mai');

      // Nothing changed: no write, however late.
      r.wait(const Duration(hours: 2));
      await r.b.publishIfDue();
      expect(r.spy.writes, 2);
    });

    test('a failed write is tried again in a minute, not in 15', () async {
      final r = _Rig(pet: 'kim_long');
      var fail = true;
      final src = _FlakySpy(() => fail, now: () => r.now);
      final s = newSession(charmBoard: src, now: () => r.now)
        ..accountUid = 'me'
        ..state.addPet('kim_long', fedDay: 1)
        ..state.petCharm = 'kim_long';
      await s.board.publishIfDue();
      expect(src.attempts, 1);
      fail = false;
      r.wait(const Duration(seconds: 30));
      await s.board.publishIfDue();
      expect(src.attempts, 1, reason: 'too soon');
      r.wait(const Duration(minutes: 1));
      await s.board.publishIfDue();
      expect(src.attempts, 2);
      expect(src.writes, 1);
    });

    test(
      'below the minimum nothing is written and an old row is taken off',
      () async {
        final r = _Rig(pet: 'ca_chep');
        await r.other('me', 80);
        await r.b.publishIfDue();
        expect(r.spy.writes, 0);
        expect(r.spy.removes, 1);
        expect(await r.spy.top(period: r.s.e.charmBoard.periodKey), isEmpty);
      },
    );

    test('an ended season is frozen: nothing is published', () async {
      final r = _Rig(pet: 'kim_long');
      r.now = r.s.e.charmBoard.seasonEnd!.add(const Duration(minutes: 1));
      expect(r.b.seasonEnded, isTrue);
      await r.b.publishIfDue();
      expect(r.spy.writes, 0);
      expect(r.b.claim, BoardClaim.pending);
    });
  });

  group('reading: 15-minute cache, pull-to-refresh, the 30-second gap', () {
    test('open reuses a fresh read', () async {
      final r = _Rig(pet: 'kim_long');
      await r.b.open();
      expect(r.spy.reads, 1);
      r.wait(const Duration(minutes: 14));
      await r.b.open();
      expect(r.spy.reads, 1);
      r.wait(const Duration(minutes: 2));
      await r.b.open();
      expect(r.spy.reads, 2);
    });

    test('pull-to-refresh skips the cache but keeps the 30 s gap', () async {
      final r = _Rig(pet: 'kim_long');
      await r.b.refresh();
      expect(r.spy.reads, 1);
      r.wait(const Duration(seconds: 10));
      await r.b.refresh(force: true);
      expect(r.spy.reads, 1, reason: 'inside the gap');
      r.wait(const Duration(seconds: 25));
      await r.b.refresh(force: true);
      expect(r.spy.reads, 2);
    });

    test(
      'an error shows when nothing was read, retry is allowed at once',
      () async {
        final r = _Rig(pet: 'kim_long');
        r.spy.failReads = true;
        await r.b.refresh();
        expect(r.b.load, BoardLoad.error);
        r.spy.failReads = false;
        await r.b.refresh(force: true);
        expect(r.b.load, BoardLoad.ready);
        // Rows already on screen stay when a later read fails.
        await r.other('p', 100);
        r.wait(const Duration(minutes: 20));
        await r.b.refresh();
        expect(r.b.rows, isNotEmpty);
        r.spy.failReads = true;
        r.wait(const Duration(minutes: 20));
        await r.b.refresh();
        expect(r.b.load, BoardLoad.ready);
        expect(r.b.rows, isNotEmpty);
      },
    );
  });

  group('season clock', () {
    test('counts down in days and hours, then in minutes', () {
      final r = _Rig();
      final end = r.s.e.charmBoard.seasonEnd!;
      r.now = end.subtract(const Duration(days: 12, hours: 5, minutes: 7));
      expect(r.b.seasonLeftText, '12 ngày 5 giờ');
      r.now = end.subtract(const Duration(hours: 5, minutes: 20));
      expect(r.b.seasonLeftText, '5 giờ 20 phút');
      r.now = end.subtract(const Duration(minutes: 20));
      expect(r.b.seasonLeftText, '20 phút');
      r.now = end;
      expect(r.b.seasonEnded, isTrue);
      expect(r.b.claim, BoardClaim.pending);
      r.now = end.subtract(const Duration(days: 1));
      expect(r.b.claim, BoardClaim.notEnded);
    });
  });
}

class _FlakySpy extends MemoryCharmBoard {
  _FlakySpy(this._fail, {super.now});

  final bool Function() _fail;
  int attempts = 0;
  int writes = 0;

  @override
  Future<void> publish({
    required String period,
    required CharmBoardEntry entry,
  }) async {
    attempts++;
    if (_fail()) throw StateError('offline');
    writes++;
    return super.publish(period: period, entry: entry);
  }
}
