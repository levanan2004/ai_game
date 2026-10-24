// Tin thế giới ticker on the main shop (Phú), fresh and faded, at 360x640
// and 390x844. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/world_chat_ticker_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

final _dir = Platform.environment['SHOT_DIR'];
const _frame = Key('shot-frame');

Future<void> _save(WidgetTester tester, String name) async {
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

void main() {
  setUpAll(loadTestFonts);
  if (_dir == null) {
    test('screenshots skipped (SHOT_DIR not set)', () {}, skip: true);
    return;
  }

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('ticker $tag', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chat = MemoryWorldChat()
        ..add(
          ChatMessage(
            id: 'm0000000001',
            uid: 'p1',
            name: 'Tiệm Hoa Lan',
            text: 'Ai có chậu Kỳ lân xanh chưa, đẹp quá trời!',
            seq: 1,
            createdAt: DateTime.now(),
          ),
        );
      final s = newSession(worldChat: chat, seed: 4);
      s.buyAndGoToShop();
      s.state.day = 20;
      s.state.potShopHintShown = true;
      s.state.potShopSeenIds = [for (final p in s.e.pots) p.id];
      s.accountUid = 'me';
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _frame,
            child: Material(
              color: const Color(0xFFB9D7A8),
              child: ListenableBuilder(
                listenable: s,
                builder: (context, _) => MainShopOverlay(session: s),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // The scroll starts on the next frame; 3 s in, the name is on screen.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(seconds: 3));
      await _save(tester, 'ticker_01_chay_$tag');
      // 8 s without a new message: 40%.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      await _save(tester, 'ticker_02_mo_$tag');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
