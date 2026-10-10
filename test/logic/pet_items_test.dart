import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/pet_items.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// The shipped economy with a made-up item catalog: the real one is empty
/// until the items are decided.
String _economyWithItems() {
  final json =
      jsonDecode(File('assets/data/economy.json').readAsStringSync())
          as Map<String, dynamic>;
  json['petItems'] = {
    'list': [
      {
        'id': 'day_thuong',
        'nameVi': 'Dây thường',
        'tier': 'thuong',
        'slot': 'neck',
      },
      {'id': 'day_hiem', 'nameVi': 'Dây hiếm', 'tier': 'hiem', 'slot': 'neck'},
      {
        'id': 'non_su_thi',
        'nameVi': 'Nón sử thi',
        'tier': 'suThi',
        'slot': 'head',
      },
      {
        'id': 'canh_huyen_thoai',
        'nameVi': 'Cánh huyền thoại',
        'tier': 'huyenThoai',
        'slot': 'accessory',
      },
      {'id': 'no_tier', 'tier': 'khong_co', 'slot': 'head'},
      {'id': 'day_thuong', 'tier': 'huyenThoai', 'slot': 'neck'},
    ],
  };
  return jsonEncode(json);
}

ShopSession _session({Map<String, int> items = const {}}) {
  final s = newSession(data: loadTestData(economy: _economyWithItems()));
  s.state.day = strayCatDay;
  s.state.addPet('ca_chep'); // base 10
  s.state.addPet('nghe'); // base 30
  s.state.petItems.addAll(items);
  return s;
}

