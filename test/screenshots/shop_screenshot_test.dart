// Renders the main shop to PNGs for a visual check. Skipped unless
// SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/logic/game_notice.dart';
import 'package:ai_game/logic/inbox.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/notice_feed.dart';
import 'package:ai_game/logic/shop_shelf.dart';
import 'package:ai_game/logic/welfare.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/corner_menu.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:flame/game.dart';
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
}

class _News implements NoticeBoard {
  @override
  Future<List<GameNotice>> published() async => const [
    GameNotice(id: 'n1', title: 'Tin mới', body: ''),
  ];
}

ShopSession _session({
  required int? stage,
  String name = 'Tiệm Hoa Tổng Xanh',
}) {
  final s = newSession(sounds: Sounds(heard: []));
  s.state.shopName = name;
  s.state.day = 12;
  s.state.phaLe = 1250;
  s.state.phase = DayPhase.open;
  s.state.elapsed = s.e.secondsPerHour * 2.5;
  s.state.hasCat = stage != null;
  s.state.petStage = stage ?? 0;
  s.screen = Screen.shop;
  return s;
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required ShopSession session,
  double ratio = 2,
  bool tip = false,
  bool pets = false,
  bool menu = false,
  int rounds = 4,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final game = ShopGame(session);
  // One unread announcement, so the basket shows its red dot.
  final inbox = Inbox(
    mail: MailboxFeed(),
    news: NoticeFeed(
      board: _News(),
      seen: NoticeSeen.memory(),
      initial: const [GameNotice(id: 'n1', title: 'Tin mới', body: '')],
    ),
  );
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
                builder: (context, _) => Stack(
                  children: [
                    Positioned.fill(child: GameWidget<ShopGame>(game: game)),
                    Positioned.fill(
                      child: pets
                          ? PetScreen(session: session)
                          : MainShopOverlay(session: session),
                    ),
                    // Basket menu where game_root puts it.
                    if (!pets)
                      Positioned.fill(
                        child: CornerMenu(
                          left: 272,
                          top: 4,
                          listenable: inbox,
                          entries: menuEntries(
                            inbox: inbox,
                            welfare: WelfareFeed(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var round = 0; round < rounds; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  if (menu) {
    await tester.tap(find.byKey(const Key('corner-menu')));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
  if (tip) {
    final taps = shelfTapsOf(session);
    taps.tap(taps.clockArea!.center);
    await tester.pump(const Duration(milliseconds: 300));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
  // Let the tip timer run out before the test ends.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('shop screen shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    await _shoot(
      tester,
      name: 'shop_phone_390x844_cat_lon',
      size: const Size(390, 844),
      session: _session(stage: 1),
    );
    await _shoot(
      tester,
      name: 'shop_phone_390x844_ten_dai',
      size: const Size(390, 844),
      // Long name: the sign shrinks the text to fit between the flowers.
      session: _session(stage: 1, name: 'Tiệm Hoa Sớm Mai Bên Hồ 99'),
    );
    // Dot 2 pots on the bar and the display stands, drawn with potScale.
    final pots = _session(stage: 1);
    pots.state.barPots
      ..[0] = 'chau_song_tu'
      ..[1] = 'chau_su_tu'
      ..[2] = 'chau_thao_thiet'
      ..[3] = 'dragon'
      ..[4] = 'chau_ky_lan';
    pots.state.displayPots
      ..[0] = 'chau_bach_duong'
      ..[1] = 'chau_con_bang'
      ..[2] = 'qilin'
      ..[3] = 'chau_song_ngu'
      ..[4] = 'chau_ho_cap'
      ..[5] = 'koi';
    await _shoot(
      tester,
      name: 'shop_phone_390x844_chau_moi',
      size: const Size(390, 844),
      session: pots,
      rounds: 100,
    );
    await _shoot(
      tester,
      name: 'shop_menu_mo_390x844',
      size: const Size(390, 844),
      session: _session(stage: 1),
      menu: true,
    );
    // Pet screen, grown cat: cost on the button, owned bánh mật above it.
    final grown = _session(stage: 2)
      ..state.biscuits = 237
      ..screen = Screen.pets;
    await _shoot(
      tester,
      name: 'pet_truong_thanh_390x844',
      size: const Size(390, 844),
      session: grown,
      pets: true,
    );
    await _shoot(
      tester,
      name: 'shop_phone_390x844_no_pet_clock_tip',
      size: const Size(390, 844),
      session: _session(stage: null),
      tip: true,
    );
    await _shoot(
      tester,
      name: 'shop_desktop_1280x800_cat_truong',
      size: const Size(1280, 800),
      session: _session(stage: 2),
      ratio: 1,
    );
    // Tiệm Chậu Hoa: placing mode with a preview, and the first-time hint.
    ShopSession placing() {
      final s = _session(stage: 1)
        ..state.phase = DayPhase.preparing
        ..state.elapsed = 0
        ..state.potShopHintShown = true
        ..state.money = 800000;
      s.state.potCounts['chau_su_tu'] = 1;
      s.state.barPots[1] = 'dragon';
      s.state.potCounts['dragon'] = 1;
      s.startPlaceMode('chau_su_tu');
      return s;
    }

    await _shoot(
      tester,
      name: 'dat_chau_chon_cho_360x640',
      size: const Size(360, 640),
      session: placing(),
    );
    await _shoot(
      tester,
      name: 'dat_chau_xem_truoc_390x844',
      size: const Size(390, 844),
      session: placing()..previewPlaceSlot(bar: true, index: 1),
    );
    await _shoot(
      tester,
      name: 'dat_chau_xem_truoc_ke_360x640',
      size: const Size(360, 640),
      session: placing()..previewPlaceSlot(bar: false, index: 3),
    );
    await _shoot(
      tester,
      name: 'goi_y_tiem_chau_hoa_390x844',
      size: const Size(390, 844),
      session: (_session(stage: 1)
        ..state.phase = DayPhase.preparing
        ..state.elapsed = 0
        ..state.money = 800000),
    );
    await _shoot(
      tester,
      name: 'shop_phone_360x640_cat_au',
      size: const Size(360, 640),
      session: _session(stage: 0),
    );
  });
}
