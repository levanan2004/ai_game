import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../logic/platform_flags.dart';
import '../logic/rewarded_ad.dart';
import 'ad_launch.dart';
import 'rewarded_ad_client.dart';

/// Ad unit ids from the AdMob console. The app ids live in the native
/// manifests (`AndroidManifest.xml`, `Info.plist`).
const androidRewardedXu = 'ca-app-pub-8348518164038508/8552842586';
const androidRewardedPhaLe = 'ca-app-pub-8348518164038508/6731574582';
const iosRewardedXu = 'ca-app-pub-8348518164038508/1767022514';
const iosRewardedPhaLe = 'ca-app-pub-8348518164038508/9071717332';

String rewardedAdUnit(RewardedAdKind kind) {
  if (isIosApp) {
    return iosRewardedUnit(
      debug: kDebugMode,
      kind: kind,
      xu: iosRewardedXu,
      phaLe: iosRewardedPhaLe,
    );
  }
  return switch (kind) {
    RewardedAdKind.xu => androidRewardedXu,
    RewardedAdKind.phaLe => androidRewardedPhaLe,
  };
}

class _MobileRewardedAds implements RewardedAds {
  final _ready = <RewardedAdKind, RewardedAd>{};
  final _loading = <RewardedAdKind>{};
  final _loaded = <RewardedAdKind, Completer<void>>{};
  var _started = false;

  @override
  Future<void> start() async {
    if (_started || kIsWeb || !rewardedAdsOffered) return;
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
    final done = Completer<void>();
    _loaded[kind] = done;
    RewardedAd.load(
      adUnitId: rewardedAdUnit(kind),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading.remove(kind);
          _ready[kind]?.dispose();
          _ready[kind] = ad;
          if (!done.isCompleted) done.complete();
        },
        onAdFailedToLoad: (_) {
          _loading.remove(kind);
          if (!done.isCompleted) done.complete();
        },
      ),
    );
  }

  /// Uses a loaded ad, or waits for the request already in flight.
  Future<RewardedAd?> _take(RewardedAdKind kind) async {
    final cached = _ready.remove(kind);
    if (cached != null) return cached;
    if (!_loading.contains(kind)) _load(kind);
    final done = _loaded[kind];
    if (done != null) {
      await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
    }
    return _ready.remove(kind);
  }

  @override
  Future<RewardedAdResult> show(RewardedAdKind kind) async {
    if (!_started) await start();
    if (!_started) return RewardedAdResult.unavailable;
    final ad = await _take(kind);
    if (ad == null) return RewardedAdResult.unavailable;
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
