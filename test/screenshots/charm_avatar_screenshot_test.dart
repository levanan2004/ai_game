// Bang xep hang Mi luc: every row, the podium and the own card show the real avatar.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/charm_avatar_screenshot_test.dart
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

import 'package:ai_game/logic/preset_avatars.dart';

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

  testWidgets('avatar shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    final r = await rig(tester, n: 60, pet: 'kim_long', stage: 2);
    r.s.openPetSlots();
    r.s.setOwnerAvatar(presetAvatarIds[3]);
    await tester.runAsync(() async {
      await r.s.board.publishIfDue();
      await r.s.board.refresh(force: true);
    });
    r.s.charmBoardOpen = true;
    await _shoot(tester, 'bxh_avatar_1_bang_360x640', r.s);
    await tester.drag(find.byKey(const Key('bxh-list')), const Offset(0, -600));
    await _settle(tester);
    await _save(
      tester,
      const ValueKey('shot-bxh_avatar_1_bang_360x640'),
      'bxh_avatar_2_cuon_360x640',
    );
    r.s.board.openProfile(r.s.board.rows.first);
    await _shoot(tester, 'bxh_avatar_3_ho_so_360x640', r.s);
  });
}
