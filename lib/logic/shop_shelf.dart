/// Clock and brought-along pet on the counter ledge of the main shop
/// (spec_man_hinh_chinh.md, 10/10).
///
/// Every rect is in the fixed 360×640 frame that both the Flame scene and
/// the Flutter overlay use; `GameFrame` scales that frame as one piece on
/// phones and desktop, so the numbers hold on every screen size.
library;

import 'dart:ui';

import '../save/game_state.dart';
import 'pet.dart';
import 'shop_session.dart';

abstract final class ShelfGeometry {
  /// Top face of the counter strip (`mat_quay`, drawn at y 276 with a 1 px
  /// transparent rim). Spec: ledgeTop ≈ y 273 on the screenshot; in the
  /// frame the strip itself is the ledge, so the clock and pet stand on it.
  static const ledgeTop = 277.0;

  /// Spec §3: clock left = scene.left + 6, picture height 39.
  static const clockLeft = 6.0;
  static const clockHeight = 39.0;

  /// `nav/dong_ho.webp` is 96×96 with the dial at x 4..92, y 7..88.
  static const clockFile = 96.0;
  static const clockInk = Rect.fromLTRB(4, 7, 92, 88);

  /// Spec §3/§4: plaque height 32, min width 46, 6 px side padding,
  /// tucked 3 px under the clock's right edge.
  static const plaqueHeight = 32.0;
  static const plaqueMinWidth = 46.0;
  static const plaquePadX = 6.0;
  static const plaqueOverlap = 3.0;

  /// Spec §3: pet centre x ≈ 311 (0.883 of the scene), base 1 px into the
  /// ledge, never closer than 4 px to the scene's right edge.
  static const petCenterX = 311.0;
  static const petSink = 1.0;
  static const sceneRight = 360.0;
  static const petEdge = 4.0;

  /// Spec §7: tap areas reach 6 px past the picture.
  static const hitPad = 6.0;

  /// Visible dial rect.
  static Rect clockRect() {
    final w = clockHeight * clockInk.width / clockInk.height;
    return Rect.fromLTWH(clockLeft, ledgeTop - clockHeight, w, clockHeight);
  }

  /// Box the full 96×96 file is drawn into so its ink lands on [clockRect].
  static Rect clockImageBox() {
    final scale = clockHeight / clockInk.height;
    final ink = clockRect();
    return Rect.fromLTWH(
      ink.left - clockInk.left * scale,
      ink.top - clockInk.top * scale,
      clockFile * scale,
      clockFile * scale,
    );
  }

  /// Plaque for a text block [textWidth] wide.
  static Rect plaqueRect(double textWidth) {
    final w = textWidth + plaquePadX * 2;
    return Rect.fromLTWH(
      clockRect().right - plaqueOverlap,
      ledgeTop - plaqueHeight,
      w < plaqueMinWidth ? plaqueMinWidth : w,
      plaqueHeight,
    );
  }

  /// Visible pet rect for [art].
  static Rect petRect(PetArt art) {
    final h = art.height;
    final w = h * art.inkAspect;
    var left = petCenterX - w / 2;
    final maxRight = sceneRight - petEdge;
    if (left + w > maxRight) left = maxRight - w;
    return Rect.fromLTWH(left, ledgeTop + petSink - h, w, h);
  }

  /// Box the whole file is drawn into so its ink lands on [petRect].
  static Rect petImageBox(PetArt art) {
    final ink = petRect(art);
    final scale = ink.height / art.ink.height;
    return Rect.fromLTWH(
      ink.left - art.ink.left * scale,
      ink.top - art.ink.top * scale,
      art.fileWidth * scale,
      art.fileHeight * scale,
    );
  }
}

/// Picture of a sitting pet and where its ink sits inside the file.
class PetArt {
  const PetArt({
    required this.asset,
    required this.height,
    required this.fileWidth,
    required this.fileHeight,
    required this.ink,
  });

