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

/// Ke 6 chau (Phu 26/10, round 8): each shop background has its own shelf
/// picture (`skin/ke_6_chau/ke_6_chau_<skin>.png`) over the cabinet painted
/// at the left. It is drawn flush with the scene's left edge, 160 dp tall,
/// width by aspect, centred on the painted cabinet (image y 407.5 of the
/// 1170x780 background, scene y 184). Three tiers of two pots: pot 32 dp,
/// tap 48 dp, the pot's foot on the tier's wood surface, pot centres at
/// 25% and 75% of the shelf's inner width.
const double cabinetLeft = 0;
const double cabinetHeight = 160;
const double cabinetPotSize = 32;
const double cabinetTop = 104; // shopBgImageY(407.5) - 80
const int cabinetColumns = 2;
const int cabinetRows = 3;
const String defaultShelfSkin = 'mac_dinh';

/// One shelf picture: pixel size, the three tier surfaces as fractions of
/// the image height (top to bottom), and the inner left/right edges as
/// fractions of the width.
class Ke6Chau {
  const Ke6Chau(
    this.width,
    this.height,
    this.tiers,
    this.innerLeft,
    this.innerRight,
  );
  final double width;
  final double height;
  final List<double> tiers;
  final double innerLeft;
  final double innerRight;
}

/// Per-skin shelf table (Phu's ratios, 26/10).
const Map<String, Ke6Chau> ke6ChauSkins = {
  'mac_dinh': Ke6Chau(322, 478, [.358, .600, .833], .155, .851),
  'bxh_mua1': Ke6Chau(350, 473, [.353, .598, .831], .171, .829),
  'son_hai': Ke6Chau(401, 478, [.360, .603, .833], .160, .723),
  'he_bien': Ke6Chau(366, 485, [.365, .608, .839], .219, .847),
  'tet': Ke6Chau(387, 485, [.365, .608, .841], .227, .796),
  'trung_thu': Ke6Chau(378, 490, [.371, .612, .843], .159, .767),
};

/// Shelf skin key for a worn background asset (`.../nen_man_hinh_tet.webp`
/// -> `tet`); the default shop background uses `mac_dinh`.
String shelfSkinFor(String backgroundAsset) {
  final m = RegExp(r'nen_man_hinh_([a-z0-9_]+)\.').firstMatch(backgroundAsset);
  final k = m?.group(1);
  return k != null && ke6ChauSkins.containsKey(k) ? k : defaultShelfSkin;
}

/// Asset of the shelf picture for [skin].
String ke6ChauAsset(String skin) =>
    'assets/images/skin/ke_6_chau/ke_6_chau_$skin.png';

Ke6Chau _shelf(String skin) =>
    ke6ChauSkins[skin] ?? ke6ChauSkins[defaultShelfSkin]!;

/// Where the shelf picture is drawn for [skin].
Rect ke6ChauRect([String skin = defaultShelfSkin]) {
  final s = _shelf(skin);
  return Rect.fromLTWH(
    cabinetLeft,
    cabinetTop,
    cabinetHeight * s.width / s.height,
    cabinetHeight,
  );
}

/// Pot art rects (32 dp, foot on the tier), left-to-right, top-to-bottom.
List<Rect> ke6ChauPotRects([String skin = defaultShelfSkin]) {
  final s = _shelf(skin);
  final r = ke6ChauRect(skin);
  final inL = r.left + r.width * s.innerLeft;
  final inW = r.width * (s.innerRight - s.innerLeft);
  return [
    for (var row = 0; row < cabinetRows; row++)
      for (var col = 0; col < cabinetColumns; col++)
        Rect.fromLTWH(
          inL + inW * (col == 0 ? .25 : .75) - cabinetPotSize / 2,
          r.top + r.height * s.tiers[row] - cabinetPotSize,
          cabinetPotSize,
          cabinetPotSize,
        ),
  ];
}

/// Tap targets: 48 dp squares centred on each pot.
List<Rect> ke6ChauHitRects([String skin = defaultShelfSkin]) => [
  for (final p in ke6ChauPotRects(skin))
    Rect.fromCenter(center: p.center, width: potHitSize, height: potHitSize),
];

/// Centre of stand slot [i] on [skin]'s shelf.
Offset cabinetCellCenter(int i, [String skin = defaultShelfSkin]) =>
    ke6ChauPotRects(skin)[i].center;

/// Default (mac_dinh) shelf slots, for screens without a worn skin.
final List<Rect> displayPotHitRects = ke6ChauHitRects();
final List<Rect> displayPotRects = ke6ChauPotRects();

/// The dashed gold box drawn on a slot in placing mode (54x56 on the bar,
/// the 48 dp target on the stand).
Rect potSlotHighlight({
  required bool bar,
  required int index,
  String skin = defaultShelfSkin,
}) {
  if (bar) {
    final r = barPotRect(index);
    return Rect.fromLTWH(r.left + 2, 86, 54, 56);
  }
  return ke6ChauHitRects(skin)[index];
}

/// 1-based number of a slot as told to the player: the bar 1-5, then the
/// stand 6-11.
int potSlotNumber({required bool bar, required int index}) =>
    bar ? index + 1 : barPotSlots + index + 1;

/// The pot slot under frame point [p], as (on the bar, index): the bar's
/// 48x76 areas first, then the stand's 48 dp targets. Empty stand slots
/// count too, so a tap there opens Kho chau (Phu 26/10, round 7).
(bool, int)? potSlotAt(Offset p, {String skin = defaultShelfSkin}) {
  for (var i = 0; i < barPotSlots; i++) {
    final x = 28.0 + i * 64;
    if (Rect.fromLTWH(x, 76, 48, 76).contains(p)) return (true, i);
  }
  final hits = ke6ChauHitRects(skin);
  for (var i = 0; i < hits.length; i++) {
    if (hits[i].contains(p)) return (false, i);
  }
  return null;
}
