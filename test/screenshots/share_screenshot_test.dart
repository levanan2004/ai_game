// Renders the share image (spec_khung_chia_se) to PNGs at 1080 wide: bouquet
// and shop, 4:5 and 9:16. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/share_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/data/share_text.dart';
import 'package:ai_game/data/skins.dart' show skinGroupShop;
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/bouquet_table_screen.dart';
import 'package:ai_game/ui/decorate_screen.dart';
import 'package:ai_game/ui/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

final _dir = Platform.environment['SHOT_DIR'];

ShopSession _session() {
  final s = newSession(seed: 3);
  s.state.shopName = 'Tiệm Hoa Tổng Xanh';
  stockAndOpen(s);
  final c = waitForCustomer(s);
  s.state.pendingArrivals.clear();
  s.openTable();
  // The exact request: a 4★+ bouquet, so "Khoe bó hoa" shows.
  final r = c.request;
  for (final e in r.stems.entries) {
    for (var i = 0; i < e.value; i++) {
      s.addStem(e.key);
    }
  }
  for (var i = 0; i < r.fillerCount; i++) {
    s.addStem(r.fillerId!);
  }
  s.selectPaper(r.paperId);
  s.selectRibbon(r.ribbonId);
  return s;
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  ShopSession s,
  ShareKind kind, {
  bool story = false,
}) async {
  final h = story ? ShareCard.storyHeight : ShareCard.feedHeight;
  tester.view.physicalSize = Size(360, h);
  tester.view.devicePixelRatio = 1;
  const shot = Key('shot');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: shot,
          child: ShareCard(
            kind: kind,
            story: story,
            shopName: s.state.shopName!,
            caption: s.data.share.onImage(kind).first,
            gameTag: s.data.share.ui('image_text.game_tag'),
            linkLabel: s.data.share.ui('image_text.link_label'),
            storyFooter: s.data.share.ui('image_text.story_footer'),
            photo: kind == ShareKind.bouquet
                ? ShareBouquetPhoto(bouquet: BouquetArt(session: s))
                : FittedBox(
                    fit: BoxFit.cover,
                    child: ShopScenePreview(session: s),
                  ),
          ),
        ),
      ),
    ),
  );
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 4; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _grab(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('screen')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _host(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: const Key('screen'),
        child: Material(child: SizedBox(width: 360, height: 640, child: child)),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('share card shots', skip: _dir == null, (tester) async {
    await loadTestFonts();
    final s = _session();
    await _shoot(tester, 'share_1_bo_hoa_4x5', s, ShareKind.bouquet);
    await _shoot(
      tester,
      'share_2_bo_hoa_9x16',
      s,
      ShareKind.bouquet,
      story: true,
    );
    await _shoot(tester, 'share_3_tiem_4x5', s, ShareKind.shop);
    await _shoot(tester, 'share_4_tiem_9x16', s, ShareKind.shop, story: true);
  });

  testWidgets('share entry + sheet shots', skip: _dir == null, (tester) async {
    await loadTestFonts();
    final s = _session();
    await _host(tester, BouquetTableScreen(session: s));
    await tester.tap(find.byKey(const Key('deliver-button')));
    await tester.pump();
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('wrap-hold'))),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await hold.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    await _grab(tester, 'share_5_nut_khoe_bo_hoa');
    await tester.tap(find.byKey(const Key('share-bouquet')));
    await tester.pump();
    await _settle(tester);
    await _grab(tester, 'share_6_sheet_bo_hoa');

    final d = newSession();
    d.state.shopName = s.state.shopName;
    d.openDecorate(skinGroupShop);
    await _host(tester, DecorateScreen(session: d));
    await _settle(tester);
    await _grab(tester, 'share_7_nut_khoe_tiem');
    await tester.tap(find.byKey(const Key('share-shop')));
    await tester.pump();
    await _settle(tester);
    await _grab(tester, 'share_8_sheet_tiem');
    await tester.tap(find.byKey(const Key('share-format-story')));
    await tester.pump();
    await _settle(tester);
    await _grab(tester, 'share_9_sheet_tiem_story');
  });
}
