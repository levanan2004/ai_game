import 'package:ai_game/logic/platform_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
