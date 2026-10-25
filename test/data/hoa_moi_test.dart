import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('hydrangea and peony use the hoa_moi numbers', () {
    final e = newSession().e;
    final h = e.flowers.firstWhere((f) => f.id == 'hydrangea');
    final p = e.flowers.firstWhere((f) => f.id == 'peony');
    expect(
      [h.buyPrice, h.sellPrice, h.freshnessDays, h.bundleSize, h.unlockCost],
      [12000, 21000, 3, 5, 350000],
    );
    expect(
      [p.buyPrice, p.sellPrice, p.freshnessDays, p.bundleSize, p.unlockCost],
      [22000, 39000, 2, 3, 600000],
    );
    expect(h.dryable, isTrue);
    expect(p.dryable, isFalse);
    expect(h.wiltedArt && p.wiltedArt, isTrue);
  });
}
