// UI fix round shots (pot detail, pet room, ticker, Cam nang, brush).
// Skipped unless SHOT_DIR is set; SHOT_ONLY=<name> limits to one group:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/ui_fix_round_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/data/skins.dart';
import 'package:ai_game/ui/decorate_screen.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/pot_popup.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _dir = Platform.environment['SHOT_DIR'];
final _only = Platform.environment['SHOT_ONLY'];

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

ShopSession _session() {
  final s = newSession(sounds: Sounds(heard: []));
  s.state.shopName = 'Ti\u{1ec7}m Hoa S\u{1edb}m Mai';
  s.state.day = 12;
  s.state.hasCat = true;
  s.state.petStage = 1;
  return s;
}

Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required ShopSession session,
  required Widget Function() child,
  required Size size,
  Future<void> Function()? act,
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
                builder: (context, _) => child(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  if (act != null) {
    await act();
    await _settle(tester);
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

Widget _shop(ShopSession s) => Stack(
  children: [
    Positioned.fill(child: GameWidget<ShopGame>(game: ShopGame(s))),
    Positioned.fill(child: MainShopOverlay(session: s)),
  ],
);

const _sizes = [('desktop', Size(1280, 800)), ('360dp', Size(360, 740))];

bool _want(String group) => _only == null || _only == group;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('ui fix round shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    for (final (tag, size) in _sizes) {
      if (_want('pot')) {
        final s = _session();
        s.state.potCounts['tiger'] = 1;
        s.openPotPicker(bar: false, index: 0);
        await _shoot(
          tester,
          name: 't2_pot_detail_$tag',
          session: s,
          size: size,
          child: () => Center(child: PotPopup(session: s)),
          act: () async {
            final cell = find.byKey(const Key('pot-cell-tiger'));
            await tester.scrollUntilVisible(cell, 80);
            await tester.tap(cell);
          },
        );
      }
      if (_want('pets')) {
        final s = _session();
        s.openPets();
        await _shoot(
          tester,
          name: 't3_pet_room_$tag',
          session: s,
          size: size,
          child: () => PetScreen(session: s),
        );
      }
      if (_want('decor')) {
        for (final group in [skinGroupShop, skinGroupRoom]) {
          final s = _session();
          s.state.day = 60; // thuong costs 1.5M before x2
          s.openDecorate(group);
          await _shoot(
            tester,
            name: 't6_decorate_${group}_$tag',
            session: s,
            size: size,
            child: () => DecorateScreen(session: s),
          );
        }
      }
      final fix1 = _want('fix1') || _only == 'fix2';
      if (_want('shelf') || fix1) {
        for (final theme
            in fix1
                ? const ['mac_dinh', 'tet', 'son_hai']
                : const [
                    'mac_dinh',
                    'bxh_mua1',
                    'son_hai',
                    'he_bien',
                    'tet',
                    'trung_thu',
                  ]) {
          final s = _session();
          s.screen = Screen.shop;
          s.markPotHintShown();
          const pots = [
            'dragon',
            'phoenix',
            'tiger',
            'tortoise',
            'qilin',
            'chau_bao_binh',
          ];
          for (var i = 0; i < pots.length; i++) {
            s.state.displayPots[i] = pots[i];
          }
          final picks = <String, String>{};
          for (final d in s.skins.list) {
            if (d.slot != 'nenManHinh' || d.theme != theme) continue;
            s.state.ownedSkins.add(d.id);
            picks[d.slot] = d.id;
          }
          s.wearSkins(picks);
          await _shoot(
            tester,
            name: fix1
                ? '${_only ?? 'fix1'}_${theme}_$tag'
                : 't1_shelf_${theme}_$tag',
            session: s,
            size: size,
            child: () => _shop(s),
            // The pot pictures load after the first frames.
            act: () => tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 4)),
            ),
          );
        }
      }
      if (_want('brush')) {
        final s = _session(); // before opening: the brush shows
        s.screen = Screen.shop;
        await _shoot(
          tester,
          name: 't7_brush_$tag',
          session: s,
          size: size,
          child: () => _shop(s),
        );
      }
      if (_want('shop')) {
        final s = _session()..state.phase = DayPhase.open;
        s.screen = Screen.shop;
        await _shoot(
          tester,
          name: 'shop_$tag',
          session: s,
          size: size,
          child: () => _shop(s),
        );
      }
    }
  });
}
