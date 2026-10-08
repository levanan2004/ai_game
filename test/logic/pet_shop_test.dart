import 'dart:convert';

import 'package:ai_game/data/economy.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/pet_shop_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

PetDef _pet(ShopSession s, String id) => s.e.pet(id)!;

/// Gives [state] the pet [id] at [stage] and puts it in the income slot.
void _income(GameState state, String id, {int stage = 2}) {
  state.addPet(id);
  state.ownedPet(id)!.stage = stage;
  state.petIncome = id;
}

void main() {
  group('shop list and card states', () {
    test('xu pets first, then Pha lê pets, each by price', () {
      final s = newSession();
      expect(
        [for (final p in s.petShopList) p.id],
        [
          'meo',
          'ca_chep',
          'hac',
          'nghe',
          'huyen_vu',
          'bach_ho',
          'ky_lan',
          'phuong_hoang',
          'rong_thien',
          'kim_long',
        ],
      );
      expect(s.petShopList.where((p) => p.paysPhaLe).length, 7);
    });

    test('enough xu, enough Pha lê, short, closed and owned', () {
      final s = newSession();
      s.state.money = 350000;
      s.state.phaLe = 450;
      expect(petCardState(s, _pet(s, 'ca_chep')), PetCardState.canPayXu);
      expect(petCardState(s, _pet(s, 'hac')), PetCardState.short);
      expect(petCardState(s, _pet(s, 'nghe')), PetCardState.canPayPhaLe);
      expect(petCardState(s, _pet(s, 'kim_long')), PetCardState.short);
      s.state.addPet('ca_chep');
      expect(petCardState(s, _pet(s, 'ca_chep')), PetCardState.owned);
      s.state.phase = DayPhase.open;
      expect(petCardState(s, _pet(s, 'nghe')), PetCardState.closed);
      expect(petCardState(s, _pet(s, 'ca_chep')), PetCardState.owned);
    });

    test('the shortfall uses the game number format', () {
      final s = newSession();
      s.state.money = 0;
      s.state.phaLe = 450;
      expect(s.petShortfall(_pet(s, 'hac')), 500000);
      expect(petShortfallText(_pet(s, 'hac'), 1200000), 'Còn thiếu 1,2tr xu');
      expect(petShortfallText(_pet(s, 'hac'), 150000), 'Còn thiếu 150k xu');
      expect(s.petShortfall(_pet(s, 'kim_long')), 750);
      expect(
        petShortfallText(_pet(s, 'kim_long'), 750),
        'Còn thiếu 750 Pha lê',
      );
      expect(petPriceText(_pet(s, 'kim_long')), '1.200');
      expect(petPriceText(_pet(s, 'ca_chep')), '300k');
      expect(petShortLine(_pet(s, 'ca_chep')), 'Chưa đủ xu');
      expect(petShortLine(_pet(s, 'nghe')), 'Chưa đủ Pha lê');
    });
  });

  group('buying', () {
    test('xu pays a xu pet and empty slots take it', () {
      final s = newSession();
      s.state.money = 300000;
      expect(s.buyPet('ca_chep'), isTrue);
      expect(s.state.money, 0);
      expect(s.state.ownsPet('ca_chep'), isTrue);
      expect(s.state.ownedPet('ca_chep')!.stage, 0);
      expect(s.state.petIncome, 'ca_chep');
      expect(s.state.petCharm, 'ca_chep');
      expect(s.buyPet('ca_chep'), isFalse);
    });

    test('Pha lê pays a Pha lê pet and leaves xu alone', () {
      final s = newSession();
      s.state.money = 5000000;
      s.state.phaLe = 1300;
      expect(s.buyPet('kim_long'), isTrue);
      expect(s.state.phaLe, 100);
      expect(s.state.money, 5000000);
      expect(s.state.ownsPet('kim_long'), isTrue);
    });

    test('not enough xu or Pha lê buys nothing', () {
      final s = newSession();
      s.state.money = 299999;
      s.state.phaLe = 299;
      expect(s.buyPet('ca_chep'), isFalse);
      expect(s.buyPet('nghe'), isFalse);
      expect(s.state.money, 299999);
      expect(s.state.phaLe, 299);
      expect(s.state.pets, isEmpty);
      expect(s.buyPet('nope'), isFalse);
    });

    test('a second pet keeps the first one in both slots', () {
      final s = newSession();
      s.state.hasCat = true;
      s.state.phaLe = 300;
      expect(s.buyPet('nghe'), isTrue);
      expect(s.state.petIncome, catPetId);
      expect(s.state.petCharm, catPetId);
      expect([for (final p in s.state.pets) p.id], [catPetId, 'nghe']);
    });
  });

  group('income-slot effects and caps', () {
    test('the cat catches mice only from the income slot', () {
      final s = newSession();
      s.state.hasCat = true;
      s.state.petStage = 2;
      var fx = PetEffects.of(s.e, s.state);
      expect(fx.mouseCatch, 0.5);
      expect(fx.mouseLossOnMiss, 0.2);
      expect(fx.fightsMice, isTrue);
      expect(fx.name, 'Mèo');

      s.state.addPet('ca_chep');
      s.state.petIncome = 'ca_chep';
      fx = PetEffects.of(s.e, s.state);
      expect(fx.mouseCatch, 0);
      expect(fx.mouseLossOnMiss, 1.0);
      expect(fx.fightsMice, isFalse);
      expect(fx.incomeBonus, 0.004);

      s.state.petIncome = null;
      expect(PetEffects.of(s.e, s.state).incomeBonus, 0);
    });

    test('a pet in the charm slot only does nothing for income', () {
      final s = newSession();
      _income(s.state, 'kim_long');
      s.state.addPet('meo');
      s.state.petCharm = 'meo';
      final fx = PetEffects.of(s.e, s.state);
      expect(fx.name, 'Kim long');
      expect(fx.mouseLossOnMiss, 1.0);
      expect(fx.mouseCatch, 0.15);
    });

    test('Kim long sits at the caps; bigger numbers are cut to them', () {
      final s = newSession();
      _income(s.state, 'kim_long');
      final fx = PetEffects.of(s.e, s.state);
      expect(fx.incomeBonus, 0.05);
      expect(fx.mysteryChance, 0.1);
      expect(s.e.petCaps.incomeBonus, 0.05);
      expect(s.e.petCaps.mysteryChance, 0.1);
      expect(s.e.petCaps.mouseCatch, 0.75);

      const huge = PetDef(
        id: 'x',
        nameVi: 'X',
        rarity: 'huyenThoai',
        price: 1,
        currency: 'phaLe',
        charmBase: 1,
        abilities: {
          'incomeBonus': [0.2, 0.2, 0.2],
          'mysteryChance': [0.5, 0.5, 0.5],
          'mouseCatch': [0.9, 0.9, 0.9],
        },
      );
      const capped = PetEffects(def: huge, stage: 2);
      expect(capped.incomeBonus, 0.05);
      expect(capped.mysteryChance, 0.1);
      expect(capped.mouseCatch, 0.75);
    });

    test('Nghê adds to both theft odds; Huyền vũ adds a fresh day', () {
      final s = newSession();
      _income(s.state, 'nghe');
      expect(s.petEffects.theftRecoverBonus, 0.1);
      expect(
        theftPoliceChance + s.petEffects.theftRecoverBonus,
        closeTo(0.8, 1e-9),
      );
      expect(
        theftChaseChance + s.petEffects.theftRecoverBonus,
        closeTo(0.6, 1e-9),
      );
      final turtle = newSession();
      _income(turtle.state, 'huyen_vu', stage: 1);
      expect(turtle.petEffects.freshnessBonusDays, 0);
      turtle.state.ownedPet('huyen_vu')!.stage = 2;
      expect(turtle.petEffects.freshnessBonusDays, 1);
    });

    test('the income bonus is paid at close, capped at 5%', () {
      ShopSession opened(String? pet) {
        final s = newSession(seed: 7);
        if (pet != null) _income(s.state, pet);
        for (final f in s.unlockedFlowers) {
          if (s.canAddBundle(f.id)) s.addBundle(f.id);
        }
        s.buyAndGoToShop();
        s.openShop();
        return s;
      }

      final s = opened('kim_long');
      s.state.metrics.flowerIncome = 100000;
      s.closeEarly();
      expect(s.state.phase, DayPhase.summary);
      expect(s.state.metrics.petBonus, 5000);

      final bare = opened(null);
      bare.state.metrics.flowerIncome = 100000;
      bare.closeEarly();
      expect(bare.state.metrics.petBonus, 0);
    });

    test('a mystery pet brings extra Khách thần bí days, none without', () {
      int due(String? pet) {
        var n = 0;
        for (var seed = 1; seed <= 300; seed++) {
          final s = newSession(seed: seed);
          s.state.day = 7;
          if (pet != null) _income(s.state, pet);
          s.buyAndGoToShop();
          s.openShop();
          if (s.mysteryVisitorDue) n++;
        }
        return n;
      }

      expect(due(null), 0);
      final rong = due('kim_long');
      expect(rong, greaterThan(10));
      expect(rong, lessThan(60));
    });
  });

  group('save migration', () {
    test('an old save with the cat gets it as a pet in both slots', () {
      final raw = newSession().state.encode();
      final map = jsonDecode(raw) as Map<String, Object?>
        ..remove('pets')
        ..remove('petIncome')
        ..remove('petCharm')
        ..['hasCat'] = true
        ..['petStage'] = 2
        ..['petProgress'] = 40
        ..['petFedDay'] = 9;
      final loaded = GameState.decode(jsonEncode(map))!;
      expect([for (final p in loaded.pets) p.id], [catPetId]);
      expect(loaded.ownedPet(catPetId)!.stage, 2);
      expect(loaded.ownedPet(catPetId)!.progress, 40);
      expect(loaded.ownedPet(catPetId)!.fedDay, 9);
      expect(loaded.petIncome, catPetId);
      expect(loaded.petCharm, catPetId);
      expect(loaded.hasCat, isTrue);
    });

    test('an old save without the cat has no pets and empty slots', () {
      final loaded = GameState.decode(newSession().state.encode())!;
      expect(loaded.pets, isEmpty);
      expect(loaded.petIncome, isNull);
      expect(loaded.petCharm, isNull);
    });

    test('pets and slots survive a round trip; legacy cat keys stay', () {
      final state = newSession().state;
      state.hasCat = true;
      state.addPet('nghe', fedDay: 3);
      state.ownedPet('nghe')!
        ..stage = 1
        ..progress = 50;
      state.petIncome = 'nghe';
      final raw = state.encode();
      final json = jsonDecode(raw) as Map<String, Object?>;
      expect(json['hasCat'], isTrue);
      final loaded = GameState.decode(raw)!;
      expect([for (final p in loaded.pets) p.id], [catPetId, 'nghe']);
      expect(loaded.ownedPet('nghe')!.stage, 1);
      expect(loaded.ownedPet('nghe')!.progress, 50);
      expect(loaded.ownedPet('nghe')!.fedDay, 3);
      expect(loaded.petIncome, 'nghe');
      expect(loaded.petCharm, catPetId);
    });

    test('a slot naming a pet the save does not own is dropped', () {
      final raw = newSession().state.encode();
      final map = jsonDecode(raw) as Map<String, Object?>
        ..['pets'] = [
          {'id': 'hac', 'stage': 0, 'progress': 0, 'fedDay': 0},
        ]
        ..['petIncome'] = 'rong_thien'
        ..['petCharm'] = 'hac';
      final loaded = GameState.decode(jsonEncode(map))!;
      expect(loaded.petIncome, isNot('rong_thien'));
      expect(loaded.petCharm, 'hac');
    });
  });

  group('typed gifts', () {
    test('gift key nghe is the pot, pet:nghe is the pet', () {
      final pot = RewardBundle.fromGiftItems({'nghe': 2});
      expect(pot.items, [const RewardItem.pot('nghe', 2)]);
      final pet = RewardBundle.fromGiftItems({'pet:nghe': 1});
      expect(pet.items, [const RewardItem.pet('nghe')]);
      expect(pet.toGiftItems(), {'pet:nghe': 1});
      expect(petGiftKey('nghe'), 'pet:nghe');
      expect(petGiftKey(catPetId), giftCat);
      expect(sanitizeGiftItems({'pet:nghe': 5, 'nghe': 3}), {
        'pet:nghe': 1,
        'nghe': 3,
      });
    });

    test('mail carries the kind; old pot mail stays a pot', () {
      final pet = RewardItem.fromJson({
        'kind': 'pet',
        'id': 'nghe',
        'amount': 1,
      });
      expect(pet, const RewardItem.pet('nghe'));
      expect(pet!.toJson(), {'kind': 'pet', 'id': 'nghe', 'amount': 1});
      final pot = RewardItem.fromJson({
        'kind': 'pot',
        'id': 'nghe',
        'amount': 1,
      });
      expect(pot, const RewardItem.pot('nghe'));
      expect(RewardItem.fromJson({'id': 'nghe', 'amount': 1}), isNull);
    });

    test('a pet gift adds the pet once; the pot gift adds a pot', () {
      final state = newSession().state;
      final first = applyRewards(
        state,
        RewardBundle(const [RewardItem.pet('nghe'), RewardItem.pot('nghe')]),
      );
      expect(first.granted.items.length, 2);
      expect(state.ownsPet('nghe'), isTrue);
      expect(state.potCounts['nghe'], 1);
      expect(state.petIncome, 'nghe');
      final again = applyRewards(
        state,
        RewardBundle(const [RewardItem.pet('nghe'), RewardItem.pet('rong')]),
      );
      expect(again.granted.items, isEmpty);
      expect(again.skipped.length, 2);
      expect(state.pets.length, 1);
    });

    test('an admin gift box with pet:kim_long gives Kim long', () {
      final state = newSession().state;
      applyRewards(
        state,
        giftBundle(
          const PetGiftBox(
            id: 'box-k',
            items: {'pet:kim_long': 1, 'dragon': 1},
          ),
          appliedId: null,
        )!,
      );
      expect(state.ownsPet('kim_long'), isTrue);
      expect(state.potCounts['dragon'], 1);
    });
  });

  group('copy', () {
    test('stat lines follow Nhất, by stage', () {
      final s = newSession();
      expect(
        petAbilityLine(_pet(s, 'nghe')),
        'Bắt chuột +10%, Lấy lại tiền khi bị trộm +10%',
      );
      expect(
        petAbilityLine(_pet(s, 'bach_ho'), stage: 1),
        'Bắt chuột +10,5%, Thu nhập +0,7%',
      );
      expect(petAbilityLine(_pet(s, 'hac')), 'Khách chờ lâu hơn 3%');
      expect(petAbilityLine(_pet(s, 'huyen_vu')), 'Hoa tươi thêm 1 ngày');
      expect(petAbilityLine(_pet(s, 'huyen_vu'), stage: 0), '');
      expect(petAbilityLine(_pet(s, 'ky_lan')), 'Khách thần bí ghé thêm 3%');
      expect(petAbilityLine(_pet(s, 'meo')), 'Bắt chuột +50%');
    });

    testWidgets('a long line ends with · +N', (tester) async {
      final s = newSession();
      final parts = petAbilityParts(_pet(s, 'kim_long'));
      expect(parts.length, 3);
      const style = TextStyle(fontSize: 12);
      final short = fitAbilityLine(parts, style, 120);
      expect(short, matches(RegExp(r' · \+[12]$')));
      expect(fitAbilityLine(parts, style, 2000), parts.join(', '));
    });
  });

  group('shop screen', () {
    Future<void> pumpShop(WidgetTester tester, ShopSession s) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      s.state.day = strayCatDay;
      s.openPetCatalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: PetCatalogPopup(session: s)),
        ),
      );
      await tester.pump();
    }

    testWidgets('a grey price button explains what is missing', (tester) async {
      final s = newSession();
      s.state.money = 100000;
      s.state.phaLe = 0;
      await pumpShop(tester, s);
      expect(find.byKey(const Key('pet-hint-ca_chep')), findsOneWidget);
      expect(find.text('Chưa đủ xu'), findsWidgets);
      await tester.tap(find.byKey(const Key('pet-buy-ca_chep')));
      await tester.pump();
      expect(find.text('Còn thiếu 200k xu'), findsOneWidget);
      expect(find.byKey(const Key('pet-confirm')), findsNothing);
      expect(s.state.ownsPet('ca_chep'), isFalse);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('buying with Pha lê shows the popup, the toast and Vào phòng', (
      tester,
    ) async {
      final s = newSession();
      s.state.phaLe = 450;
      await pumpShop(tester, s);
      await tester.scrollUntilVisible(
        find.byKey(const Key('pet-buy-nghe')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('pet-buy-nghe')));
      await tester.pump();
      expect(find.text('Đón Nghê về tiệm?'), findsOneWidget);
      expect(
        find.text(
          'Bắt chuột +10%, Lấy lại tiền khi bị trộm +10%. '
          'Bé sẽ lớn dần khi được cho ăn bánh mật.',
        ),
        findsOneWidget,
      );
      expect(find.text('Để sau'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pet-confirm-yes')));
      await tester.pump();
      expect(s.state.phaLe, 150);
      expect(find.text('Nghê đã về tiệm rồi!'), findsOneWidget);
      expect(find.byKey(const Key('pet-owned-nghe')), findsOneWidget);
      expect(find.byKey(const Key('pet-income-nghe')), findsOneWidget);
      expect(find.byKey(const Key('pet-charm-nghe')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pet-room-nghe')));
      await tester.pump();
      expect(s.petCatalogOpen, isFalse);
      expect(s.screen, Screen.pets);
      expect(s.roomPet!.id, 'nghe');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Để sau keeps the money', (tester) async {
      final s = newSession();
      s.state.money = 300000;
      await pumpShop(tester, s);
      await tester.tap(find.byKey(const Key('pet-buy-ca_chep')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pet-confirm-later')));
      await tester.pump();
      expect(find.byKey(const Key('pet-confirm')), findsNothing);
      expect(s.state.money, 300000);
      expect(s.state.ownsPet('ca_chep'), isFalse);
    });

    testWidgets('the room shows the chosen pet', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = newSession();
      s.state.hasCat = true;
      s.state.addPet('ca_chep');
      s.state.biscuits = 1;
      s.openPetRoom('ca_chep');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: PetScreen(session: s)),
        ),
      );
      await tester.pump();
      expect(find.text('Cá chép đang đói'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pet-feed')));
      await tester.pump();
      expect(s.state.ownedPet('ca_chep')!.progress, 25);
      expect(s.state.petProgress, 0);
    });

    testWidgets('tapping the pet in the room switches the one in use', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = newSession();
      s.state.hasCat = true;
      s.state.addPet('ca_chep');
      s.openPetRoom('ca_chep');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: PetScreen(session: s)),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('pet-cat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pet-pick-meo')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pet-pick-meo')));
      await tester.pumpAndSettle();
      expect(s.roomPet!.id, 'meo');
      expect(s.state.petIncome, 'meo');
      expect(find.text('Mèo · Ấu thú'), findsOneWidget);
    });
  });
}
