// Giá bán on the counter ledge (PA2), the 5-tab bar and the Xếp hạng Mị lực
// row of the map. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/gia_ban_ban_do_screenshot_test.dart
// The shop scene itself is drawn by Flame, so the ledge shots paint a plain
// scene colour and a counter strip at y 277 under the real overlay.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart' show GameFrame;
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/map_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../ui/charm_board_screen_test.dart' show rig;

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
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
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

class _Down extends MemoryCharmBoard {
  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) async => throw StateError('offline');
}

Widget _shell(Key key, Widget child, {bool framed = false}) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SoundScope(
      sounds: Sounds(heard: []),
      child: Material(
        color: AppColors.bgBase,
        child: framed
            ? GameFrame(child: child)
            : Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

/// A stand-in for the Flame scene: plain wall and the counter strip.
Widget _ledge(ShopSession s) => SizedBox(
  width: 360,
  height: 640,
  child: Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFFF3E9D2))),
      Positioned(
        left: 0,
        right: 0,
        top: 277,
        height: 24,
        child: const ColoredBox(color: Color(0xFFC9A27A)),
      ),
      ListenableBuilder(
        listenable: s,
        builder: (_, _) => MainShopOverlay(session: s),
      ),
    ],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ledge shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    final s = newSession(seed: 4);
    s.buyAndGoToShop();
    s.state.day = 20;
    for (final (name, size, framed) in const [
      ('pa2_gia_ban_canh_dong_ho_360x640', Size(360, 640), false),
      ('pa2_gia_ban_canh_dong_ho_390x844', Size(390, 844), true),
      ('pa2_gia_ban_man_rong_900x600', Size(900, 600), true),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _shell(ValueKey(name), _ledge(s), framed: framed),
      );
      await _settle(tester);
      await _save(tester, ValueKey(name), name);
    }
    // Before the opening day: dimmed.
    final early = newSession(seed: 4)..buyAndGoToShop();
    early.state.day = 4;
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpWidget(_shell(const ValueKey('pa2_mo'), _ledge(early)));
    await _settle(tester);
    await _save(
      tester,
      const ValueKey('pa2_mo'),
      'pa2_gia_ban_mo_truoc_ngay_10',
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('map shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name, ShopSession s, {Size? size}) async {
      tester.view.physicalSize = size ?? const Size(360, 640);
      await tester.pumpWidget(
        _shell(
          ValueKey(name),
          ListenableBuilder(
            listenable: s,
            builder: (_, _) => Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFFF7F5EF)),
                ),
                MapPopup(session: s, onClose: () {}),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      await _save(tester, ValueKey(name), name);
    }

    final mid = await rig(tester, n: 11, pet: 'kim_long', stage: 2);
    await tester.runAsync(() => mid.s.board.publishIfDue());
    await shoot('ban_do_hang_12_360x640', mid.s);
    await shoot('ban_do_hang_12_390x844', mid.s, size: const Size(390, 844));

    final top = await rig(tester, n: 1, pet: 'kim_long', stage: 2);
    await tester.runAsync(() => top.s.board.publishIfDue());
    await shoot('ban_do_top3_360x640', top.s);

    final out = await rig(tester, n: 100, pet: 'kim_long', stage: 0);
    await shoot('ban_do_ngoai_top100_360x640', out.s);

    final none = await rig(tester, pet: null);
    await shoot('ban_do_chua_xep_hang_360x640', none.s);

    final guest = await rig(tester, signedIn: false);
    await shoot('ban_do_khach_360x640', guest.s);

    final down = newSession(charmBoard: _Down(), now: mid.now)
      ..accountUid = 'me'
      ..state.day = 8
      ..state.addPet('kim_long', fedDay: 1)
      ..state.petCharm = 'kim_long';
    await shoot('ban_do_loi_mang_360x640', down);

    final locked = await rig(tester);
    locked.s.state.day = 3;
    await shoot('ban_do_chua_mo_thu_cung_360x640', locked.s);
  });
}
