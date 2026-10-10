import 'package:ai_game/logic/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pha lê counts stay short in the top bar', () {
    expect(formatCount(0), '0');
    expect(formatCount(950), '950');
    expect(formatCount(1000), '1k');
    expect(formatCount(1250), '1,2k');
    expect(formatCount(1299), '1,2k');
    expect(formatCount(18400), '18k');
    expect(formatCount(999999), '999k');
    expect(formatCount(2500000), '2,5tr');
    expect(formatCount(12000000), '12tr');
  });

  test('xu in the narrow shop pill switches to tr from a million', () {
    expect(formatHudMoney(500000), '500k');
    expect(formatHudMoney(999900), '999,9k');
    expect(formatHudMoney(1000000), '1tr');
    expect(formatHudMoney(1250000), '1,2tr');
    expect(formatHudMoney(999990000), '999,9tr');
    expect(formatHudMoney(-1250000), '-1,2tr');
  });
}
