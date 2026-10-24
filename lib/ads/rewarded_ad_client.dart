import '../logic/rewarded_ad.dart';

/// Loads and shows AdMob rewarded ads. The web build uses a no-op.
abstract class RewardedAds {
  Future<void> start();
  Future<RewardedAdResult> show(RewardedAdKind kind);
}
