// Khung tin nhắn: economy.json chatBubbleFrames, Phú's nine-slice bubble,
// the world chat drawing the stamped frame, the picker on your own card.
import 'package:ai_game/data/chat_frames.dart';
import 'package:ai_game/data/titles.dart';
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/wallet.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/ui/chat_bubble.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/world_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'charm_board_screen_test.dart' show loadFonts;

WidgetTester? tester0;

void main() {
  final cfg = loadTestData().economy.chatFrames;
  setUpAll(loadFonts);
  Transform flip(String id) => tester0!.widget<Transform>(
    find.descendant(
      of: find.byKey(Key('chat-bubble-$id')),
      matching: find.byType(Transform),
    ),
  );

  test('economy.json: 6 frames, VIP 5/7/9, the two titles, default thường', () {
    expect(cfg.frames.map((f) => f.id), [
      'chat_thuong',
      'chat_vip_bac',
      'chat_vip_vang',
      'chat_vip_ngoc',
      'chat_de_nhat_goi_hoa',
      'chat_mi_luc_nhat_troi',
    ]);
    expect(cfg.frames.map((f) => f.vip), [0, 5, 7, 9, 0, 0]);
    expect(cfg.byId('chat_de_nhat_goi_hoa')!.title, TitleIds.rating);
    expect(cfg.byId('chat_mi_luc_nhat_troi')!.title, TitleIds.charm);
    expect(cfg.defaultId, 'chat_thuong');
    for (final f in cfg.frames) {
      expect(chatFrameArtOf(f.id), isNotNull, reason: f.id);
      expect(ChatFrameText.name(f.id), isNotEmpty, reason: f.id);
    }
    expect(chatFrameArtOf('chat_thuong')!.top, 50);
    expect(
      chatFrameArtOf('chat_vip_ngoc')!.slice,
      const Rect.fromLTRB(200, 130, 382, 199),
    );
  });

  test(
    'effective: like the server (title only while held, VIP hidden = thường)',
    () {
      expect(
        cfg.effective(
          'chat_de_nhat_goi_hoa',
          base: 'chat_vip_bac',
          holds: (_) => true,
        ),
        'chat_de_nhat_goi_hoa',
      );
      expect(
        cfg.effective('chat_de_nhat_goi_hoa', base: 'chat_vip_bac'),
        'chat_vip_bac',
      );
      expect(cfg.effective('chat_vip_bac', badgeHidden: true), 'chat_thuong');
      expect(
        cfg.effective(
          'chat_mi_luc_nhat_troi',
          holds: (_) => true,
          badgeHidden: true,
        ),
        'chat_mi_luc_nhat_troi',
      );
      expect(cfg.effective('nope'), 'chat_thuong');
    },
  );

  testWidgets('bubble: nine-slice at 0.25, 13 sp #2E5E3D, text below the '
      'decoration, own flipped; unknown = thường', (tester) async {
    tester0 = tester;
    Future<void> show(Widget w) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: w)),
      ),
    );
    await show(const ChatBubble(frameId: 'chat_vip_vang', text: 'chào'));
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.centerSlice, chatFrameArtOf('chat_vip_vang')!.slice);
    final text = tester.widget<Text>(find.text('chào'));
    expect(text.style!.fontSize, 13);
    expect(text.style!.color, const Color(0xFF2E5E3D));
    final bubble = tester.getRect(
      find.byKey(const Key('chat-bubble-chat_vip_vang')),
    );
    expect(tester.getTopLeft(find.text('chào')).dy - bubble.top, 32.5);
    expect(
      tester.getTopLeft(find.text('chào')).dx - bubble.left,
      20,
      reason: 'decorated frames: 20 dp sides (Phú 21:33)',
    );
    expect(bubble.width, greaterThanOrEqualTo(104));
    expect(flip('chat_vip_vang').transform.storage[0], 1);

    await show(const ChatBubble(frameId: 'x', text: 'mình', own: true));
    expect(find.byKey(const Key('chat-bubble-chat_thuong')), findsOneWidget);
    expect(flip('chat_thuong').transform.storage[0], -1);
    final b2 = tester.getRect(find.byKey(const Key('chat-bubble-chat_thuong')));
    expect(tester.getTopLeft(find.text('mình')).dy - b2.top, 12.5);
    expect(tester.getTopLeft(find.text('mình')).dx - b2.left, 12);

    // Mị Lực Nhất Trời: same insets, the first line 10 dp lower (top 18
    // instead of 8) so it clears the bell; sides 20 like the others.
    await show(const ChatBubble(frameId: 'chat_mi_luc_nhat_troi', text: 'meo'));
    final b3 = tester.getRect(
      find.byKey(const Key('chat-bubble-chat_mi_luc_nhat_troi')),
    );
    expect(tester.getTopLeft(find.text('meo')).dy - b3.top, 42.5);
    expect(tester.getTopLeft(find.text('meo')).dx - b3.left, 20);
    expect(
      chatFrameArtOf('chat_mi_luc_nhat_troi')!.slice,
      const Rect.fromLTRB(200, 130, 383, 206),
    );
  });

  testWidgets('world chat draws each message in the frame the server stamped', (
    tester,
  ) async {
    final chat = MemoryWorldChat(on: true)
      ..add(
        ChatMessage(
          id: 'm0000000001',
          uid: 'p1',
          name: 'Tiệm Lan',
          text: 'xin chào',
          seq: 1,
          bubble: 'chat_mi_luc_nhat_troi',
          createdAt: DateTime.now(),
        ),
      )
      ..add(
        ChatMessage(
          id: 'm0000000002',
          uid: 'p2',
          name: 'Tiệm Cúc',
          text: 'chào nha',
          seq: 2,
          createdAt: DateTime.now(),
        ),
      );
    final s = newSession(worldChat: chat)..accountUid = 'me';
    s.state.day = 9;
    s.chat.openChat();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorldChatSheet(session: s)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const Key('chat-bubble-chat_mi_luc_nhat_troi')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat-bubble-chat_thuong')), findsOneWidget);
  });

  testWidgets(
    'your card: Khung tin nhắn with open / locked / using, equip toast, '
    'lost-title and hidden-VIP notes',
    (tester) async {
      final frames =
          MemoryAvatarFrames(
              loadTestData().economy.avatarFrames,
              profiles: {
                'me': PublicProfile(
                  day: 40,
                  titles: PlayerTitles(
                    uid: 'me',
                    stats: const {
                      TitleIds.rating: TitleStat(
                        timesWon: 1,
                        lastPeriod: 'rating-2',
                      ),
                    },
                    holders: const {
                      TitleIds.rating: TitleHolder(
                        titleId: TitleIds.rating,
                        holderUid: 'me',
                      ),
                    },
                  ),
                ),
              },
            )
            ..chatConfig = cfg
            ..vipMax = 7
            ..holding = {TitleIds.rating}
            ..chat = const ChatFrameChoice(
              chosen: 'chat_vip_bac',
              base: 'chat_vip_bac',
              lostTitle: TitleIds.charm,
            );
      final ShopSession s = newSession(avatarFrames: frames)..accountUid = 'me';
      s.wallet = const WalletView(
        phaLe: 0,
        vip: VipStatus(level: 3, max: 7, badgeHidden: true),
      );
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: PlayerProfileCard(
                    session: s,
                    uid: 'me',
                    name: 'Tiệm Hoa Sớm Mai',
                    avatar: '',
                    onClose: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(find.text(ChatFrameText.section), findsOneWidget);
      expect(
        find.text(ChatFrameText.lostTitleNote('Mị Lực Nhất Trời')),
        findsOneWidget,
      );
      expect(find.text(ChatFrameText.hiddenVipNote), findsOneWidget);
      expect(
        find.byKey(const Key('profile-card-chat-frame-using-chat_vip_bac')),
        findsOneWidget,
      );
      expect(find.text(ChatFrameText.lockedVip(9)), findsOneWidget);
      expect(
        find.text(ChatFrameText.lockedTitle('Mị Lực Nhất Trời')),
        findsOneWidget,
      );
      final equip = find.byKey(
        const Key('profile-card-chat-frame-equip-chat_de_nhat_goi_hoa'),
      );
      await tester.ensureVisible(equip);
      await tester.pump();
      await tester.tap(equip);
      await tester.pump();
      expect(find.text(ChatFrameText.equipToast), findsOneWidget);
      expect(frames.chat.chosen, 'chat_de_nhat_goi_hoa');
      expect(frames.chat.base, 'chat_vip_bac');
      expect(
        find.byKey(
          const Key('profile-card-chat-frame-using-chat_de_nhat_goi_hoa'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
