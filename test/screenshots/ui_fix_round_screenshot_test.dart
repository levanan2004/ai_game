// UI fix round shots (pot detail, pet room, ticker, Cam nang, brush).
// Skipped unless SHOT_DIR is set; SHOT_ONLY=<name> limits to one group:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/ui_fix_round_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/logic/game_notice.dart';
import 'package:ai_game/logic/inbox.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/notice_feed.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/welfare.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/data/skins.dart';
import 'package:ai_game/ui/corner_menu.dart';
import 'package:ai_game/ui/decorate_screen.dart';
import 'package:ai_game/ui/frame_metrics.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/pet_screen.dart';
import 'package:ai_game/ui/pot_popup.dart';
import 'package:ai_game/ui/so_tay_screen.dart';
import 'package:ai_game/ui/world_chat_ticker.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _dir = Platform.environment['SHOT_DIR'];
final _only = Platform.environment['SHOT_ONLY'];

Future<void> _loadFonts() async {
  const fonts = {
    AppFonts.body: 'assets/fonts/nunito/Nunito-VariableFont_wght.ttf',
    AppFonts.display: 'assets/fonts/baloo2/Baloo2-VariableFont_wght.ttf',
  };
  // Icon font, so the ticker's megaphone and x are not tofu boxes.
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '${root ?? r'C:\flutter'}/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final bytes = icons.readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  for (final e in fonts.entries) {
    final bytes = File(e.value).readAsBytesSync();
    await (FontLoader(
      e.key,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

ShopSession _session() {
  final s = newSession(sounds: Sounds(heard: []));
  s.state.shopName = 'Ti\u{1ec7}m Hoa S\u{1edb}m Mai';
  s.state.day = 12;
  s.state.hasCat = true;
  s.state.petStage = 1;
  return s;
}

Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required ShopSession session,
  required Widget Function() child,
  required Size size,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
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
                builder: (context, _) => child(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  if (act != null) {
    await act();
    await _settle(tester);
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
}

Widget _shop(ShopSession s) => Stack(
  children: [
    Positioned.fill(child: GameWidget<ShopGame>(game: ShopGame(s))),
    Positioned.fill(child: MainShopOverlay(session: s)),
  ],
);

/// The shop as game_root lays it on a tall phone: the 640 stage centred,
/// the overlay scaled with the Flame camera, so both line up.
Widget _stage(ShopSession s) => ColoredBox(
  color: AppColors.surfaceCard,
  child: Center(
    child: AspectRatio(
      aspectRatio: 360 / 640,
      child: Stack(
        children: [
          Positioned.fill(child: GameWidget<ShopGame>(game: ShopGame(s))),
          Positioned.fill(
            child: FittedBox(child: MainShopOverlay(session: s)),
          ),
        ],
      ),
    ),
  ),
);

/// A screen on the 640 stage the way game_root places it on a tall phone
/// (GameFrame grows the frame; the stage sits at [FrameMetrics.stageGapTop]).
Widget _onStage(Widget child) => Builder(
  builder: (context) {
    final top = FrameMetrics.maybeOf(context)?.stageGapTop ?? 0;
    return Stack(
      children: [
        Positioned(left: 0, top: top, width: 360, height: 640, child: child),
      ],
    );
  },
);

/// The main shop as game_root lays it (An 26/10): the Flame scene on the
/// 640 stage under the safe area, the overlay stretched to the bottom.
Widget _shopStage(ShopSession s) => Builder(
  builder: (context) {
    final m = FrameMetrics.maybeOf(context);
    final top = m?.stageGapTop ?? 0;
    final bottom = m?.stageGapBottom ?? 0;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: top,
          width: 360,
          height: 640,
          child: GameWidget<ShopGame>(game: ShopGame(s)),
        ),
        Positioned(
          left: 0,
          top: top,
          width: 360,
          height: 640 + bottom,
          child: MainShopOverlay(session: s),
        ),
        // The Hop thu / Phuc loi basket where game_root puts it, with one
        // unread announcement so its red badge shows.
        Positioned(
          left: 0,
          top: top,
          width: 360,
          height: 640 + bottom,
          child: CornerMenu(
            left: CornerMenu.shopHudLeft,
            top: 4 + (m?.topInset ?? 0),
            listenable: _fix10Inbox,
            entries: menuEntries(
              inbox: _fix10Inbox,
              welfare: WelfareFeed(),
              session: s,
            ),
          ),
        ),
      ],
    );
  },
);

class _News implements NoticeBoard {
  @override
  Future<List<GameNotice>> published() async => const [
    GameNotice(id: 'n1', title: 'Tin m\u{1edb}i', body: ''),
  ];
}

final _fix10Inbox = Inbox(
  mail: MailboxFeed(),
  news: NoticeFeed(
    board: _News(),
    seen: NoticeSeen.memory(),
    initial: const [GameNotice(id: 'n1', title: 'Tin m\u{1edb}i', body: '')],
  ),
);

/// Fix 10 session: morning of day 12 before opening (Mo cua, Ban do tab),
/// ticker on with one message, the cat, So tay unlocked.
ShopSession _fix10Session() {
  final chat = MemoryWorldChat(on: true)
    ..add(
      ChatMessage(
        id: 'm0000000001',
        uid: 'c1',
        name: 'Tiệm Lan',
        text: 'Chào cả nhà, hôm nay bán hoa vui quá!',
        seq: 1,
        createdAt: DateTime.now(),
      ),
    );
  final s = newSession(
    sounds: Sounds(heard: []),
    worldChat: chat,
  );
  s.accountUid = 'me';
  s.chat.enabled = true;
  s.state.shopName = 'An X\u00e0i Tech';
  s.state.day = 12;
  s.state.hasCat = true;
  s.state.petStage = 1;
  s.state.lifetimeGreat = 1000;
  s.state.phase = DayPhase.preparing;
  s.screen = Screen.shop;
  s.markPotHintShown();
  return s;
}

const _sizes = [('desktop', Size(1280, 800)), ('360dp', Size(360, 740))];

bool _want(String group) => _only == null || _only == group;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('ui fix round shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    for (final (tag, size) in _sizes) {
      if (_want('pot')) {
        final s = _session();
        s.state.potCounts['tiger'] = 1;
        s.openPotPicker(bar: false, index: 0);
        await _shoot(
          tester,
          name: 't2_pot_detail_$tag',
          session: s,
          size: size,
          child: () => Center(child: PotPopup(session: s)),
          act: () async {
            final cell = find.byKey(const Key('pot-cell-tiger'));
            await tester.scrollUntilVisible(cell, 80);
            await tester.tap(cell);
          },
        );
      }
      if (_want('pets')) {
        final s = _session();
        s.openPets();
        await _shoot(
          tester,
          name: 't3_pet_room_$tag',
          session: s,
          size: size,
          child: () => PetScreen(session: s),
        );
      }
      if (_want('decor')) {
        for (final group in [skinGroupShop, skinGroupRoom]) {
          final s = _session();
          s.state.day = 60; // thuong costs 1.5M before x2
          s.openDecorate(group);
          await _shoot(
            tester,
            name: 't6_decorate_${group}_$tag',
            session: s,
            size: size,
            child: () => DecorateScreen(session: s),
          );
        }
      }
      final fix1 = _want('fix1') || _only == 'fix2';
      if (_want('shelf') || fix1) {
        for (final theme
            in fix1
                ? const ['mac_dinh', 'tet', 'son_hai']
                : const [
                    'mac_dinh',
                    'bxh_mua1',
                    'son_hai',
                    'he_bien',
                    'tet',
                    'trung_thu',
                  ]) {
          final s = _session();
          s.screen = Screen.shop;
          s.markPotHintShown();
          const pots = [
            'dragon',
            'phoenix',
            'tiger',
            'tortoise',
            'qilin',
            'chau_bao_binh',
          ];
          for (var i = 0; i < pots.length; i++) {
            s.state.displayPots[i] = pots[i];
          }
          final picks = <String, String>{};
          for (final d in s.skins.list) {
            if (d.slot != 'nenManHinh' || d.theme != theme) continue;
            s.state.ownedSkins.add(d.id);
            picks[d.slot] = d.id;
          }
          s.wearSkins(picks);
          await _shoot(
            tester,
            name: fix1
                ? '${_only ?? 'fix1'}_${theme}_$tag'
                : 't1_shelf_${theme}_$tag',
            session: s,
            size: size,
            child: () => _shop(s),
            // The pot pictures load after the first frames.
            act: () => tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 4)),
            ),
          );
        }
      }
      if (_only == 'fix3' && tag == '360dp') {
        // Shop open at the evening peak, so the rush pill shows.
        final s = _session()..state.phase = DayPhase.open;
        s.screen = Screen.shop;
        s.markPotHintShown();
        final e = s.e;
        final peak = e.peakWindows.peaks.last;
        s.state.elapsed = (peak.start - e.openHour) * e.secondsPerHour + 0.01;
        await _shoot(
          tester,
          name: 'fix3_mac_dinh_${tag}_open',
          session: s,
          size: size,
          child: () => _shop(s),
        );
      }
      if ((_only == 'fix4' && tag == '360dp') || _only == 'fix5') {
        // Tight top: shop open at the evening peak (rush pill), Tin the
        // gioi ticker on, So tay unlocked.
        final chat = MemoryWorldChat(on: true)
          ..add(
            ChatMessage(
              id: 'm0000000001',
              uid: 'c1',
              name: 'Tiệm Lan',
              text: 'Chào cả nhà, hôm nay bán hoa vui quá!',
              seq: 1,
              createdAt: DateTime.now(),
            ),
          );
        final s = newSession(
          sounds: Sounds(heard: []),
          worldChat: chat,
        );
        s.accountUid = 'me';
        s.state.shopName = 'Ti\u{1ec7}m Hoa S\u{1edb}m Mai';
        s.state.hasCat = true;
        s.state.petStage = 1;
        s.state.day = 60;
        s.state.lifetimeGreat = 1000;
        s.state.phase = DayPhase.open;
        s.chat.enabled = true;
        s.screen = Screen.shop;
        s.markPotHintShown();
        if (_only == 'fix5') {
          const pots = [
            'dragon',
            'phoenix',
            'tiger',
            'tortoise',
            'qilin',
            'chau_bao_binh',
          ];
          for (var i = 0; i < pots.length; i++) {
            s.state.displayPots[i] = pots[i];
          }
        }
        final e = s.e;
        final peak = e.peakWindows.peaks.last;
        s.state.elapsed = (peak.start - e.openHour) * e.secondsPerHour + 0.01;
        expect(s.notebookUnlocked, isTrue);
        expect(WorldChatTicker.on(s), isTrue);
        await _shoot(
          tester,
          name: _only == 'fix5'
              ? (tag == '360dp' ? 'fix5_360dp_tight' : 'fix5_$tag')
              : 'fix4_mac_dinh_${tag}_tight',
          session: s,
          size: size,
          child: () => _shop(s),
          // Pot pictures load late; the ticker text scrolls in from the
          // right, so give it game time to reach the middle.
          act: () async {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 4)),
            );
            await tester.pump(const Duration(seconds: 3));
          },
        );
      }
      if (_only == 'fix6' || _only == 'fix7') {
        // Morning (brush shows), all six stand pots owned, the Vong quay
        // icon offered, Tin the gioi ticker on.
        final chat = MemoryWorldChat(on: true);
        final s = newSession(
          sounds: Sounds(heard: []),
          worldChat: chat,
        );
        s.accountUid = 'me';
        s.state.shopName = 'Ti\u{1ec7}m Hoa S\u{1edb}m Mai';
        s.state.day = 60;
        s.chat.enabled = true;
        s.screen = Screen.shop;
        s.markPotHintShown();
        const pots = [
          'dragon',
          'phoenix',
          'tiger',
          'tortoise',
          'qilin',
          'chau_bao_binh',
        ];
        for (var i = 0; i < (_only == 'fix7' ? 4 : pots.length); i++) {
          s.state.displayPots[i] = pots[i];
          s.state.potCounts[pots[i]] = 1;
        }
        await _shoot(
          tester,
          name: '${_only}_$tag',
          session: s,
          size: size,
          child: () => _shop(s),
          act: () => tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 4)),
          ),
        );
      }
      if (_only == 'fix8') {
        // Ke 6 chau shelf per background skin: 4 pots, 2 empty '+' slots.
        for (final theme in const ['mac_dinh', 'tet', 'son_hai']) {
          final s = newSession(sounds: Sounds(heard: []));
          s.state.day = 60;
          s.screen = Screen.shop;
          s.markPotHintShown();
          const pots = ['dragon', 'phoenix', 'tiger', 'tortoise'];
          for (var i = 0; i < pots.length; i++) {
            s.state.displayPots[i] = pots[i];
            s.state.potCounts[pots[i]] = 1;
          }
          final picks = <String, String>{};
          for (final d in s.skins.list) {
            if (d.slot != 'nenManHinh' || d.theme != theme) continue;
            s.state.ownedSkins.add(d.id);
            picks[d.slot] = d.id;
          }
          s.wearSkins(picks);
          await _shoot(
            tester,
            name: 'fix8_${theme}_$tag',
            session: s,
            size: size,
            child: () => _shop(s),
            act: () => tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 4)),
            ),
          );
        }
      }
      if (_only == 'fix9' && tag == '360dp') {
        // Fix 9: ke 6 chau pots on every skin, one shop sign, So tay above
        // the cabinet, bucket row inside the screen, Vong quay over the pet.
        for (final w in const [360.0, 393.0]) {
          for (final theme in const [
            'mac_dinh',
            'bxh_mua1',
            'son_hai',
            'he_bien',
            'tet',
            'trung_thu',
          ]) {
            final chat = MemoryWorldChat(on: true)
              ..add(
                ChatMessage(
                  id: 'm0000000001',
                  uid: 'c1',
                  name: 'Tiệm Lan',
                  text: 'Chào cả nhà, hôm nay bán hoa vui quá!',
                  seq: 1,
                  createdAt: DateTime.now(),
                ),
              );
            final s = newSession(
              sounds: Sounds(heard: []),
              worldChat: chat,
            );
            s.accountUid = 'me';
            s.chat.enabled = true;
            s.state.shopName = 'An X\u00e0i Tech';
            s.state.day = 12;
            s.state.hasCat = true;
            s.state.petStage = 1;
            s.state.lifetimeGreat = 1000;
            s.screen = Screen.shop;
            s.markPotHintShown();
            const pots = ['dragon', 'phoenix', 'tiger', 'tortoise'];
            for (var i = 0; i < pots.length; i++) {
              s.state.displayPots[i] = pots[i];
              s.state.potCounts[pots[i]] = 1;
            }
            final picks = <String, String>{};
            for (final d in s.skins.list) {
              if (d.slot != 'nenManHinh' || d.theme != theme) continue;
              s.state.ownedSkins.add(d.id);
              picks[d.slot] = d.id;
            }
            s.wearSkins(picks);
            await _shoot(
              tester,
              name: 'fix9_${theme}_${w.round()}dp',
              session: s,
              size: Size(w, w * 852 / 393),
              child: () => _stage(s),
              act: () => tester.runAsync(
                () => Future<void>.delayed(const Duration(seconds: 4)),
              ),
            );
            if (theme == 'he_bien') {
              // Ticker closed with its x: the reopen button by the sign,
              // red dot for news that came in meanwhile.
              s.chat.dismissTicker();
              s.chat.tickerArrivals++;
              await _shoot(
                tester,
                name: 'fix9_ticker_hidden_${w.round()}dp',
                session: s,
                size: Size(w, w * 852 / 393),
                child: () => _stage(s),
                act: () => tester.runAsync(
                  () => Future<void>.delayed(const Duration(seconds: 4)),
                ),
              );
            }
          }
        }
      }
      if (_only == 'fix10' && tag == '360dp') {
        // 360 wide at the 393x852 aspect (tall phone, no safe area).
        const size = Size(360, 360 * 852 / 393);
        for (final (theme, sz, tag) in const [
          ('mac_dinh', Size(360, 360 * 852 / 393), '393x852'),
          ('son_hai', Size(360, 360 * 852 / 393), '393x852'),
          ('mac_dinh', Size(360, 640), '360x640'),
        ]) {
          final s = _fix10Session();
          final picks = <String, String>{};
          for (final d in s.skins.list) {
            if (d.slot != 'nenManHinh' || d.theme != theme) continue;
            s.state.ownedSkins.add(d.id);
            picks[d.slot] = d.id;
          }
          s.wearSkins(picks);
          await _shoot(
            tester,
            name: 'fix10_task2_shop_${theme}_$tag',
            session: s,
            size: sz,
            child: () => _shopStage(s),
            act: () async {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(seconds: 4)),
              );
              // The ticker text mid-scroll.
              await tester.pump(const Duration(seconds: 3));
            },
          );
        }
        for (final (sz, tag) in const [
          (Size(360, 640), '360x640'),
          (Size(360, 360 * 852 / 393), '393x852'),
        ]) {
          final s = _fix10Session();
          await _shoot(
            tester,
            name: 'fix10_topbar_basket_$tag',
            session: s,
            size: sz,
            child: () => _shopStage(s),
            act: () => tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 4)),
            ),
          );
        }
        // 11 pots with flowers (Phu 26/10): morning, empty stock, and with
        // the first three kinds in stock.
        for (final (theme, stock) in const [
          ('mac_dinh', false),
          ('son_hai', false),
          ('mac_dinh', true),
        ]) {
          final s = _fix10Session();
          final picks = <String, String>{};
          for (final d in s.skins.list) {
            if (d.slot != 'nenManHinh' || d.theme != theme) continue;
            s.state.ownedSkins.add(d.id);
            picks[d.slot] = d.id;
          }
          s.wearSkins(picks);
          if (stock) {
            for (final f in s.unlockedFlowers.take(3)) {
              s.state.stock.add(
                StockBatch(flowerId: f.id, count: 6, freshnessLeft: 3),
              );
            }
          }
          await _shoot(
            tester,
            name: 'fix10_pots11c_${stock ? 'stock_' : ''}${theme}_393x852',
            session: s,
            size: const Size(360, 360 * 852 / 393),
            child: () => _shopStage(s),
            act: () => tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 4)),
            ),
          );
        }
        final p = _fix10Session()..openPets();
        await _shoot(
          tester,
          name: 'fix10_pet_room_360dp',
          session: p,
          size: size,
          child: () => _onStage(PetScreen(session: p)),
        );
        for (final (tag5, sz) in const [
          ('393x852', Size(360, 360 * 852 / 393)),
          ('360x640', Size(360, 640)),
        ]) {
          final t5 = _fix10Session()..openNotebook();
          await _shoot(
            tester,
            name: 'fix10_task5_so_tay_$tag5',
            session: t5,
            size: sz,
            child: () => _onStage(SoTayScreen(session: t5)),
          );
        }
        final n = _fix10Session()..openNotebook();
        await _shoot(
          tester,
          name: 'fix10_so_tay_360dp',
          session: n,
          size: size,
          child: () => _onStage(SoTayScreen(session: n)),
        );
      }
      if (_want('brush')) {
        final s = _session(); // before opening: the brush shows
        s.screen = Screen.shop;
        await _shoot(
          tester,
          name: 't7_brush_$tag',
          session: s,
          size: size,
          child: () => _shop(s),
        );
      }
      if (_want('shop')) {
        final s = _session()..state.phase = DayPhase.open;
        s.screen = Screen.shop;
        await _shoot(
          tester,
          name: 'shop_$tag',
          session: s,
          size: size,
          child: () => _shop(s),
        );
      }
    }
  });
}
