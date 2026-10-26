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
  test(
    'ke 6 chau: per-skin shelf, 160 tall, flush left, pots on the tiers',
    () {
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
        expect(r.height, 160);
        expect(r.width, closeTo(160 * s.width / s.height, 1e-9));
        expect(r.center.dy, closeTo(184, 0.01));
        final pots = ke6ChauPotRects(e.key);
        final hits = ke6ChauHitRects(e.key);
        final inL = r.width * s.innerLeft;
        final inW = r.width * (s.innerRight - s.innerLeft);
        for (var i = 0; i < 6; i++) {
          expect(pots[i].width, closeTo(32, 1e-9));
          expect(pots[i].height, closeTo(32, 1e-9));
          expect(hits[i].width, closeTo(48, 1e-9));
          expect((pots[i].center - hits[i].center).distance, lessThan(1e-9));
          expect(pots[i].bottom, closeTo(r.top + 160 * s.tiers[i ~/ 2], 1e-9));
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
    },
  );
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
