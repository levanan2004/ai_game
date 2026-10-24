/// When iOS may ask AdMob for an ad. A fresh install stays quiet for this
/// long so the tracking prompt is not tied to an ad request.
const iosAdQuietPeriod = Duration(days: 7);

/// How long the first screen stays up before the tracking dialog.
const iosTrackingPromptDelay = Duration(seconds: 1);

/// True during the first [iosAdQuietPeriod] after [firstOpen].
bool iosAdsQuiet(DateTime firstOpen, DateTime now) =>
    now.difference(firstOpen) < iosAdQuietPeriod;

/// App Review order: the app is active, the first screen has been visible,
/// iOS tracking permission is requested, and only then may the ads SDK start.
/// During the quiet period the permission is still requested and the SDK
/// does not start, so no ad is requested.
Future<void> prepareMobileAds({
  required bool ios,
  required DateTime? firstOpen,
  required DateTime now,
  required Future<void> Function() waitUntilActive,
  required Future<void> Function() requestTracking,
  required Future<void> Function() startSdk,
  Duration promptDelay = iosTrackingPromptDelay,
  Duration quietPeriod = iosAdQuietPeriod,
}) async {
  await waitUntilActive();
  if (ios) {
    if (promptDelay > Duration.zero) {
      await Future<void>.delayed(promptDelay);
    }
    await requestTracking();
    final opened = firstOpen ?? now;
    if (now.difference(opened) < quietPeriod) return;
  }
  await startSdk();
}
