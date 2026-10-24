import '../logic/rewarded_ad.dart';
import 'rewarded_ad_client.dart';

class _StubRewardedAds implements RewardedAds {
  @override
  Future<void> start() async {}

  @override
  Future<RewardedAdResult> show(RewardedAdKind kind) async =>
      RewardedAdResult.unavailable;
}

final RewardedAds rewardedAds = _StubRewardedAds();
