import 'dart:io';

import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/save/game_state.dart' show catPetId;
import 'package:flutter_test/flutter_test.dart';

/// Baby and teen pose pictures of the nine pets other than the cat
/// (`pet_<id>_<be|vuot|an|doi>_<au|lon>.webp`): the files are there and
/// registered, and the lookup picks them by stage with the shared file as the
/// fallback. The cat and the growing / breakthrough poses are unchanged.
const _poses = ['be', 'vuot', 'an', 'doi'];
final _others = [
  for (final id in knownPetIds)
    if (id != catPetId) id,
];

void main() {
  test('nine pets x four poses x baby/teen = 72 pictures exist', () {
    expect(_others.length, 9);
    var n = 0;
    for (final id in _others) {
      for (final pose in _poses) {
        for (final stage in ['au', 'lon']) {
          final f = File('assets/images/pets/pet_${id}_${pose}_$stage.webp');
          expect(f.existsSync(), isTrue, reason: f.path);
          expect(f.lengthSync(), greaterThan(5000), reason: f.path);
          n++;
        }
      }
    }
    expect(n, 72);
  });

  test('the pets folder is registered in pubspec, so all 72 ship', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/images/pets/\n'.trim()),
    );
  });

  test('pictures are real WebP with an alpha channel', () {
    for (final id in _others) {
      for (final pose in _poses) {
        for (final stage in ['au', 'lon']) {
          final b = File(
            'assets/images/pets/pet_${id}_${pose}_$stage.webp',
          ).readAsBytesSync();
          expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
          expect(String.fromCharCodes(b.sublist(8, 12)), 'WEBP');
          // VP8X chunk = extended format, the one that carries alpha.
          expect(String.fromCharCodes(b.sublist(12, 16)), 'VP8X');
          expect(b[20] & 0x10, 0x10, reason: '$id $pose $stage has no alpha');
        }
      }
    }
  });

  group('petArtId by stage', () {
    test('baby and teen use their own pose picture, grown uses the shared', () {
      for (final id in _others) {
        for (final pose in _poses) {
          expect(petArtId(id, 0, pose: pose), 'pet_${id}_${pose}_au');
          expect(petArtId(id, 1, pose: pose), 'pet_${id}_${pose}_lon');
          expect(petArtId(id, 2, pose: pose), 'pet_${id}_$pose');
        }
      }
    });

    test('out-of-range stages clamp', () {
      expect(petArtId('hac', -1, pose: 'vuot'), 'pet_hac_vuot_au');
      expect(petArtId('hac', 9, pose: 'vuot'), 'pet_hac_vuot');
    });

    test('idle and the poses without pictures show the stage picture', () {
      for (final id in _others) {
        for (var stage = 0; stage < 3; stage++) {
          final s = petStageIds[stage];
          expect(petArtId(id, stage), 'pet_${id}_$s');
          expect(petArtId(id, stage, pose: 'ngoi'), 'pet_${id}_$s');
          expect(petArtId(id, stage, pose: 'nang'), 'pet_${id}_$s');
          expect(petArtId(id, stage, pose: 'dotpha'), 'pet_${id}_$s');
        }
      }
    });

    test('the cat path is unchanged', () {
      for (var stage = 0; stage < 3; stage++) {
        for (final pose in [..._poses, 'ngoi', 'nang', 'dotpha']) {
          expect(
            petArtId(catPetId, stage, pose: pose),
            'meo_${petStageIds[stage]}_$pose',
          );
        }
        expect(petArtFallbackId(catPetId, stage, pose: 'vuot'), isNull);
        expect(petHasStagePoseArt(catPetId, stage, 'vuot'), isFalse);
      }
    });

    test('the fallback is the shared file, only where a own file is used', () {
      expect(petArtFallbackId('kim_long', 0, pose: 'be'), 'pet_kim_long_be');
      expect(petArtFallbackId('kim_long', 1, pose: 'doi'), 'pet_kim_long_doi');
      expect(petArtFallbackId('kim_long', 2, pose: 'be'), isNull);
      expect(petArtFallbackId('kim_long', 0, pose: 'ngoi'), isNull);
      expect(petArtFallbackId('kim_long', 0, pose: 'nang'), isNull);
      // and that file exists
      expect(
        File('assets/images/pets/pet_kim_long_be.webp').existsSync(),
        isTrue,
      );
    });
  });

  group('petHasPoseArt (drives the hop-and-hearts fallback)', () {
    test('the four poses have art at every stage, for every pet', () {
      for (final id in knownPetIds) {
        for (final pose in _poses) {
          for (var stage = 0; stage < 3; stage++) {
            expect(petHasPoseArt(id, pose, stage: stage), isTrue);
          }
        }
      }
    });

    test('growing / breakthrough still have no art for the others', () {
      for (final id in _others) {
        for (final pose in ['nang', 'dotpha', 'ngoi']) {
          for (var stage = 0; stage < 3; stage++) {
            expect(petHasPoseArt(id, pose, stage: stage), isFalse);
          }
        }
      }
      expect(petHasPoseArt(catPetId, 'dotpha', stage: 0), isTrue);
    });

    test('an unknown pet has none', () {
      expect(petHasPoseArt('rong_xanh', 'vuot', stage: 0), isFalse);
      expect(petHasStagePoseArt('rong_xanh', 0, 'vuot'), isFalse);
    });
  });
}
