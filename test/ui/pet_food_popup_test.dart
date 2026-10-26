import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart' show DayPhase;
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/petdo_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

ShopSession _room() {
  final s = newSession();
  s.state.day = strayCatDay;
  s.state.hasCat = true;
  s.state.addPet('meo');
  s.state.money = 100000000;
  s.state.biscuits = 0;
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
        children: [Positioned.fill(child: PetScreen(session: s))],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('no Bánh mật: Mua đồ ăn opens the popup; buying feeds', (
    tester,
  ) async {
    final s = _room();
    await _pump(tester, s);
    expect(find.text(PetDo.feedBuy), findsOneWidget);
    expect(find.byKey(const Key('pet-food-popup')), findsNothing);

    await tester.tap(find.byKey(const Key('pet-feed')));
    await tester.pump();
    expect(find.text(PetDo.foodTitle), findsOneWidget);
    final price = s.treatPrice(giftBiscuit)!;
    expect(find.byKey(const Key('pet-food-row')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('pet-food-row'))).data,
      contains(' xu'),
    );

    final money = s.state.money;
    await tester.tap(find.byKey(const Key('pet-food-buy')));
    await tester.pump();
    expect(s.state.money, money - price);
    if (s.state.biscuits == 0) {
      // A one-biscuit meal was eaten right after the buy.
      expect(find.byKey(const Key('pet-food-popup')), findsNothing);
    }
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('while the shop is open: the popup buys, the shop does not', (
    tester,
  ) async {
    final s = _room();
    s.state.phase = DayPhase.open;
    expect(s.petShopOpen, isFalse);
    // Every other pet-shop purchase keeps the closed-shop rule.
    expect(s.buyTreat(giftBiscuit), isFalse);
    expect(s.buyTreat(giftDrop), isFalse);
    expect(s.buyTreat(giftDrop, anyTime: true), isFalse);
    expect(s.state.biscuits, 0);

    await _pump(tester, s);
    await tester.tap(find.byKey(const Key('pet-feed')));
    await tester.pump();
    final money = s.state.money;
    await tester.tap(find.byKey(const Key('pet-food-buy')));
    await tester.pump();
    expect(s.state.money, money - s.treatPrice(giftBiscuit)!);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the + opens the popup and has a 48dp tap area', (tester) async {
    final s = _room();
    s.state.biscuits = 3;
    await _pump(tester, s);
    final plus = find.byKey(const Key('pet-food-plus'));
    final r = tester.getRect(plus);
    expect(r.width, greaterThanOrEqualTo(48));
    expect(r.height, greaterThanOrEqualTo(48));
    await tester.tap(plus);
    await tester.pump();
    expect(find.byKey(const Key('pet-food-popup')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('pet-food-dismiss')),
      warnIfMissed: false,
    );
    await tester.pump();
  });
}
