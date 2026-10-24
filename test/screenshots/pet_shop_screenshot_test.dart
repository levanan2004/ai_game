// Renders the Tiệm thú cưng grid, its buy popup and a pet room to PNGs.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/pet_shop_grid.dart';
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

/// Mock balances (spec §9): 350.000 xu, 450 Pha lê, the cat at home.
ShopSession _session({bool open = false}) {
  final s = newSession(sounds: Sounds(heard: []));
  s.state.day = 12;
  s.state.money = 3000000;
  s.state.phaLe = 450;
  s.state.hasCat = true;
  s.state.petStage = 1;
  if (open) s.state.phase = DayPhase.open;
  s.openPetCatalog();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('Tiệm thú cưng shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    const shot = Key('shot');
    Future<void> grab(String name) async {
      await _settle(tester);
      await _save(tester, shot, name);
    }

    Future<void> scrollTo(String key) async {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
    }

    var s = _session();
    await tester.pumpWidget(_frame(shot, PetCatalogPopup(session: s)));
    await grab('pet_shop_top_360x640');

    // Grey xu button: the bubble says what is missing.
    await tester.tap(find.byKey(const Key('pet-buy-hac')));
    await tester.pump();
    await grab('pet_shop_thieu_xu_360x640');
    await tester.pump(const Duration(seconds: 3));

    await scrollTo('pet-card-bach_ho');
    await grab('pet_shop_middle_360x640');
    await tester.tap(find.byKey(const Key('pet-buy-bach_ho')));
    await tester.pump();
    await grab('pet_shop_thieu_pha_le_360x640');
    await tester.pump(const Duration(seconds: 3));

    await scrollTo('pet-shop-footer');
    await grab('pet_shop_bottom_360x640');

    // Buy popup (xu), then Pha lê with the toast and the owned card.
    s = _session();
    await tester.pumpWidget(
      _frame(shot, PetCatalogPopup(key: const ValueKey('b'), session: s)),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const Key('pet-buy-ca_chep')));
    await tester.pump();
    await grab('pet_shop_popup_xu_360x640');
    await tester.tap(find.byKey(const Key('pet-confirm-later')));
    await tester.pump();
    await scrollTo('pet-card-nghe');
    await tester.tap(find.byKey(const Key('pet-buy-nghe')));
    await tester.pump();
    await grab('pet_shop_popup_pha_le_360x640');
    await tester.tap(find.byKey(const Key('pet-confirm-yes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await grab('pet_shop_da_mua_toast_360x640');
    await tester.pump(const Duration(seconds: 3));

    // Open hours: buttons wait for closing time.
    s = _session(open: true);
    await tester.pumpWidget(
      _frame(shot, PetCatalogPopup(key: const ValueKey('c'), session: s)),
    );
    await grab('pet_shop_dang_mo_cua_360x640');

    // Vào phòng with Kim long.
    s = _session();
    s.state.addPet('kim_long');
    s.state.ownedPet('kim_long')!.stage = 2;
    s.openPetRoom('kim_long');
    await tester.pumpWidget(
      _frame(shot, PetScreen(key: const ValueKey('r'), session: s)),
    );
    await grab('pet_phong_kim_long_360x640');
    expect(s.roomPet!.id, 'kim_long');
    expect(petArtId('kim_long', 2), 'pet_kim_long_truong');
  });
}
