import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('hydrangea and peony keep the repo numbers and add dryable', () {
    final e = newSession().e;
    final h = e.flowers.firstWhere((f) => f.id == 'hydrangea');
    final p = e.flowers.firstWhere((f) => f.id == 'peony');
    expect(
      [h.buyPrice, h.sellPrice, h.freshnessDays, h.bundleSize, h.unlockCost],
      [20000, 34000, 3, 3, 700000],
    );
    expect(
      [p.buyPrice, p.sellPrice, p.freshnessDays, p.bundleSize, p.unlockCost],
      [25000, 42000, 2, 3, 900000],
    );
    expect(h.dryable, isTrue);
    expect(p.dryable, isFalse);
    expect(h.wiltedArt && p.wiltedArt, isTrue);
  });
}
