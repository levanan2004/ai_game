// Hoa sắp héo shots. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/hoa_sap_heo_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/delivery.dart' show gameHour;
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/hoa_sap_heo_view.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/summary_screen.dart';
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
  // Material icons (the day-7 lock) come with the Flutter SDK; tests do not
  // load them by default and would draw empty squares.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      [
        root,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        'materialicons-regular.otf',
      ].join(Platform.pathSeparator),
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Future<void> _save(WidgetTester tester, Key key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _frame(Key key, Widget child) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SoundScope(
      sounds: Sounds(heard: []),
      child: Material(
        type: MaterialType.transparency,
        child: GameFrame(child: child),
      ),
    ),
  ),
);

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget child, {
  Future<void> Function()? after,
}) async {
  await tester.pumpWidget(_frame(ValueKey('shot-$name'), child));
  await _settle(tester);
  if (after != null) {
    await after();
    await _settle(tester);
  }
  await _save(tester, ValueKey('shot-$name'), name);
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
}

Widget _shop(ShopSession s) => ColoredBox(
  color: AppColors.bgShop,
  child: ListenableBuilder(
    listenable: s,
    builder: (_, _) => MainShopOverlay(session: s),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hoa sap heo shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Clearance basket at 17h + its sheet.
    final a = newSession(sounds: Sounds(heard: []));
    stockAndOpen(a);
    a.state.stock
      ..clear()
      ..add(StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1))
      ..add(StockBatch(flowerId: 'tulip', count: 2, freshnessLeft: 1));
    final start = a.data.wilting.clearance.startHour;
    while (gameHour(a.e, a.state.elapsed) < start) {
      a.state.elapsed += 1;
    }
    a.state.dryingUnlocked = true;
    a.state.drying.add(DryingBatch(flowerId: 'rose', stems: 2, daysLeft: 1));
    a.state.driedStock['hydrangea'] = 3;
    await _shoot(tester, 'shop_basket_shelf', _shop(a));
    await _shoot(
      tester,
      'clearance_sheet',
      _shop(a),
      after: () => tester.tap(find.byKey(const Key('clearance-basket'))),
    );
    await _shoot(
      tester,
      'dried_shelf_sheet',
      _shop(a),
      after: () => tester.tap(find.byKey(const Key('dried-shelf'))),
    );

    // Pick-to-dry sheet on the summary.
    final b = newSession(sounds: Sounds(heard: []));
    stockAndOpen(b);
    b.state.pendingArrivals.clear();
    b.closeEarly();
    b.state.stock
      ..clear()
      ..add(StockBatch(flowerId: 'rose', count: 4, freshnessLeft: 1))
      ..add(StockBatch(flowerId: 'hydrangea', count: 2, freshnessLeft: 1))
      ..add(StockBatch(flowerId: 'peony', count: 2, freshnessLeft: 1));
    b.state.dryingUnlocked = true;
    b.screen = Screen.summary;
    await _shoot(
      tester,
      'dry_pick_sheet',
      SummaryScreen(session: b),
      after: () => tester.tap(find.byKey(const Key('dry-cell-rose'))),
    );

    await _shoot(
      tester,
      'dry_pick_stepper',
      SummaryScreen(session: b),
      after: () async {
        await tester.longPress(find.byKey(const Key('dry-cell-rose')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('dry-step-rose--')));
      },
    );

    // Unlock popup.
    final c = newSession(sounds: Sounds(heard: []));
    c.state.day = c.data.wilting.drying.unlockDay;
    await _shoot(
      tester,
      'drying_unlock_popup',
      ColoredBox(
        color: AppColors.bgBase,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              right: 12,
              top: 150,
              child: DryingUnlockCard(session: c, onBuy: () {}),
            ),
            Positioned.fill(
              child: DryingUnlockPopup(session: c, onClose: () {}),
            ),
          ],
        ),
      ),
    );
  });
}
