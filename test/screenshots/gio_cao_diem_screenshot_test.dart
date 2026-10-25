// Giờ cao điểm + Giá chợ shots for a visual check. Skipped unless SHOT_DIR
// is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/gio_cao_diem_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/data/economy.dart';
import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/market_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

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

ShopSession _session(int day) {
  final s = newSession(sounds: Sounds(heard: []));
  s.state.shopName = 'Tiệm Hoa Sớm Mai';
  s.state.day = day;
  s.state.hasCat = true;
  s.state.petStage = 1;
  return s;
}

/// [h]'s first day in the second year, plus [offset].
int _dayOf(Economy e, String id, int offset) =>
    e.yearLengthDays +
    e.holidays.firstWhere((h) => h.id == id).days.first +
    offset;

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required ShopSession session,
  bool shop = false,
  bool sheet = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  const shot = Key('shot');
  await tester.pumpWidget(
    RepaintBoundary(
      key: shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SoundScope(
          sounds: session.sounds,
          child: Material(
            type: MaterialType.transparency,
            child: GameFrame(
              child: ListenableBuilder(
                listenable: session,
                builder: (context, _) => shop
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: GameWidget<ShopGame>(
                              game: ShopGame(session),
                            ),
                          ),
                          Positioned.fill(
                            child: MainShopOverlay(session: session),
                          ),
                        ],
                      )
                    : MarketScreen(session: session),
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
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  if (sheet) {
    await tester.tap(find.byKey(const Key('market-card')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('gio cao diem shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    final e = newSession().e;
    var normal = 9;
    while (e.holidayOn(normal) != null || e.priceRiseHoliday(normal) != null) {
      normal++;
    }
    final days = {
      'cho_ngay_thuong': normal,
      'cho_valentine_-2': _dayOf(e, 'valentine', -2),
      'cho_tet_ngay_1': _dayOf(e, 'tet', 0),
    };
    for (final d in days.entries) {
      for (final sheet in [false, true]) {
        final s = _session(d.value);
        s.state.unlockedItems.addAll(
          e.flowers.where((f) => f.unlockCost > 0).map((f) => f.id).take(4),
        );
        await _shoot(
          tester,
          name: '${d.key}${sheet ? '_bang_gia' : ''}',
          session: s,
          sheet: sheet,
        );
      }
    }
    for (final hour in [18, 12, 16]) {
      final s = _session(normal)
        ..state.phase = DayPhase.open
        ..state.elapsed =
            (hour - e.openHour + (hour == 16 ? 0.5 : 0.1)) * e.secondsPerHour;
      s.screen = Screen.shop;
      await _shoot(tester, name: 'shop_${hour}h', session: s, shop: true);
    }
    // Pill fix (Phú 23:57): desktop window and a 360 dp phone.
    for (final (tag, size) in [
      ('desktop', const Size(1280, 800)),
      ('360dp', const Size(360, 740)),
    ]) {
      for (final hour in [18, 12]) {
        final s = _session(normal)
          ..state.phase = DayPhase.open
          ..state.elapsed = (hour - e.openHour + 0.1) * e.secondsPerHour;
        s.screen = Screen.shop;
        await _shoot(
          tester,
          name: 'shop_${hour}h_$tag',
          session: s,
          shop: true,
          size: size,
        );
      }
    }
  });
}
