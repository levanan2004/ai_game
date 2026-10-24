// Vòng quay tuần (task 8) at 360x640: the entry icon on the shop, the
// intro, the wheel, the last day, Quay 10, Kho thẻ and Tỉ lệ. Skipped unless
// SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/gacha_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/gacha.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../load_fonts.dart';
import '../logic/gacha_test.dart';
import '../ui/gacha_ui_test.dart' show gachaHost, ready;

final _dir = Platform.environment['SHOT_DIR'];
const _frame = Key('shot-frame');

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  await _settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_frame),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _host(
  WidgetTester tester,
  ShopSession s, {
  bool shop = false,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _frame,
      child: gachaHost(s, shop: shop),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadTestFonts);
  if (_dir == null) {
    test('screenshots skipped (SHOT_DIR not set)', () {}, skip: true);
    return;
  }

  testWidgets('shop icon and intro', (tester) async {
    final chat = MemoryWorldChat()
      ..add(
        ChatMessage(
          id: 'm0000000001',
          uid: 'p1',
          name: 'Tiệm Hoa Lan',
          text: 'Tuần này Cửu Vĩ Hồ đẹp quá!',
          seq: 1,
          createdAt: DateTime.now(),
        ),
      );
    final s = await ready(
      tester,
      FakeGachaWallet(cards: {'chau_cuu_vi_ho': 2}),
      worldChat: chat,
    );
    s.state.day = 20;
    s.state.potShopHintShown = true;
    s.state.potShopSeenIds = [for (final p in s.e.pots) p.id];
    await _host(tester, s, shop: true);
    // Let the scroll start, then catch the message mid-way.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 3));
    await _save(tester, 'gacha_01_icon_shop');
    s.state.gachaIntroShown = false;
    s.gacha.closePopup();
    await tester.pump();
    await _save(tester, 'gacha_02_intro');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shop icon with no news', (tester) async {
    final s = await ready(
      tester,
      FakeGachaWallet(),
      worldChat: MemoryWorldChat(),
    );
    s.state.day = 20;
    s.state.potShopHintShown = true;
    s.state.potShopSeenIds = [for (final p in s.e.pots) p.id];
    await _host(tester, s, shop: true);
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, 'gacha_01b_icon_no_news');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wheel screens', (tester) async {
    final api = FakeGachaWallet(
      cards: {'chau_cuu_vi_ho': 12, 'chau_con_bang': 3, 'chau_ky_lan': 1},
      pity: {
        'chau_cuu_vi_ho': {'n': 23},
      },
    );
    final s = await ready(tester, api);
    s.gacha.openScreen();
    await _host(tester, s);
    await _save(tester, 'gacha_03_screen');
    await tester.tap(find.byKey(const Key('gacha-spin-10')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, 'gacha_05_x10');
    await tester.tap(find.byKey(const Key('gacha-result-claim')));
    await tester.pump();
    await tester.pump();
    // The owned-cards chip became the buy chip (598629c); open Kho thẻ directly.
    s.gacha.showPopup(GachaPopup.cards);
    await tester.pump();
    await _save(tester, 'gacha_06_kho_the');
    s.gacha.showPopup(GachaPopup.odds);
    await tester.pump();
    await _save(tester, 'gacha_07_ti_le');
    s.gacha.openBuy(10);
    await tester.pump();
    await _save(tester, 'gacha_08_mua_the');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('last day', (tester) async {
    final s = await ready(
      tester,
      FakeGachaWallet(
        cards: {'chau_cuu_vi_ho': 1},
        pity: {
          'chau_cuu_vi_ho': {'n': 64},
        },
      ),
      now: DateTime.utc(2026, 10, 25, 3),
    );
    s.gacha.openScreen();
    await _host(tester, s);
    await _save(tester, 'gacha_04a_reminder');
    s.gacha.closeNotice();
    await tester.pump();
    await _save(tester, 'gacha_04b_last_day');
    await tester.pumpWidget(const SizedBox());
  });
}
