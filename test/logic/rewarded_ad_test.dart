import 'package:ai_game/logic/rewarded_ad.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a new day resets both counters', () {
    final yesterday = RewardedAdLedger(day: '2026-10-10', xu: 5, phaLe: 5);
    final today = RewardedAdLedger.forDay(
      yesterday,
      DateTime(2026, 10, 11, 8),
    );
    expect(today.day, '2026-10-11');
    expect(today.xu, 0);
    expect(today.phaLe, 0);
    expect(today.canWatch(RewardedAdKind.xu), isTrue);
  });

  test('each kind has its own daily cap', () {
    var ledger = RewardedAdLedger(day: '2026-10-11');
    for (var i = 0; i < rewardedAdDailyCap; i++) {
      ledger = ledger.watched(RewardedAdKind.xu);
    }
    expect(ledger.canWatch(RewardedAdKind.xu), isFalse);
    expect(ledger.remaining(RewardedAdKind.xu), 0);
    expect(ledger.canWatch(RewardedAdKind.phaLe), isTrue);
    expect(rewardForAd(RewardedAdKind.xu).amountOf(RewardKind.coins), 200000);
    expect(rewardForAd(RewardedAdKind.phaLe).amountOf(RewardKind.phaLe), 2);
  });
}
