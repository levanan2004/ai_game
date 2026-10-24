// Khung tin nhắn: the 6 frames in Tin thế giới (others' and own, flipped),
// long and short text, and the picker on your own profile card.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/chat_frames_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/data/titles.dart';
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/wallet.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/chat_bubble.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/world_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../ui/charm_board_screen_test.dart' show loadFonts;

final _dir = Platform.environment['SHOT_DIR'];

Future<void> _wait(WidgetTester tester, [int rounds = 3]) async {
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

const _ids = [
  'chat_thuong',
  'chat_vip_bac',
  'chat_vip_vang',
  'chat_vip_ngoc',
  'chat_de_nhat_goi_hoa',
  'chat_mi_luc_nhat_troi',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat frame shots', skip: _dir == null, (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 1. All 6 frames, short and long text, others' then own (flipped).
    await tester.pumpWidget(
      _app(
        ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final (i, id) in _ids.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: i.isEven
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: ChatBubble(
                      frameId: id,
                      own: i.isOdd,
                      text: i < 2
                          ? 'Chào cả nhà!'
                          : 'Hôm nay tiệm mình bán được 60 khách, ai cần hoa cưới cứ ghé nha.',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    await _wait(tester, 8);
    await _save(tester, 'chat_frames_1_all_six_360');

    // 2. Tin thế giới with stamped frames.
    final chat = MemoryWorldChat(on: true);
    final now = DateTime.now();
    final rows = [
      (
        'p1',
        'Tiệm Lan',
        'chat_mi_luc_nhat_troi',
        'Chúc mọi người buôn may bán đắt!',
      ),
      ('p2', 'Tiệm Cúc', '', 'Có ai đổi chậu sứ không?'),
      ('me', 'Tiệm Hoa Sớm Mai', 'chat_vip_vang', 'Mình mới lên VIP 7 nè 🌼'),
      ('p3', 'Tiệm Mai', 'chat_vip_ngoc', 'Đá quý đẹp quá trời'),
      ('p4', 'Tiệm Hồng', 'chat_de_nhat_goi_hoa', 'Mùa này gói hoa vui ghê'),
      ('p5', 'Tiệm Sen', 'chat_vip_bac', 'Lá bạc cũng xinh lắm'),
    ];
    for (final (i, (uid, name, bubble, text)) in rows.indexed) {
      chat.add(
        ChatMessage(
          id: 'm${(i + 1).toString().padLeft(10, '0')}',
          uid: uid,
          name: name,
          text: text,
          seq: i + 1,
          bubble: bubble,
          createdAt: now.subtract(Duration(minutes: 6 - i)),
        ),
      );
    }
    final store = ProgressStore.memory({ProgressStore.chatRulesKey: 'true'});
    final s = newSession(store: store, worldChat: chat)..accountUid = 'me';
    s.state.day = 30;
    await s.chat.useStore(store);
    s.chat.openChat();
    await tester.pumpWidget(_app(WorldChatSheet(session: s)));
    await _wait(tester, 8);
    await _save(tester, 'chat_frames_2_world_chat_360');

    // 3. Your card: the picker (VIP max 7, holding Đệ Nhất Gói Hoa).
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
          ..chatConfig = loadTestData().economy.chatFrames
          ..vipMax = 7
          ..holding = {TitleIds.rating}
          ..chat = const ChatFrameChoice(
            chosen: 'chat_vip_vang',
            base: 'chat_vip_vang',
          );
    final ShopSession me = newSession(avatarFrames: frames)..accountUid = 'me';
    me.wallet = const WalletView(phaLe: 0, vip: VipStatus(level: 7, max: 7));
    await tester.pumpWidget(
      _app(
        Stack(
          children: [
            Positioned.fill(
              child: PlayerProfileCard(
                session: me,
                uid: 'me',
                name: 'Tiệm Hoa Sớm Mai',
                avatar: '',
                onClose: () {},
              ),
            ),
          ],
        ),
      ),
    );
    await _wait(tester);
    await tester.ensureVisible(
      find.byKey(const Key('profile-card-chat-frames')),
    );
    await _wait(tester, 2);
    await _save(tester, 'chat_frames_3_profile_picker_360');
    await tester.drag(
      find.byKey(const Key('profile-card-chat-frame-chat_thuong')),
      const Offset(-420, 0),
    );
    await _wait(tester, 2);
    await _save(tester, 'chat_frames_4_profile_picker_scrolled_360');
    await tester.pumpWidget(const SizedBox());
  });
}
