import 'dart:io';

import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart' show catPetId;
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/pet_item_shop.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import 'charm_board_screen_test.dart' as board;

const _sizes = [Size(360, 640), Size(390, 844)];

ShopSession _room(String id, {Map<String, int> items = const {}}) {
  final s = newSession();
  s.state.day = strayCatDay;
  s.state.hasCat = true;
  s.state.addPet('meo');
  s.state.petItems.addAll(items);
  s.state.money = 100000000;
  if (id != 'meo') s.state.addPet(id, fedDay: s.state.day);
  s.openPetRoom(id);
  return s;
}

Future<void> _pump(WidgetTester tester, ShopSession s, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ListenableBuilder(
        listenable: s,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(child: PetScreen(session: s)),
            if (s.petItemShopOpen)
              Positioned.fill(child: PetItemShopScreen(session: s)),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _r(WidgetTester t, String key) => t.getRect(find.byKey(Key(key)));

/// The widgets whose place must not depend on the pet or the state.
const _stable = ['pet-room', 'pet-charm-card', 'pet-hold', 'pet-feed'];

String _asset(WidgetTester tester) {
  final img = tester.widget<Image>(
    find.descendant(
      of: find.byKey(const Key('pet-cat')),
      matching: find.byType(Image),
    ),
  );
  return (img.image as AssetImage).assetName;
}

void main() {
  setUpAll(loadTestFonts);

  for (final size in _sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets('the scene is the same size for every pet and state ($tag)', (
      tester,
    ) async {
      // Mèo, empty slots, nothing going on.
      final base = _room('meo');
      await _pump(tester, base, size);
      final want = {for (final k in _stable) k: _r(tester, k)};
      expect(want['pet-room']!.width, closeTo(size.width - 24, 0.5));

      Future<void> same(ShopSession s, String why) async {
        await _pump(tester, s, size);
        for (final k in _stable) {
          expect(_r(tester, k), want[k], reason: '$k: $why');
        }
        await tester.pump(const Duration(seconds: 2));
      }

      await same(_room('hac'), 'Hạc');
      await same(_room('ca_chep'), 'Cá chép');
      await same(_room('bach_ho'), 'Bạch hổ');
      // Items on all three slots.
      final dressed = _room('hac', items: {'mu_rom': 1, 'no_co_vai': 1});
      dressed.state.ownedPet('hac')!.worn
        ..['head'] = 'mu_rom'
        ..['neck'] = 'no_co_vai';
      await same(dressed, 'items worn');
      // In both Mị lực / Thu nhập slots (two badges).
      final slots = _room('meo');
      slots.state.petCharm = 'meo';
      slots.state.petIncome = 'meo';
      await same(slots, 'both slot badges');
      // Ready to break through, hungry, adult, a pet holding the max Mị lực.
      final ready = _room('ca_chep');
      ready.state.ownedPet('ca_chep')!.progress = 100;
      await same(ready, 'ready to break through');
      expect(find.byKey(const Key('pet-break')), findsOneWidget);
      final adult = _room('hac');
      adult.state.ownedPet('hac')!.stage = 2;
      await same(adult, 'adult');
    });
  }

  testWidgets('a swipe on the scene switches pets like the arrows', (
    tester,
  ) async {
    final s = _room('meo');
    s.state.addPet('hac', fedDay: s.state.day);
    s.state.addPet('ca_chep', fedDay: s.state.day);
    s.openPetRoom('meo');
    await _pump(tester, s, _sizes.first);
    expect(s.roomPet!.id, 'meo');
    await tester.fling(
      find.byKey(const Key('pet-room')),
      const Offset(-200, 0),
      900,
    );
    await tester.pump();
    expect(s.roomPet!.id, 'hac', reason: 'swipe left = next');
    await tester.fling(
      find.byKey(const Key('pet-room')),
      const Offset(200, 0),
      900,
    );
    await tester.pump();
    expect(s.roomPet!.id, 'meo', reason: 'swipe right = previous');
    await tester.fling(
      find.byKey(const Key('pet-room')),
      const Offset(200, 0),
      900,
    );
    await tester.pump();
    expect(s.roomPet!.id, 'ca_chep', reason: 'wraps like the arrows');
    // A tap on the pet still strokes it and does not switch.
    await tester.tap(find.byKey(const Key('pet-cat')));
    await tester.pump();
    expect(s.roomPet!.id, 'ca_chep');
    await tester.pump(const Duration(seconds: 2));
  });

  for (final id in knownPetIds) {
    testWidgets('$id: stroke, hold, hint and hearts', (tester) async {
      final s = _room(id);
      await _pump(tester, s, _sizes.first);
      expect(find.text('Chạm vào pet để vuốt.'), findsOneWidget);
      final idle = _asset(tester);
      await tester.tap(find.byKey(const Key('pet-cat')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('pet-hearts')), findsOneWidget);
      expect(_asset(tester), endsWith('_vuot.webp'), reason: id);
      expect(_asset(tester), isNot(idle));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('pet-hearts')), findsNothing);
      await tester.tap(find.byKey(const Key('pet-hold')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_asset(tester), endsWith('_be.webp'), reason: id);
      await tester.pump(const Duration(seconds: 2));
    });
  }

  test('every pet has the four pose pictures and none needs a missing one', () {
    for (final id in knownPetIds) {
      expect(petHasPoses(id), isTrue);
      for (final pose in ['an', 'be', 'doi', 'vuot']) {
        final file = 'assets/images/pets/${petArtId(id, 1, pose: pose)}.webp';
        expect(File(file).existsSync(), isTrue, reason: file);
      }
      // Growing / breakthrough have no picture for the other pets: the stage
      // picture is used (a hop and hearts are drawn over it).
      for (final pose in ['nang', 'dotpha']) {
        final file = 'assets/images/pets/${petArtId(id, 1, pose: pose)}.webp';
        expect(File(file).existsSync(), isTrue, reason: file);
        if (id != catPetId) expect(petHasPoseArt(id, pose), isFalse);
      }
    }
  });

  testWidgets('picker price chip opens the shop on that item and asks', (
    tester,
  ) async {
    final s = _room('meo');
    await _pump(tester, s, _sizes.first);
    await tester.tap(find.byKey(const Key('pet-slot-neck')));
    await tester.pump();
    final buy = find.byKey(const Key('item-buy-chuong_ngoc'));
    expect(buy, findsOneWidget);
    s.state.phaLe = 1000;
    s.notifyListeners();
    await tester.pump();
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pump();
    expect(s.petItemShopOpen, isTrue);
    expect(s.petItemPickSlot, isNull);
    expect(s.petItemShopTab, 'neck');
    expect(s.petItemShopFocus, 'chuong_ngoc');
    expect(find.byKey(const Key('item-row-chuong_ngoc')), findsOneWidget);
    expect(s.petItemBuyId, 'chuong_ngoc', reason: 'can pay: confirm shown');
    expect(find.byKey(const Key('item-buy')), findsOneWidget);
    // Not enough: the shop shows the row, no confirm.
    s.closePetItemShop();
    s.state.phaLe = 0;
    expect(s.openPetItemShopFor('chuong_ngoc'), isTrue);
    await tester.pump();
    expect(s.petItemBuyId, isNull);
    expect(s.petItemShopFocus, 'chuong_ngoc');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a row far down the list is scrolled into view', (tester) async {
    final s = _room('meo');
    s.state.money = 100000000;
    await _pump(tester, s, _sizes.first);
    final last = s.petItemsOfSlot('accessory').last;
    s.openPetItemShopFor(last.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final row = tester.getRect(find.byKey(Key('item-row-${last.id}')));
    expect(row.top, greaterThan(100));
    expect(row.bottom, lessThanOrEqualTo(640));
    await tester.pump(const Duration(seconds: 3));
  });

  for (final size in _sizes) {
    for (final n in [0, 20]) {
      testWidgets(
        'rewards: the "Bạn · hạng" tag is fully visible (${size.width.round()}, $n others)',
        (tester) async {
          final r = await board.rig(tester, n: n, pet: 'kim_long', stage: 2);
          r.s.openPetSlots();
          await board.mount(tester, r.s);
          await tester.runAsync(() => r.s.board.publishIfDue());
          await board.open(tester, r.s);
          await tester.runAsync(() => r.s.board.refresh(force: true));
          await tester.pump();
          await tester.tap(find.byKey(const Key('bxh-rewards-btn')));
          await tester.pump(const Duration(milliseconds: 400));
          final tag = find.byKey(const Key('bxh-you-at'));
          expect(tag, findsOneWidget);
          final list = tester.getRect(find.byKey(const Key('bxh-reward-list')));
          final t = tester.getRect(tag);
          expect(t.top, greaterThanOrEqualTo(list.top), reason: 'not clipped');
          expect(t.left, greaterThanOrEqualTo(list.left));
          expect(find.text(Bxh.youAt(r.s.board.myRank!)), findsOneWidget);
        },
      );
    }
  }
}
