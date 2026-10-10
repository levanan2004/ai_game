import 'package:ai_game/logic/price_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coinFull', () {
    test('dots between thousands', () {
      expect(coinFull(0), '0');
      expect(coinFull(950), '950');
      expect(coinFull(1000), '1.000');
      expect(coinFull(80000), '80.000');
      expect(coinFull(1250000), '1.250.000');
      expect(coinFull(30000000), '30.000.000');
    });

    test('negative keeps the sign', () {
      expect(coinFull(-24000), '-24.000');
    });
  });

  group('coinLabel', () {
    test('under a million stays whole with dots', () {
      expect(coinLabel(0), '0');
      expect(coinLabel(80000), '80.000');
      expect(coinLabel(500000), '500.000');
      expect(coinLabel(999999), '999.999');
    });

    test('from a million it is written in tr, ,0 dropped', () {
      expect(coinLabel(1000000), '1 tr');
      expect(coinLabel(2000000), '2 tr');
      expect(coinLabel(30000000), '30 tr');
      expect(coinLabel(120000000), '120 tr');
    });

    test('Vietnamese decimal comma', () {
      expect(coinLabel(2500000), '2,5 tr');
      expect(coinLabel(6500000), '6,5 tr');
      expect(coinLabel(10500000), '10,5 tr');
    });

    test('exact, never rounded', () {
      expect(coinLabel(1250000), '1,25 tr');
      expect(coinLabel(1000500), '1,0005 tr');
      expect(coinLabel(1000001), '1,000001 tr');
    });

    test('every approved price (3..30 tr, pets, items)', () {
      const expected = {
        3000000: '3 tr',
        4000000: '4 tr',
        5000000: '5 tr',
        6500000: '6,5 tr',
        8000000: '8 tr',
        10000000: '10 tr',
        12000000: '12 tr',
        15000000: '15 tr',
        18000000: '18 tr',
        22000000: '22 tr',
        26000000: '26 tr',
        30000000: '30 tr',
        1000000: '1 tr',
        2500000: '2,5 tr',
        20000000: '20 tr',
      };
      expected.forEach((v, label) => expect(coinLabel(v), label));
    });
  });

  group('priceLabel', () {
    test('xu abbreviates, Pha lê is always whole', () {
      expect(priceLabel(2500000), '2,5 tr');
      expect(priceLabel(120, phaLe: true), '120');
      expect(priceLabel(1200, phaLe: true), '1.200');
      expect(priceLabel(2500000, phaLe: true), '2.500.000');
    });
  });

  group('priceUnit', () {
    test('whole number and the unit, never abbreviated', () {
      expect(priceUnit(150000), '150.000 xu');
      expect(priceUnit(30000000), '30.000.000 xu');
      expect(priceUnit(36, phaLe: true), '36 Pha lê');
      expect(priceUnit(1200, phaLe: true), '1.200 Pha lê');
    });
  });

  group('priceLabelUnit', () {
    test('plain text without an icon keeps the word', () {
      expect(priceLabelUnit(30000000), '30 tr xu');
      expect(priceLabelUnit(6500000), '6,5 tr xu');
      expect(priceLabelUnit(500000), '500.000 xu');
      expect(priceLabelUnit(300, phaLe: true), '300 Pha lê');
    });
  });
}
