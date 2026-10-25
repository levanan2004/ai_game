// Renders Kho chậu with Phú's dot 2 pots to PNGs. Skipped unless SHOT_DIR
// is set:
//   $env:SHOT_DIR="C:\\tmp\\shots"; flutter test test/screenshots/dot2_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/pot_popup.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('Kho chậu dot 2 shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    const shot = Key('shot');
    final s = newSession(sounds: Sounds(heard: []));
    s.state.day = 12;
    s.state.money = 520000;
    s.state.phaLe = 280;
    // A mix the owner could hold later: the old pots and some dot-2 ones.
    for (final id in [
      'dragon',
      'qilin',
      'chau_bach_duong',
      'chau_song_tu',
      'chau_ho_cap',
      'chau_ma_ket',
      'chau_cuu_vi_ho',
      'chau_tat_phuong',
      'chau_ky_lan',
      'chau_bach_trach',
    ]) {
      s.state.potCounts[id] = 1;
    }
    s.openPotPicker(bar: false, index: 0);
    await tester.pumpWidget(
      _frame(shot, PotPopup(key: const ValueKey('grid'), session: s)),
    );
    await _settle(tester);
    await _save(tester, shot, 'kho_chau_dot2_luoi_360x640');
    final scroll = find.byType(Scrollable).first;
    await tester.drag(scroll, const Offset(0, -330));
    await _settle(tester);
    await _save(tester, shot, 'kho_chau_dot2_luoi_giua_360x640');
    await tester.drag(scroll, const Offset(0, -2000));
    await _settle(tester);
    await _save(tester, shot, 'kho_chau_dot2_luoi_cuoi_360x640');

    for (final (id, name) in [
      ('chau_ky_lan', 'kho_chau_chi_tiet_ky_lan_xanh_360x640'),
      ('qilin', 'kho_chau_chi_tiet_ky_lan_vang_360x640'),
      ('chau_song_tu', 'kho_chau_chi_tiet_song_tu_360x640'),
      ('chau_su_tu', 'kho_chau_chi_tiet_su_tu_mua_xu_360x640'),
      ('chau_song_ngu', 'kho_chau_chi_tiet_song_ngu_thieu_xu_360x640'),
      ('chau_thao_thiet', 'kho_chau_chi_tiet_thao_thiet_mua_phale_360x640'),
      ('chau_con_bang', 'kho_chau_chi_tiet_con_bang_thieu_phale_360x640'),
    ]) {
      await tester.pumpWidget(
        _frame(shot, PotPopup(key: ValueKey('d$id'), session: s)),
      );
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(Key('pot-cell-$id')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(Key('pot-cell-$id')));
      await tester.pump();
      await tester.tap(find.byKey(Key('pot-cell-$id')));
      await _settle(tester);
      await _save(tester, shot, name);
    }
  });
}
