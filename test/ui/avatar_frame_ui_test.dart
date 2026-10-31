import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/art.dart';
import 'package:ai_game/ui/avatar_frame_sheet.dart';
import 'package:ai_game/ui/player_avatar.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/world_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'charm_board_screen_test.dart' as board_test;

/// Khung avatar on screen: the one avatar widget draws the frame (72% hole,
/// `_nho` at 28 dp), Tin thế giới shows the frame the server stamped and opens
/// the profile card from "Xem hồ sơ", and the F1 sheet wears frames through
/// the server.
void main() {
  // The real fonts, like the board's own tests (the test font is far wider).
  setUpAll(board_test.loadFonts);

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('PlayerAvatar: the frame spills, the slot stays 2·radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const PlayerAvatar(avatar: '', name: 'Mai', radius: 48, frameId: 'la_non')),
    );
    final slot = tester.getSize(find.byType(PlayerAvatar));
    expect(slot, const Size(96, 96));
    final frame = find.byKey(const Key('player-avatar-frame-la_non'));
    expect(frame, findsOneWidget);
    expect(tester.getSize(frame).width, closeTo(96 / 0.72, 0.01));
    expect(
      (tester.widget<Image>(frame).image as AssetImage).assetName,
      Art.avatarFrame('la_non'),
    );
    expect(tester.getCenter(frame), tester.getCenter(find.byType(PlayerAvatar)));

    await tester.pumpWidget(
      host(const PlayerAvatar(avatar: '', name: 'Mai', radius: 14, frameId: 'la_non')),
    );
    expect(
      (tester.widget<Image>(find.byKey(const Key('player-avatar-frame-la_non'))).image
              as AssetImage)
          .assetName,
      Art.avatarFrame('la_non', small: true),
      reason: '28 dp uses the simple sprite',
    );

    await tester.pumpWidget(
      host(const PlayerAvatar(avatar: 'minh_anh', name: 'Mai', radius: 20)),
    );
    expect(find.byKey(const Key('player-avatar-frame-la_non')), findsNothing);
  });

  Future<(ShopSession, MemoryWorldChat, MemoryAvatarFrames)> chat(
    WidgetTester tester, {
    Map<String, PublicProfile>? profiles,
  }) async {
    final e = loadTestData().economy;
    final src = MemoryAvatarFrames(e.avatarFrames, profiles: profiles);
    final c = MemoryWorldChat(on: true);
    c.add(
      ChatMessage(
        id: 'm0000000001',
        uid: 'u2',
        name: 'Tiệm Lan',
        text: 'chào cả nhà',
        seq: 1,
        frame: 'la_non',
        createdAt: DateTime.now(),
      ),
    );
    final store = ProgressStore.memory({ProgressStore.chatRulesKey: 'true'});
    final s = newSession(store: store, worldChat: c, avatarFrames: src);
    s.accountUid = 'me';
    s.state.day = 9;
    await s.chat.useStore(store);
    await s.board.useHiddenPlayers(store);
    s.chat.openChat();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: WorldChatSheet(session: s))),
    );
    await tester.pump();
    await tester.pump();
    return (s, c, src);
  }

  testWidgets('chat: the stamped frame, "Xem hồ sơ" opens the profile card', (
    tester,
  ) async {
    await chat(
      tester,
      profiles: {
        'u2': const PublicProfile(
          day: 37,
          entry: CharmBoardEntry(
            uid: 'u2',
            displayName: 'Tiệm Lan',
            avatar: '',
            charm: 312,
          ),
        ),
      },
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('world-chat-msg-m0000000001')),
        matching: find.byKey(const Key('player-avatar-frame-la_non')),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('world-chat-more-m0000000001')));
    await tester.pump();
    expect(find.text('Xem hồ sơ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-chat-menu-profile')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('profile-card')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('profile-card-avatar'))),
      const Size(PlayerProfileCard.avatarSize, PlayerProfileCard.avatarSize),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-card')),
        matching: find.byKey(const Key('player-avatar-frame-la_non')),
      ),
      findsOneWidget,
    );
    expect(find.text('Ngày thứ 37'), findsOneWidget);
    // Phú spec 2.4: Khách đã bán | Sao trung bình | Mùa giữ hạng 1.
    expect(find.byKey(const Key('profile-card-customers')), findsOneWidget);
    expect(find.text(ProfileText.statStars), findsOneWidget);
    expect(find.text(ProfileText.statChampion), findsOneWidget);
    expect(find.text('Chưa mang pet'), findsOneWidget);
    expect(find.byKey(const Key('profile-card-report')), findsOneWidget);
    expect(find.byKey(const Key('profile-card-block')), findsOneWidget);
    expect(find.byKey(const Key('profile-card-change-frame')), findsNothing);
    await tester.tap(find.byKey(const Key('profile-card-visit')));
    await tester.pump();
    expect(find.text('Tính năng ghé tiệm đang được làm, chờ nhé!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byKey(const Key('profile-card-block')));
    await tester.pump();
    expect(find.byKey(const Key('world-chat-block')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the avatar opens the card too; a failed read can retry', (
    tester,
  ) async {
    final (_, _, src) = await chat(tester);
    src.fail = true;
    await tester.tap(find.byKey(const Key('world-chat-avatar-m0000000001')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Không tải được hồ sơ'), findsOneWidget);
    src.fail = false;
    await tester.tap(find.byKey(const Key('profile-card-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Không tải được hồ sơ'), findsNothing);
    expect(find.text('Chưa mang pet'), findsOneWidget);
  });

  testWidgets('F1: VIP frames locked, wearing goes through the server', (
    tester,
  ) async {
    final e = loadTestData().economy;
    final src = MemoryAvatarFrames(e.avatarFrames);
    final s = newSession(avatarFrames: src);
    s.accountUid = 'me';
    s.frames.openPicker();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: s.frames,
            builder: (_, _) => s.frames.pickerOpen
                ? AvatarFrameSheet(session: s)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Khung avatar'), findsOneWidget);
    for (final f in e.avatarFrames.frames) {
      expect(find.byKey(Key('frame-cell-${f.id}')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(Key('frame-cell-${f.id}'))),
        const Size(AvatarFrameSheet.cell, AvatarFrameSheet.cell),
      );
    }
    expect(find.byKey(const Key('frame-cell-locked-la_non')), findsNothing);
    expect(find.byKey(const Key('frame-cell-locked-vip_hoa_dao')), findsOneWidget);
    expect(find.text('Khung mặc định khi đăng nhập'), findsOneWidget);
    expect(find.byKey(const Key('frame-sheet-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('frame-cell-vip_hoa_dao')));
    await tester.pump();
    expect(find.text('VIP Hoa đào'), findsOneWidget);
    expect(find.text('Mở ở VIP 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('frame-cell-hoa_dao')));
    await tester.pump();
    expect(find.text('Sự kiện Tết'), findsOneWidget);
    await tester.tap(find.byKey(const Key('frame-cell-vuong_mien_mua')));
    await tester.pump();
    expect(find.text('Thưởng top 3 mùa (giữ vĩnh viễn)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('frame-sheet-equip')));
    await tester.pump();
    expect(src.worn['me'], isNull, reason: 'a locked frame cannot be worn');

    await tester.tap(find.byKey(const Key('frame-cell-la_non')));
    await tester.pump();
    expect(find.text('Dùng khung này'), findsOneWidget);
    await tester.tap(find.byKey(const Key('frame-sheet-equip')));
    await tester.pump();
    await tester.pump();
    expect(src.worn['me'], 'la_non');
    expect(s.frames.equipped, 'la_non');
    expect(find.text('Đang dùng'), findsOneWidget);
    expect(find.text('Đã đổi khung avatar.'), findsOneWidget);
    expect(find.byKey(const Key('frame-cell-worn')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mị lực board: rows and the profile wear the server frame', (
    tester,
  ) async {
    final e = loadTestData().economy;
    final src = MemoryAvatarFrames(e.avatarFrames, worn: {'p1': 'la_non'});
    final r = await board_test.rig(tester, frames: src);
    await r.s.frames.refresh();
    await r.s.frames.equip('la_non');
    await board_test.mount(tester, r.s);
    await board_test.open(tester, r.s);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(r.s.frames.frameOf('p1'), 'la_non');
    expect(find.byKey(const Key('player-avatar-frame-la_non')), findsWidgets);
    final row = r.s.board.rows.firstWhere((x) => x.entry.uid == 'p1');
    r.s.board.openProfile(row);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('bxh-profile-avatar')),
        matching: find.byKey(const Key('player-avatar-frame-la_non')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bxh-change-frame')), findsNothing);
    await tester.runAsync(
      () => r.s.board.hidePlayer(row.entry.uid, row.entry.displayName),
    );
    await tester.pump();
    expect(r.s.frames.frameOf('p1'), 'la_non');
    expect(
      find.descendant(
        of: find.byKey(const Key('bxh-profile-avatar')),
        matching: find.byKey(const Key('player-avatar-frame-la_non')),
      ),
      findsNothing,
      reason: 'a hidden player shows no frame',
    );
    expect(tester.takeException(), isNull);
  });

  test('season number from the period key', () {
    expect(seasonNumberOf('season-3'), 3);
    expect(seasonNumberOf('mua_he'), isNull);
    expect(FrameText.name('vuong_mien_mua', season: 1), 'Vương Miện Mùa 1');
    expect(FrameText.name('vuong_mien_mua'), 'Vương Miện Mùa');
  });

  test('Season Pass frames: name and tier from season_pass_strings', () {
    final s = newSession();
    final c = s.e.avatarFrames;
    expect(FrameText.pass(s, c.byId('khung_avatar_sp_tri_an_2011_thuong')!), (
      'Khung avatar Tri ân 20/11',
      'Quà cấp 30',
    ));
    expect(FrameText.pass(s, c.byId('khung_avatar_sp_tri_an_2011_hiem')!), (
      'Khung avatar Tri ân 20/11',
      'Quà cấp 22',
    ));
    expect(FrameText.pass(s, c.byId('la_non')!), isNull);
  });
}
