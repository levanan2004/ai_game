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

/// The shelf band and its plank (image px): pots stand on the plank top.
/// The 48 dp pot row of Phu's round 2 (16 dp under the buckets, just above
/// the clock row) does not fit in the 33 dp between them, so the slots stay
/// where eea5cd1 put them until that is decided.
const double shelfImageTop = 300;
const double shelfPlankImageTop = 382;

/// `scenes/ke_hoa.webp` (1008x60) is drawn at a third, stretched only
/// sideways: its plank face is rows 2..33, about 10 dp tall.
const double plankFaceSrcTop = 2;
const double plankFaceSrcBottom = 33;
const double plankArtScale = 1 / 3;
const double potShelfShadowHeight = 4;

/// The plank face, 12 dp from each side of the 360 dp frame.
final Rect displayShelfPlank = Rect.fromLTWH(
  12,
  shopBgImageY(shelfPlankImageTop),
  336,
  (plankFaceSrcBottom - plankFaceSrcTop) * plankArtScale,
);

/// 4 dp shadow under the plank face.
final Rect displayShelfShadow = Rect.fromLTWH(
  displayShelfPlank.left,
  displayShelfPlank.bottom,
  displayShelfPlank.width,
  potShelfShadowHeight,
);

/// Six equal slots on the shelf, centred in 56 dp cells; each pot is as
/// tall as the band above the plank allows (about 30 dp).
final List<Rect> displayPotRects = () {
  final plank = displayShelfPlank;
  final size = plank.top + 1 - shopBgImageY(shelfImageTop);
  final cell = plank.width / 6;
  return [
    for (var i = 0; i < 6; i++)
      Rect.fromLTWH(
        plank.left + cell * i + (cell - size) / 2,
        plank.top + 1 - size,
        size,
        size,
      ),
  ];
}();

/// The dashed gold box drawn on a slot in placing mode (54×56 on the bar,
/// just inside the stand's 33 dp pitch on the stand).
Rect potSlotHighlight({required bool bar, required int index}) {
  if (bar) {
    final r = barPotRect(index);
    return Rect.fromLTWH(r.left + 2, 86, 54, 56);
  }
  return displayPotRects[index].inflate(1);
}

/// 1-based number of a slot as told to the player: the bar 1–5, then the
/// stand 6–11.
int potSlotNumber({required bool bar, required int index}) =>
    bar ? index + 1 : barPotSlots + index + 1;
