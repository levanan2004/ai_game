// QA fix round shots (bouquet table, summary, dialogs). Skipped unless
// SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/qa_fix_round_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/ui/bouquet_table_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

final _dir = Platform.environment['SHOT_DIR'];

Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 4; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _grab(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('screen')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _host(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: const Key('screen'),
        child: Material(child: SizedBox(width: 360, height: 640, child: child)),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('bouquet table', skip: _dir == null, (tester) async {
    await loadTestFonts();
    final s = newSession(seed: 3);
    stockAndOpen(s);
    waitForCustomer(s);
    s.state.pendingArrivals.clear();
    s.openTable();
    await _host(tester, BouquetTableScreen(session: s));
    await _settle(tester);
    await _grab(tester, 'qa_bo_hoa_360dp');
  });
}
