import 'package:ai_game/data/skins.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/decorate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<ShopSession> _open(WidgetTester tester, String group) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final s = newSession();
  s.state.phase = DayPhase.summary;
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
    expect(find.text('Trang trí phòng'), findsOneWidget);
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
}
