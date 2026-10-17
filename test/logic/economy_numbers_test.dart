import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/pha_le_rules.dart';
import 'package:ai_game/data/rarity_rules.dart';
import 'package:ai_game/logic/login_rewards.dart';
import 'package:ai_game/logic/pha_le_exchange.dart';
import 'package:ai_game/logic/rewarded_ad.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Numbers that used to be Dart constants now come from economy.json
/// (Hà Phương's block, 17/10): phaLeFree, phaLeExchange, loginRewards,
/// gacha.ticketRarity.
void main() {
  final raw = File('assets/data/economy.json').readAsStringSync();
  Map<String, dynamic> patched(void Function(Map<String, dynamic> j) edit) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    edit(j);
    return j;
  }

  tearDown(loadTestData); // back to the shipped file

  test(
    'shipped numbers are unchanged: 2 Pha lê per ad, 5 a day, 100 = 1M xu',
    () {
      loadTestData();
      expect(rewardedPhaLeAmount, 2);
      expect(rewardedAdDailyCap, 5);
      expect(phaLePerMillionXu, 100);
      expect(xuPerPhaLeExchangePack, 1000000);
      expect(rewardForAd(RewardedAdKind.phaLe).amountOf(RewardKind.phaLe), 2);
    },
  );

  test('ad and exchange numbers follow economy.json', () {
    loadTestData(
      economy: jsonEncode(
        patched((j) {
          j['phaLeFree'] = {'adReward': 3, 'adMaxPerDay': 2};
          j['phaLeExchange'] = {'phaLe': 50, 'coins': 400000};
        }),
      ),
    );
    expect(rewardedPhaLeAmount, 3);
    expect(rewardedAdDailyCap, 2);
    var l = RewardedAdLedger(day: '2026-10-17');
    l = l.watched(RewardedAdKind.phaLe).watched(RewardedAdKind.phaLe);
    expect(l.canWatch(RewardedAdKind.phaLe), isFalse);
    expect(phaLeCostForMissingXu(400000), 50);
    expect(phaLeCostForMissingXu(400001), 100);
    expect(xuFromExchangePacks(2), 800000);
  });

  test('a missing phaLeFree block is an error, not a silent 0', () {
    expect(
      () => loadTestData(
        economy: jsonEncode(patched((j) => j.remove('phaLeFree'))),
      ),
      throwsFormatException,
    );
    expect(
      () => PhaLeRules.fromJson({'adReward': 2}, {'phaLe': 1, 'coins': 1}),
      throwsFormatException,
    );
  });

  test('loginRewards week 1 matches the repeating week', () {
    loadTestData();
    final week = [
      RewardBundle(const [RewardItem.treat(1)]),
      RewardBundle(const [RewardItem.coins(30000)]),
      RewardBundle(const [RewardItem.phaLe(20)]),
      RewardBundle(const [RewardItem.treat(2)]),
      RewardBundle(const [RewardItem.coins(50000)]),
      RewardBundle(const [RewardItem.giotHoa(3)]),
      RewardBundle(const [RewardItem.phaLe(30), RewardItem.giotHoa(30)]),
    ];
    final old = LoginRewardConfig(
      newbie: week,
      weekly: [
        RewardBundle(const [RewardItem.treat(1)]),
        RewardBundle(const [RewardItem.coins(30000)]),
        RewardBundle(const [RewardItem.phaLe(20)]),
        RewardBundle(const [RewardItem.treat(2)]),
        RewardBundle(const [RewardItem.coins(50000)]),
        RewardBundle(const [RewardItem.giotHoa(3)]),
        RewardBundle(const [RewardItem.phaLe(30), RewardItem.giotHoa(30)]),
      ],
      milestones: [
        LoginMilestone(14, RewardBundle(const [RewardItem.phaLe(40)])),
        LoginMilestone(30, RewardBundle(const [RewardItem.phaLe(80)])),
      ],
    );
    expect(defaultLoginRewards, old);
  });

  test(
    'the fallback login table follows economy.json; a broken one throws',
    () {
      loadTestData(
        economy: jsonEncode(
          patched((j) {
            final newbie = (j['loginRewards']['newbie'] as List).toList();
            newbie[0] = {
              'items': [
                {'kind': 'giotHoa', 'amount': 99},
              ],
            };
            j['loginRewards']['newbie'] = newbie;
          }),
        ),
      );
      expect(
        defaultLoginRewards.day(1),
        RewardBundle(const [RewardItem.giotHoa(99)]),
      );
      expect(
        () => LoginRewardConfig.fromEconomy({'newbie': [], 'weekly': []}),
        throwsFormatException,
      );
    },
  );

  test('Thẻ gacha frame is gacha.ticketRarity (hiem)', () {
    final e = loadTestData().economy;
    expect(e.rewardRarity.of('ticket', 1), RewardRarity.hiem);
    final other = loadTestData(
      economy: jsonEncode(patched((j) => j['gacha']['ticketRarity'] = 'suThi')),
    ).economy;
    expect(other.rewardRarity.of('ticket', 5), RewardRarity.suThi);
    expect(
      () => loadTestData(
        economy: jsonEncode(patched((j) => j['gacha']['ticketRarity'] = 'x')),
      ),
      throwsFormatException,
    );
  });
}
