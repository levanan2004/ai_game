// Baby and teen non-cat pets stroked and held at 360x640. Skipped unless
// SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/pet_stage_poses_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

final _dir = Platform.environment['SHOT_DIR'];
const _frame = Key('shot-frame');

Future<void> _save(WidgetTester tester, String name) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1200)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_frame),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

ShopSession _room(String id, int stage) {
  final s = newSession();
  s.state.day = strayCatDay;
  s.state.hasCat = true;
  s.state.addPet('meo');
  s.state.addPet(id, fedDay: s.state.day);
  s.state.ownedPet(id)!.stage = stage;
  s.openPetRoom(id);
  return s;
}

void main() {
  setUpAll(loadTestFonts);
  if (_dir == null) {
    test('screenshots skipped (SHOT_DIR not set)', () {}, skip: true);
    return;
  }

  for (final (id, stage, tag) in const [
    ('hac', 0, 'hac_be_thu'),
    ('ky_lan', 1, 'ky_lan_thieu_nien'),
    ('kim_long', 0, 'kim_long_be_thu'),
    ('huyen_vu', 1, 'huyen_vu_thieu_nien'),
  ]) {
    testWidgets('$tag stroke and hold at 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = _room(id, stage);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _frame,
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => PetScreen(session: s),
            ),
          ),
        ),
      );
      await tester.pump();
      await _save(tester, 'pet_${tag}_01_ngoi_360x640');
      await tester.tap(find.byKey(const Key('pet-cat')));
      await tester.pump(const Duration(milliseconds: 300));
      await _save(tester, 'pet_${tag}_02_vuot_360x640');
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('pet-hold')));
      await tester.pump(const Duration(milliseconds: 300));
      await _save(tester, 'pet_${tag}_03_be_360x640');
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
