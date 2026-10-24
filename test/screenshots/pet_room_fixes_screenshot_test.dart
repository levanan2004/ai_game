// Renders the pet room fixes (fixed scene, swipe, poses, picker chip, rewards
// tag) at 360x640 and 390x844. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/pet_room_fixes_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/pet_item_shop.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import '../ui/charm_board_screen_test.dart' as board;

final _dir = Platform.environment['SHOT_DIR'];
const _sizes = [Size(360, 640), Size(390, 844)];
const _frame = Key('shot-frame');

Future<void> _save(WidgetTester tester, String name, {Finder? of}) async {
  // Let the pictures decode before the shot.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1200)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    of ?? find.byKey(_frame),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ShopSession _room(String id) {
  final s = newSession();
  s.state.day = strayCatDay;
  s.state.hasCat = true;
  s.state.addPet('meo');
  s.state.addPet('hac', fedDay: s.state.day);
  s.state.addPet('ca_chep', fedDay: s.state.day);
  s.state.money = 100000000;
  s.state.phaLe = 500;
  s.openPetRoom(id);
  return s;
}

Future<void> _pump(WidgetTester tester, ShopSession s) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _frame,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(child: PetScreen(session: s)),
              if (s.petItemShopOpen)
                Positioned.fill(child: PetItemShopScreen(session: s)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadTestFonts);
  if (_dir == null) {
    test('screenshots skipped (SHOT_DIR not set)', () {}, skip: true);
    return;
  }

  for (final size in _sizes) {
    final tag = '${size.width.round()}';

    testWidgets('pet room $tag', (tester) async {
      _size(tester, size);
      final s = _room('meo');
      await _pump(tester, s);
      await _save(tester, 'room_01_meo_$tag');
      s.stepRoomPet(1);
      await tester.pump();
      await _save(tester, 'room_02_hac_$tag');
      // A stroked Hạc: its own picture and hearts.
      await tester.tap(find.byKey(const Key('pet-cat')));
      await tester.pump(const Duration(milliseconds: 300));
      await _save(tester, 'room_03_hac_vuot_$tag');
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('pet-hold')));
      await tester.pump(const Duration(milliseconds: 300));
      await _save(tester, 'room_04_hac_be_$tag');
      await tester.pump(const Duration(seconds: 2));
      // Cá chép, dressed, ready to break through.
      s.stepRoomPet(1);
      final pet = s.roomPet!;
      pet.progress = 100;
      pet.worn['head'] = 'mu_rom';
      s.state.petItems['mu_rom'] = 1;
      s.state.petCharm = 'ca_chep';
      s.notifyListeners();
      await tester.pump();
      await _save(tester, 'room_05_ca_chep_dua_$tag');
    });

    testWidgets('picker chip to the shop $tag', (tester) async {
      _size(tester, size);
      final s = _room('meo');
      await _pump(tester, s);
      await tester.tap(find.byKey(const Key('pet-slot-neck')));
      await tester.pump();
      await _save(tester, 'chip_01_picker_$tag');
      s.openPetItemShopFor('chuong_ngoc');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _save(tester, 'chip_02_shop_focus_$tag');
    });

    testWidgets('rewards tag $tag', (tester) async {
      _size(tester, size);
      final r = await board.rig(tester, n: 0, pet: 'kim_long', stage: 2);
      r.s.openPetSlots();
      await board.mount(tester, r.s);
      await tester.runAsync(() => r.s.board.publishIfDue());
      await board.open(tester, r.s);
      await tester.runAsync(() => r.s.board.refresh(force: true));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bxh-rewards-btn')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(Bxh.youAt(1)), findsOneWidget);
      await _save(
        tester,
        'bxh_rewards_tag_$tag',
        of: find
            .ancestor(
              of: find.byKey(const Key('bxh-screen')),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
    });
  }
}
