import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  random: Random(3),
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
        // Rank 12: 10 Pha lê and one hiếm item, no Giọt hoa.
        final kinds = [for (final i in mail.rewards.items) i.kind];
        expect(kinds, [RewardKind.phaLe, RewardKind.petItem]);
        expect(mail.rewards.items.first.amount, 10);
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
        final bundle = charmRewardBundle(line, _economy, Random(1));
        expect(bundle.items.map((i) => i.kind), [
          RewardKind.phaLe,
          RewardKind.giotHoa,
          RewardKind.petItem,
        ]);
        expect(bundle.items[0].amount, 100);
        expect(bundle.items[1].amount, 20);
        final pool = (fixture['pools'] as Map)['huyenThoai'] as List;
        expect(pool, contains(bundle.items[2].id));
      },
    );

    test('the mail text names the rank the way the server writes it', () {
      final mail = charmRewardMail(
        period: _period,
        rank: 7,
        uid: 'u',
        rewards: RewardBundle([const RewardItem.phaLe(1)]),
      );
      expect(mail.title, 'Thưởng xếp hạng Mị lực');
      expect(
        mail.body,
        'Bạn đứng hạng 7 ở bảng xếp hạng Mị lực mùa season-1. '
        'Quà thưởng đã được duyệt, nhận ngay nhé!',
      );
      expect(charmMailRank(mail), 7);
    });
  });
}
