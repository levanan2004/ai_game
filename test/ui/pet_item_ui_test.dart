import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/pet_item_room.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/pet_item_shop.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

ShopSession _room({Map<String, int> items = const {}}) {
  final s = newSession();
  s.state.day = strayCatDay;
  s.state.hasCat = true;
  s.state.addPet('meo');
  s.state.petItems.addAll(items);
  s.state.money = 100000000;
  s.openPetRoom('meo');
  return s;
}

Future<void> _pump(WidgetTester tester, ShopSession s) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          PetScreen(session: s),
          ListenableBuilder(
            listenable: s,
            builder: (context, _) => s.petItemGift == null
                ? const SizedBox()
                : PetItemGiftPopup(session: s),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadTestFonts);
  testWidgets('empty slot opens the picker with its empty block', (
    tester,
  ) async {
    final s = _room();
    await _pump(tester, s);
    expect(find.byKey(const Key('pet-charm-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pet-slot-neck')));
    await tester.pump();
    expect(find.byKey(const Key('item-pick')), findsOneWidget);
    expect(find.byKey(const Key('item-pick-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('item-pick-empty-cta')));
    await tester.pump();
    expect(s.petItemShopOpen, isTrue);
  });

  testWidgets('wearing raises Mị lực and never happens by itself', (
    tester,
  ) async {
    final s = _room(items: {'chuong_ngoc': 2});
    await _pump(tester, s);
    expect(s.petItemWornBy('chuong_ngoc'), isNull);
    final before = s.petItemCharm('meo');
    await tester.tap(find.byKey(const Key('pet-slot-neck')));
    await tester.pump();
    expect(find.byKey(const Key('item-card-chuong_ngoc')), findsOneWidget);
    await tester.tap(find.byKey(const Key('item-card-chuong_ngoc')));
    await tester.pump();
    expect(find.byKey(const Key('item-detail-count')), findsOneWidget);
    await tester.tap(find.byKey(const Key('item-wear')));
    await tester.pump();
    expect(s.petItemWornBy('chuong_ngoc'), 'Mèo');
    expect(s.petItemCharm('meo'), before + 40);
  });

  testWidgets('selling asks first, a single worn copy cannot be sold', (
    tester,
  ) async {
    final s = _room(items: {'mu_rom': 2, 'no_co_vai': 1});
    s.state.ownedPet('meo')!.worn['head'] = 'mu_rom';
    await _pump(tester, s);
    await tester.tap(find.byKey(const Key('pet-slot-head')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('item-card-mu_rom')));
    await tester.pump();
    final money = s.state.money;
    await tester.tap(find.byKey(const Key('item-sell')));
    await tester.pump();
    expect(find.byKey(const Key('item-sell-title')), findsOneWidget);
    expect(s.state.money, money, reason: 'nothing sold before the confirm');
    await tester.tap(find.byKey(const Key('item-sell-yes')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // the toast
    expect(s.state.petItems['mu_rom'], 1);
    expect(s.state.money, money + s.petItemSellPrice('mu_rom'));
    // The last copy is on the pet: it cannot be sold any more.
    expect(s.petItemCounts('mu_rom').spare, 0);
    expect(s.openPetItemSell('mu_rom'), isFalse);
  });

  testWidgets('a duplicate gift sells its spare at once, new one stays', (
    tester,
  ) async {
    final s = _room(items: {'canh_binh_minh': 2});
    s.petItemGifts.add(
      const PetItemGift(
        itemId: 'canh_binh_minh',
        kind: PetItemGiftKind.mystery,
      ),
    );
    await _pump(tester, s);
    expect(find.byKey(const Key('item-gift')), findsOneWidget);
    expect(find.byKey(const Key('item-gift-dup')), findsOneWidget);
    final money = s.state.money;
    final sell = s.petItemSellPrice('canh_binh_minh');
    final phale = s.state.phaLe;
    await tester.tap(find.byKey(const Key('item-gift-sell')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // the toast
    expect(s.state.petItems['canh_binh_minh'], 1);
    expect(s.state.money, money, reason: 'legendary pays Pha lê, not xu');
    expect(s.state.phaLe, phale + sell);
    expect(s.petItemWornBy('canh_binh_minh'), isNull);
  });
}
