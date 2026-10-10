// Renders Xếp hạng Mị lực (every state of SPEC_bang_xep_hang.md) to PNGs.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/charm_board_screenshot_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/pet_slots_screen.dart';
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

/// Never answers: the board stays on its loading skeleton.
class _Silent extends MemoryCharmBoard {
  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) => Completer<List<CharmBoardRow>>().future;
}

class _Down extends MemoryCharmBoard {
  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) async => throw StateError('offline');
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  ShopSession s, {
  Widget Function(ShopSession)? build,
}) async {
  await tester.pumpWidget(
    _frame(
      ValueKey('shot-$name'),
      ListenableBuilder(
        listenable: s,
        builder: (_, _) => (build ?? (s) => CharmBoardScreen(session: s))(s),
      ),
    ),
  );
  await _settle(tester);
  await _save(tester, ValueKey('shot-$name'), name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('charm board shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;

    // L1: ranked (a mid-table player), the 360 x 640 board.
    final r = await rig(tester, n: 60, pet: 'kim_long', stage: 2);
    r.s.openPetSlots();
    await tester.runAsync(() async {
      r.s.state.ownedPet('kim_long')!.worn.addAll({'neck': 'no_co_vai'});
      await r.s.board.publishIfDue();
      await r.s.board.refresh(force: true);
    });
    r.s.charmBoardOpen = true;
    await _shoot(tester, 'bxh_1_bang_360x640', r.s);

    // The same board scrolled to the player's row region.
    await tester.drag(find.byKey(const Key('bxh-list')), const Offset(0, -600));
    await _settle(tester);
    await _save(
      tester,
      const ValueKey('shot-bxh_1_bang_360x640'),
      'bxh_1b_cuon_360x640',
    );

    // L4: profile of the first place, then of a player with no items.
    r.s.board.openProfile(r.s.board.rows.first);
    await _shoot(tester, 'bxh_4_ho_so_360x640', r.s);
    r.s.board.closeProfile();
    r.s.board.openProfile(r.s.board.rows[1]);
    await _shoot(tester, 'bxh_4b_ho_so_o_trong_360x640', r.s);
    r.s.board.closeProfile();

    // L2: rewards.
    r.s.board.openRewards();
    await _shoot(tester, 'bxh_2_phan_thuong_360x640', r.s);

    // L3a1: no pet in the Mị lực slot.
    final none = await rig(tester, n: 30, pet: null);
    await tester.runAsync(() => none.s.board.refresh(force: true));
    none.s.charmBoardOpen = true;
    await _shoot(tester, 'bxh_3a1_chua_co_pet_360x640', none.s);

    // L3a2: under the minimum.
    final low = await rig(tester, n: 30, pet: 'ca_chep', stage: 0);
    await tester.runAsync(() => low.s.board.refresh(force: true));
    low.s.charmBoardOpen = true;
    await _shoot(tester, 'bxh_3a2_duoi_20_360x640', low.s);

    // L3b: guest.
    final guest = await rig(tester, signedIn: false);
    guest.s.charmBoardOpen = true;
    await _shoot(tester, 'bxh_3b_khach_360x640', guest.s);

    // L3c1 loading / L3c2 error.
    final loading = newSession(charmBoard: _Silent())
      ..accountUid = 'me'
      ..state.day = 8
      ..state.addPet('kim_long', fedDay: 1)
      ..state.petCharm = 'kim_long';
    loading.charmBoardOpen = true;
    loading.board.refresh();
    await _shoot(tester, 'bxh_3c1_dang_tai_360x640', loading);
    final down = newSession(charmBoard: _Down())
      ..accountUid = 'me'
      ..state.day = 8
      ..state.addPet('kim_long', fedDay: 1)
      ..state.petCharm = 'kim_long';
    down.charmBoardOpen = true;
    await tester.runAsync(() => down.board.refresh());
    await _shoot(tester, 'bxh_3c2_loi_mang_360x640', down);

    // L3d: outside the top 100.
    final out = await rig(tester, n: 100, pet: 'kim_long', stage: 0);
    await tester.runAsync(() => out.s.board.refresh(force: true));
    out.s.charmBoardOpen = true;
    await _shoot(tester, 'bxh_3d_ngoai_top100_360x640', out.s);

    // L5-A: the entry button in the slot picker's title row, with a rank chip.
    r.s.charmBoardOpen = false;
    await _shoot(
      tester,
      'bxh_5_loi_vao_360x640',
      r.s,
      build: (s) => PetSlotsScreen(session: s),
    );
  });
}
