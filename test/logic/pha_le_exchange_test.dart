import 'package:ai_game/logic/pha_le_exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('exchangePacksForMissingXu', () {
    test('zero when nothing missing', () {
      expect(exchangePacksForMissingXu(0), 0);
      expect(exchangePacksForMissingXu(-1), 0);
    });

    test('one pack up to 1M', () {
      expect(exchangePacksForMissingXu(1), 1);
      expect(exchangePacksForMissingXu(xuPerPhaLeExchangePack), 1);
    });

    test('rounds up past 1M', () {
      expect(exchangePacksForMissingXu(xuPerPhaLeExchangePack + 1), 2);
      expect(phaLeCostForMissingXu(xuPerPhaLeExchangePack + 1), 200);
    });
  });

  test('100 Pha lê per million xu pack', () {
    expect(phaLePerMillionXu, 100);
    expect(
      phaLeCostForMissingXu(500_000),
      100,
    );
    expect(xuFromExchangePacks(3), 3_000_000);
  });
}
