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

/// 4 dp shadow under the plank face.
final Rect displayShelfShadow = Rect.fromLTWH(
  potShelfLeft,
  displayShelfPlank.bottom,
  potShelfRight - potShelfLeft,
  potShelfShadowHeight,
);

/// Stand pots (Phu 26/10, round 8): a 100x160 dp cabinet frame flush with
/// the scene's left edge, over the cabinet painted in the background.
/// Measured on `nen_man_hinh_mac_dinh` (1170x780): the painted cabinet runs
/// image y 255..560, so its middle is image y 407.5 (scene y 184); the
/// frame is centred there. Two columns of 50 dp, three rows of 53.3 dp;
/// pots 32 dp, tap targets 48 dp, both centred in their cell. Art for the
/// cabinet itself comes later from An; until then nothing is drawn.
const double cabinetLeft = 0;
const double cabinetWidth = 100;
const double cabinetHeight = 160;
const double cabinetPotSize = 32;
const double cabinetTop = 104; // shopBgImageY(407.5) - 80
const Rect cabinetRect = Rect.fromLTWH(
  cabinetLeft,
  cabinetTop,
  cabinetWidth,
  cabinetHeight,
);
const int cabinetColumns = 2;
const int cabinetRows = 3;

/// Kệ 6 chậu slot centres in scene space, left-to-right then
/// top-to-bottom: 2 columns of 50 dp, 3 rows of 53.3 dp in [cabinetRect]
/// (x 0..100, y 104..264). One row per background skin can be added here
/// when Phú's shelf art arrives with its exact slot coordinates.
const Map<String, List<Offset>> ke6ChauSlots = {
  'mac_dinh': [
    Offset(25, 130.67),
    Offset(75, 130.67),
    Offset(25, 184),
    Offset(75, 184),
    Offset(25, 237.33),
    Offset(75, 237.33),
  ],
};

/// Centre of stand slot [i] (the default table for now).
Offset cabinetCellCenter(int i) => ke6ChauSlots['mac_dinh']![i];

/// Tap targets: 48 dp squares centred in each cabinet cell.
final List<Rect> displayPotHitRects = [
  for (var i = 0; i < cabinetColumns * cabinetRows; i++)
    Rect.fromCenter(
      center: cabinetCellCenter(i),
      width: potHitSize,
      height: potHitSize,
    ),
];

/// Pot art: 32 dp, centred in its cell.
final List<Rect> displayPotRects = [
  for (var i = 0; i < cabinetColumns * cabinetRows; i++)
    Rect.fromCenter(
      center: cabinetCellCenter(i),
      width: cabinetPotSize,
      height: cabinetPotSize,
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
