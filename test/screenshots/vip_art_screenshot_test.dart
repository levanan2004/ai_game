// Phú's final VIP art: the crown of each tier next to names (16/18 dp), on
// Tin thế giới and the profile card (32 dp), and the card background
// vip_nen_the on Màn VIP. Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/vip_art_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/vip_badge.dart';
import 'package:ai_game/ui/vip_screen.dart';
import 'package:ai_game/ui/world_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import '../logic/vip_test.dart' show FakeVipWallet, vipSession;

final _dir = Platform.environment['SHOT_DIR'];
const _frame = Key('shot-frame');

Future<void> _save(WidgetTester tester, String name) async {
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

/// Lets the asset images decode, then paints.
Future<void> _settleImages(WidgetTester tester) async {
  for (final e in find.byType(Image).evaluate()) {
    final img = e.widget as Image;
    await tester.runAsync(
      () => precacheImage(img.image, e).catchError((Object _) {}),
    );
  }
  await tester.pump();
}

Future<void> _phone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: _frame, child: child),
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

  testWidgets('vip_01 crowns next to names, VIP 1..10', (tester) async {
    await _phone(
      tester,
      Material(
        color: AppColors.bgBase,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var k = 1; k <= 10; k++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: VipName(
                          name: 'Tiệm Hoa $k',
                          level: k,
                          style: AppText.body(size: 14, weight: 800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      VipName(
                        name: 'Chat $k',
                        level: k,
                        style: AppText.caption(size: 12, weight: 800),
                        badgeSize: 16,
                      ),
                      const SizedBox(width: 12),
                      VipBadge(level: k, size: 32),
                    ],
                  ),
                ),
              const VipTitleLine(level: 10),
            ],
          ),
        ),
      ),
    );
    await _settleImages(tester);
    await _save(tester, 'vip_01_crowns');
  });

  testWidgets('vip_02 Tin thế giới and vip_03 the profile card', (
    tester,
  ) async {
    final c = MemoryWorldChat(on: true)
      ..add(
        ChatMessage(
          id: 'm0000000001',
          uid: 'u2',
          name: 'Tiệm Lan',
          text: 'Chào cả nhà, hôm nay tiệm có hoa sen mới!',
          seq: 1,
          vip: 10,
          createdAt: DateTime.now(),
        ),
      )
      ..add(
        ChatMessage(
          id: 'm0000000002',
          uid: 'u3',
          name: 'Tiệm Cúc',
          text: 'Đẹp quá!',
          seq: 2,
          vip: 4,
          createdAt: DateTime.now(),
        ),
      );
    final store = ProgressStore.memory({ProgressStore.chatRulesKey: 'true'});
    final e = loadTestData().economy;
    final s = newSession(
      store: store,
      worldChat: c,
      avatarFrames: MemoryAvatarFrames(e.avatarFrames),
    );
    s.accountUid = 'me';
    s.state.day = 9;
    await tester.runAsync(() async {
      await s.chat.useStore(store);
      await s.board.useHiddenPlayers(store);
    });
    s.chat.openChat();
    await _phone(tester, Scaffold(body: WorldChatSheet(session: s)));
    await tester.pump();
    await _settleImages(tester);
    await _save(tester, 'vip_02_tin_the_gioi');
    await tester.tap(find.byKey(const Key('world-chat-more-m0000000001')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('world-chat-menu-profile')));
    await tester.pump();
    await tester.pump();
    await _settleImages(tester);
    await _save(tester, 'vip_03_profile_card');
  });

  for (final level in const [1, 10]) {
    testWidgets('vip_04 Màn VIP card on vip_nen_the, VIP $level', (
      tester,
    ) async {
      final s = vipSession(FakeVipWallet(level: level, vnd: 15000000));
      await tester.runAsync(s.syncWallet);
      s.vip.openScreen();
      await _phone(
        tester,
        // In the game it sits in the root Scaffold's Stack.
        Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([s, s.vip]),
            builder: (_, _) => VipScreen(session: s),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      await _settleImages(tester);
      await _save(tester, 'vip_04_card_vip$level');
    });
  }
}
