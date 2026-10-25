// Sổ tay button with and without the Same-Day card, on the shop screen.
// Skipped unless SHOT_DIR is set.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui/notebook_button_position_test.dart' show sameDayOffer;
import '../ui/so_tay_screen_test.dart' show soTaySession;

final _dir = Platform.environment['SHOT_DIR'];

Future<void> _loadFonts() async {
  const fonts = {
    AppFonts.body: 'assets/fonts/nunito/Nunito-VariableFont_wght.ttf',
    AppFonts.display: 'assets/fonts/baloo2/Baloo2-VariableFont_wght.ttf',
  };
  for (final e in fonts.entries) {
    final bytes = File(e.value).readAsBytesSync();
    await (FontLoader(
      e.key,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

ShopSession _session({required bool sameDay}) {
  final s = soTaySession();
  s.state.phase = DayPhase.open;
  s.state.elapsed = s.e.secondsPerHour * 2.5;
  s.screen = Screen.shop;
  if (sameDay) s.onlineOrders.add(sameDayOffer());
  return s;
}

Future<void> _shoot(WidgetTester tester, String name, ShopSession s) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  const shot = Key('shot');
  await tester.pumpWidget(
    RepaintBoundary(
      key: shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SoundScope(
          sounds: s.sounds,
          child: Material(
            type: MaterialType.transparency,
            child: GameFrame(
              child: ListenableBuilder(
                listenable: s,
                builder: (context, _) => Stack(
                  children: [
                    Positioned.fill(
                      child: GameWidget<ShopGame>(game: ShopGame(s)),
                    ),
                    Positioned.fill(child: MainShopOverlay(session: s)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var round = 0; round < 4; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('notebook button shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    await _shoot(tester, 'btn_360x640_khong_sameday', _session(sameDay: false));
    await _shoot(tester, 'btn_360x640_co_sameday', _session(sameDay: true));
  });
}
