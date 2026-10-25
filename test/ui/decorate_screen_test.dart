import 'package:ai_game/data/skins.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/decorate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<ShopSession> _open(
  WidgetTester tester,
  String group, {
  void Function(ShopSession s)? setup,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final s = newSession();
  s.state.phase = DayPhase.summary;
  setup?.call(s);
  expect(s.openDecorate(group), isTrue);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(child: DecorateScreen(session: s)),
    ),
  );
  await tester.pump();
  return s;
}

void main() {
  testWidgets('preview, then Mua 1 món buys and wears it', (tester) async {
    final s = await _open(tester, skinGroupShop);
    expect(find.text('Trang trí tiệm'), findsOneWidget);
    await tester.tap(find.byKey(const Key('decorate-tab-quay')));
    await tester.pump();
    final he = s.skins.byId('quay_he_bien')!;
    s.state.money = s.skinPrice(he).amount;
    await tester.ensureVisible(find.byKey(Key('decorate-card-${he.id}')));
    await tester.pump();
    await tester.tap(find.byKey(Key('decorate-card-${he.id}')));
    await tester.pump();
    expect(s.skinWorn('quay'), 'quay_mac_dinh', reason: 'preview only');
    expect(find.text('Mua 1 món'), findsOneWidget);
    await tester.tap(find.byKey(const Key('decorate-save')));
    await tester.pump();
    expect(find.byKey(const Key('decorate-buy-xu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('decorate-buy-yes')));
    await tester.pumpAndSettle();
    expect(s.skinHas(he.id), isTrue);
    expect(s.skinWorn('quay'), he.id);
    expect(s.state.money, 0);
  });

  testWidgets('Hoàn tác goes back to the worn set; leaving asks first', (
    tester,
  ) async {
    final s = await _open(tester, skinGroupRoom);
    expect(find.text(s.skins.ui('skin.edit.pet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('decorate-tab-doChoi')));
    await tester.pump();
    final tet = find.byKey(const Key('decorate-card-do_choi_tet'));
    await tester.ensureVisible(tet);
    await tester.pump();
    await tester.tap(tet);
    await tester.pump();
    await tester.tap(find.byKey(const Key('decorate-undo')));
    await tester.pump();
    expect(find.text('Lưu'), findsOneWidget);
    await tester.tap(tet);
    await tester.pump();
    await tester.tap(find.byKey(const Key('decorate-back')));
    await tester.pump();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('decorate-discard-yes')));
    await tester.pump();
    expect(s.decorateGroup, isNull);
    expect(s.skinWorn('doChoi'), 'do_choi_mac_dinh');
  });

  testWidgets('event skins show Nhận từ sự kiện, no price', (tester) async {
    await _open(tester, skinGroupShop);
    await tester.tap(find.byKey(const Key('decorate-tab-quay')));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('decorate-grid')),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(find.text('Nhận từ sự kiện'), findsOneWidget);
    expect(find.byKey(const Key('decorate-price-quay_bxh_mua1')), findsNothing);
  });

  test('shop set cannot open while serving', () {
    final s = newSession();
    s.state.phase = DayPhase.open;
    expect(s.openDecorate(skinGroupShop), isFalse);
    expect(s.openDecorate(skinGroupRoom), isTrue);
  });

  testWidgets('preview stays under 38% of the screen; 1.5 rows of cards', (
    tester,
  ) async {
    await _open(tester, skinGroupShop);
    final preview = tester.getRect(find.byKey(const Key('decorate-preview')));
    expect(preview.height, lessThanOrEqualTo(640 * decoratePreviewMaxShare));
    final grid = tester.getRect(find.byKey(const Key('decorate-grid')));
    expect(grid.height, greaterThanOrEqualTo(120 * 1.5 + 8));
  });

  testWidgets('shop preview: real shop name and the 3 pots in use', (
    tester,
  ) async {
    await _open(
      tester,
      skinGroupShop,
      setup: (s) => s.state.shopName = 'Tiệm Hoa Tổng Xanh',
    );
    expect(find.text('Tiệm Hoa Tổng Xanh'), findsOneWidget);
    for (var i = 0; i < decoratePreviewPots; i++) {
      expect(find.byKey(Key('decorate-pot-$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('decorate-pot-3')), findsNothing);
  });

  testWidgets('room preview: the pet stands on the cushion', (tester) async {
    await _open(
      tester,
      skinGroupRoom,
      setup: (s) {
        s.state.hasCat = true;
        s.state.addPet('meo');
        s.openPetRoom('meo');
      },
    );
    final pet = tester.getRect(find.byKey(const Key('decorate-pet')));
    final preview = tester.getRect(find.byKey(const Key('decorate-preview')));
    // Cushion 168–228 of 268 in the preview; feet at 70% of it.
    final k = preview.height / 268;
    expect(
      pet.bottom,
      moreOrLessEquals(preview.top + (168 + 42) * k, epsilon: 1),
    );
  });

  testWidgets('event preview: note shows, Lưu goes back free', (tester) async {
    final s = await _open(tester, skinGroupShop);
    await tester.tap(find.byKey(const Key('decorate-tab-quay')));
    await tester.pump();
    final ev = find.byKey(const Key('decorate-card-quay_bxh_mua1'));
    await tester.ensureVisible(ev);
    await tester.pump();
    await tester.tap(ev);
    await tester.pump();
    expect(find.byKey(const Key('decorate-event-note')), findsOneWidget);
    expect(find.text(s.skins.ui('skin.event.preview_only')), findsOneWidget);
    expect(
      s.skins.ui('skin.event.preview_only'),
      isNot('skin.event.preview_only'),
    );
    final money = s.state.money;
    await tester.tap(find.byKey(const Key('decorate-save')));
    await tester.pump();
    expect(s.skinWorn('quay'), 'quay_mac_dinh');
    expect(s.state.money, money);
    expect(find.byKey(const Key('decorate-event-note')), findsNothing);
  });

  testWidgets('two buys for one slot: the last bought is worn', (tester) async {
    final s = await _open(tester, skinGroupShop);
    await tester.tap(find.byKey(const Key('decorate-tab-quay')));
    await tester.pump();
    for (final id in ['quay_he_bien', 'quay_tet']) {
      final d = s.skins.byId(id)!;
      s.state.money += s.skinPrice(d).phaLe ? 0 : s.skinPrice(d).amount;
      s.state.phaLe += s.skinPrice(d).phaLe ? s.skinPrice(d).amount : 0;
      final card = find.byKey(Key('decorate-card-$id'));
      await tester.ensureVisible(card);
      await tester.pump();
      await tester.tap(card);
      await tester.pump();
      await tester.tap(find.byKey(const Key('decorate-save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('decorate-buy-yes')));
      await tester.pumpAndSettle();
      expect(s.skinWorn('quay'), id);
    }
    expect(s.skinHas('quay_he_bien'), isTrue);
  });
}
