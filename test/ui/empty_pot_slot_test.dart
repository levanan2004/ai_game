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
  test('stand slots: 2x3 in the 100x160 cabinet frame at the left', () {
    expect(cabinetRect.left, 0);
    expect(cabinetRect.width, 100);
    expect(cabinetRect.height, 160);
    expect(cabinetRect.center.dy, closeTo(184, 0.01));
    for (var i = 0; i < 6; i++) {
      final hit = displayPotHitRects[i];
      final art = displayPotRects[i];
      expect(hit.width, closeTo(48, 1e-9));
      expect(hit.height, closeTo(48, 1e-9));
      expect(art.width, closeTo(32, 1e-9));
      expect(art.height, closeTo(32, 1e-9));
      expect((art.center - hit.center).distance, lessThan(1e-9));
      expect(hit.center.dx, i.isEven ? 25 : 75);
      expect(cabinetRect.contains(art.center), isTrue);
    }
    // Slots below the bucket row's tap areas map to the stand.
    for (final i in [2, 3, 4, 5]) {
      expect(potSlotAt(displayPotHitRects[i].center), (false, i));
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
