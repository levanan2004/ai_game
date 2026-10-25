import 'package:ai_game/components/shop_scene.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../ui/notebook_button_position_test.dart' show sameDayOffer;
import '../ui/so_tay_screen_test.dart' show soTaySession;

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

  // First queue slot x 70, floor 272 (shop_scene).
  const slot0 = 70.0, floorY = 272.0;

  test('no Same-Day card: button at y56 misses the bubble, stays centred', () {
    final s = soTaySession();
    final button = ShopScene.notebookButtonRect(s)!;
    expect(button, const Rect.fromLTWH(12, 56, 44, 44));
    final r = ShopScene.regularBubbleRect(slot0, floorY, avoid: button);
    expect(r.overlaps(button), isFalse);
    expect(r.center.dx, slot0);
  });

  test(
    'Same-Day card: pushed button hits the bubble, bubble + heart 8dp right',
    () {
      final s = soTaySession()..onlineOrders.add(sameDayOffer());
      final button = ShopScene.notebookButtonRect(s)!;
      final plain = ShopScene.regularBubbleRect(slot0, floorY);
      expect(plain.overlaps(button), isTrue);
      final r = ShopScene.regularBubbleRect(slot0, floorY, avoid: button);
      expect(r, plain.shift(const Offset(8, 0)));
      expect(r.overlaps(button), isFalse);
      expect(
        ShopScene.regularHeartRect(r),
        ShopScene.regularHeartRect(plain).shift(const Offset(8, 0)),
      );
    },
  );

  test('notebook closed: no button rect, bubble centred', () {
    final s = newSession(seed: 3)..onlineOrders.add(sameDayOffer());
    expect(ShopScene.notebookButtonRect(s), isNull);
    expect(ShopScene.regularBubbleRect(slot0, floorY).center.dx, slot0);
  });
}
