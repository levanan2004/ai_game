import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/pet_slots_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// A session that owns [ids] (first one takes both slots, like a first buy).
ShopSession _owning(List<String> ids, {Map<String, int> stages = const {}}) {
  final s = newSession();
  s.state.day = strayCatDay;
  for (final id in ids) {
    s.state.addPet(id);
    s.state.ownedPet(id)!.stage = stages[id] ?? 0;
  }
  return s;
}

void main() {
  group('slot logic', () {
    test('opening selects the first empty slot, Thu nhập before Mị lực', () {
      final none = _owning([]);
      none.openPetSlots();
      expect(none.petSlotsOpen, isTrue);
      expect(none.petSlotSelected, petSlotIncome);

      final half = _owning(['ca_chep']);
      half.state.petCharm = null;
      half.openPetSlots();
      expect(half.petSlotSelected, petSlotCharm);

      final full = _owning(['ca_chep']);
      full.openPetSlots();
      expect(full.petSlotSelected, isNull);

      // A tap on a chip names the slot it opens on.
      full.closePetSlots();
      expect(full.petSlotsOpen, isFalse);
      full.openPetSlots(select: petSlotCharm);
      expect(full.petSlotSelected, petSlotCharm);
    });

    test('a tap on a slot selects it, a second tap lets go', () {
      final s = _owning(['ca_chep']);
      s.openPetSlots();
      s.selectPetSlot(petSlotIncome);
      expect(s.petSlotSelected, petSlotIncome);
      s.selectPetSlot(petSlotIncome);
      expect(s.petSlotSelected, isNull);
      s.selectPetSlot(petSlotCharm);
      s.selectPetSlot(petSlotIncome);
      expect(s.petSlotSelected, petSlotIncome);
    });

    test('a pet fills the selected slot, replaces without asking, and the '
        'other empty slot is selected next', () {
      final s = _owning(['ca_chep', 'hac', 'meo']);
      s.state.petIncome = null;
      s.state.petCharm = null;
      s.openPetSlots();
      expect(s.petSlotSelected, petSlotIncome);

      var r = s.placePetInSlot('ca_chep');
      expect(r.result, PetSlotResult.placed);
      expect(r.slot, petSlotIncome);
      expect(s.state.petIncome, 'ca_chep');
      expect(s.petSlotSelected, petSlotCharm);

      r = s.placePetInSlot('hac');
      expect(r.slot, petSlotCharm);
      expect(s.state.petCharm, 'hac');
      expect(s.petSlotSelected, isNull);

      // Both full, nothing selected: ask for a slot first.
      r = s.placePetInSlot('meo');
      expect(r.result, PetSlotResult.pickSlot);
      expect(s.state.petIncome, 'ca_chep');
      expect(s.state.petCharm, 'hac');

      // Pick Mị lực and replace Hạc with Mèo.
      s.selectPetSlot(petSlotCharm);
      r = s.placePetInSlot('meo');
      expect(r.result, PetSlotResult.placed);
      expect(s.state.petCharm, 'meo');
      expect(s.petSlotSelected, isNull);
    });

    test('with no slot selected the first empty one is used', () {
      final s = _owning(['ca_chep', 'hac']);
      s.state.petIncome = null;
      s.openPetSlots();
      s.selectPetSlot(petSlotIncome); // let go
      expect(s.petSlotSelected, isNull);
      final r = s.placePetInSlot('hac');
      expect(r.result, PetSlotResult.placed);
      expect(r.slot, petSlotIncome);
      expect(s.state.petIncome, 'hac');
    });

    test('one pet may sit in both slots; the pet already there is a no-op', () {
      final s = _owning(['ca_chep', 'hac']);
      s.state.petCharm = 'hac';
      s.state.petIncome = 'ca_chep';
      s.openPetSlots();
      s.selectPetSlot(petSlotIncome);
      // Hạc is in the other slot: still placeable here.
      var r = s.placePetInSlot('hac');
      expect(r.result, PetSlotResult.placed);
      expect([s.state.petIncome, s.state.petCharm], ['hac', 'hac']);
      // Same pet in the selected slot: nothing changes.
      s.selectPetSlot(petSlotIncome);
      r = s.placePetInSlot('hac');
      expect(r.result, PetSlotResult.already);
      expect(r.slot, petSlotIncome);
      expect([s.state.petIncome, s.state.petCharm], ['hac', 'hac']);
    });

    test('a pet that is not owned cannot be placed', () {
      final s = _owning(['ca_chep']);
      s.openPetSlots();
      expect(s.placePetInSlot('kim_long').result, PetSlotResult.notOwned);
      expect(s.state.petIncome, 'ca_chep');
    });

    test('× empties the slot and selects it; it stays empty', () {
      final s = _owning(['ca_chep']);
      s.openPetSlots();
      s.clearPetSlot(petSlotCharm);
      expect(s.state.petCharm, isNull);
      expect(s.state.petIncome, 'ca_chep');
      expect(s.petSlotSelected, petSlotCharm);
      s.clearPetSlot(petSlotCharm); // already empty: nothing
      // Buying a second pet does not refill a slot emptied on purpose.
      s.state.addPet('hac');
      expect(s.state.petCharm, isNull);
      // A save round trip keeps it empty too.
      final back = GameState.decode(s.state.encode())!;
      expect(back.petCharm, isNull);
      expect(back.petIncome, 'ca_chep');
    });

    test('every change is saved at once, no Save button', () async {
      final backing = <String, String>{};
      final base = _owning(['ca_chep', 'hac']);
      await ProgressStore.memory(
        backing,
      ).save(GameState.decode(base.state.encode())!);
      final s = newSession(
        backing: backing,
        saved: GameState.decode(base.state.encode()),
      );
      s.openPetSlots();
      s.selectPetSlot(petSlotCharm);
      expect(s.placePetInSlot('hac').result, PetSlotResult.placed);
      await s.pendingSaves;
      var saved = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(saved.petCharm, 'hac');
      expect(saved.petIncome, 'ca_chep');

      s.clearPetSlot(petSlotIncome);
      await s.pendingSaves;
      saved = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(saved.petIncome, isNull);
      expect(saved.petCharm, 'hac');
    });

    test('the room pet no longer moves the Thu nhập slot', () {
      final s = _owning(['ca_chep', 'hac']);
      s.state.petIncome = 'ca_chep';
      s.useRoomPet('hac');
      expect(s.roomPet!.id, 'hac');
      expect(s.state.petIncome, 'ca_chep');
    });

    test('"Vào phòng" closes the picker and the shop', () {
      final s = _owning(['ca_chep']);
      s.openPetSlots();
      s.openPetCatalog();
      expect(s.petSlotsOpen, isTrue);
      expect(s.petCatalogOpen, isTrue);
      s.openPetRoom('ca_chep');
      expect(s.petSlotsOpen, isFalse);
      expect(s.petCatalogOpen, isFalse);
      expect(s.screen, Screen.pets);
    });

    test('a chip in the shop reopens the picker over it', () {
      final s = _owning(['ca_chep']);
      s.openPetCatalog();
      s.openPetSlots(select: petSlotIncome);
      expect(s.petCatalogOpen, isFalse);
      expect(s.petSlotsOpen, isTrue);
      expect(s.petSlotSelected, petSlotIncome);
    });
  });

  group('stage scaling and Mị lực', () {
    test('Mị lực is charmBase × 1 / 1.5 / 2 by stage, plus worn items', () {
      final s = newSession();
      expect(s.e.charmStageMultiplier, [1.0, 1.5, 2.0]);
      for (final def in s.e.pets) {
        final base = def.charmBase;
        expect(petCharmScore(def, 0), base, reason: def.id);
        expect(petCharmScore(def, 1), (base * 1.5).round(), reason: def.id);
        expect(petCharmScore(def, 2), base * 2, reason: def.id);
        expect(petCharmScore(def, 2, itemCharm: 30), base * 2 + 30);
        // A stage out of range stays inside the table.
        expect(petCharmScore(def, 9), base * 2);
        expect(petCharmScore(def, -1), base);
      }
      final kim = s.e.pet('kim_long')!;
      expect(kim.charmBase, greaterThan(s.e.pet('meo')!.charmBase));
    });

    test('only the pet in the Mị lực slot counts, and it grows with stage', () {
      final s = _owning(['ca_chep', 'hac']);
      s.state.petIncome = 'hac';
      s.state.petCharm = 'ca_chep';
      final base = s.e.pet('ca_chep')!.charmBase;
      expect(s.charmScore, base);
      s.state.ownedPet('ca_chep')!.stage = 1;
      expect(s.charmScore, (base * 1.5).round());
      s.state.ownedPet('ca_chep')!.stage = 2;
      expect(s.charmScore, base * 2);
      // Moving the other pet around changes nothing; emptying the slot
      // drops the score to 0.
      s.state.petIncome = 'ca_chep';
      expect(s.charmScore, base * 2);
      s.clearPetSlot(petSlotCharm);
      expect(s.charmScore, 0);
      expect(s.petCharmOf('kim_long'), 0, reason: 'not owned');
    });

    test('income effects follow the stage of the Thu nhập pet only', () {
      final s = _owning(['meo']);
      final fx = <double>[];
      for (var stage = 0; stage <= 2; stage++) {
        s.state.ownedPet('meo')!.stage = stage;
        fx.add(PetEffects.of(s.e, s.state).mouseCatch);
      }
      expect(fx, [0.2, 0.35, 0.5]);
      // The same cat in the Mị lực slot only: no mouse effect.
      s.state.petIncome = null;
      expect(PetEffects.of(s.e, s.state).mouseCatch, 0);
      // Huyền vũ does nothing until it is grown.
      final t = _owning(['huyen_vu'], stages: {'huyen_vu': 1});
      expect(t.petEffects.freshnessBonusDays, 0);
      t.state.ownedPet('huyen_vu')!.stage = 2;
      expect(t.petEffects.freshnessBonusDays, 1);
    });

    test('the Thu nhập line shows the current stage, not the adult one', () {
      final s = newSession();
      final meo = s.e.pet('meo')!;
      expect(petSlotIncomeLine(meo, 0), 'Bắt chuột +20%');
      expect(petSlotIncomeLine(meo, 2), 'Bắt chuột +50%');
      final turtle = s.e.pet('huyen_vu')!;
      expect(petSlotIncomeLine(turtle, 1), 'Có tác dụng khi trưởng thành');
      expect(petSlotIncomeLine(turtle, 2), 'Hoa tươi thêm 1 ngày');
    });
  });

  group('slot screen', () {
    Future<void> pump(WidgetTester tester, ShopSession s) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      s.openPetSlots();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: PetSlotsScreen(session: s)),
        ),
      );
      await tester.pump();
    }

    testWidgets('two empty slots, the first selected, only the shop cell', (
      tester,
    ) async {
      final s = _owning([]);
      await pump(tester, s);
      expect(find.byKey(const Key('slot-income')), findsOneWidget);
      expect(find.byKey(const Key('slot-charm')), findsOneWidget);
      expect(find.text('Trống'), findsNWidgets(2));
      expect(find.text('Chọn thú'), findsNWidgets(2));
      expect(
        find.text('Nuôi thú ở Tiệm thú cưng rồi quay lại đây nhé.'),
        findsOneWidget,
      );
      expect(find.text('Thú đã nuôi (0)'), findsOneWidget);
      expect(find.byKey(const Key('slot-to-shop')), findsOneWidget);
      expect(find.byKey(const Key('slot-clear-income')), findsNothing);
      expect(s.petSlotSelected, petSlotIncome);
    });

    testWidgets('unowned pets are hidden; owned ones show their stage', (
      tester,
    ) async {
      final s = _owning(['ca_chep', 'hac'], stages: {'hac': 2, 'ca_chep': 1});
      await pump(tester, s);
      expect(find.byKey(const Key('slot-pet-ca_chep')), findsOneWidget);
      expect(find.byKey(const Key('slot-pet-hac')), findsOneWidget);
      expect(find.byKey(const Key('slot-pet-kim_long')), findsNothing);
      expect(find.byKey(const Key('slot-pet-meo')), findsNothing);
      expect(find.text('Thú đã nuôi (2)'), findsOneWidget);
      expect(find.text('Lớn'), findsWidgets);
      expect(find.text('Trưởng thành'), findsWidgets);
      // Cá chép took both slots when it was the first pet.
      expect(
        find.byKey(const Key('slot-badge-income-ca_chep')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('slot-badge-charm-ca_chep')), findsOneWidget);
      expect(find.byKey(const Key('slot-badge-income-hac')), findsNothing);
      // Two full slots, nothing selected.
      expect(find.text('Chạm vào một ô để đổi thú.'), findsOneWidget);
    });

    testWidgets('tap a slot, tap a pet: it moves in, saved, toast, hint', (
      tester,
    ) async {
      final s = _owning(['ca_chep', 'hac'], stages: {'hac': 2});
      await pump(tester, s);
      await tester.tap(find.byKey(const Key('slot-charm')));
      await tester.pump();
      expect(s.petSlotSelected, petSlotCharm);
      expect(
        find.text('Chạm vào thú khác để thay, hoặc bấm × để tháo.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('slot-pet-hac')));
      await tester.pump();
      expect(s.state.petCharm, 'hac');
      expect(s.state.petIncome, 'ca_chep');
      expect(find.text('Hạc đã vào ô Mị lực'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('slot-name-charm'))).data,
        'Hạc',
      );
      // Mị lực slot: stage name and the number.
      final hac = s.e.pet('hac')!;
      expect(
        tester.widget<Text>(find.byKey(const Key('slot-line-charm'))).data,
        'Trưởng thành · ${hac.charmBase * 2}',
      );
      expect(find.byKey(const Key('slot-badge-charm-hac')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('one pet in both slots; × empties one and selects it', (
      tester,
    ) async {
      final s = _owning(['ca_chep']);
      await pump(tester, s);
      expect(find.byKey(const Key('slot-clear-income')), findsOneWidget);
      expect(find.byKey(const Key('slot-clear-charm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('slot-clear-charm')));
      await tester.pump();
      expect(s.state.petCharm, isNull);
      expect(s.state.petIncome, 'ca_chep');
      expect(find.text('Trống'), findsOneWidget);
      expect(find.byKey(const Key('slot-clear-charm')), findsNothing);
      expect(s.petSlotSelected, petSlotCharm);
      expect(find.text('Chạm vào thú để đặt vào ô đang chọn.'), findsOneWidget);
    });

    testWidgets('tapping the pet in the selected slot only shakes the card', (
      tester,
    ) async {
      final s = _owning(['ca_chep']);
      await pump(tester, s);
      await tester.tap(find.byKey(const Key('slot-income')));
      await tester.pump();
      expect(s.petSlotSelected, petSlotIncome);
      await tester.tap(find.byKey(const Key('slot-pet-ca_chep')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.state.petIncome, 'ca_chep');
      expect(s.petSlotSelected, petSlotIncome);
      expect(find.byKey(const Key('game-toast-ok')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('with both slots full and none selected, a hint asks first', (
      tester,
    ) async {
      final s = _owning(['ca_chep', 'hac']);
      await pump(tester, s);
      await tester.tap(find.byKey(const Key('slot-pet-hac')));
      await tester.pump();
      expect(s.state.petIncome, 'ca_chep');
      expect(find.text('Chạm vào một ô trước nhé.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the last cell opens the pet shop over the picker', (
      tester,
    ) async {
      final s = _owning(['ca_chep']);
      await pump(tester, s);
      await tester.tap(find.byKey(const Key('slot-to-shop')));
      await tester.pump();
      expect(s.petCatalogOpen, isTrue);
      expect(s.petSlotsOpen, isTrue);
    });

    testWidgets('the back button closes the picker', (tester) async {
      final s = _owning(['ca_chep']);
      await pump(tester, s);
      await tester.tap(find.byKey(const Key('slot-close')));
      await tester.pump();
      expect(s.petSlotsOpen, isFalse);
    });

    testWidgets('entry points: a button in the pet room and the shop chips', (
      tester,
    ) async {
      final s = _owning(['ca_chep']);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      s.openPets();
      await tester.pumpWidget(MaterialApp(home: PetScreen(session: s)));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pet-open-slots')));
      await tester.pump();
      expect(s.petSlotsOpen, isTrue);
      expect(find.byKey(const Key('pet-slots')), findsOneWidget);

      // Now from the shop: tap the "Đang thi Mị lực" chip.
      s.closePetSlots();
      s.openPetCatalog();
      await tester.pump();
      expect(find.byKey(const Key('pet-charm-ca_chep')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pet-charm-ca_chep')));
      await tester.pump();
      expect(s.petCatalogOpen, isFalse);
      expect(s.petSlotsOpen, isTrue);
      expect(s.petSlotSelected, petSlotCharm);
    });
  });
}
