// Khung avatar skins (spec skin_trang_tri "Chot 25/10 toi"): the frame drawn
// over the round avatar on the profile card (96 dp), the leaderboard rows
// (40 dp), Tin the gioi (32 dp), and the frame sheet with a skin to buy.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/avatar_frame_skin_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/preset_avatars.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/avatar_frame_sheet.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/world_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../ui/charm_board_screen_test.dart' show loadFonts, rig;

final _dir = Platform.environment['SHOT_DIR'];

const _skins = [
  'khung_avatar_mac_dinh',
  'khung_avatar_tet',
  'khung_avatar_he_bien',
  'khung_avatar_trung_thu',
  'khung_avatar_son_hai',
  'khung_avatar_bxh_mua1',
];

Future<void> _wait(WidgetTester tester, [int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _app(Widget child) => RepaintBoundary(
  key: const Key('shot'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(color: AppColors.bgBase, child: child),
  ),
);

MemoryAvatarFrames _frames(Map<String, String> worn) {
  final d = loadTestData();
  return MemoryAvatarFrames(
    d.economy.avatarFrames.withSkins({
      for (final k in d.skins.ofSlot('khungAvatar')) k.id: k.tier,
    }),
    skins: {'khung_avatar_he_bien', 'khung_avatar_son_hai'},
    worn: worn,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('avatar frame skin shots', skip: _dir == null, (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Decode the skin frame sprites once (the lossy webp decode is slower
    // than the screenshot waits).
    await tester.pumpWidget(_app(const SizedBox()));
    final ctx = tester.element(find.byType(SizedBox).last);
    await tester.runAsync(() async {
      for (final id in _skins) {
        for (final size in ['lon', 'nho']) {
          await precacheImage(
            AssetImage('assets/images/avatar_frames/${id}_$size.webp'),
            ctx,
          );
        }
      }
    });

    // 1. Profile card: own avatar (96 dp) in Khung May Song Vang.
    final mine = _frames({'me': 'khung_avatar_son_hai'});
    final me = newSession(avatarFrames: mine)..accountUid = 'me';
    me.setOwnerAvatar(presetAvatarIds[3]);
    await tester.runAsync(me.frames.refresh);
    await tester.pumpWidget(
      _app(
        Stack(
          children: [
            Positioned.fill(
              child: PlayerProfileCard(
                session: me,
                uid: 'me',
                name: 'Tiem Hoa Som Mai',
                avatar: presetAvatarIds[3],
                onClose: () {},
              ),
            ),
          ],
        ),
      ),
    );
    await _wait(tester);
    await _save(tester, 'khung_avatar_1_profile_96dp');

    // 2. Leaderboard rows (40 dp): every skin frame on a row.
    final board = _frames({
      for (var i = 0; i < 12; i++) 'p$i': _skins[i % _skins.length],
    });
    final r = await rig(tester, n: 12, frames: board);
    await tester.runAsync(() async {
      await r.s.board.publishIfDue();
      await r.s.board.refresh(force: true);
      await r.s.frames.prefetch([for (var i = 0; i < 12; i++) 'p$i']);
    });
    r.s.charmBoardOpen = true;
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: r.s,
          builder: (_, _) => CharmBoardScreen(session: r.s),
        ),
      ),
    );
    await _wait(tester);
    await tester.drag(find.byKey(const Key('bxh-list')), const Offset(0, -300));
    await _wait(tester);
    await _save(tester, 'khung_avatar_2_leaderboard_40dp');

    // 3. Tin the gioi (32 dp).
    final chat = MemoryWorldChat(on: true);
    final now = DateTime.now();
    for (var i = 0; i < 6; i++) {
      chat.add(
        ChatMessage(
          id: 'm${(i + 1).toString().padLeft(10, '0')}',
          uid: 'c$i',
          name: 'Tiem ${i + 1}',
          text: 'Chao ca nha, hom nay ban hoa vui qua!',
          seq: i + 1,
          avatar: presetAvatarIds[i],
          // Stamped by the server from player_avatars (world_chat.js).
          frame: _skins[i],
          createdAt: now.subtract(Duration(minutes: 6 - i)),
        ),
      );
    }
    final chatFrames = _frames({for (var i = 0; i < 6; i++) 'c$i': _skins[i]});
    final store = ProgressStore.memory({ProgressStore.chatRulesKey: 'true'});
    final s = newSession(
      store: store,
      worldChat: chat,
      avatarFrames: chatFrames,
    )..accountUid = 'me';
    s.state.day = 30;
    await s.chat.useStore(store);
    await tester.runAsync(
      () => s.frames.prefetch([for (var i = 0; i < 6; i++) 'c$i']),
    );
    s.chat.openChat();
    await tester.pumpWidget(_app(WorldChatSheet(session: s)));
    await _wait(tester, 8);
    await _save(tester, 'khung_avatar_3_chat_32dp');

    // 4. Frame sheet: Khung Do Hoa Mai not owned yet, with its Pha le price.
    me.state.phaLe = 500;
    me.frames.openPicker();
    me.frames.select('khung_avatar_tet');
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: Listenable.merge([me, me.frames]),
          builder: (_, _) => AvatarFrameSheet(session: me),
        ),
      ),
    );
    await _wait(tester);
    await _save(tester, 'khung_avatar_4_frame_shop_buy');
    me.frames.select('khung_avatar_son_hai');
    await _wait(tester, 2);
    await _save(tester, 'khung_avatar_5_frame_shop_owned');
    me.frames.select('khung_avatar_bxh_mua1');
    await _wait(tester, 2);
    await _save(tester, 'khung_avatar_6_frame_shop_event');
    await tester.pumpWidget(const SizedBox());
  });
}
