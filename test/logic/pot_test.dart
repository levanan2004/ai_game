import 'dart:convert';

import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test(
    'an old save without pot keys fills every slot with the free bucket',
    () {
      final s = newSession();
      final j = s.state.toJson();
      j.remove('potCounts');
      j.remove('barPots');
      j.remove('displayPots');
      final back = GameState.decode(jsonEncode(j))!;
      expect(back.barPots, List.filled(barPotSlots, defaultPotId));
      expect(back.displayPots, List.filled(displayPotSlots, defaultPotId));
      expect(back.potCounts, isEmpty);
    },
  );

  test('owned copies limit how many slots a pot can fill', () async {
    final born = newSession().state
      ..money = 3600000
      ..phaLe = 600;
    final raw = born.encode();
    final backing = <String, String>{};
    await ProgressStore.memory(backing).save(GameState.decode(raw)!);
    final s = newSession(backing: backing, saved: GameState.decode(raw));
    final start = s.state.phaLe;

    expect(s.buyPot('sage'), isFalse);
    expect(s.buyPot('dragon'), isTrue);
    expect(s.state.phaLe, start - 300);
    expect(s.potOwned('dragon'), 1);

    s.openPotPicker(bar: true, index: 0);
    expect(s.placePot('dragon'), isTrue);
    expect(s.state.barPots[0], 'dragon');

    s.openPotPicker(bar: true, index: 1);
    expect(s.canPlacePot('dragon', bar: true, index: 1), isFalse);
    expect(s.placePot('dragon'), isFalse);
    expect(s.state.barPots[1], defaultPotId);

    // No second copy from the shop; a welfare gift can still add one.
    expect(s.buyPot('dragon'), isFalse);
    s.state.potCounts['dragon'] = 2;
    expect(s.potOwned('dragon'), 2);
    expect(s.canPlacePot('dragon', bar: true, index: 1), isTrue);
    expect(s.placePot('dragon'), isTrue);

    s.openPotPicker(bar: true, index: 0);
    expect(s.placePot('sage'), isTrue);
    expect(s.potPlaced('dragon'), 1);
    s.openPotPicker(bar: false, index: 0);
    expect(s.placePot('dragon'), isTrue);
    expect(s.state.displayPots[0], 'dragon');
    expect(s.potPlaced('dragon'), 2);

    s.openPotPicker(bar: false, index: 1);
    expect(s.canPlacePot('dragon', bar: false, index: 1), isFalse);
    expect(s.buyPot('dragon'), isFalse);

    for (var i = 0; i < displayPotSlots; i++) {
      s.openPotPicker(bar: false, index: i);
      expect(s.placePot('sage'), isTrue);
    }
    expect(s.state.displayPots, List.filled(displayPotSlots, defaultPotId));

    await s.pendingSaves;
    final loaded = GameState.decode(backing[ProgressStore.storageKey])!;
    expect(loaded.potCounts['dragon'], 1); // the gift copy was not saved here
    expect(loaded.barPots[1], 'dragon');
    expect(loaded.displayPots, List.filled(displayPotSlots, defaultPotId));
    expect(loaded.phaLe, start - 300);
  });
}
