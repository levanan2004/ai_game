import 'dart:math' as math;
import 'dart:ui';

import '../save/game_state.dart' show barPotSlots;

/// Where the pot slots are on the main screen, in the 360×640 frame (the
/// scene draws and taps in the same space). 5 slots on the long bar and 6 on
/// the left stand: 11 in all.
///
/// The scene (`ShopScene`) and the placing mode share these numbers.
/// Bucket plank (An 26/10): starts right after the window painted in each
/// background (frame x, measured on the 1170x780 pictures), ends at 348.
const Map<String, double> barShelfLeftBySkin = {
  'mac_dinh': 62,
  'bxh_mua1': 91,
  'son_hai': 98,
  'he_bien': 100,
  'tet': 98,
  'trung_thu': 75,
};
const double barShelfRight = 348;

/// Left end of the bucket plank on [skin].
double barShelfLeft([String skin = defaultShelfSkin]) =>
    barShelfLeftBySkin[skin] ?? barShelfLeftBySkin[defaultShelfSkin]!;

/// The 5 bucket slots, spread evenly on the plank with 8 dp margins.
double barRowLeft([String skin = defaultShelfSkin]) => barShelfLeft(skin) + 8;
const double barRowRight = barShelfRight - 8;
double barPitch([String skin = defaultShelfSkin]) =>
    (barRowRight - barRowLeft(skin) - potHitSize) / 4;
double barSlotCenterX(int i, [String skin = defaultShelfSkin]) =>
    barRowLeft(skin) + potHitSize / 2 + i * barPitch(skin);

/// Left of slot [i]'s 44 dp bucket area.
double barSlotX(int i, [String skin = defaultShelfSkin]) =>
    barSlotCenterX(i, skin) - 22;

/// Bar tap area, split at the midpoints between neighbours, y 76..152.
Rect barHitRect(int i, [String skin = defaultShelfSkin]) {
  final c = barSlotCenterX(i, skin);
  final half = barPitch(skin) / 2;
  final l = i == 0 ? barRowLeft(skin) : c - half;
  final r = i == barPotSlots - 1 ? barRowRight : c + half;
  return Rect.fromLTRB(l, 76, r, 152);
}

/// The slot's pot area on the bar: 58 wide, 66 tall, from bucket x - 6.
Rect barPotRect(int i, [String skin = defaultShelfSkin]) =>
    Rect.fromLTWH(barSlotX(i, skin) - 6, 76, 58, 66);

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
/// at the left. It is drawn flush with the scene's left edge, 150 dp tall,
/// width by aspect, centred on the painted cabinet (image y 407.5 of the
/// 1170x780 background, scene y 184). Three tiers of two pots: pot 32 dp,
/// tap 48 dp, the pot's foot on the tier's wood surface, pot centres at
/// 25% and 75% of the shelf's inner width.
const double cabinetLeft = 0;
const double cabinetHeight = 150;
const double cabinetPotSize = 32;
const double cabinetTop = 84; // Phu 26/10 final: scene y 84
const double cabinetMaxWidth = 104;

/// Lowest scene y a bottom-tier pot may reach (8 dp above the clock row).
const double bottomTierMaxY = 212;

/// Top of the clock row (clock dial) in scene space: 268 frame - 48.
/// Bottom-tier tap areas are clipped at [bottomTierMaxY], 8 dp above it.
const double clockRowTopScene = 220;
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

