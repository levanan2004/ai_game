import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/data/pet_items.dart';
import 'package:ai_game/logic/charm_payout.dart';
import 'package:ai_game/logic/charm_rewards.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _economy = loadTestData().economy;
const _period = 'season-1';

CharmPayoutController _controller({
  required MemoryCharmPayoutStore payout,
  required MemoryCharmRewardStore rewards,
}) => CharmPayoutController(
  payout: payout,
  rewards: rewards,
  economy: _economy,
  period: _period,
);

MemoryCharmPayoutStore _payout() => MemoryCharmPayoutStore(
  metas: {'season-1': const PayoutMeta(status: 'done', sent: 1, held: 1)},
  lines: {
    'season-1': const [
      PayoutLine(uid: 'skip', status: PayoutStatus.skipped, reason: 'no_pet'),
      PayoutLine(
        uid: 'held',
        status: PayoutStatus.held,
        rank: 12,
        stored: 400,
        recomputed: 300,
        flags: ['mismatch'],
      ),
      PayoutLine(uid: 'top', status: PayoutStatus.sent, rank: 1),
      PayoutLine(
        uid: 'fail',
        status: PayoutStatus.failed,
        rank: 4,
        mailId: 'bxh_season-1_fail',
      ),
    ],
  },
);

void main() {
  group('CharmPayoutController', () {
    test(
      'loads meta, lines (ranked first, dropped last) and the switch',
      () async {
        final c = _controller(
          payout: _payout()..auto = false,
          rewards: MemoryCharmRewardStore(),
        );
        await c.load();
        expect(c.failed, isFalse);
        expect(c.meta.ran, isTrue);
        expect(c.autoPayout, isFalse);
        expect(c.lines.map((l) => l.uid), ['top', 'fail', 'held', 'skip']);
        expect(c.sent.map((l) => l.uid), ['top']);
        expect(c.held.map((l) => l.uid), ['held']);
        expect(c.skipped.map((l) => l.uid), ['skip']);
        expect(c.failedLines.map((l) => l.uid), ['fail']);
      },
    );

    test('a period the payout has not run reads as not ran', () async {
      final c = _controller(
        payout: MemoryCharmPayoutStore(),
        rewards: MemoryCharmRewardStore(),
      );
      await c.load();
      expect(c.meta.ran, isFalse);
      expect(c.lines, isEmpty);
      expect(c.autoPayout, isTrue); // no doc means on
    });

    test(
      'release writes the mail of that rank once and marks the line',
      () async {
        final store = MemoryCharmRewardStore();
        final payout = _payout();
        final c = _controller(payout: payout, rewards: store);
        await c.load();
        expect(await c.release(c.held.single), isTrue);
        final mail = store.mails['bxh_season-1_held']!;
        expect(mail.target, 'held');
        expect(charmMailRank(mail), 12);
        // Rank 12: 20 Pha lê and one hiếm item, no Giọt hoa (an older line
        // without server items: the period + uid pick).
        final kinds = [for (final i in mail.rewards.items) i.kind];
        expect(kinds, [RewardKind.phaLe, RewardKind.petItem]);
        expect(mail.rewards.items.first.amount, 20);
        expect(
          mail.rewards.items.last,
          charmRewardPick(_economy, 'hiem', period: _period, uid: 'held'),
        );
        final item = _economy.petItem(mail.rewards.items.last.id!)!;
        expect(item.tier, PetItemTier.hiem);
        expect(payout.released, [(_period, 'held')]);
        expect(c.held, isEmpty);
        expect(c.sent.map((l) => l.uid), containsAll(['top', 'held']));
        // Releasing again does nothing (the line is no longer held).
        expect(
          await c.release(c.sent.firstWhere((l) => l.uid == 'held')),
          isFalse,
        );
        expect(store.mails.length, 1);
      },
    );

    test(
      'release sends exactly the items the server stored on the line',
      () async {
        final store = MemoryCharmRewardStore();
        final picked = RewardBundle(const [
          RewardItem.phaLe(20),
          RewardItem.coins(20000000),
        ]);
        final payout = MemoryCharmPayoutStore(
          metas: {'season-1': const PayoutMeta(status: 'done', held: 1)},
          lines: {
            'season-1': [
              PayoutLine(
                uid: 'h2',
                status: PayoutStatus.held,
                rank: 20,
                flags: const ['new_account'],
                items: picked,
              ),
            ],
          },
        );
        final c = _controller(payout: payout, rewards: store);
        await c.load();
        expect(await c.release(c.held.single), isTrue);
        expect(store.mails['bxh_season-1_h2']!.rewards, picked);
      },
    );

    test('only a held row can be released', () async {
      final store = MemoryCharmRewardStore();
      final c = _controller(payout: _payout(), rewards: store);
      await c.load();
      for (final uid in ['top', 'skip', 'fail']) {
        expect(
          await c.release(c.lines.firstWhere((l) => l.uid == uid)),
          isFalse,
        );
      }
      expect(store.mails, isEmpty);
    });

    test('a row that already has its mail is not paid twice', () async {
      final store = MemoryCharmRewardStore();
      final c = _controller(payout: _payout(), rewards: store);
      await c.load();
      final line = c.held.single;
      await store.grant(
        charmRewardMail(
          period: _period,
          rank: 12,
          uid: 'held',
          rewards: RewardBundle([const RewardItem.phaLe(10)]),
          line: _economy.charmBoard.rewardFor(12)!,
          economy: _economy,
        ),
      );
      final before = store.mails['bxh_season-1_held']!;
      expect(await c.release(line), isTrue);
      expect(store.mails.length, 1);
      expect(store.mails['bxh_season-1_held'], same(before));
    });

    test('a failed write leaves the line held and not marked', () async {
      final store = MemoryCharmRewardStore()..failFor.add('held');
      final payout = _payout();
      final c = _controller(payout: payout, rewards: store);
      await c.load();
      expect(await c.release(c.held.single), isFalse);
      expect(c.held.map((l) => l.uid), ['held']);
      expect(payout.released, isEmpty);
      expect(c.releasing, isEmpty);
    });

    test('the switch is written and read back', () async {
      final payout = _payout();
      final c = _controller(payout: payout, rewards: MemoryCharmRewardStore());
      await c.load();
      await c.setAutoPayout(false);
      expect(payout.auto, isFalse);
      expect(c.autoPayout, isFalse);
      await c.setAutoPayout(true);
      expect(c.autoPayout, isTrue);
    });

    test('flags read as words for the admin', () {
      expect(payoutFlagText('mismatch'), 'Bảng ghi cao hơn Mị lực tính lại');
      expect(payoutFlagText('over_cap'), 'Mị lực trên 600');
      expect(payoutFlagText('new_account'), 'Tài khoản lập trong mùa');
      expect(payoutFlagText('no_save'), 'Không đọc được save');
      expect(payoutFlagText('no_pet'), 'Ô Mị lực không có thú');
      expect(payoutFlagText('under_min'), 'Dưới mức tối thiểu');
    });
  });

  group('the season phase around the end', () {
    final end = DateTime.utc(2026, 11, 8, 17);
    test('running, grace (5 minutes), ended, unknown', () {
      expect(
        seasonPhaseAt(end, end.subtract(const Duration(seconds: 1))),
        SeasonPhase.running,
      );
      expect(seasonPhaseAt(end, end), SeasonPhase.grace);
      expect(
        seasonPhaseAt(end, end.add(const Duration(minutes: 4, seconds: 59))),
        SeasonPhase.grace,
      );
      expect(
        seasonPhaseAt(end, end.add(const Duration(minutes: 5))),
        SeasonPhase.ended,
      );
      expect(seasonPhaseAt(null, end), SeasonPhase.unknown);
    });
  });

  group('parity with functions/payout.js (shared fixture)', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/charm_rewards_fixture.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    test('the season pick (hash, not owned, price fallback) is the same', () {
      final picks = fixture['picks'] as List;
      expect(picks.length, greaterThanOrEqualTo(5));
      expect(_economy.charmBoard.picksNotOwned, isTrue);
      for (final raw in picks) {
        final c = raw as Map<String, dynamic>;
        final period = c['period'] as String;
        final uid = c['uid'] as String;
        expect(seasonPickHash(period, uid), c['hash'], reason: '$uid hash');
        final pick = charmRewardPick(
          _economy,
          c['tier'] as String,
          period: period,
          uid: uid,
          owned: (c['owned'] as List).cast<String>().toSet(),
        );
        expect(pick, RewardItem.fromJson(c['pick']), reason: uid);
      }
    });

    test('owning every item of the tier pays its shop price', () {
      final suThi = {
        for (final i in _economy.petItems)
          if (i.tier == PetItemTier.suThi) i.id,
      };
      expect(
        charmRewardPick(
          _economy,
          'suThi',
          period: _period,
          uid: 'x',
          owned: suThi,
        ),
        const RewardItem.phaLe(120),
      );
      final thuong = {
        for (final i in _economy.petItems)
          if (i.tier == PetItemTier.thuong) i.id,
      };
      expect(
        charmRewardPick(
          _economy,
          'thuong',
          period: _period,
          uid: 'x',
          owned: thuong,
        ),
        const RewardItem.coins(2000000),
      );
    });

    test('never an owned item while one is left', () {
      final hiem = [
        for (final i in _economy.petItems)
          if (i.tier == PetItemTier.hiem) i.id,
      ];
      for (var u = 0; u < 20; u++) {
        final owned = {hiem[u % 3], hiem[(u + 1) % 3]};
        final p = charmRewardPick(
          _economy,
          'hiem',
          period: _period,
          uid: 'u$u',
          owned: owned,
        )!;
        expect(p.id, hiem[(u + 2) % 3]);
      }
    });

    test('the reward of every rank is the same table', () {
      final ranks = fixture['ranks'] as List;
      expect(ranks.length, 101);
      for (final raw in ranks) {
        final row = raw as Map<String, dynamic>;
        final rank = row['rank'] as int;
        final line = _economy.charmBoard.rewardFor(rank);
        if (row['none'] == true) {
          expect(line, isNull, reason: 'rank $rank');
        } else {
          expect(line, isNotNull, reason: 'rank $rank');
          expect(line!.phaLe, row['phaLe'], reason: 'rank $rank phaLe');
          expect(line.giotHoa, row['giotHoa'], reason: 'rank $rank giotHoa');
          expect(line.itemTier, row['tier'], reason: 'rank $rank tier');
        }
      }
    });

    test('the item pool of every tier is the same list', () {
      final pools = fixture['pools'] as Map<String, dynamic>;
      for (final tier in PetItemTier.values) {
        final ids = [
          for (final item in _economy.petItems)
            if (item.tier == tier) item.id,
        ];
        expect(ids, (pools[tier.key] as List).cast<String>(), reason: tier.key);
      }
    });

    test(
      'the bundle of a rank is Pha lê, Giọt hoa, then an item of the tier',
      () {
        final line = _economy.charmBoard.rewardFor(1)!;
        final bundle = charmRewardBundle(
          line,
          _economy,
          period: _period,
          uid: 'u1',
        );
        expect(bundle.items.map((i) => i.kind), [
          RewardKind.phaLe,
          RewardKind.giotHoa,
          RewardKind.petItem,
        ]);
        expect(bundle.items[0].amount, 200);
        expect(bundle.items[1].amount, 20);
        final pool = (fixture['pools'] as Map)['huyenThoai'] as List;
        expect(pool, contains(bundle.items[2].id));
      },
    );

    test(
      'the mail text: Nhất\'s keys, the item name, the rank parsed back',
      () {
        final line = _economy.charmBoard.rewardFor(7)!;
        final bundle = charmRewardBundle(
          line,
          _economy,
          period: _period,
          uid: 'u',
        );
        final mail = charmRewardMail(
          period: _period,
          rank: 7,
          uid: 'u',
          rewards: bundle,
          line: line,
          economy: _economy,
        );
        final name = _economy.petItem(bundle.items.last.id!)!.nameVi;
        expect(mail.title, 'Thưởng mùa Mị lực: hạng 7');
        expect(
          mail.body,
          'Chúc mừng bạn đạt hạng 7 bảng Mị lực mùa này! Quà của bạn: '
          '${line.phaLe} Pha lê, ${line.giotHoa} giọt hoa và $name.',
        );
        expect(charmMailRank(mail), 7);
      },
    );

    test('a rank without giọt hoa or Pha lê drops that whole phrase', () {
      CharmBoardReward line(int phaLe, int giot, [String tier = 'suThi']) =>
          CharmBoardReward(
            rankFrom: 3,
            rankTo: 3,
            phaLe: phaLe,
            giotHoa: giot,
            itemTier: tier,
          );
      String body(CharmBoardReward l, RewardItem pick) => seasonMailText(
        rank: 3,
        line: l,
        rewards: RewardBundle([
          if (l.phaLe > 0) RewardItem.phaLe(l.phaLe),
          if (l.giotHoa > 0) RewardItem.giotHoa(l.giotHoa),
          pick,
        ]),
        e: _economy,
      ).body;
      final item = _economy.petItems.first;
      final pet = RewardItem.petItem(item.id);
      expect(
        body(line(100, 10), pet),
        'Chúc mừng bạn đạt hạng 3 bảng Mị lực mùa này! Quà của bạn: 100 Pha lê, 10 giọt hoa và ${item.nameVi}.',
      );
      expect(
        body(line(20, 0), pet),
        'Chúc mừng bạn đạt hạng 3 bảng Mị lực mùa này! Quà của bạn: 20 Pha lê và ${item.nameVi}.',
      );
      expect(
        body(line(0, 0), pet),
        'Chúc mừng bạn đạt hạng 3 bảng Mị lực mùa này! Quà của bạn: ${item.nameVi}.',
      );
      expect(
        body(line(100, 10), const RewardItem.coins(1000000)),
        'Chúc mừng bạn đạt hạng 3 bảng Mị lực mùa này! Bạn đã có đủ đồ pet Sử thi, nên nhận '
        '1.000.000 xu thay thế, kèm 100 Pha lê và 10 giọt hoa.',
      );
      expect(
        body(line(20, 0), const RewardItem.phaLe(80)),
        'Chúc mừng bạn đạt hạng 3 bảng Mị lực mùa này! Bạn đã có đủ đồ pet Sử thi, nên nhận '
        '80 Pha lê thay thế, kèm 20 Pha lê.',
      );
      expect(
        body(line(0, 0), const RewardItem.coins(5000)),
        'Chúc mừng bạn đạt hạng 3 bảng Mị lực mùa này! Bạn đã có đủ đồ pet Sử thi, nên nhận '
        '5.000 xu thay thế.',
      );
      expect(
        seasonAdminRewardRow(line(200, 20, 'huyenThoai')),
        '200 Pha lê · 20 giọt hoa · 1 đồ pet Huyền thoại ngẫu nhiên (chưa có)',
      );
      expect(
        seasonAdminRewardRow(line(20, 0, 'hiem')),
        '20 Pha lê · 1 đồ pet Hiếm ngẫu nhiên (chưa có)',
      );
      expect(
        seasonAdminRewardRow(line(0, 0, 'thuong')),
        '1 đồ pet Thường ngẫu nhiên (chưa có)',
      );
    });
  });
  group('Bảng Đánh giá period (functions/rating_payout.js)', () {
    test('the letter is Nhất\'s mục 11, non-zero items only', () {
      final one = ratingMailText(
        rank: 1,
        line: _economy.ratingBoard.rewardFor(1)!,
      );
      expect(one.title, 'Thưởng mùa Đánh giá: hạng 1');
      expect(
        one.body,
        'Chúc mừng bạn đạt hạng 1 bảng Đánh giá mùa này! Quà của bạn: '
        '200 Pha lê, 20 giọt hoa, 10.000.000 xu và danh hiệu "Tiệm 5 sao mùa".',
      );
      final twenty = ratingMailText(
        rank: 20,
        line: _economy.ratingBoard.rewardFor(20)!,
      );
      expect(
        twenty.body,
        'Chúc mừng bạn đạt hạng 20 bảng Đánh giá mùa này! Quà của bạn: '
        '20 Pha lê và 1.000.000 xu.',
      );
      expect(isRatingPeriod('rating-2'), isTrue);
      expect(isRatingPeriod('season-2'), isFalse);
    });

    test(
      'releasing a held #1 sends the rating mail and sets the champion',
      () async {
        final store = MemoryCharmRewardStore();
        final payout = MemoryCharmPayoutStore(
          metas: {'rating-2': const PayoutMeta(status: 'done', held: 2)},
          lines: {
            'rating-2': const [
              PayoutLine(
                uid: 'new1',
                status: PayoutStatus.held,
                rank: 1,
                flags: ['new_account'],
              ),
              PayoutLine(
                uid: 'new7',
                status: PayoutStatus.held,
                rank: 7,
                flags: ['new_account'],
              ),
            ],
          },
        );
        final c = CharmPayoutController(
          payout: payout,
          rewards: store,
          economy: _economy,
          period: 'rating-2',
        );
        await c.load();
        final first = c.held.firstWhere((l) => l.rank == 1);
        expect(await c.release(first), isTrue);
        final mail = store.mails['bxh_rating-2_new1']!;
        expect(mail.title, 'Thưởng mùa Đánh giá: hạng 1');
        expect(mail.rewards.items, const [
          RewardItem.phaLe(200),
          RewardItem.giotHoa(20),
          RewardItem.coins(10000000),
        ]);
        expect(payout.champions, {'rating-2': 'new1'});
        expect(payout.released, [('rating-2', 'new1')]);
        // Rank 7 (hạng 4–10): no title, no champion change.
        expect(await c.release(c.held.single), isTrue);
        expect(store.mails['bxh_rating-2_new7']!.rewards.items, const [
          RewardItem.phaLe(60),
          RewardItem.giotHoa(5),
          RewardItem.coins(3000000),
        ]);
        expect(payout.champions, {'rating-2': 'new1'});
      },
    );
  });
}
