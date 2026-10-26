import 'package:ai_game/ads/ad_launch.dart';
import 'package:ai_game/logic/rewarded_ad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS asks for tracking and then starts ads on the first open', () async {
    final log = <String>[];
    await prepareMobileAds(
      ios: true,
      waitUntilActive: () async => log.add('active'),
      requestTracking: () async => log.add('att'),
      startSdk: () async => log.add('sdk'),
      promptDelay: Duration.zero,
    );
    expect(log, ['active', 'att', 'sdk']);
  });

  test('Android starts the ads SDK without a tracking prompt', () async {
    final log = <String>[];
    await prepareMobileAds(
      ios: false,
      waitUntilActive: () async => log.add('active'),
      requestTracking: () async => log.add('att'),
      startSdk: () async => log.add('sdk'),
      promptDelay: Duration.zero,
    );
    expect(log, ['active', 'sdk']);
  });

  test('a release build uses the real rewarded units', () {
    expect(
      iosRewardedUnit(
        debug: false,
        kind: RewardedAdKind.xu,
        xu: 'xu-unit',
        phaLe: 'pl-unit',
      ),
      'xu-unit',
    );
    expect(
      iosRewardedUnit(
        debug: false,
        kind: RewardedAdKind.phaLe,
        xu: 'xu-unit',
        phaLe: 'pl-unit',
      ),
      'pl-unit',
    );
  });

  test('a debug build uses the sample rewarded unit', () {
    expect(
      iosRewardedUnit(
        debug: true,
        kind: RewardedAdKind.xu,
        xu: 'xu-unit',
        phaLe: 'pl-unit',
      ),
      iosRewardedTestUnit,
    );
  });
}
