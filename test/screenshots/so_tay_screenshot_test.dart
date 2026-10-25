// Sổ tay khách quen: list, a regular's page, an open letter, the shop queue.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/so_tay_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui/so_tay_screen_test.dart' show soTayFrame, soTaySession;

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
  if (root == null) return;
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
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
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
  testWidgets('so tay shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    final s = soTaySession()..openNotebook();
    await tester.pumpWidget(soTayFrame(s, key: const ValueKey('shot')));
    await _shoot(tester, 'so_tay_1_danh_sach');
    s.selectNotebookTab('locked');
    await _shoot(tester, 'so_tay_2_chua_gap');
    s
      ..selectNotebookTab('all')
      ..openRegularCard('anh_minh_khoa');
    await _shoot(tester, 'so_tay_3_chi_tiet');
    s.openLetter(1);
    await _shoot(tester, 'so_tay_4_la_thu');
    s
      ..closeNotebook()
      ..openRegularCard('chi_ngoc');
    await _shoot(tester, 'so_tay_5_moi_ghe_lai');
  });
}
