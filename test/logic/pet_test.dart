import 'dart:io';

import 'package:ai_game/data/game_data.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/event_popup.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/pet_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('biscuits fill the bar and a drop raises the stage', () {
    final s = newSession();
    s.state.hasCat = true;
    s.state.biscuits = 5;
    s.state.drops = 110;
    s.state.day = 3;
    expect(s.petHungry, isTrue);
    expect(s.feedPet(), 'nang');
    expect(s.state.petProgress, 25);
    expect(s.petHungry, isFalse);
    s.feedPet();
    s.feedPet();
    expect(s.feedPet(), 'nang');
    expect(s.state.petProgress, 100);
    expect(s.state.biscuits, 1);
    expect(s.feedPet(), 'an');
    expect(s.state.petProgress, 100);
    expect(s.breakthroughPet(), 'dotpha');
    expect(s.state.petStage, 1);
    expect(s.state.petProgress, 0);
    expect(s.state.drops, 100);

    s.state.petProgress = 100;
    expect(s.breakthroughPet(), 'dotpha');
    expect(s.state.petStage, 2);
    expect(s.state.drops, 0);
    expect(s.breakthroughPet(), isNull);
    s.state.biscuits = 1;
    expect(s.feedPet(), isNull);
    s.state.biscuits = 3;
    expect(s.feedPet(), 'an');
    expect(s.state.biscuits, 0);
    expect(s.state.petProgress, 0);
  });

  test('an older stone save still breaks through as giọt hoa', () {
    final s = newSession();
    s.state.hasCat = true;
    s.state.petProgress = 100;
    s.state.stones = 10;
    expect(s.breakthroughPet(), 'dotpha');
    expect(s.state.petStage, 1);
    expect(s.state.stones, 0);
    expect(s.state.drops, 0);
  });

  test('a bigger cat eats more biscuits per meal', () {
    expect(biscuitsToEat(0), 1);
    expect(biscuitsToEat(1), 2);
    expect(biscuitsToEat(2), 3);
    final s = newSession();
    s.state.hasCat = true;
    s.state.petStage = 1;
    s.state.biscuits = 2;
    s.state.day = 4;
    expect(s.feedPet(), 'nang');
    expect(s.state.biscuits, 0);
    expect(s.state.petProgress, 25);
    expect(s.petHungry, isFalse);
  });

  test('a gift adds the cat once and stacks treats', () {
    final state = newSession().state
      ..hasCat = false
      ..petSeats = []
      ..petBowls = []
      ..petSeat = null
      ..petBowl = null;
    final biscuits = state.biscuits;
    final drops = state.drops;
    final first = applyRewards(
      state,
      giftBundle(
        const PetGiftBox(
          id: 'box-1',
          items: {giftCat: 1, giftBiscuit: 3, giftSeat: 1, giftBowl: 1},
        ),
        appliedId: null,
      )!,
    );
    state.appliedGiftId = 'box-1';
    expect(state.hasCat, isTrue);
    expect(state.biscuits, biscuits + 3);
    expect(state.petSeats, [giftSeat]);
    expect(state.petBowls, [giftBowl]);
    expect(first.skipped, isEmpty);
    expect(
      giftGrantedLine(first.granted),
      'Nhận quà: Mèo, Bánh mật ×3, Đệm xanh, Bát lá.',
    );

    final again = giftBundle(
      const PetGiftBox(id: 'box-1', items: {giftBiscuit: 3}),
      appliedId: state.appliedGiftId,
    );
    expect(again, isNull);

    final extra = applyRewards(
      state,
      giftBundle(
        const PetGiftBox(
          id: 'box-2',
          items: {giftCat: 1, giftBiscuit: 2, giftDrop: 1},
        ),
        appliedId: state.appliedGiftId,
      )!,
    );
    expect(state.biscuits, biscuits + 5);
    expect(state.drops, drops + 1);
    expect(extra.skipped, [const RewardItem.cat()]);
    expect(extra.granted.amountOf(RewardKind.cat), 0);
  });

  test('a gift adds pots and xu on top of what the shop has', () {
    final state = newSession().state..hasCat = true;
    final money = state.money;
    final biscuits = state.biscuits;
    final effect = applyRewards(
      state,
      giftBundle(
        const PetGiftBox(
          id: 'box-pots',
          items: {'dragon': 2, giftXu: 50000, giftBiscuit: 1},
        ),
        appliedId: null,
      )!,
    );
    expect(state.potCounts['dragon'], 2);
    expect(state.money, money + 50000);
    expect(state.biscuits, biscuits + 1);
    expect(
      giftGrantedLine(effect.granted),
      'Nhận quà: Bánh mật, Chậu rồng thiên ×2, Xu 50k.',
    );

    final pocket = PetPocket.fromProgress({
      'money': 12000,
      'potCounts': {'dragon': 1, 'sage': 4, 'nope': 3},
    });
    expect(pocket.countOf(giftXu), 12000);
    expect(pocket.countOf('dragon'), 1);
    expect(pocket.countOf('sage'), 0);
  });

  test('gift pots stay the paid pots from the economy', () async {
    final data = await GameData.load();
    final paid = [
      // Catalog-only pots (price 0, dot 2) cannot be gifted until decided.
      for (final pot in data.economy.pots)
        if (pot.purchasable) pot,
    ];
    final gifted = [
      for (final kind in giftCatalog)
        if (kind.art == GiftArt.pot) kind,
    ];
    expect(
      [for (final kind in gifted) kind.id],
      [for (final pot in paid) pot.id],
    );
    expect(
      [for (final kind in gifted) kind.name],
      [for (final pot in paid) pot.nameVi],
    );
    final rules = File('firestore.rules').readAsStringSync();
    for (final kind in giftCatalog) {
      expect(rules, contains("'${kind.id}'"));
    }
  });

  test('a waiting gift keeps its items when another shipment is added', () {
    final merged = combineGiftItems(
      {giftBiscuit: 2, giftCat: 1},
      {giftBiscuit: 3, giftCat: 1, giftDrop: 1},
    );
    expect(merged[giftBiscuit], 5);
    expect(merged[giftCat], 1);
    expect(merged[giftDrop], 1);
    expect(giftFormError(const {}, note: ''), 'Chọn ít nhất một quà.');
  });

  test('an old save has no pet', () {
    final raw = newSession().state.encode();
    expect(raw, isNot(contains('hasCat')));
    final loaded = GameState.decode(raw)!;
    expect(loaded.hasCat, isFalse);
    expect(loaded.biscuits, 0);
    expect(loaded.petSeats, [giftSeat]);
    expect(loaded.petBowls, [giftBowl]);
    expect(loaded.petSeat, giftSeat);
    expect(loaded.petBowl, giftBowl);
  });

  testWidgets('cho ăn raises the bar on the pet screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession();
    s.state.hasCat = true;
    s.state.biscuits = 1;
    s.state.petSeats = [giftSeat];
    s.state.petSeat = giftSeat;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PetScreen(session: s)),
      ),
    );
    await tester.pump();
    expect(find.text('Mèo đang đói'), findsOneWidget);
    // Cost on the button, owned count on its own line.
    expect(find.text('Cho ăn (-1)'), findsOneWidget);
    expect(find.text('Bánh mật: 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pet-feed')));
    await tester.pump();
    expect(s.state.petProgress, 25);
    expect(find.text('Tiến trình 25%'), findsOneWidget);
    expect(find.text('Bánh mật: 0'), findsOneWidget);
  });

  test('mouse damage is doubled and a cat cuts it by stage', () {
    expect(mouseWantedStems(5), 4);
    expect(mouseWantedStems(20), 8);
    expect(mouseWantedStems(40), 12);
    expect(mouseAimedStems(day: 20, available: 80), 8);
    // A miss still costs 100/70/40/20% of the aimed stems (no pet, then
    // the cat by stage); a catch costs nothing.
    expect(mouseStemsLost(aimed: 8, caught: false, lossOnMiss: 1), 8);
    expect(mouseStemsLost(aimed: 8, caught: false, lossOnMiss: 0.7), 5);
    expect(mouseStemsLost(aimed: 8, caught: false, lossOnMiss: 0.4), 3);
    expect(mouseStemsLost(aimed: 8, caught: false, lossOnMiss: 0.2), 1);
    expect(mouseStemsLost(aimed: 8, caught: true, lossOnMiss: 0.2), 0);
  });

  test('day 5 asks once about the stray cat', () {
    final skip = newSession();
    skip.state.day = 5;
    skip.state.phase = DayPhase.summary;
    expect(skip.strayCatOffer, isTrue);
    skip.chooseStrayCat(false);
    expect(skip.state.hasCat, isFalse);
    expect(skip.strayCatOffer, isFalse);

    final adopt = newSession();
    adopt.state.day = 5;
    adopt.state.phase = DayPhase.summary;
    adopt.chooseStrayCat(true);
    expect(adopt.state.hasCat, isTrue);
    expect(adopt.state.petStage, 0);
    expect(adopt.state.petFedDay, 5);

    final later = newSession();
    later.state.day = 5;
    later.state.phase = DayPhase.summary;
    later.startNextDay();
    expect(later.state.day, 6);
    expect(later.state.hasCat, isFalse);
    expect(later.state.strayCatSeen, isTrue);
  });

  test('the pet shop sells one cat for 100k while the shop is closed', () {
    final s = newSession();
    s.state.money = catPrice;
    expect(s.buyPet(giftCat), isTrue);
    expect(s.state.hasCat, isTrue);
    expect(s.state.money, 0);
    expect(s.buyPet(giftCat), isFalse);

    final open = newSession();
    open.state.money = catPrice;
    open.state.phase = DayPhase.open;
    expect(open.buyPet(giftCat), isFalse);
    expect(open.state.hasCat, isFalse);
  });

  test('the pet shop sells biscuits while the shop is closed', () {
    final s = newSession();
    s.state.money = biscuitPrice;
    expect(s.buyTreat(giftBiscuit), isTrue);
    expect(s.state.biscuits, 1);
    expect(s.state.money, 0);
    expect(s.buyTreat(giftDrop), isFalse);

    final open = newSession();
    open.state.money = biscuitPrice;
    open.state.phase = DayPhase.open;
    expect(open.buyTreat(giftBiscuit), isFalse);
    expect(open.state.biscuits, 0);

    final full = newSession();
    full.state.money = biscuitPrice;
    full.state.biscuits = maxGiftCount;
    expect(full.buyTreat(giftBiscuit), isFalse);
    expect(full.state.biscuits, maxGiftCount);
  });

  test('the shared pet frame shrinks the carp and the crane', () {
    expect(petFrameScale('meo', 2), closeTo(0.88, 0.001));
    expect(petFrameScale('ca_chep', 2), closeTo(0.88 * 0.86, 0.001));
    expect(petFrameScale('hac', 0), closeTo(0.88 * 0.92 * 0.80, 0.001));
  });

  test('stone gifts follow the bouquet stars', () {
    expect(stoneGiftRange(5), (6, 10));
    expect(stoneGiftRange(4), (2, 6));
    expect(stoneGiftRange(3), (1, 1));
  });

  test('day 10 sends the mysterious guest and a bouquet pays stones', () {
    final s = newSession(seed: 2);
    s.state.day = 10;
    stockAndOpen(s);
    s.state.pendingArrivals
      ..clear()
      ..add(0);
    final c = waitForCustomer(s);
    expect(c.name, mysteryName);
    expect(c.avatarId, mysteryAvatar);
    s.openTable();
    final r = c.request;
    for (final e in r.stems.entries) {
      for (var i = 0; i < e.value; i++) {
        expect(s.addStem(e.key), isTrue);
      }
    }
    if (r.fillerId != null) {
      for (var i = 0; i < r.fillerCount; i++) {
        s.addStem(r.fillerId!);
      }
    }
    s.selectPaper(r.paperId);
    s.selectRibbon(r.ribbonId);
    s.beginWrap();
    final res = s.finishWrap(hit: true)!;
    expect(res.review.stars, 5);
    expect(res.stones, inInclusiveRange(6, 10));
    expect(s.state.drops, res.stones);

    final ordinary = newSession(seed: 2);
    ordinary.state.day = 9;
    stockAndOpen(ordinary);
    ordinary.state.pendingArrivals
      ..clear()
      ..add(0);
    expect(waitForCustomer(ordinary).avatarId, isNot(mysteryAvatar));
  });

  test(
    'the free cushion and bowl stay while the catalog does not change screen',
    () {
      final s = newSession();
      expect(s.state.petSeat, giftSeat);
      expect(s.state.petBowl, giftBowl);
      final screen = s.screen;
      s.openPetCatalog();
      expect(s.petCatalogOpen, isFalse);
      s.state.day = strayCatDay;
      s.openPetCatalog();
      expect(s.petCatalogOpen, isTrue);
      expect(s.screen, screen);
      s.closePetCatalog();
      expect(s.petCatalogOpen, isFalse);
    },
  );

  testWidgets('tapping the cushion opens the skin cupboard', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PetScreen(session: s)),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('pet-seat')));
    await tester.pump();
    expect(find.byKey(const Key('pet-skin-cell-$giftSeat')), findsOneWidget);
  });

  testWidgets('the pet shop buy button gives the cat', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession();
    s.state.day = strayCatDay;
    s.state.money = catPrice;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PetShopScreen(session: s)),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('pet-shop-open')));
    await tester.pump();
    expect(find.byKey(const Key('pet-shop-popup')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('pet-buy-meo')),
        matching: find.text('100k'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pet-buy-meo')));
    await tester.pump();
    expect(find.text('Đón Mèo về tiệm?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pet-confirm-yes')));
    await tester.pump();
    expect(s.state.hasCat, isTrue);
    expect(find.text('Mèo đã về tiệm rồi!'), findsOneWidget);
    expect(find.byKey(const Key('pet-owned-meo')), findsOneWidget);
    expect(find.byKey(const Key('pet-room-meo')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the stray kitten popup can be adopted', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = newSession();
    s.state.day = 5;
    s.state.phase = DayPhase.summary;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: StrayCatPopup(session: s)),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('stray-adopt')));
    await tester.pump();
    expect(s.state.hasCat, isTrue);
    expect(s.strayCatOffer, isFalse);
  });
}