  /// File id under `assets/images/pets/`, e.g. `meo_lon_ngoi`.
  final String asset;

  /// Shown height of the ink. Spec §3: ấu thú 42, lớn 50, trưởng thành 56.
  final double height;
  final double fileWidth;
  final double fileHeight;
  final Rect ink;

  double get inkAspect => ink.width / ink.height;
}

/// Spec §3: the pet grows on the ledge stage by stage.
const shelfPetHeights = [42.0, 50.0, 56.0];

/// Measured ink of the cat files (alpha > 20). Pets without an entry use
/// the whole file.
const _petInk = <String, (double, double, Rect)>{
  'meo_au_ngoi': (174, 200, Rect.fromLTRB(1, 6, 173, 195)),
  'meo_lon_ngoi': (264, 264, Rect.fromLTRB(1, 6, 263, 258)),
  'meo_truong_ngoi': (291, 302, Rect.fromLTRB(0, 0, 290, 301)),
  'pet_bach_ho_au': (269, 277, Rect.fromLTRB(6, 6, 263, 270)),
  'pet_bach_ho_lon': (334, 346, Rect.fromLTRB(7, 7, 328, 340)),
  'pet_bach_ho_truong': (447, 375, Rect.fromLTRB(6, 6, 440, 368)),
  'pet_ca_chep_au': (261, 256, Rect.fromLTRB(7, 6, 255, 249)),
  'pet_ca_chep_lon': (339, 331, Rect.fromLTRB(6, 7, 333, 324)),
  'pet_ca_chep_truong': (415, 420, Rect.fromLTRB(7, 7, 409, 413)),
  'pet_hac_au': (217, 242, Rect.fromLTRB(8, 6, 211, 235)),
  'pet_hac_lon': (366, 328, Rect.fromLTRB(7, 7, 358, 322)),
  'pet_hac_truong': (440, 407, Rect.fromLTRB(7, 6, 432, 401)),
  'pet_huyen_vu_au': (238, 215, Rect.fromLTRB(6, 6, 231, 208)),
  'pet_huyen_vu_lon': (309, 315, Rect.fromLTRB(7, 6, 303, 307)),
  'pet_huyen_vu_truong': (426, 381, Rect.fromLTRB(6, 6, 420, 373)),
  'pet_kim_long_au': (310, 285, Rect.fromLTRB(6, 6, 303, 278)),
  'pet_kim_long_lon': (369, 404, Rect.fromLTRB(6, 7, 363, 397)),
  'pet_kim_long_truong': (475, 443, Rect.fromLTRB(6, 6, 468, 436)),
  'pet_ky_lan_au': (270, 332, Rect.fromLTRB(7, 6, 264, 324)),
  'pet_ky_lan_lon': (336, 442, Rect.fromLTRB(7, 6, 330, 434)),
  'pet_ky_lan_truong': (469, 464, Rect.fromLTRB(6, 6, 463, 457)),
  'pet_nghe_au': (288, 299, Rect.fromLTRB(6, 6, 282, 292)),
  'pet_nghe_lon': (325, 380, Rect.fromLTRB(6, 7, 319, 374)),
  'pet_nghe_truong': (437, 421, Rect.fromLTRB(6, 6, 431, 414)),
  'pet_phuong_hoang_au': (241, 274, Rect.fromLTRB(6, 6, 235, 268)),
  'pet_phuong_hoang_lon': (390, 334, Rect.fromLTRB(6, 6, 382, 327)),
  'pet_phuong_hoang_truong': (429, 445, Rect.fromLTRB(6, 6, 422, 438)),
  'pet_rong_thien_au': (276, 254, Rect.fromLTRB(6, 7, 269, 248)),
  'pet_rong_thien_lon': (385, 343, Rect.fromLTRB(7, 7, 378, 336)),
  'pet_rong_thien_truong': (458, 417, Rect.fromLTRB(6, 7, 452, 411)),
};

