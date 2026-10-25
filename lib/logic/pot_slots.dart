import 'dart:ui';

import '../save/game_state.dart' show barPotSlots;

/// Where the pot slots are on the main screen, in the 360×640 frame (the
/// scene draws and taps in the same space). 5 slots on the long bar and 6 on
/// the left stand: 11 in all.
///
/// The scene (`ShopScene`) and the placing mode share these numbers.
/// The slot's pot area on the bar: x 28 + 64 i, 58 wide, 66 tall.
Rect barPotRect(int i) => Rect.fromLTWH(28.0 + i * 64 - 6, 76, 58, 66);

/// The shop backgrounds (`nen_man_hinh_*`, 1170x780) no longer paint a
/// shelf (Phu 26/10): the scene draws it inside image y 300-410 px. The
/// picture fills the 268 dp tall area from y 44 (cover, bottom-anchored,
/// height-bound for a 3:2 file), so an image row maps to the frame here.
const double shopBgTop = 44;
const double shopBgHeight = 268;
const double shopBgImageHeight = 780;
double shopBgImageY(double y) =>
    shopBgTop + y * shopBgHeight / shopBgImageHeight;

/// Pot shelf (Phu 26/10, round 3): its own 62 dp row under the bucket
/// row: 8 dp gap, 40 dp pot art, 10 dp plank, 4 dp shadow. The clock row
/// moved 30 dp lower (`ShelfGeometry.clockRowDrop`) to make room.
const double upperShelfBottom = 152;
const double potShelfGap = 8;
const double potArtSize = 40;
const double potHitSize = 48;
const double potShelfLeft = 12;
const double potShelfRight = 348;

/// `scenes/ke_hoa.webp` (1008x60) is drawn at a third, stretched only
/// sideways: its plank face is rows 2..33, about 10 dp tall.
const double plankFaceSrcTop = 2;
const double plankFaceSrcBottom = 33;
const double plankArtScale = 1 / 3;
const double potShelfShadowHeight = 4;

/// The plank face, under the pot art.
final Rect displayShelfPlank = Rect.fromLTWH(
  potShelfLeft,
  upperShelfBottom + potShelfGap + potArtSize,
  potShelfRight - potShelfLeft,
  (plankFaceSrcBottom - plankFaceSrcTop) * plankArtScale,
);

/// Lower-tier plank drawn under the stand pots (Phu 26/10, round 7):
/// 6 dp thick, x 12..348, its top face where the pot bottoms rest.
const double standPlankHeight = 6;
final Rect standPlank = Rect.fromLTWH(
  potShelfLeft,
  displayShelfPlank.top,
  potShelfRight - potShelfLeft,
  standPlankHeight,
);

/// 4 dp shadow under the plank face.
final Rect displayShelfShadow = Rect.fromLTWH(
  potShelfLeft,
  displayShelfPlank.bottom,
  potShelfRight - potShelfLeft,
  potShelfShadowHeight,
);

/// Tap targets (Phu 26/10, round 6): x 12..348 split into six equal 56 dp
/// columns, a 48 dp square centred in each.
const double potColumnWidth = (potShelfRight - potShelfLeft) / 6;
final List<Rect> displayPotHitRects = [
  for (var i = 0; i < 6; i++)
    Rect.fromLTWH(
      potShelfLeft + (i + 0.5) * potColumnWidth - potHitSize / 2,
      displayShelfPlank.top - potHitSize,
      potHitSize,
      potHitSize,
    ),
];

/// Pot art: 40 dp, centred in its tap target, standing on the plank.
final List<Rect> displayPotRects = [
  for (final r in displayPotHitRects)
    Rect.fromLTWH(
      r.center.dx - potArtSize / 2,
      displayShelfPlank.top - potArtSize,
      potArtSize,
      potArtSize,
    ),
];

/// The dashed gold box drawn on a slot in placing mode (54×56 on the bar,
/// just inside the stand's 33 dp pitch on the stand).
Rect potSlotHighlight({required bool bar, required int index}) {
  if (bar) {
    final r = barPotRect(index);
    return Rect.fromLTWH(r.left + 2, 86, 54, 56);
  }
  return displayPotHitRects[index];
}

/// 1-based number of a slot as told to the player: the bar 1–5, then the
/// stand 6–11.
int potSlotNumber({required bool bar, required int index}) =>
    bar ? index + 1 : barPotSlots + index + 1;

/// The pot slot under frame point [p], as (on the bar, index): the bar's
/// 48x76 areas first, then the stand's 48 dp targets. Empty stand slots
/// count too, so a tap there opens Kho chậu (Phu 26/10, round 7).
(bool, int)? potSlotAt(Offset p) {
  for (var i = 0; i < barPotSlots; i++) {
    final x = 28.0 + i * 64;
    if (Rect.fromLTWH(x, 76, 48, 76).contains(p)) return (true, i);
  }
  for (var i = 0; i < displayPotHitRects.length; i++) {
    if (displayPotHitRects[i].contains(p)) return (false, i);
  }
  return null;
}
