import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';

import '../logic/platform_flags.dart';
import 'ad_launch.dart';
import 'ios_ad_clock.dart';
import 'rewarded_ads.dart';

var _launchStarted = false;

/// After the first screen is up: on iOS, ask for tracking permission, then
/// start the ads SDK once the seven-day quiet period has passed.
Future<void> launchMobileAds() async {
  if (_launchStarted || !rewardedAdsOffered) return;
  _launchStarted = true;
  final now = DateTime.now();
  final firstOpen = isIosApp ? await rememberIosFirstOpen(now) : null;
  await prepareMobileAds(
    ios: isIosApp,
    firstOpen: firstOpen,
    now: DateTime.now(),
    waitUntilActive: waitUntilAppActive,
    requestTracking: requestIosTracking,
    startSdk: rewardedAds.start,
  );
}

/// Resolves once the app is in the foreground. The system dialog does not
/// appear if tracking permission is requested before that.
Future<void> waitUntilAppActive({
  Duration timeout = const Duration(seconds: 5),
}) async {
  final binding = WidgetsBinding.instance;
  if (binding.lifecycleState == AppLifecycleState.resumed) return;
  final done = Completer<void>();
  final listener = AppLifecycleListener(
    onStateChange: (state) {
      if (state == AppLifecycleState.resumed && !done.isCompleted) {
        done.complete();
      }
    },
  );
  try {
    await done.future.timeout(timeout, onTimeout: () {});
  } finally {
    listener.dispose();
  }
}

Future<void> requestIosTracking() async {
  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await AppTrackingTransparency.requestTrackingAuthorization();
  } catch (_) {}
}
