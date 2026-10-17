import 'dart:io';

import 'package:ai_game/ui/art.dart';
import 'package:ai_game/ui/pet_item_art.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('every pet item has its picture under assets/images/pet_do/', () {
    final eco = loadTestData().economy;
    expect(eco.petItems, hasLength(12));
    for (final item in eco.petItems) {
      expect(File(Art.petDo(item.id)).existsSync(), isTrue, reason: item.id);
    }
  });

  test('the empty slot glyphs and the pack pictures exist', () {
    for (final slot in ['head', 'neck', 'accessory']) {
      expect(
        File(Art.trong(emptySlotFile(slot))).existsSync(),
        isTrue,
        reason: slot,
      );
    }
    for (final k in ['10k', '20k', '50k', '100k', '200k', '500k']) {
      expect(File(Art.phale('pack_$k')).existsSync(), isTrue, reason: k);
    }
    expect(File(Art.phaleQr).existsSync(), isTrue);
  });

  test('the three new folders are declared in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final d in ['phale', 'pet_do', 'trong']) {
      expect(pubspec, contains('assets/images/$d/'));
    }
  });
}
