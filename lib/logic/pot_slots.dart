import 'dart:ui';

import '../save/game_state.dart' show barPotSlots;

/// Where the pot slots are on the main screen, in the 360×640 frame (the
/// scene draws and taps in the same space). 5 slots on the long bar and 6 on
/// the left stand: 11 in all.
///
/// The scene (`ShopScene`) and the placing mode share these numbers.
/// The slot's pot area on the bar: x 28 + 64 i, 58 wide, 66 tall.
Rect barPotRect(int i) => Rect.fromLTWH(28.0 + i * 64 - 6, 76, 58, 66);

/// Six buckets on the left stand. Each skin is only as tall as its own
/// bucket, so the pot above does not cover the one below.
const displayPotRects = [
  Rect.fromLTWH(28, 156, 32, 32),
  Rect.fromLTWH(61, 156, 32, 32),
  Rect.fromLTWH(19, 194, 32, 32),
  Rect.fromLTWH(61, 194, 32, 32),
  Rect.fromLTWH(23, 229, 32, 32),
  Rect.fromLTWH(63, 229, 32, 32),
];

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
