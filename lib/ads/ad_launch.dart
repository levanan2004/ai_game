import '../logic/rewarded_ad.dart';

/// How long the first screen stays up before the tracking dialog.
const iosTrackingPromptDelay = Duration(seconds: 1);

/// Google's sample rewarded ad. Debug builds use it so a dev device can
/// watch an ad; release builds use the real AdMob units.
const iosRewardedTestUnit = 'ca-app-pub-3940256099942544/1712485313';

/// Real iOS units in release. A debug build always gets the sample unit.
String iosRewardedUnit({
  required bool debug,
  required RewardedAdKind kind,
  required String xu,
  required String phaLe,
}) => debug
    ? iosRewardedTestUnit
    : switch (kind) {
        RewardedAdKind.xu => xu,
        RewardedAdKind.phaLe => phaLe,
      };

/// App Review order: the app is active, the first screen has been visible,
/// iOS tracking permission is requested, and only then the ads SDK starts.
/// There is no install-day wait: a rewarded ad can load on the first open.
Future<void> prepareMobileAds({
  required bool ios,
  required Future<void> Function() waitUntilActive,
  required Future<void> Function() requestTracking,
  required Future<void> Function() startSdk,
  Duration promptDelay = iosTrackingPromptDelay,
}) async {
  await waitUntilActive();
  if (ios) {
    if (promptDelay > Duration.zero) {
      await Future<void>.delayed(promptDelay);
    }
    await requestTracking();
  }
  await startSdk();
}
