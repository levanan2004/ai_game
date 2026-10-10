// Renders the pet slot picker (Ô thú cưng) and the pet room button to PNGs.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/pet_slots_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/pet_slots_screen.dart';
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

ShopSession _owning(Map<String, int> stages) {
  final s = newSession();
  s.state.day = strayCatDay;
  for (final e in stages.entries) {
    s.state.addPet(e.key);
    s.state.ownedPet(e.key)!.stage = e.value;
  }
  return s;
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  ShopSession s, {
  Widget Function(ShopSession)? build,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    _frame(
      ValueKey('shot-$name'),
      Builder(builder: (_) => (build ?? (s) => PetSlotsScreen(session: s))(s)),
    ),
  );
  key.toString();
  await _settle(tester);
  await _save(tester, ValueKey('shot-$name'), name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('pet slot picker shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;

    // 1. The cat only (it took both slots), then emptied: two empty slots.
    final empty = _owning({'meo': 0});
    empty.state.petIncome = null;
    empty.state.petCharm = null;
    empty.openPetSlots();
    await _shoot(tester, 'slots_1_hai_o_trong_360x640', empty);

    // 2. Income filled, Mị lực selected and empty.
    final one = _owning({'meo': 1, 'ca_chep': 0, 'hac': 2, 'kim_long': 1});
    one.state.petIncome = 'ca_chep';
    one.state.petCharm = null;
    one.openPetSlots();
    await _shoot(tester, 'slots_2_mot_o_360x640', one);

    // 3. Both full, mixed stages, nothing selected.
    final full = _owning({
      'meo': 2,
      'ca_chep': 1,
      'hac': 2,
      'nghe': 0,
      'huyen_vu': 1,
      'phuong_hoang': 2,
      'kim_long': 1,
    });
    full.state.petIncome = 'kim_long';
    full.state.petCharm = 'phuong_hoang';
    full.openPetSlots();
    await _shoot(tester, 'slots_3_hai_o_360x640', full);

    // 4. One pet in both slots, Thu nhập selected (swap hint), scrolled.
    final both = _owning({'meo': 0, 'ca_chep': 2, 'hac': 1});
    both.state.petIncome = 'hac';
    both.state.petCharm = 'hac';
    both.openPetSlots(select: petSlotIncome);
    await _shoot(tester, 'slots_4_mot_thu_hai_o_360x640', both);

    // 5. The pet room with the "Ô thú cưng" button.
    final room = _owning({'meo': 1});
    room.openPets();
    await _shoot(
      tester,
      'slots_5_phong_thu_nut_360x640',
      room,
      build: (s) => PetScreen(session: s),
    );
  });
}