/// Per-skin shelf table (Phu's ratios, 26/10). Tiers: where a pot's foot
/// stands on each plank, near its front edge (measured on the pictures,
/// An 26/10), not the plank's back edge.
const Map<String, Ke6Chau> ke6ChauSkins = {
  'mac_dinh': Ke6Chau(322, 478, [.385, .630, .862], .155, .851),
  'bxh_mua1': Ke6Chau(350, 473, [.380, .625, .858], .171, .829),
  'son_hai': Ke6Chau(401, 478, [.385, .625, .855], .160, .723),
  'he_bien': Ke6Chau(366, 485, [.395, .640, .870], .219, .847),
  'tet': Ke6Chau(387, 485, [.390, .632, .865], .227, .796),
  'trung_thu': Ke6Chau(378, 490, [.400, .642, .875], .159, .767),
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

/// Background picture width (`nen_man_hinh_*` are 1170x780).
const double shopBgImageWidth = 1170;

/// Frame point of background pixel ([x], [y]): the picture fills the
/// 360x268 area from y 44 with BoxFit.cover, bottom-anchored and anchored
/// to the left edge, so the painted cabinet is never cut (An 26/10) (`ShopScene._drawCoverBottom`). The game canvas is a fixed 360
/// wide frame scaled to the screen, so this holds at every screen width.
Offset shopBgToFrame(double x, double y) {
  final k = math.max(360 / shopBgImageWidth, shopBgHeight / shopBgImageHeight);
  const cropLeft = 0.0;
  final cropTop = shopBgImageHeight - shopBgHeight / k;
  return Offset((x - cropLeft) * k, shopBgTop + (y - cropTop) * k);
}

/// The wooden cabinet painted at the left of each background, in background
/// pixels (left, top, right, bottom), measured on the 1170x780 pictures. The
/// ke 6 chau picture is laid exactly over it.
const Map<String, Rect> cabinetBgPixels = {
  'mac_dinh': Rect.fromLTRB(15, 252, 175, 558),
  'bxh_mua1': Rect.fromLTRB(5, 245, 190, 585),
  'son_hai': Rect.fromLTRB(5, 240, 210, 565),
  'he_bien': Rect.fromLTRB(18, 242, 208, 555),
  'tet': Rect.fromLTRB(5, 242, 222, 562),
  'trung_thu': Rect.fromLTRB(12, 242, 212, 545),
};

/// Where the shelf picture is drawn for [skin]: over the background's own
/// cabinet, mapped through BoxFit.cover (no fixed dp).
Rect ke6ChauRect([String skin = defaultShelfSkin]) {
  final px = cabinetBgPixels[skin] ?? cabinetBgPixels[defaultShelfSkin]!;
  return Rect.fromPoints(
    shopBgToFrame(px.left, px.top),
    shopBgToFrame(px.right, px.bottom),
  );
}

/// Pot size on [skin]'s cabinet: 32 dp, or less so a pot fits between two
/// tiers.
double cabinetPotSizeFor([String skin = defaultShelfSkin]) {
  final s = _shelf(skin);
  final r = ke6ChauRect(skin);
  var gap = double.infinity;
  for (var i = 1; i < s.tiers.length; i++) {
    gap = math.min(gap, (s.tiers[i] - s.tiers[i - 1]) * r.height);
  }
  return math.min(cabinetPotSize, gap * 0.9);
}

/// Pot art rects, the pot's foot flush on its tier's plank, left-to-right,
/// top-to-bottom.
List<Rect> ke6ChauPotRects([String skin = defaultShelfSkin]) {
  final s = _shelf(skin);
  final r = ke6ChauRect(skin);
  final size = cabinetPotSizeFor(skin);
  final inL = r.left + r.width * s.innerLeft;
  final inW = r.width * (s.innerRight - s.innerLeft);
  return [
    for (var row = 0; row < cabinetRows; row++)
      for (var col = 0; col < cabinetColumns; col++)
        Rect.fromLTWH(
          inL + inW * (col == 0 ? .25 : .75) - size / 2,
          r.top + r.height * s.tiers[row] - size,
          size,
          size,
        ),
  ];
}

/// Tap targets: each pot's cell on the painted cabinet (half the inner
/// width, from the tier above down to the pot's plank), so neighbouring
/// cells never overlap; the cabinet is smaller than 48 dp per cell.
List<Rect> ke6ChauHitRects([String skin = defaultShelfSkin]) {
  final s = _shelf(skin);
  final r = ke6ChauRect(skin);
  final inL = r.left + r.width * s.innerLeft;
  final half = r.width * (s.innerRight - s.innerLeft) / 2;
  final pots = ke6ChauPotRects(skin);
  return [
    for (var i = 0; i < pots.length; i++)
      Rect.fromLTRB(
        inL + half * (i % 2),
        i < 2 ? pots[i].top : pots[i - 2].bottom,
        inL + half * (i % 2 + 1),
        pots[i].bottom,
      ),
  ];
}

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
    final r = barHitRect(index, skin);
    return Rect.fromLTWH(r.left, 86, r.width, 56);
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
    if (barHitRect(i, skin).contains(p)) return (true, i);
  }
  final hits = ke6ChauHitRects(skin);
  for (var i = 0; i < hits.length; i++) {
    if (hits[i].contains(p)) return (false, i);
  }
  return null;
}
