import 'rewarded_ad_client.dart';
import 'rewarded_ads_stub.dart'
    if (dart.library.io) 'rewarded_ads_io.dart'
    as impl;

export 'rewarded_ad_client.dart';

RewardedAds get rewardedAds => impl.rewardedAds;
