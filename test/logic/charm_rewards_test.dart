import 'dart:math';

import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/data/pet_items.dart';
import 'package:ai_game/logic/charm_board_controller.dart';
import 'package:ai_game/logic/charm_rewards.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _economy = loadTestData().economy;
const _period = 'season-1';
final _during = DateTime.utc(2026, 10, 20, 8);
final _after = DateTime.utc(2026, 11, 10, 8);

GameState _save(String pet, int stage, {Map<String, String> worn = const {}}) {
  final s = newSession().state;
  s.addPet(pet, fedDay: 1);
  s.ownedPet(pet)!.stage = stage;
  s.ownedPet(pet)!.worn.addAll(worn);
  s.petCharm = pet;
  return s;
}

/// A board of [n] players, charm 600 downwards in steps of 5, with a save
/// for each that matches its stored row unless [off] says otherwise.
Future<
  ({
    MemoryCharmBoard board,
    MemoryCharmRewardStore store,
    CharmReviewController review,
  })
>
_review({
  int n = 12,
  Set<int> off = const {},
  Set<int> noSave = const {},
  Random? random,
}) async {
  var clock = _during;
  final board = MemoryCharmBoard(now: () => clock);
  final saves = <String, GameState>{};
  for (var i = 0; i < n; i++) {
    clock = clock.add(const Duration(minutes: 1));
    final uid = 'p$i';
    final save = _save('kim_long', 2, worn: const {'neck': 'no_co_vai'});
    final real = recomputeCharm(save, _economy); // 300 + 5
    if (!noSave.contains(i)) saves[uid] = save;
    await board.publish(
      period: _period,
      entry: CharmBoardEntry.forPlayer(
        uid: uid,
        displayName: 'Tiệm $i',
        charm: off.contains(i) ? real + 50 : real,
        petId: 'kim_long',
        stage: 2,
        worn: const {'neck': 'no_co_vai'},
      ),
    );
  }
  final store = MemoryCharmRewardStore(saves: saves);
  final review = CharmReviewController(
    board: board,
    store: store,
    economy: _economy,
    period: _period,
    random: random ?? Random(7),
  );
  await review.loadBoard();
  return (board: board, store: store, review: review);
}

