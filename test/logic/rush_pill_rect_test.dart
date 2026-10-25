import 'package:ai_game/logic/pot_slots.dart';
import 'package:ai_game/logic/shop_shelf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gio cao diem pill and chalkboard placement (Phu 26/10).
void main() {
  test('pill: x 12, 8 dp inside the scene top, 24 tall, 72..84 wide', () {
    final narrow = ShelfGeometry.rushPillRect(width: 40);
    expect(narrow.left, 12);
    expect(narrow.top, ShelfGeometry.sceneTopEdge + 8);
    expect(narrow.top, 100);
    expect(narrow.height, 24);
    expect(narrow.width, 72);
    final wide = ShelfGeometry.rushPillRect(width: 130);
    expect(wide.width, 84);
    expect(wide.right, lessThan(ShelfGeometry.shopNameBoardLeft));
  });

  test('chalkboard hidden when the gap under the shelf is under 72 dp', () {
    // 312 layout: 264 - 214.3 = 49.7 dp; with the online strip (top 300)
    // even less.
    expect(ShelfGeometry.chalkGapHeight(), closeTo(49.67, 0.01));
    expect(ShelfGeometry.chalkboardRect(), isNull);
    expect(ShelfGeometry.chalkboardRect(strip: true), isNull);
  });

  test('cat anchor stays at the old board edge', () {
    expect(ShelfGeometry.chalkLeft, closeTo(352 - 41.67 * 160 / 192, 0.01));
    expect(displayShelfShadow.bottom, closeTo(214.33, 0.01));
  });
}
