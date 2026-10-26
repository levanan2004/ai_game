import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/pot_slots.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/pot_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

// Phu 26/10 round 7: an empty stand slot (default pot) is a 48 dp tap
// target; the scene's tap handler opens Kho chau for it.
void main() {
  test('ke 6 chau: shelf at y 84, max 104x150, pots above y 212', () {
    expect(ke6ChauSkins.keys.toSet(), {
      'mac_dinh',
      'bxh_mua1',
      'son_hai',
      'he_bien',
      'tet',
      'trung_thu',
    });
    expect(shelfSkinFor(''), 'mac_dinh');
    expect(
      shelfSkinFor('assets/images/skin/tiem/nen_man_hinh_tet.webp'),
      'tet',
    );
    for (final e in ke6ChauSkins.entries) {
      final s = e.value;
      final r = ke6ChauRect(e.key);
      expect(r.left, 0);
      expect(r.top, 84);
      expect(r.width, lessThanOrEqualTo(104 + 1e-9));
      expect(r.height, lessThanOrEqualTo(150 + 1e-9));
      expect(r.width / r.height, closeTo(s.width / s.height, 1e-9));
      final pots = ke6ChauPotRects(e.key);
      final hits = ke6ChauHitRects(e.key);
      expect(pots[4].bottom, lessThanOrEqualTo(bottomTierMaxY + 1e-9));
      final inL = r.width * s.innerLeft;
      final inW = r.width * (s.innerRight - s.innerLeft);
      for (var i = 0; i < 6; i++) {
        expect(pots[i].width, closeTo(32, 1e-9));
        expect(pots[i].height, closeTo(32, 1e-9));
        expect(hits[i].width, closeTo(48, 1e-9));
        // Tap areas never reach into the clock row.
        expect(hits[i].bottom, lessThanOrEqualTo(bottomTierMaxY));
        expect(
          hits[i].height,
          i < 4 ? closeTo(48, 1e-9) : lessThanOrEqualTo(48),
        );
        expect(pots[i].center.dx, closeTo(hits[i].center.dx, 1e-9));
        expect(
          pots[i].bottom,
          closeTo(r.top + r.height * s.tiers[i ~/ 2], 1e-9),
        );
        expect(
          pots[i].center.dx,
          closeTo(inL + inW * (i.isEven ? .25 : .75), 1e-9),
        );
      }
      // Lower tiers sit below the bucket row's tap areas.
      for (final i in [2, 3, 4, 5]) {
        expect(potSlotAt(hits[i].center, skin: e.key), (false, i));
      }
    }
    expect(displayPotRects, ke6ChauPotRects('mac_dinh'));
    // Bucket row: x 116..348, evenly spread, no overlapping tap areas.
    expect(barHitRect(0).left, 116);
    expect(barHitRect(4).right, 348);
    for (var i = 0; i < 5; i++) {
      expect(barSlotCenterX(i), closeTo(140 + 46.0 * i, 1e-9));
      if (i > 0) expect(barHitRect(i).left, barHitRect(i - 1).right);
      expect(potSlotAt(barHitRect(i).center), (true, i));
    }
  });
  testWidgets('tapping an empty stand slot opens Kho chau', (tester) async {
    final s = newSession(sounds: Sounds(heard: []));
    s.screen = Screen.shop;
    s.markPotHintShown();
    for (var i = 0; i < 6; i++) {
      s.state.displayPots[i] = i < 4 ? 'dragon' : defaultPotId;
    }
    final slot = potSlotAt(displayPotHitRects[4].center)!;
    expect(s.potInSlot(bar: slot.$1, index: slot.$2), defaultPotId);
    // What ShopScene.onTapUp does with a slot hit.
    s.openPotPicker(bar: slot.$1, index: slot.$2);
    expect(s.potPickerOpen, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: PotPopup(session: s)),
      ),
    );
    expect(find.text('Kho ch\u{1ead}u'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
