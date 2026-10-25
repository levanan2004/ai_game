import 'package:ai_game/ads/ad_launch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final opened = DateTime(2026, 10, 24, 8);

  test('fresh iOS install asks for tracking and does not start ads', () async {
    final log = <String>[];
    await prepareMobileAds(
      ios: true,
      firstOpen: opened,
      now: opened.add(const Duration(seconds: 1)),
      waitUntilActive: () async => log.add('active'),
      requestTracking: () async => log.add('att'),
      startSdk: () async => log.add('sdk'),
      promptDelay: Duration.zero,
    );
    expect(log, ['active', 'att']);
    expect(iosAdsQuiet(opened, opened.add(const Duration(days: 6))), isTrue);
  });

  test(
    'iOS starts ads only after tracking, once seven days have passed',
    () async {
      final log = <String>[];
      await prepareMobileAds(
        ios: true,
        firstOpen: opened,
        now: opened.add(iosAdQuietPeriod),
        waitUntilActive: () async => log.add('active'),
        requestTracking: () async => log.add('att'),
        startSdk: () async => log.add('sdk'),
        promptDelay: Duration.zero,
      );
      expect(log, ['active', 'att', 'sdk']);
      expect(iosAdsQuiet(opened, opened.add(iosAdQuietPeriod)), isFalse);
    },
  );

  test('Android starts the ads SDK without a tracking prompt', () async {
    final log = <String>[];
    await prepareMobileAds(
      ios: false,
      firstOpen: opened,
      now: opened,
      waitUntilActive: () async => log.add('active'),
      requestTracking: () async => log.add('att'),
      startSdk: () async => log.add('sdk'),
      promptDelay: Duration.zero,
    );
    expect(log, ['active', 'sdk']);
  });
}