void main() {
  group('reward data', () {
    test('the mail id is bxh_{period}_{uid}', () {
      expect(charmRewardMailId('season-1', 'abc'), 'bxh_season-1_abc');
    });

    test('Mị lực is recomputed from the save (base x stage + worn items)', () {
      expect(recomputeCharm(_save('kim_long', 2), _economy), 300);
      expect(recomputeCharm(_save('kim_long', 0), _economy), 150);
      expect(
        recomputeCharm(
          _save(
            'kim_long',
            2,
            worn: const {
              'neck': 'day_chuyen_suong_mai',
              'head': 'vuong_mien_som_mai',
              'accessory': 'canh_binh_minh',
            },
          ),
          _economy,
        ),
        600,
      );
      // An item in the wrong slot or an unknown id adds nothing.
      expect(
        recomputeCharm(
          _save('kim_long', 2, worn: const {'neck': 'mu_rom', 'head': 'nope'}),
          _economy,
        ),
        300,
      );
      final none = newSession().state..petCharm = null;
      expect(recomputeCharm(none, _economy), 0);
    });

    test(
      'each reward line pays its Pha lê, Giọt hoa and one item of its tier',
      () {
        final rng = Random(1);
        final first = charmRewardBundle(
          _economy.charmBoard.rewardFor(1)!,
          _economy,
          rng,
        );
        expect(first.amountOf(RewardKind.phaLe), 100);
        expect(first.amountOf(RewardKind.giotHoa), 20);
        expect(first.amountOf(RewardKind.petItem), 1);
        final item = first.items.firstWhere(
          (i) => i.kind == RewardKind.petItem,
        );
        expect(_economy.petItem(item.id!)!.tier, PetItemTier.huyenThoai);

        final last = charmRewardBundle(
          _economy.charmBoard.rewardFor(100)!,
          _economy,
          rng,
        );
        expect(last.amountOf(RewardKind.phaLe), 0);
        expect(last.amountOf(RewardKind.giotHoa), 0);
        final low = last.items.single;
        expect(_economy.petItem(low.id!)!.tier, PetItemTier.thuong);
      },
    );

    test(
      'the item is random inside the tier and may repeat between players',
      () {
        final rng = Random(3);
        final ids = <String>[];
        for (var i = 0; i < 60; i++) {
          final b = charmRewardBundle(
            _economy.charmBoard.rewardFor(5)!,
            _economy,
            rng,
          );
          final id = b.items
              .firstWhere((x) => x.kind == RewardKind.petItem)
              .id!;
          expect(_economy.petItem(id)!.tier, PetItemTier.hiem);
          ids.add(id);
        }
        // 3 rare items, 60 draws: every one comes up and there are repeats.
        expect(ids.toSet().length, 3);
        expect(ids.length, greaterThan(ids.toSet().length));
      },
    );

    test('the mail carries the bundle for that player', () {
      final bundle = RewardBundle([const RewardItem.phaLe(10)]);
      final mail = charmRewardMail(
        period: _period,
        rank: 12,
        uid: 'u1',
        rewards: bundle,
      );
      expect(mail.id, 'bxh_season-1_u1');
      expect(mail.target, 'u1');
      expect(mail.title.length, lessThanOrEqualTo(maxMailTitleChars));
      expect(mail.body, contains('hạng 12'));
      expect(mailToMap(mail)['rewards'], bundle.toJson());
    });
  });

  group('admin review', () {
    test(
      'top 10 first, the rest after; rows carry the recomputed Mị lực',
      () async {
        final r = await _review(n: 14);
        final c = r.review;
        expect(c.load, ReviewLoad.ready);
        expect(c.top.map((x) => x.rank), [for (var i = 1; i <= 10; i++) i]);
        expect(c.rest.map((x) => x.rank), [11, 12, 13, 14]);
        expect(c.rows.first.recomputed, 305);
        expect(c.rows.first.needsLook, isFalse);
        expect(c.rows.first.savedPetId, 'kim_long');
        expect(c.rows.first.savedStage, 2);
        expect(c.rows.first.savedWorn, {'neck': 'no_co_vai'});
      },
    );

    test(
      'a stored charm that the save does not back, or no save, needs a look',
      () async {
        final r = await _review(n: 6, off: {1}, noSave: {2});
        final byUid = {for (final x in r.review.rows) x.entry.uid: x};
        expect(byUid['p0']!.needsLook, isFalse);
        // p1: stored 355, save says 305 (the player's save was edited down).
        expect(byUid['p1']!.recomputed, 305);
        expect(byUid['p1']!.needsLook, isTrue);
        // p2: the save could not be read at all.
        expect(byUid['p2']!.recomputed, isNull);
        expect(byUid['p2']!.needsLook, isTrue);
      },
    );

    test(
      'rows under the minimum or with no save are flagged and ticked',
      () async {
        final r = await _review(n: 6, noSave: {2});
        final c = r.review;
        expect(
          c.underMin(c.rows.firstWhere((x) => x.entry.uid == 'p2')),
          isTrue,
        );
        expect(
          c.underMin(c.rows.firstWhere((x) => x.entry.uid == 'p0')),
          isFalse,
        );
        expect(c.flagged.map((x) => x.entry.uid), ['p2']);
        expect(c.skipped, {'p2'});
        expect(c.flaggedSkipped, 1);
        expect(c.payable.map((x) => x.entry.uid), isNot(contains('p2')));
        expect(c.payable.length, 5);
        // The admin can untick it, and a reload of the same board keeps that.
        c.toggleSkip('p2');
        expect(c.payable.length, 6);
        await c.loadBoard();
        expect(c.skipped, isEmpty);
        // Another period starts from the flagged rows again.
        c.period = 'season-2';
        await c.loadBoard();
        expect(c.skipped, isEmpty); // nobody on that board
      },
    );

    test('a save whose pet is gone recomputes to 0 and is flagged', () async {
      final r = await _review(n: 3);
      final empty = _save('kim_long', 2)..petCharm = null;
      final custom = MemoryCharmRewardStore(
        saves: {
          for (final x in r.review.rows)
            x.entry.uid: x.entry.uid == 'p1' ? empty : x.save!,
        },
      );
      final c = CharmReviewController(
        board: r.board,
        store: custom,
        economy: _economy,
        period: _period,
      );
      await c.loadBoard();
      expect(c.rows.firstWhere((x) => x.entry.uid == 'p1').recomputed, 0);
      expect(c.skipped, {'p1'});
    });

    test('a read that fails shows the error state', () async {
      final r = await _review(n: 3);
      r.review.period = 'Bad Key';
      await r.review.loadBoard();
      expect(r.review.load, ReviewLoad.error);
    });

    test('Duyệt thưởng writes one mail per ranked player, once', () async {
      final r = await _review(n: 12);
      final c = r.review;
      expect(c.payable.length, 12);
      final first = await c.approve();
      expect(first.created, 12);
      expect(first.already, 0);
      expect(first.failed, 0);
      expect(r.store.mails.keys.toSet(), {
        for (var i = 0; i < 12; i++) 'bxh_season-1_p$i',
      });
      // Rank 1 gets the top line, rank 4 the 4-10 line.
      final top = r.store.mails['bxh_season-1_p0']!;
      expect(top.rewards.amountOf(RewardKind.phaLe), 100);
      expect(top.rewards.amountOf(RewardKind.giotHoa), 20);
      expect(top.target, 'p0');
      final fourth = r.store.mails['bxh_season-1_p3']!;
      expect(fourth.rewards.amountOf(RewardKind.phaLe), 30);

      // A second press adds nothing and changes nothing.
      expect(c.payable, isEmpty);
      final before = {
        for (final e in r.store.mails.entries) e.key: e.value.rewards.toJson(),
      };
      final second = await c.approve();
      expect(second.created, 0);
      expect(r.store.mails.length, 12);
      expect({
        for (final e in r.store.mails.entries) e.key: e.value.rewards.toJson(),
      }, before);
    });

    test(
      'reloading after an approval shows who is already paid and pays no one twice',
      () async {
        final r = await _review(n: 5);
        await r.review.approve();
        final again = CharmReviewController(
          board: r.board,
          store: r.store,
          economy: _economy,
          period: _period,
          random: Random(99),
        );
        await again.loadBoard();
        expect(again.alreadyPaid, 5);
        expect(again.payable, isEmpty);
        final res = await again.approve();
        expect(res.created, 0);
        expect(r.store.mails.length, 5);
      },
    );

    test(
      'two admins pressing at once: the second write is "already", not a second grant',
      () async {
        final r = await _review(n: 4);
        final other = CharmReviewController(
          board: r.board,
          store: r.store,
          economy: _economy,
          period: _period,
          random: Random(5),
        );
        await other.loadBoard();
        final a = await r.review.approve();
        final b = await other.approve(); // loaded before a finished
        expect(a.created, 4);
        expect(b.created, 0);
        expect(b.already, 4);
        expect(r.store.mails.length, 4);
      },
    );

    test('a skipped player gets nothing, and can be added back', () async {
      final r = await _review(n: 5);
      r.review.toggleSkip('p1');
      expect(r.review.payable.map((x) => x.entry.uid), isNot(contains('p1')));
      await r.review.approve();
      expect(r.store.mails.containsKey('bxh_season-1_p1'), isFalse);
      expect(r.store.mails.length, 4);
      r.review.toggleSkip('p1');
      final res = await r.review.approve();
      expect(res.created, 1);
      expect(r.store.mails.length, 5);
    });

    test('a failed write is counted and only that player is retried', () async {
      final r = await _review(n: 4);
      r.store.failFor.add('p2');
      final first = await r.review.approve();
      expect(first.created, 3);
      expect(first.failed, 1);
      expect(r.review.payable.map((x) => x.entry.uid), ['p2']);
      r.store.failFor.clear();
      final second = await r.review.approve();
      expect(second.created, 1);
      expect(r.store.mails.length, 4);
    });

    test('rank 101 and beyond has no reward line', () async {
      final r = await _review(n: 3);
      expect(r.review.config.rewardFor(101), isNull);
      expect(r.review.config.rewardFor(100), isNotNull);
    });
  });

  group('player claims the approved reward', () {
    test(
      'Đang chốt bảng until the mail arrives, then Nhận thưởng once',
      () async {
        var clock = _during;
        final board = MemoryCharmBoard(now: () => clock);
        final s = newSession(charmBoard: board, now: () => clock);
        s.accountUid = 'me';
        s.state.shopName = 'Tiệm Hoa Sớm Mai';
        s.state.addPet('kim_long', fedDay: 1);
        s.state.ownedPet('kim_long')!.stage = 2;
        s.state.petCharm = 'kim_long';
        final server = _Server();
        final feed = MailboxFeed(service: server, now: () => clock);
        s.board.attachMailbox(feed);
        await feed.bindUser('me');
        await board.publish(
          period: _period,
          entry: CharmBoardEntry.forPlayer(
            uid: 'other',
            displayName: 'x',
            charm: 500,
          ),
        );
        clock = clock.add(const Duration(hours: 1));
        await s.board.open();
        clock = clock.add(const Duration(minutes: 1));
        await s.board.refresh(force: true);
        expect(s.board.myRank, 2);
        expect(s.board.claim, BoardClaim.notEnded);

        // The season is over, the payout has not written the mail yet (or the
        // row is held for the admin: no mail either).
        clock = _after;
        await s.board.open();
        expect(s.board.claim, BoardClaim.pending);
        expect(await s.board.claimReward(), MailClaimResult.refused);

        // The admin approves: the mail is in the mailbox.
        final bundle = RewardBundle([
          const RewardItem.phaLe(70),
          const RewardItem.giotHoa(15),
          const RewardItem.petItem('mao_lua'),
        ]);
        server.mails.add(
          charmRewardMail(period: _period, rank: 2, uid: 'me', rewards: bundle),
        );
        await s.board.open();
        expect(s.board.claim, BoardClaim.ready);

        final phaLe = s.state.phaLe;
        final giot = s.state.drops;
        expect(await s.board.claimReward(), MailClaimResult.claimed);
        expect(s.state.phaLe, phaLe + 70);
        expect(s.state.drops, giot + 15);
        expect(s.state.petItems['mao_lua'], 1);
        expect(s.board.claim, BoardClaim.done);

        // Again, from the board or another tab: nothing more.
        expect(await s.board.claimReward(), MailClaimResult.already);
        expect(s.state.phaLe, phaLe + 70);
        expect(s.state.petItems['mao_lua'], 1);
        expect(server.claimCalls, 1);
      },
    );

    test('another player\'s reward mail is not mine', () async {
      var clock = _after;
      final s = newSession(
        charmBoard: MemoryCharmBoard(now: () => clock),
        now: () => clock,
      );
      s.accountUid = 'me';
      final server = _Server()
        ..mails.add(
          charmRewardMail(
            period: _period,
            rank: 1,
            uid: 'someone-else',
            rewards: RewardBundle([const RewardItem.phaLe(100)]),
          ),
        );
      final feed = MailboxFeed(service: server, now: () => clock);
      s.board.attachMailbox(feed);
      await feed.bindUser('me');
      expect(s.board.rewardMail, isNull);
      expect(s.board.claim, BoardClaim.pending);
    });

    test('a reward mail of an older period is not this season\'s', () async {
      final clock = _after;
      final s = newSession(
        charmBoard: MemoryCharmBoard(now: () => clock),
        now: () => clock,
      );
      s.accountUid = 'me';
      final server = _Server()
        ..mails.add(
          charmRewardMail(
            period: 'season-0',
            rank: 1,
            uid: 'me',
            rewards: RewardBundle([const RewardItem.phaLe(100)]),
          ),
        );
      final feed = MailboxFeed(service: server, now: () => clock);
      s.board.attachMailbox(feed);
      await feed.bindUser('me');
      expect(s.board.claim, BoardClaim.pending);
    });
  });
}

class _Server implements MailService {
  final mails = <GameMail>[];
  final marks = <String, Map<String, MailState>>{};
  var claimCalls = 0;

  @override
  Future<List<GameMail>> inbox(String uid) async => [
    for (final m in mails)
      if (m.target == mailToAll || m.target == uid) m,
  ];

  @override
  Future<Map<String, MailState>> states(String uid) async => {...?marks[uid]};

  @override
  Future<void> markRead(String uid, String mailId) async {}

  @override
  Future<MailClaimResult> claim(String uid, String mailId) async {
    claimCalls++;
    final mine = marks.putIfAbsent(uid, () => {});
    if (mine[mailId]?.claimed == true) return MailClaimResult.already;
    mine[mailId] = const MailState(read: true, claimed: true);
    return MailClaimResult.claimed;
  }
}
