import 'package:ai_game/logic/price_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPriceFull', () {
    test('dots between thousands', () {
      expect(formatPriceFull(0), '0');
      expect(formatPriceFull(950), '950');
      expect(formatPriceFull(1000), '1.000');
      expect(formatPriceFull(80000), '80.000');
      expect(formatPriceFull(350000), '350.000');
      expect(formatPriceFull(1250000), '1.250.000');
      expect(formatPriceFull(30000000), '30.000.000');
    });

    test('negative keeps the sign', () {
      expect(formatPriceFull(-24000), '-24.000');
    });
  });

  group('formatPrice xu', () {
    test('under a million stays whole with dots', () {
      expect(formatPrice(0), '0');
      expect(formatPrice(80000), '80.000');
      expect(formatPrice(500000), '500.000');
      expect(formatPrice(999000), '999.000');
      expect(formatPrice(999999), '999.999');
    });

    test('from a million it is written in tr', () {
      expect(formatPrice(1000000), '1 tr');
      expect(formatPrice(2000000), '2 tr');
      expect(formatPrice(30000000), '30 tr');
      expect(formatPrice(120000000), '120 tr');
    });

    test('one decimal with a comma, ,0 dropped', () {
      expect(formatPrice(2500000), '2,5 tr');
      expect(formatPrice(1200000), '1,2 tr');
      expect(formatPrice(10500000), '10,5 tr');
      expect(formatPrice(1000000 + 40000), '1 tr');
    });

    test('rounds to the nearest tenth, half up', () {
      expect(formatPrice(2540000), '2,5 tr');
      expect(formatPrice(2550000), '2,6 tr');
      expect(formatPrice(1950000), '2 tr');
      expect(formatPrice(1949999), '1,9 tr');
    });
  });

  group('formatPrice Pha lê', () {
    test('always whole', () {
      expect(formatPrice(120, phaLe: true), '120');
      expect(formatPrice(300, phaLe: true), '300');
      expect(formatPrice(1200, phaLe: true), '1.200');
      expect(formatPrice(2500000, phaLe: true), '2.500.000');
    });
  });

  group('formatPriceUnit', () {
    test('whole number and the unit, never abbreviated', () {
      expect(formatPriceUnit(150000), '150.000 xu');
      expect(formatPriceUnit(2500000), '2.500.000 xu');
      expect(formatPriceUnit(36, phaLe: true), '36 Pha lê');
      expect(formatPriceUnit(1200, phaLe: true), '1.200 Pha lê');
    });
  });
}