void main() {
  group('Mị lực of a pet without items', () {
    test('base x 1 / 1.5 / 2 for every pet and stage', () {
      final s = newSession();
      expect(s.e.charmStageMultiplier, [1.0, 1.5, 2.0]);
      const base = {
        'meo': 10,
        'ca_chep': 10,
        'hac': 10,
        'nghe': 30,
        'huyen_vu': 30,
        'bach_ho': 60,
        'ky_lan': 60,
        'phuong_hoang': 100,
        'rong_thien': 100,
        'kim_long': 150,
      };
      for (final e in base.entries) {
        final def = s.e.pet(e.key)!;
        expect(def.charmBase, e.value, reason: e.key);
        expect(petCharmScore(def, 0), e.value);
        expect(petCharmScore(def, 1), (e.value * 1.5).round());
        expect(petCharmScore(def, 2), e.value * 2);
      }
      // A stage outside 0..2 is clamped, never an error.
      final def = s.e.pet('kim_long')!;
      expect(petCharmScore(def, -1), 150);
      expect(petCharmScore(def, 9), 300);
    });

    test('items add on top of the stage score, not before the multiplier', () {
      final def = newSession().e.pet('nghe')!;
      expect(petCharmScore(def, 2, itemCharm: 55), 30 * 2 + 55);
      expect(petCharmScore(def, 1, itemCharm: 100), 45 + 100);
    });

    test('only the pet in the Mị lực slot counts', () {
      final s = _session();
      s.state.ownedPet('nghe')!.stage = 2;
      s.state.petCharm = 'nghe';
      s.state.petIncome = 'ca_chep';
      expect(s.charmScore, 60);
      expect(s.petCharmOf('ca_chep'), 10);
      s.state.petCharm = null;
      expect(s.charmScore, 0);
    });
  });

  group('item catalog', () {
    test(
      'the shipped catalog is empty, the tiers and slots are the decided ones',
      () {
        final s = newSession();
        expect(s.e.petItems, isEmpty);
        expect(s.e.petItemRules.slots, ['neck', 'head', 'accessory']);
        expect(s.e.petItemRules.charmOfTier(PetItemTier.thuong), 5);
        expect(s.e.petItemRules.charmOfTier(PetItemTier.hiem), 15);
        expect(s.e.petItemRules.charmOfTier(PetItemTier.suThi), 40);
        expect(s.e.petItemRules.charmOfTier(PetItemTier.huyenThoai), 100);
      },
    );

    test('a bad entry or a repeated id is skipped, not fatal', () {
      final s = _session();
      expect(s.e.petItems.map((i) => i.id), [
        'day_thuong',
        'day_hiem',
        'non_su_thi',
        'canh_huyen_thoai',
      ]);
      expect(s.e.petItem('day_thuong')!.tier, PetItemTier.thuong);
      expect(s.e.petItem('nope'), isNull);
    });

    test('a data file with no charm block falls back to the same numbers', () {
      const rules = PetItemRules();
      expect(rules.slots.length, 3);
      expect(
        [for (final t in PetItemTier.values) rules.charmOfTier(t)],
        [5, 15, 40, 100],
      );
      final custom = PetItemRules.fromJson({
        'itemSlots': ['neck', 'head'],
        'itemCharmByRarity': {'thuong': 7},
      });
      expect(custom.slots, ['neck', 'head']);
      expect(custom.charmOfTier(PetItemTier.thuong), 7);
      expect(custom.charmOfTier(PetItemTier.hiem), 15);
    });
  });

  group('wearing', () {
    test('three slots add up and show in the pet score', () {
      final s = _session(
        items: {'day_hiem': 1, 'non_su_thi': 1, 'canh_huyen_thoai': 1},
      );
      s.state.petCharm = 'nghe';
      s.state.ownedPet('nghe')!.stage = 1; // 45
      expect(s.charmScore, 45);
      expect(s.wearPetItem('nghe', 'day_hiem'), PetItemResult.worn);
      expect(s.charmScore, 60);
      expect(s.wearPetItem('nghe', 'non_su_thi'), PetItemResult.worn);
      expect(s.charmScore, 100);
      expect(s.wearPetItem('nghe', 'canh_huyen_thoai'), PetItemResult.worn);
      expect(s.charmScore, 200);
      expect(s.petItemCharm('nghe'), 155);
      expect(s.state.ownedPet('nghe')!.worn, {
        'neck': 'day_hiem',
        'head': 'non_su_thi',
        'accessory': 'canh_huyen_thoai',
      });
    });

    test(
      'a new item replaces the one in its slot, the old one is free again',
      () {
        final s = _session(items: {'day_thuong': 1, 'day_hiem': 1});
        expect(s.wearPetItem('nghe', 'day_thuong'), PetItemResult.worn);
        expect(s.petItemCharm('nghe'), 5);
        expect(s.wearPetItem('nghe', 'day_thuong'), PetItemResult.already);
        expect(s.wearPetItem('nghe', 'day_hiem'), PetItemResult.worn);
        expect(s.petItemCharm('nghe'), 15);
        expect(s.petItemWorn('day_thuong'), 0);
        expect(s.wearPetItem('ca_chep', 'day_thuong'), PetItemResult.worn);
      },
    );

    test('one copy cannot be worn by two pets; a second copy can', () {
      final s = _session(items: {'non_su_thi': 1});
      expect(s.wearPetItem('nghe', 'non_su_thi'), PetItemResult.worn);
      expect(s.wearPetItem('ca_chep', 'non_su_thi'), PetItemResult.noneLeft);
      s.state.petItems['non_su_thi'] = 2;
      expect(s.wearPetItem('ca_chep', 'non_su_thi'), PetItemResult.worn);
      expect(s.petItemWorn('non_su_thi'), 2);
    });

    test('refusals: not owned pet, unknown item, item not in the bag', () {
      final s = _session(items: {'day_thuong': 1});
      expect(s.wearPetItem('kim_long', 'day_thuong'), PetItemResult.notOwned);
      expect(s.wearPetItem('nghe', 'nope'), PetItemResult.unknownItem);
      expect(s.wearPetItem('nghe', 'day_hiem'), PetItemResult.noneLeft);
      expect(s.state.ownedPet('nghe')!.worn, isEmpty);
    });

    test('taking an item off', () {
      final s = _session(items: {'day_thuong': 1});
      s.wearPetItem('nghe', 'day_thuong');
      expect(s.unwearPetItem('nghe', 'head'), isFalse);
      expect(s.unwearPetItem('nghe', 'neck'), isTrue);
      expect(s.petItemCharm('nghe'), 0);
      expect(s.unwearPetItem('nghe', 'neck'), isFalse);
      expect(s.unwearPetItem('kim_long', 'neck'), isFalse);
    });

    test('an item the catalog no longer knows, or in a wrong slot, adds 0', () {
      final s = _session();
      s.state.ownedPet('nghe')!.worn.addAll({
        'neck': 'gone_item',
        'head': 'day_hiem', // a neck item in the head slot
        'wing': 'canh_huyen_thoai', // not a slot of this game
      });
      expect(s.petItemCharm('nghe'), 0);
      s.state.petCharm = 'nghe';
      expect(s.charmScore, 30);
    });
  });

  group('save', () {
    test('worn items and the bag survive a round trip', () {
      final s = _session(items: {'day_hiem': 2, 'non_su_thi': 1});
      s.wearPetItem('nghe', 'day_hiem');
      s.wearPetItem('nghe', 'non_su_thi');
      final back = GameState.decode(s.state.encode())!;
      expect(back.petItems, {'day_hiem': 2, 'non_su_thi': 1});
      expect(back.ownedPet('nghe')!.worn, {
        'neck': 'day_hiem',
        'head': 'non_su_thi',
      });
      expect(back.ownedPet('ca_chep')!.worn, isEmpty);
      expect(back.ownedPet('nghe')!.copy().worn, back.ownedPet('nghe')!.worn);
    });

    test('an old save with no item fields loads with nothing worn', () {
      final s = newSession();
      s.state.addPet('hac');
      final json = jsonDecode(s.state.encode()) as Map<String, dynamic>;
      expect(json.containsKey('petItems'), isFalse);
      expect((json['pets'] as List).first.containsKey('worn'), isFalse);
      final back = GameState.decode(jsonEncode(json))!;
      expect(back.petItems, isEmpty);
      expect(back.ownedPet('hac')!.worn, isEmpty);
    });

    test('junk in the item fields is dropped, not thrown', () {
      final s = newSession();
      s.state.addPet('hac');
      final json = jsonDecode(s.state.encode()) as Map<String, dynamic>;
      json['petItems'] = {'a': 2, 'b': 'x', 'c': 0, 'd': -1};
      (json['pets'] as List).first['worn'] = {'neck': 5, 'head': 'x'};
      final back = GameState.decode(jsonEncode(json))!;
      expect(back.petItems, {'a': 2});
      expect(back.ownedPet('hac')!.worn, {'head': 'x'});
    });

    test('wearing is in the morning save at once', () async {
      final fresh = _session(items: {'non_su_thi': 1});
      final raw = fresh.state.encode();
      final backing = <String, String>{};
      await ProgressStore.memory(backing).save(GameState.decode(raw)!);
      final s = newSession(
        data: loadTestData(economy: _economyWithItems()),
        backing: backing,
        saved: GameState.decode(raw),
      );
      expect(s.wearPetItem('nghe', 'non_su_thi'), PetItemResult.worn);
      await s.pendingSaves;
      final saved = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(saved.ownedPet('nghe')!.worn, {'head': 'non_su_thi'});
      expect(saved.petItems, {'non_su_thi': 1});
    });
  });
}
