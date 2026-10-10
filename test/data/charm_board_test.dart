import 'dart:io';

import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/data/pet_items.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

CharmBoardEntry _e(
  String uid,
  int charm, {
  DateTime? at,
  String name = 'Hoa',
}) => CharmBoardEntry(
  uid: uid,
  displayName: name,
  avatar: '',
  charm: charm,
  updatedAt: at,
);

void main() {
  group('config', () {
    test('the period key is one value in economy.json', () {
      final s = newSession();
      expect(s.e.charmBoard.periodKey, 'season-1');
      expect(isValidPeriodKey(s.e.charmBoard.periodKey), isTrue);
      expect(s.e.charmBoard.limit, 100);
    });

    test('a bad key or limit falls back to the defaults', () {
      for (final bad in [
        '',
        'Season 1',
        'SEASON',
        '-x',
        'a' * 25,
        '../x',
        'a/b',
      ]) {
        expect(isValidPeriodKey(bad), isFalse, reason: bad);
        expect(
          CharmBoardConfig.fromJson({'periodKey': bad}).periodKey,
          'season-1',
        );
      }
      for (final ok in ['season-1', 'w2026-41', 'a', 'a' * 24, 's_2']) {
        expect(isValidPeriodKey(ok), isTrue, reason: ok);
      }
      expect(CharmBoardConfig.fromJson(null).periodKey, 'season-1');
      expect(CharmBoardConfig.fromJson({'topLimit': 500}).limit, 100);
      expect(CharmBoardConfig.fromJson({'topLimit': 0}).limit, 100);
      expect(CharmBoardConfig.fromJson({'topLimit': 25}).limit, 25);
      expect(
        CharmBoardConfig.fromJson({'periodKey': 'w2026-42'}).periodKey,
        'w2026-42',
      );
    });
  });

  group('season, minimum and reward table', () {
    test('the shipped config is the approved one', () {
      final c = newSession().e.charmBoard;
      expect(c.minCharm, 20);
      expect(charmBoardMinCharm, 20);
      expect(charmBoardMaxCharm, 600);
      expect(c.cycleDays, 28);
      expect(c.limit, 100);
      // A Monday 00:00 in Vietnam, 4 weeks long, ends Sunday 23:59.
      expect(c.seasonStart, DateTime.utc(2026, 10, 11, 17));
      expect(
        c.seasonStart!.add(const Duration(hours: 7)).weekday,
        DateTime.monday,
      );
      expect(c.seasonEnd, DateTime.utc(2026, 11, 8, 17));
      expect(
        c.seasonEnd!.add(const Duration(hours: 7)).weekday,
        DateTime.monday,
      );
    });

    test('rewards: 6 tiers, every rank 1..100 in exactly one', () {
      final c = newSession().e.charmBoard;
      expect(c.rewards.length, 6);
      for (var r = 1; r <= 100; r++) {
        expect(c.rewards.where((x) => x.covers(r)).length, 1, reason: '$r');
      }
      expect(c.rewardFor(101), isNull);
      expect(c.rewardFor(0), isNull);
      final one = c.rewardFor(1)!;
      expect((one.phaLe, one.giotHoa, one.itemTier), (100, 20, 'huyenThoai'));
      final two = c.rewardFor(2)!;
      expect((two.phaLe, two.giotHoa, two.itemTier), (70, 15, 'suThi'));
      expect(c.rewardFor(3)!.phaLe, 50);
      for (final r in [4, 7, 10]) {
        final x = c.rewardFor(r)!;
        expect((x.phaLe, x.giotHoa, x.itemTier), (30, 5, 'hiem'));
      }
      final mid = c.rewardFor(11)!;
      expect((mid.phaLe, mid.giotHoa, mid.itemTier), (10, 0, 'hiem'));
      expect(c.rewardFor(50)!.phaLe, 10);
      final low = c.rewardFor(51)!;
      expect((low.phaLe, low.giotHoa, low.itemTier), (0, 0, 'thuong'));
      expect(c.rewardFor(100)!.itemTier, 'thuong');
      var total = 0;
      for (var r = 1; r <= 100; r++) {
        total += c.rewardFor(r)!.phaLe;
      }
      expect(total, 830); // Hà Phương: 830 Pha lê per season
    });

    test('the board takes only 20..600; below 20 is not ranked', () async {
      final low = CharmBoardEntry.forPlayer(
        uid: 'u',
        displayName: 'a',
        charm: 19,
      );
      expect(low.ranked, isFalse);
      expect(
        CharmBoardEntry.forPlayer(uid: 'u', displayName: 'a', charm: 20).ranked,
        isTrue,
      );
      final board = MemoryCharmBoard();
      expect(
        () => board.publish(period: 'season-1', entry: low),
        throwsArgumentError,
      );
      expect(
        () => board.publish(
          period: 'season-1',
          entry: CharmBoardEntry(
            uid: 'u',
            displayName: 'a',
            avatar: '',
            charm: 601,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('a bad config falls back', () {
      final c = CharmBoardConfig.fromJson({
        'seasonStart': 'nope',
        'cycleDays': 0,
        'minCharmToRank': 0,
        'rewards': [
          {'rankFrom': 5, 'rankTo': 2},
          'x',
          {'rankFrom': 1, 'rankTo': 3, 'phaLe': 7},
        ],
      });
      expect(c.seasonStart, isNull);
      expect(c.seasonEnd, isNull);
      expect(c.cycleDays, 28);
      expect(c.minCharm, 20);
      expect(c.rewards.length, 1);
      expect(c.rewardFor(2)!.phaLe, 7);
    });
  });

  group('entry', () {
    test('the document has exactly the fields the rules allow', () {
      final e = CharmBoardEntry.forPlayer(
        uid: 'u1',
        displayName: '  Tiệm Hoa Sớm Mai  ',
        avatar: 'avatars/u1.webp',
        charm: 450,
        petId: 'kim_long',
        stage: 2,
        worn: {'neck': 'chuong_ngoc', 'tail': 'x', 'head': ''},
      );
      expect(e.toMap(), {
        'uid': 'u1',
        'displayName': 'Tiệm Hoa Sớm Mai',
        'avatar': 'avatars/u1.webp',
        'charm': 450,
        'petId': 'kim_long',
        'stage': 2,
        // An unknown slot and an empty id are dropped.
        'worn': {'neck': 'chuong_ngoc'},
      });
    });

    test(
      'stage is clamped, a stored row reads back, sameContent ignores times',
      () {
        final e = CharmBoardEntry.forPlayer(
          uid: 'u',
          displayName: 'a',
          charm: 30,
          petId: 'meo',
          stage: 9,
        );
        expect(e.stage, 2);
        final back = CharmBoardEntry.fromMap('u', {
          ...e.toMap(),
          'worn': {'accessory': 'canh_buom', 'wing': 'x'},
        }, reachedAt: DateTime.utc(2026, 10, 12));
        expect(back!.worn, {'accessory': 'canh_buom'});
        expect(back.reachedAt, DateTime.utc(2026, 10, 12));
        expect(
          e.sameContent(e.withTimes(updatedAt: DateTime.utc(2026))),
          isTrue,
        );
        expect(back.sameContent(e), isFalse);
        // An old row without the new fields still reads.
        final old = CharmBoardEntry.fromMap('u', {
          'charm': 40,
          'displayName': 'a',
        });
        expect(old!.petId, '');
        expect(old.stage, 0);
        expect(old.worn, isEmpty);
      },
    );

    test(
      'name is cut to 40 characters, empty falls back, charm is clamped',
      () {
        final long = CharmBoardEntry.forPlayer(
          uid: 'u',
          displayName: 'Ê' * 60,
          charm: 3,
        );
        expect(long.displayName.runes.length, charmBoardNameMax);
        expect(
          CharmBoardEntry.forPlayer(
            uid: 'u',
            displayName: '   ',
            charm: 1,
          ).displayName,
          charmBoardFallbackName,
        );
        expect(
          CharmBoardEntry.forPlayer(
            uid: 'u',
            displayName: 'a',
            charm: -4,
          ).charm,
          0,
        );
        expect(
          CharmBoardEntry.forPlayer(
            uid: 'u',
            displayName: 'a',
            charm: 99999,
          ).charm,
          charmBoardMaxCharm,
        );
        expect(
          CharmBoardEntry.forPlayer(
            uid: 'u',
            displayName: 'a',
            charm: 1,
            avatar: 'x' * 501,
          ).avatar,
          '',
        );
      },
    );

    test('reading a stored row is tolerant', () {
      expect(CharmBoardEntry.fromMap('u', {'charm': 'x'}), isNull);
      expect(CharmBoardEntry.fromMap('u', {'charm': -1}), isNull);
      expect(CharmBoardEntry.fromMap('u', {'charm': 19}), isNull);
      expect(CharmBoardEntry.fromMap('', {'charm': 5}), isNull);
      final e = CharmBoardEntry.fromMap('u', {
        'charm': 42.0,
        'displayName': 7,
      })!;
      expect(e.charm, 42);
      expect(e.displayName, charmBoardFallbackName);
      expect(e.avatar, '');
    });

    test('the most a player can reach fits under the cap', () {
      final s = newSession();
      final top = s.e.pets
          .map((p) => p.charmBase)
          .reduce((a, b) => a > b ? a : b);
      final mult = s.e.charmStageMultiplier.last;
      final slots = s.e.petItemRules.slots.length;
      final best = s.e.petItemRules.charmOfTier(PetItemTier.huyenThoai);
      expect((top * mult).round() + slots * best, 600);
      expect(600, lessThanOrEqualTo(charmBoardMaxCharm));
    });
  });

  group('ranking', () {
    final t0 = DateTime.utc(2026, 10, 1);

    test('highest charm first, numbered 1, 2, 3', () {
      final rows = rankCharmBoard([_e('a', 10), _e('b', 300), _e('c', 45)]);
      expect(
        [for (final r in rows) (r.rank, r.entry.uid)],
        [(1, 'b'), (2, 'c'), (3, 'a')],
      );
    });

    test('equal charm: who got there first, then uid; no time comes last', () {
      final rows = rankCharmBoard([
        _e('z', 100, at: t0),
        _e('a', 100, at: t0.add(const Duration(hours: 1))),
        _e('m', 100),
        _e('b', 100, at: t0),
      ]);
      expect([for (final r in rows) r.entry.uid], ['b', 'z', 'a', 'm']);
      expect([for (final r in rows) r.rank], [1, 2, 3, 4]);
    });

    test('only the top 100 are kept, and the input is not changed', () {
      final all = [for (var i = 0; i < 250; i++) _e('u$i', i)];
      final rows = rankCharmBoard(all);
      expect(rows.length, 100);
      expect(rows.first.entry.charm, 249);
      expect(rows.last.entry.charm, 150);
      expect(rows.last.rank, 100);
      expect(all.first.uid, 'u0');
      expect(rankCharmBoard(all, limit: 3).length, 3);
      expect(rankCharmBoard(all, limit: 9999).length, 100);
      expect(rankCharmBoard(const []), isEmpty);
    });
  });

  group('memory board (same limits as the rules)', () {
    var clock = DateTime.utc(2026, 10, 1, 8);
    late MemoryCharmBoard board;
    setUp(() {
      clock = DateTime.utc(2026, 10, 1, 8);
      board = MemoryCharmBoard(now: () => clock);
    });

    test('publish, read the top, one row per player', () async {
      await board.publish(period: 'season-1', entry: _e('a', 50));
      await board.publish(period: 'season-1', entry: _e('b', 80));
      clock = clock.add(const Duration(minutes: 1));
      await board.publish(period: 'season-1', entry: _e('a', 120));
      final rows = await board.top(period: 'season-1');
      expect(
        [for (final r in rows) (r.rank, r.entry.uid, r.entry.charm)],
        [(1, 'a', 120), (2, 'b', 80)],
      );
      expect(rows.first.entry.updatedAt, clock);
    });

    test('each period is its own board', () async {
      await board.publish(period: 'season-1', entry: _e('a', 50));
      expect(await board.top(period: 'season-2'), isEmpty);
      expect((await board.top(period: 'season-1')).length, 1);
    });

    test(
      'refuses a bad period, a charm over the cap, a write too soon',
      () async {
        expect(
          () => board.publish(period: 'Bad Key', entry: _e('a', 1)),
          throwsArgumentError,
        );
        expect(
          () => board.publish(
            period: 'season-1',
            entry: _e('a', charmBoardMaxCharm + 1),
          ),
          throwsArgumentError,
        );
        await board.publish(period: 'season-1', entry: _e('a', 30));
        clock = clock.add(const Duration(seconds: 10));
        expect(
          () => board.publish(period: 'season-1', entry: _e('a', 31)),
          throwsStateError,
        );
        clock = clock.add(charmBoardMinGap);
        await board.publish(period: 'season-1', entry: _e('a', 31));
        expect(
          () => board.top(period: 'season-1', limit: 101),
          throwsArgumentError,
        );
      },
    );

    test('a player can take their row off', () async {
      await board.publish(period: 'season-1', entry: _e('a', 30));
      await board.remove(period: 'season-1', uid: 'a');
      expect(await board.top(period: 'season-1'), isEmpty);
    });
  });

  group('from the game', () {
    test(
      'the row is the Mị lực-slot pet with its items; null when signed out',
      () {
        final s = newSession();
        s.state.day = strayCatDay;
        s.state.addPet('nghe'); // first pet: both slots
        s.state.ownedPet('nghe')!.stage = 2;
        expect(s.charmBoardEntry(displayName: 'Hoa'), isNull);
        s.accountUid = 'uid-1';
        final e = s.charmBoardEntry(displayName: ' Hoa ', avatar: 'p')!;
        expect(e.uid, 'uid-1');
        expect(e.displayName, 'Hoa');
        expect(e.charm, 60);
        s.state.petCharm = null;
        expect(s.charmBoardEntry(displayName: 'Hoa')!.charm, 0);
      },
    );
  });

  group('tie-break: who reached the charm first', () {
    CharmBoardEntry e(
      String uid,
      int charm,
      DateTime reached,
      DateTime updated,
    ) => CharmBoardEntry(
      uid: uid,
      displayName: uid,
      avatar: '',
      charm: charm,
      updatedAt: updated,
      reachedAt: reached,
    );

    test('reachedAt wins over a later updatedAt, then uid', () {
      final rows = rankCharmBoard([
        // b wrote more recently but reached 100 first.
        e('a', 100, DateTime.utc(2026, 10, 14), DateTime.utc(2026, 10, 14)),
        e('b', 100, DateTime.utc(2026, 10, 13), DateTime.utc(2026, 10, 20)),
        e('c', 100, DateTime.utc(2026, 10, 13), DateTime.utc(2026, 10, 20)),
        e('d', 150, DateTime.utc(2026, 10, 30), DateTime.utc(2026, 10, 30)),
      ]);
      expect([for (final r in rows) r.entry.uid], ['d', 'b', 'c', 'a']);
      expect([for (final r in rows) r.rank], [1, 2, 3, 4]);
    });

    test(
      'the memory board keeps reachedAt while the charm is unchanged',
      () async {
        var now = DateTime.utc(2026, 10, 12, 8);
        final board = MemoryCharmBoard(now: () => now);
        CharmBoardEntry mine(int charm) =>
            CharmBoardEntry.forPlayer(uid: 'u', displayName: 'a', charm: charm);
        await board.publish(period: 'season-1', entry: mine(100));
        final first = (await board.top(period: 'season-1')).single.entry;
        expect(first.reachedAt, now);
        now = now.add(const Duration(minutes: 15));
        await board.publish(period: 'season-1', entry: mine(100));
        var row = (await board.top(period: 'season-1')).single.entry;
        expect(row.updatedAt, now);
        expect(row.reachedAt, first.reachedAt, reason: 'same charm');
        now = now.add(const Duration(minutes: 15));
        await board.publish(period: 'season-1', entry: mine(110));
        row = (await board.top(period: 'season-1')).single.entry;
        expect(row.reachedAt, now, reason: 'new charm, new time');
      },
    );
  });

  group('firestore.rules block', () {
    final rules = File('firestore.rules').readAsStringSync();
    final block = rules.substring(
      rules.indexOf('match /charm_board/{period}/entries/{uid}'),
    );

    test('path, reads and writes', () {
      expect(rules, contains('match /charm_board/{period}/entries/{uid}'));
      expect(block, contains('request.query.limit <= 100'));
      expect(charmBoardTopLimit, 100);
      expect(block, contains('request.auth.uid == uid'));
      expect(
        block,
        contains(
          'allow delete: if request.auth != null && request.auth.uid == uid\n'
          '        && boardOpen(period);',
        ),
      );
      // Every write is refused after the season end (+5 min), by server time.
      expect(
        rules,
        contains(
          'request.time <= get(meta).data.get(' + "'endsAt'" + ', null)',
        ),
      );
      expect(rules, contains("duration.value(5, 'm')"));
      // No public read: every read needs a signed-in player.
      final head = block.substring(0, block.indexOf('function periodKeyOk'));
      expect(head, isNot(contains('if true')));
    });

    test('field list and numbers match the Dart constants', () {
      expect(
        block,
        contains(
          "['uid', 'displayName', 'avatar', 'charm', 'petId', 'stage', 'worn',\n"
          "           'updatedAt', 'reachedAt']",
        ),
      );
      expect(block, contains("hasOnly(['neck', 'head', 'accessory'])"));
      expect(charmBoardSlots, ['neck', 'head', 'accessory']);
      expect(
        block,
        contains('request.resource.data.reachedAt == request.time'),
      );
      expect(block, contains('resource.data.reachedAt : request.time'));
      expect(
        block,
        contains('request.resource.data.charm >= $charmBoardMinCharm'),
      );
      expect(
        block,
        contains('request.resource.data.charm <= $charmBoardMaxCharm'),
      );
      expect(
        block,
        contains('duration.value(${charmBoardMinGap.inSeconds}, \'s\')'),
      );
      expect(block, contains('displayName.size() <= 80'));
      expect(
        block,
        contains('request.resource.data.updatedAt == request.time'),
      );
      final regex = RegExp(r"period\.matches\('([^']+)'\)").firstMatch(block)!;
      expect(RegExp(regex.group(1)!).hasMatch('season-1'), isTrue);
      expect(RegExp(regex.group(1)!).hasMatch('Bad Key'), isFalse);
      for (final k in ['season-1', 'w2026-41', 'a' * 25, '-x', 'a/b', '']) {
        expect(
          RegExp(regex.group(1)!).hasMatch(k),
          isValidPeriodKey(k),
          reason: k,
        );
      }
    });

    test('the document the client writes passes the field list', () {
      final keys = {
        ...CharmBoardEntry.forPlayer(
          uid: 'u',
          displayName: 'a',
          charm: 1,
        ).toMap().keys,
        'updatedAt',
        'reachedAt',
      };
      expect(keys, {
        'uid',
        'displayName',
        'avatar',
        'charm',
        'petId',
        'stage',
        'worn',
        'updatedAt',
        'reachedAt',
      });
    });
  });
}
