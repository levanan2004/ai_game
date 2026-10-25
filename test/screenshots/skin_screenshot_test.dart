// Renders the decoration skins (spec_skin_trang_tri) to PNGs: the shop scene
// with the free and the Tết set, the pet room with the free and the Sơn Hải
// set (and a short screen), and Tiệm Trang Trí for both groups. Skipped
// unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/skin_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/data/skins.dart';
import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/decorate_screen.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

final _dir = Platform.environment['SHOT_DIR'];

ShopSession _session(String? theme, {bool pets = false}) {
  final s = newSession(sounds: Sounds(heard: []));
  s.state.shopName = 'Tiệm Hoa Tổng Xanh';
  s.state.day = 12;
  s.state.money = 50000000;
  s.state.phaLe = 400;
  s.state.phase = DayPhase.preparing;
  s.state.hasCat = true;
  s.state.petStage = 1;
  if (theme != null) {
    final group = pets ? skinGroupRoom : skinGroupShop;
    final picks = <String, String>{};
    for (final d in s.skins.list) {
      if (d.group != group || d.theme != theme) continue;
      switch (d.slot) {
        case 'choNgoi':
          s.state.petSeats.add(d.id);
        case 'batAn':
          s.state.petBowls.add(d.id);
        default:
          s.state.ownedSkins.add(d.id);
      }
      picks[d.slot] = d.id;
    }
    s.wearSkins(picks);
  }
  if (pets) {
    s.state.day = strayCatDay;
    s.state.addPet('meo');
    s.openPetRoom('meo');
  } else {
    s.screen = Screen.shop;
  }
  // The one-time new-pot hint would cover the scene.
  s.markPotHintShown();
  return s;
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  ShopSession s, {
  double height = 640,
  String? decorate,
}) async {
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1;
  if (decorate != null) s.openDecorate(decorate);
  final pets = s.screen != Screen.shop;
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
                    Positioned.fill(
                      child: pets
                          ? PetScreen(session: s)
                          : MainShopOverlay(session: s),
                    ),
                    if (s.decorateGroup != null)
                      Positioned.fill(child: DecorateScreen(session: s)),
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
      await tester.pump(const Duration(milliseconds: 16));
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
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('skin shots', skip: _dir == null, (tester) async {
    await loadTestFonts();
    await _shoot(tester, 'skin_1_tiem_mac_dinh_360x640', _session(null));
    await _shoot(tester, 'skin_2_tiem_tet_360x640', _session('tet'));
    await _shoot(
      tester,
      'skin_3_phong_pet_mac_dinh_360x640',
      _session(null, pets: true),
    );
    await _shoot(
      tester,
      'skin_4_phong_pet_son_hai_360x640',
      _session('son_hai', pets: true),
    );
    await _shoot(
      tester,
      'skin_5_phong_pet_man_thap_360x480',
      _session('son_hai', pets: true),
      height: 480,
    );
    await _shoot(
      tester,
      'skin_6_trang_tri_tiem_360x640',
      _session('tet'),
      decorate: skinGroupShop,
    );
    await _shoot(
      tester,
      'skin_7_trang_tri_phong_360x640',
      _session('son_hai', pets: true),
      decorate: skinGroupRoom,
    );
  });
}
