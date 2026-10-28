import 'package:ai_game/logic/play_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(PlayAnalytics.rewardedEntrySeenKinds.clear);

  test('the xu or Pha lê entry is counted once per session', () {
    expect(PlayAnalytics.noteRewardedEntrySeen('xu'), isTrue);
    expect(PlayAnalytics.noteRewardedEntrySeen('xu'), isFalse);
    expect(PlayAnalytics.noteRewardedEntrySeen('phaLe'), isTrue);
  });

  test('each placement of the same reward is counted once', () {
    PlayAnalytics.rewardedEntrySeen('xu', place: 'topbar');
    PlayAnalytics.rewardedEntrySeen('xu', place: 'topbar');
    PlayAnalytics.rewardedEntrySeen('xu', place: 'home');
    expect(PlayAnalytics.rewardedEntrySeenKinds, {'topbar:xu', 'home:xu'});
  });
}
