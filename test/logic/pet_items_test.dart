import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/pet_items.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// The shipped economy plus two broken item entries: a tier that does not
/// exist, and a repeat of an id with another tier.
String _economyWithItems() {
  final json =
      jsonDecode(File('assets/data/economy.json').readAsStringSync())
          as Map<String, dynamic>;
  final list = (json['petItems'] as Map)['list'] as List;
  list
    ..add({'id': 'no_tier', 'rarity': 'khong_co', 'slot': 'head'})
    ..add({'id': 'no_co_vai', 'rarity': 'huyenThoai', 'slot': 'neck'});
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
    test('the tiers and slots are the decided ones', () {
      final s = newSession();
      expect(s.e.petItemRules.slots, ['neck', 'head', 'accessory']);
      expect(s.e.petItemRules.charmOfTier(PetItemTier.thuong), 5);
      expect(s.e.petItemRules.charmOfTier(PetItemTier.hiem), 15);
      expect(s.e.petItemRules.charmOfTier(PetItemTier.suThi), 40);
      expect(s.e.petItemRules.charmOfTier(PetItemTier.huyenThoai), 100);
      expect(s.e.petItemResaleRate, 0.3);
    });

    test('the 12 approved items: slot, tier, price, resale, Nhất names', () {
      final s = newSession();
      // id: (name, slot, tier, price, currency, resale)
      const table = {
        'no_co_vai': (
          'Nơ cổ vải',
          'neck',
          PetItemTier.thuong,
          2000000,
          'coins',
          600000,
        ),
        'vong_hoa_nho': (
          'Vòng hoa cài cổ',
          'neck',
          PetItemTier.hiem,
          20000000,
          'coins',
          6000000,
        ),
        'chuong_ngoc': (
          'Chuông ngọc',
          'neck',
          PetItemTier.suThi,
          120,
          'phaLe',
          36,
        ),
        'day_chuyen_suong_mai': (
          'Dây chuyền sương mai',
          'neck',
          PetItemTier.huyenThoai,
          300,
          'phaLe',
          90,
        ),
        'mu_rom': (
          'Mũ rơm',
          'head',
          PetItemTier.thuong,
          2000000,
          'coins',
          600000,
        ),
        'vong_hoa_doi_dau': (
          'Vòng hoa đội đầu',
          'head',
          PetItemTier.hiem,
          20000000,
          'coins',
          6000000,
        ),
        'mao_lua': ('Mão lụa', 'head', PetItemTier.suThi, 120, 'phaLe', 36),
        'vuong_mien_som_mai': (
          'Vương miện Sớm Mai',
          'head',
          PetItemTier.huyenThoai,
          300,
          'phaLe',
          90,
        ),
        'tui_vai_nho': (
          'Túi thêu nhỏ',
          'accessory',
          PetItemTier.thuong,
          2000000,
          'coins',
          600000,
        ),
        'canh_buom': (
          'Cánh bướm',
          'accessory',
          PetItemTier.hiem,
          20000000,
          'coins',
          6000000,
        ),
        'long_den_ngoc': (
          'Lồng đèn ngọc',
          'accessory',
          PetItemTier.suThi,
          120,
          'phaLe',
          36,
        ),
        'canh_binh_minh': (
          'Cánh bình minh',
          'accessory',
          PetItemTier.huyenThoai,
          300,
          'phaLe',
          90,
        ),
      };
      expect(s.e.petItems.length, table.length);
      for (final e in table.entries) {
        final d = s.e.petItem(e.key)!;
        expect(
          (d.nameVi, d.slot, d.tier, d.price, d.currency, d.resaleValue),
          e.value,
          reason: e.key,
        );
        // the resale value is 30% of the price
        expect(d.resaleValue, (d.price * 0.3).floor(), reason: e.key);
        expect(d.description, isNotEmpty);
        expect(d.description.length, lessThanOrEqualTo(63), reason: e.key);
      }
      // three items per slot, one per tier
      for (final slot in s.e.petItemRules.slots) {
        expect(
          s.e.petItems.where((i) => i.slot == slot).map((i) => i.tier).toSet(),
          PetItemTier.values.toSet(),
          reason: slot,
        );
      }
      expect(s.e.petItems.map((i) => i.nameVi).toSet().length, 12);
    });

    test('a bad entry or a repeated id is skipped, not fatal', () {
      final s = _session();
      expect(s.e.petItems.length, 12);
      expect(s.e.petItems.map((i) => i.id).toSet().length, 12);
      expect(s.e.petItem('no_co_vai')!.tier, PetItemTier.thuong);
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
        items: {'vong_hoa_nho': 1, 'mao_lua': 1, 'canh_binh_minh': 1},
      );
      s.state.petCharm = 'nghe';
      s.state.ownedPet('nghe')!.stage = 1; // 45
      expect(s.charmScore, 45);
      expect(s.wearPetItem('nghe', 'vong_hoa_nho'), PetItemResult.worn);
      expect(s.charmScore, 60);
      expect(s.wearPetItem('nghe', 'mao_lua'), PetItemResult.worn);
      expect(s.charmScore, 100);
      expect(s.wearPetItem('nghe', 'canh_binh_minh'), PetItemResult.worn);
      expect(s.charmScore, 200);
      expect(s.petItemCharm('nghe'), 155);
      expect(s.state.ownedPet('nghe')!.worn, {
        'neck': 'vong_hoa_nho',
        'head': 'mao_lua',
        'accessory': 'canh_binh_minh',
      });
    });

    test(
      'a new item replaces the one in its slot, the old one is free again',
      () {
        final s = _session(items: {'no_co_vai': 1, 'vong_hoa_nho': 1});
        expect(s.wearPetItem('nghe', 'no_co_vai'), PetItemResult.worn);
        expect(s.petItemCharm('nghe'), 5);
        expect(s.wearPetItem('nghe', 'no_co_vai'), PetItemResult.already);
        expect(s.wearPetItem('nghe', 'vong_hoa_nho'), PetItemResult.worn);
        expect(s.petItemCharm('nghe'), 15);
        expect(s.petItemWorn('no_co_vai'), 0);
        expect(s.wearPetItem('ca_chep', 'no_co_vai'), PetItemResult.worn);
      },
    );

    test('one copy cannot be worn by two pets; a second copy can', () {
      final s = _session(items: {'mao_lua': 1});
      expect(s.wearPetItem('nghe', 'mao_lua'), PetItemResult.worn);
      expect(s.wearPetItem('ca_chep', 'mao_lua'), PetItemResult.noneLeft);
      s.state.petItems['mao_lua'] = 2;
      expect(s.wearPetItem('ca_chep', 'mao_lua'), PetItemResult.worn);
      expect(s.petItemWorn('mao_lua'), 2);
    });

    test('refusals: not owned pet, unknown item, item not in the bag', () {
      final s = _session(items: {'no_co_vai': 1});
      expect(s.wearPetItem('kim_long', 'no_co_vai'), PetItemResult.notOwned);
      expect(s.wearPetItem('nghe', 'nope'), PetItemResult.unknownItem);
      expect(s.wearPetItem('nghe', 'vong_hoa_nho'), PetItemResult.noneLeft);
      expect(s.state.ownedPet('nghe')!.worn, isEmpty);
    });

    test('taking an item off', () {
      final s = _session(items: {'no_co_vai': 1});
      s.wearPetItem('nghe', 'no_co_vai');
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
        'head': 'vong_hoa_nho', // a neck item in the head slot
        'wing': 'canh_binh_minh', // not a slot of this game
      });
      expect(s.petItemCharm('nghe'), 0);
      s.state.petCharm = 'nghe';
      expect(s.charmScore, 30);
    });
  });

  group('buying and selling', () {
    test('xu items pay xu, Pha lê items pay Pha lê', () {
      final s = _session();
      s.state.money = 30000000;
      s.state.phaLe = 500;
      expect(s.buyPetItem('no_co_vai'), PetItemTrade.bought);
      expect(s.state.money, 28000000);
      expect(s.buyPetItem('vong_hoa_nho'), PetItemTrade.bought);
      expect(s.state.money, 8000000);
      expect(s.buyPetItem('mao_lua'), PetItemTrade.bought);
      expect(s.state.phaLe, 380);
      expect(s.buyPetItem('vuong_mien_som_mai'), PetItemTrade.bought);
      expect(s.state.phaLe, 80);
      expect(s.state.petItems, {
        'no_co_vai': 1,
        'vong_hoa_nho': 1,
        'mao_lua': 1,
        'vuong_mien_som_mai': 1,
      });
      expect(s.state.money, 8000000);
    });

    test('not enough money buys nothing and costs nothing', () {
      final s = _session();
      s.state.money = 1999999;
      s.state.phaLe = 299;
      expect(s.buyPetItem('no_co_vai'), PetItemTrade.short);
      expect(s.buyPetItem('canh_binh_minh'), PetItemTrade.short);
      expect(s.petItemShortfall(s.e.petItem('no_co_vai')!), 1);
      expect(s.petItemShortfall(s.e.petItem('canh_binh_minh')!), 1);
      expect(s.buyPetItem('nope'), PetItemTrade.unknownItem);
      expect((s.state.money, s.state.phaLe), (1999999, 299));
      expect(s.state.petItems, isEmpty);
    });

    test('copies are not limited (up to 99) and each is its own wearer', () {
      final s = _session();
      s.state.money = s.e.petItem('mu_rom')!.price * 3;
      for (var i = 0; i < 3; i++) {
        expect(s.buyPetItem('mu_rom'), PetItemTrade.bought);
      }
      expect(s.petItemOwned('mu_rom'), 3);
      expect(s.wearPetItem('nghe', 'mu_rom'), PetItemResult.worn);
      expect(s.wearPetItem('ca_chep', 'mu_rom'), PetItemResult.worn);
      expect(s.petItemWorn('mu_rom'), 2);
      s.state.petItems['mu_rom'] = maxGiftCount;
      s.state.money = 999999;
      expect(s.buyPetItem('mu_rom'), PetItemTrade.noCopies);
      expect(s.state.money, 999999);
    });

    test('the shop must be closed, like the pet shop', () {
      final s = _session();
      s.state.money = 999999;
      s.state.phase = DayPhase.open;
      expect(s.buyPetItem('no_co_vai'), PetItemTrade.shopOpen);
      s.state.petItems['no_co_vai'] = 1;
      expect(s.sellPetItem('no_co_vai'), PetItemTrade.shopOpen);
      expect(s.state.money, 999999);
    });

    test('selling pays 30% of the price in the same currency', () {
      final s = _session();
      s.state.petItems.addAll({
        'no_co_vai': 1,
        'vong_hoa_nho': 1,
        'chuong_ngoc': 1,
        'day_chuyen_suong_mai': 1,
      });
      s.state.money = 0;
      s.state.phaLe = 0;
      expect(s.petItemSellPrice('vong_hoa_nho'), 6000000);
      expect(s.sellPetItem('no_co_vai'), PetItemTrade.sold);
      expect(s.sellPetItem('vong_hoa_nho'), PetItemTrade.sold);
      expect(s.state.money, 6600000);
      expect(s.sellPetItem('chuong_ngoc'), PetItemTrade.sold);
      expect(s.sellPetItem('day_chuyen_suong_mai'), PetItemTrade.sold);
      expect(s.state.phaLe, 126);
      expect(s.state.petItems, isEmpty);
      expect(s.sellPetItem('mao_lua'), PetItemTrade.noCopies);
      expect(s.sellPetItem('nope'), PetItemTrade.unknownItem);
    });

    test('resale is the rate times the CURRENT price, not the file value', () {
      const def = PetItemDef(
        id: 'x',
        nameVi: 'x',
        tier: PetItemTier.thuong,
        slot: 'head',
        price: 1000000,
        resaleValue: 123,
      );
      expect(petItemSellValue(def, 0.3), 300000);
      const pl = PetItemDef(
        id: 'y',
        nameVi: 'y',
        tier: PetItemTier.suThi,
        slot: 'head',
        price: 120,
        currency: 'phaLe',
      );
      expect(petItemSellValue(pl, 0.3), 36);
      expect(petItemSellValue(pl, 0.5), 60);
    });

    test('a worn copy is not sold; a spare one is', () {
      final s = _session(items: {'mao_lua': 2});
      s.state.phaLe = 0;
      s.wearPetItem('nghe', 'mao_lua');
      expect(s.sellPetItem('mao_lua'), PetItemTrade.sold);
      expect(s.state.phaLe, 36);
      expect(s.petItemOwned('mao_lua'), 1);
      expect(s.sellPetItem('mao_lua'), PetItemTrade.allWorn);
      expect(s.state.phaLe, 36);
      expect(s.petItemCharm('nghe'), 40);
      s.unwearPetItem('nghe', 'head');
      expect(s.sellPetItem('mao_lua'), PetItemTrade.sold);
      expect(s.state.petItems, isEmpty);
    });

    test('a copy that came as a reward sells for the same 30%', () {
      final s = _session();
      s.state.money = 0;
      s.grantRewards(
        RewardBundle([const RewardItem.petItem('canh_buom')]),
        source: RewardSource.mailbox,
      );
      expect(s.petItemOwned('canh_buom'), 1);
      expect(s.sellPetItem('canh_buom'), PetItemTrade.sold);
      expect(s.state.money, 6000000);
    });

    test('buying and selling are saved at once', () async {
      final fresh = _session();
      fresh.state.money = 40000000;
      final raw = fresh.state.encode();
      final backing = <String, String>{};
      await ProgressStore.memory(backing).save(GameState.decode(raw)!);
      final s = newSession(
        data: loadTestData(economy: _economyWithItems()),
        backing: backing,
        saved: GameState.decode(raw),
      );
      expect(s.buyPetItem('vong_hoa_nho'), PetItemTrade.bought);
      expect(s.buyPetItem('vong_hoa_nho'), PetItemTrade.bought);
      await s.pendingSaves;
      var saved = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(saved.petItems, {'vong_hoa_nho': 2});
      expect(saved.money, 0);
      expect(s.sellPetItem('vong_hoa_nho'), PetItemTrade.sold);
      await s.pendingSaves;
      saved = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(saved.petItems, {'vong_hoa_nho': 1});
      expect(saved.money, 6000000);
    });
  });

  group('rewards and gifts', () {
    test('a petItem reward stacks copies; duplicates are fine', () {
      final s = _session();
      final r = s.grantRewards(
        RewardBundle([
          const RewardItem.petItem('mao_lua'),
          const RewardItem.petItem('mao_lua', 2),
          const RewardItem.petItem('nope'),
        ]),
        source: RewardSource.mailbox,
      );
      expect(s.petItemOwned('mao_lua'), 3);
      expect(s.petItemOwned('nope'), 0);
      expect(r.amountOf(RewardKind.petItem, 'mao_lua'), 3);
    });

    test('the reward JSON and the admin gift key round trip', () {
      const item = RewardItem.petItem('mao_lua', 2);
      expect(RewardItem.fromJson(item.toJson()), item);
      expect(RewardItem.fromJson({'kind': 'petItem', 'amount': 1}), isNull);
      final bundle = RewardBundle([item]);
      expect(bundle.toGiftItems(), {'item:mao_lua': 2});
      expect(RewardBundle.fromGiftItems({'item:mao_lua': 2}), bundle);
      expect(petItemIdOfGiftKey('item:mao_lua'), 'mao_lua');
      expect(petItemIdOfGiftKey('mao_lua'), isNull);
      // an item never reads as a pot or a pet
      expect(petIdOfGiftKey('item:mao_lua'), isNull);
    });

    test('every item is a gift kind that matches the rules', () {
      final s = newSession();
      final rules = File('firestore.rules').readAsStringSync();
      for (final item in s.e.petItems) {
        final kind = giftKind(petItemGiftKey(item.id))!;
        expect(kind.name, item.nameVi);
        expect(kind.art, GiftArt.item);
        expect(kind.cap, maxGiftCount);
        expect(rules, contains("'item:${item.id}'"));
      }
      expect(
        giftCatalog.where((k) => k.art == GiftArt.item).length,
        s.e.petItems.length,
      );
    });
  });

  group('save', () {
    test('worn items and the bag survive a round trip', () {
      final s = _session(items: {'vong_hoa_nho': 2, 'mao_lua': 1});
      s.wearPetItem('nghe', 'vong_hoa_nho');
      s.wearPetItem('nghe', 'mao_lua');
      final back = GameState.decode(s.state.encode())!;
      expect(back.petItems, {'vong_hoa_nho': 2, 'mao_lua': 1});
      expect(back.ownedPet('nghe')!.worn, {
        'neck': 'vong_hoa_nho',
        'head': 'mao_lua',
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
      final fresh = _session(items: {'mao_lua': 1});
      final raw = fresh.state.encode();
      final backing = <String, String>{};
      await ProgressStore.memory(backing).save(GameState.decode(raw)!);
      final s = newSession(
        data: loadTestData(economy: _economyWithItems()),
        backing: backing,
        saved: GameState.decode(raw),
      );
      expect(s.wearPetItem('nghe', 'mao_lua'), PetItemResult.worn);
      await s.pendingSaves;
      final saved = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(saved.ownedPet('nghe')!.worn, {'head': 'mao_lua'});
      expect(saved.petItems, {'mao_lua': 1});
    });
  });
}
