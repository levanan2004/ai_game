import 'dart:ui';

import 'package:ai_game/logic/shop_shelf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gio cao diem pill placement (Phu 26/10, round 4).
void main() {
  const prices = Rect.fromLTWH(100, 263, 78, 44);

  test('x 12 while So tay is locked, x 60 once it is unlocked', () {
    final locked = ShelfGeometry.rushPillRect(prices, null);
    expect(locked.left, 12);
    expect(locked.top, 56);
    expect(locked.height, 28);
    final unlocked = ShelfGeometry.rushPillRect(prices, null, notebook: true);
    expect(unlocked.left, 60);
    expect(unlocked.top, 56);
  });

  test('8 dp under the ticker; 24 tall when 28 would cross the scene', () {
    final roomy = ShelfGeometry.rushPillRect(prices, null, tickerBottom: 40);
    expect(roomy.top, 48);
    expect(roomy.height, 28);
    final tight = ShelfGeometry.rushPillRect(prices, null, tickerBottom: 88);
    expect(tight.top, 96);
    expect(tight.height, 24);
    expect(ShelfGeometry.sceneTopEdge, 92);
  });
}
