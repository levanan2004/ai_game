import 'package:ai_game/logic/pot_slots.dart';
import 'package:ai_game/logic/shop_shelf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gio cao diem pill and chalkboard placement (Phu 26/10, final).
void main() {
  test('pill: x 12, 8 dp inside the scene top, 24 tall, min 72 wide', () {
    final narrow = ShelfGeometry.rushPillRect(fullWidth: 40);
    expect(narrow.left, 12);
    expect(narrow.top, ShelfGeometry.sceneTopEdge + 8);
    expect(narrow.top, 100);
    expect(narrow.height, 24);
    expect(narrow.width, 72);
    expect(ShelfGeometry.rushPillRect(fullWidth: 130).width, 130);
  });

  test('chalkboard: between shelf shadow and goals card, right x 352', () {
    final r = ShelfGeometry.chalkboardRect();
    expect(r.top, closeTo(displayShelfShadow.bottom + 4, 1e-9));
    expect(r.bottom, 312 - 48 - 4);
    expect(r.right, closeTo(352, 1e-9));
    expect(r.width / r.height, closeTo(160 / 192, 1e-9));
    expect(r.height, closeTo(41.67, 0.01));
  });
}
