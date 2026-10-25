import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../logic/platform_flags.dart';
import '../logic/rewarded_ad.dart';
import 'ios_ad_clock.dart';
import 'rewarded_ad_client.dart';

/// Ad unit ids from the AdMob console. The app ids live in the native
/// manifests (`AndroidManifest.xml`, `Info.plist`).
const androidRewardedXu = 'ca-app-pub-8348518164038508/8552842586';
const androidRewardedPhaLe = 'ca-app-pub-8348518164038508/6731574582';
const iosRewardedXu = 'ca-app-pub-8348518164038508/1767022514';
const iosRewardedPhaLe = 'ca-app-pub-8348518164038508/9071717332';

String rewardedAdUnit(RewardedAdKind kind) {
  final ios = isIosApp;
  return switch (kind) {
    RewardedAdKind.xu => ios ? iosRewardedXu : androidRewardedXu,
    RewardedAdKind.phaLe => ios ? iosRewardedPhaLe : androidRewardedPhaLe,
  };
}

class _MobileRewardedAds implements RewardedAds {
  final _ready = <RewardedAdKind, RewardedAd>{};
  final _loading = <RewardedAdKind>{};
  var _started = false;

  @override
  Future<void> start() async {
    if (_started || kIsWeb || !rewardedAdsOffered) return;
    // iOS: no SDK init and no ad request during the first seven days.
    if (isIosApp && await iosAdRequestsBlocked(DateTime.now())) return;
    _started = true;
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      _started = false;
      return;
    }
    for (final kind in RewardedAdKind.values) {
      _load(kind);
    }
  }

  void _load(RewardedAdKind kind) {
    if (_loading.contains(kind) || _ready.containsKey(kind)) return;
    _loading.add(kind);
    RewardedAd.load(
      adUnitId: rewardedAdUnit(kind),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading.remove(kind);
          _ready[kind]?.dispose();
          _ready[kind] = ad;
        },
        onAdFailedToLoad: (_) {
          _loading.remove(kind);
        },
      ),
    );
  }

  @override
  Future<RewardedAdResult> show(RewardedAdKind kind) async {
    if (!_started) await start();
    if (!_started) return RewardedAdResult.unavailable;
    final ad = _ready.remove(kind);
    if (ad == null) {
      _load(kind);
      return RewardedAdResult.unavailable;
    }
    final done = Completer<RewardedAdResult>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _load(kind);
        if (!done.isCompleted) {
          done.complete(
            earned ? RewardedAdResult.earned : RewardedAdResult.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _load(kind);
        if (!done.isCompleted) done.complete(RewardedAdResult.unavailable);
      },
    );
    ad.show(
      onUserEarnedReward: (_, _) {
        earned = true;
      },
    );
    return done.future;
  }
}

final RewardedAds rewardedAds = _MobileRewardedAds();