/// The pet in the "Thu nhập" slot, sitting on the ledge, or null when the
/// shop has none. The cat sits (`meo_<stage>_ngoi`); other pets use their
/// stage picture (`pet_<id>_<stage>`).
PetArt? shelfPet(GameState state) {
  final id = state.petIncome;
  final pet = id == null ? null : state.ownedPet(id);
  if (pet == null) return null;
  final stage = pet.stage.clamp(0, 2);
  final asset = petArtId(pet.id, stage);
  final known = _petInk[asset];
  final w = known?.$1 ?? 256;
  final h = known?.$2 ?? 256;
  return PetArt(
    asset: asset,
    height: shelfPetHeights[stage],
    fileWidth: w,
    fileHeight: h,
    ink: known?.$3 ?? Rect.fromLTWH(0, 0, w, h),
  );
}

/// Line 1 of the plaque: "Ngày N", or the holiday's short date like the
/// old header box.
String shelfDayLine(ShopSession s) =>
    s.holidayToday?.shortLabel ?? 'Ngày ${s.state.day}';

/// Line 2: in-game "HH:mm", or "Đóng cửa" after closing time.
String shelfTimeLine(ShopSession s) => s.clockText;

/// Open, with less than an hour of in-game time left (spec §4, optional).
bool shelfClosingSoon(ShopSession s) {
  final left = shelfMinutesToClose(s);
  return left != null && left > 0 && left <= 60;
}

/// In-game minutes until closing while open; null otherwise.
int? shelfMinutesToClose(ShopSession s) {
  if (s.state.phase != DayPhase.open || s.afterClose) return null;
  final e = s.e;
  final total = (e.closeHour - e.openHour) * 60;
  final done = (s.state.elapsed / e.secondsPerHour * 60).floor();
  final left = total - done;
  return left < 0 ? 0 : left;
}

/// Tooltip over the clock (spec §7): "Ngày 1 · 08:00 · còn 9 giờ nữa
/// đóng cửa".
String shelfClockTip(ShopSession s) {
  final head = '${shelfDayLine(s)} · ${shelfTimeLine(s)}';
  if (s.afterClose) return '${shelfDayLine(s)} · tiệm đã đóng cửa';
  final left = shelfMinutesToClose(s);
  if (left == null) {
    return '$head · tiệm chưa mở cửa';
  }
  final h = left ~/ 60;
  final m = left % 60;
  final span = h == 0
      ? '$m phút'
      : m == 0
      ? '$h giờ'
      : '$h giờ $m phút';
  return '$head · còn $span nữa đóng cửa';
}

/// Shared between the Flutter shelf layer (which draws the clock and pet
/// and knows their rects) and the Flame scene (which receives taps on the
/// floor). The scene offers a tap here only after its own pots and the
/// waiting customer passed on it, so the shelf never steals their taps.
class ShelfTaps {
  /// Drawn rects, set by the shelf layer on every build.
  Rect? clockArea;
  Rect? petArea;

  VoidCallback? onClock;
  VoidCallback? onPet;
  VoidCallback? onPetHold;

  Rect? get clockHit => clockArea?.inflate(ShelfGeometry.hitPad);
  Rect? get petHit => petArea?.inflate(ShelfGeometry.hitPad);

  /// True when the tap at [p] (frame coordinates) was the shelf's.
  bool tap(Offset p) {
    if (petHit?.contains(p) ?? false) {
      onPet?.call();
      return true;
    }
    if (clockHit?.contains(p) ?? false) {
      onClock?.call();
      return true;
    }
    return false;
  }

  bool hold(Offset p) {
    if (petHit?.contains(p) ?? false) {
      onPetHold?.call();
      return true;
    }
    return false;
  }
}

final _shelves = Expando<ShelfTaps>('shelf');

/// One [ShelfTaps] per session, so neither the session nor the game needs
/// a new field.
ShelfTaps shelfTapsOf(ShopSession s) => _shelves[s] ??= ShelfTaps();
