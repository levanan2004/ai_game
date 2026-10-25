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
  test('empty stand slots: 48 dp targets in six equal columns', () {
    for (var i = 0; i < 6; i++) {
      final r = displayPotHitRects[i];
      expect(r.width, 48);
      expect(r.height, 48);
      expect(r.center.dx, 12 + 56 * (i + 0.5));
      expect(potSlotAt(r.center), (false, i));
      // Pot bottoms rest on the plank's top face.
      expect(displayPotRects[i].bottom, standPlank.top);
    }
    expect(standPlank.left, 12);
    expect(standPlank.right, 348);
    expect(standPlank.height, 6);
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
