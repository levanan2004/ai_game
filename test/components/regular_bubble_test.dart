import 'package:ai_game/components/shop_scene.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('regular bubble: 40dp, 8dp above the head, heart 14dp bottom-right', () {
    const floorY = 500.0;
    final r = ShopScene.regularBubbleRect(100, floorY);
    expect(r.width, 40);
    expect(r.height, 40);
    expect(r.center.dx, 100);
    // Head circle: centre floorY - 58, radius 18 → top floorY - 76.
    expect(r.bottom, floorY - 76 - 8);
    final h = ShopScene.regularHeartRect(r);
    expect(h.size, const Size(14, 14));
    expect(h.right, r.right);
    expect(h.bottom, r.bottom);
  });
}
