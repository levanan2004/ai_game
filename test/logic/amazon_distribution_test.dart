import 'package:ai_game/logic/platform_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The top-up shop is closed in the build (platform_flags.dart); these tests
  // cover the code kept behind the flag.
  setUp(() => phaLeTopUpOverride = true);
  tearDown(() => phaLeTopUpOverride = null);
  tearDown(() => distributionOverride = null);

  test('open distribution keeps cloud and Pha lê shop', () {
    distributionOverride = 'open';
    expect(isAmazonDistribution, isFalse);
    expect(cloudAccountOffered, isTrue);
    expect(phaLeTopUpOffered, isTrue);
  });

  test('amazon distribution disables cloud account features', () {
    distributionOverride = 'amazon';
    expect(isAmazonDistribution, isTrue);
    expect(cloudAccountOffered, isFalse);
    expect(phaLeTopUpOffered, isFalse);
  });
}
