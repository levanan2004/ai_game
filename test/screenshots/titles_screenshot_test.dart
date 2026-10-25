// Danh hiệu: Phú's nameplates (still and mid-shine), the cabinet on the
// profile card, the rank-1 reward rows and the preview.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/titles_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/data/titles.dart';
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/title_plate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../ui/charm_board_screen_test.dart' show loadFonts, rig;

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

/// All five plates.
Widget _plates({TitleLook look = TitleLook.normal}) {
  const ids = [
    (TitleIds.rating, 'Đệ Nhất Gói Hoa'),
    (TitleIds.charm, 'Mị Lực Nhất Trời'),
    (TitleIds.customers1k, 'Người Bán Hoa Tận Tâm'),
    (TitleIds.customers10k, 'Chủ Shop Được Yêu Mến'),
    (TitleIds.customers100k, 'Chủ Shop Huyền Thoại'),
  ];
  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final (id, name) in ids)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TitlePlate(id: id, name: name, width: 328, look: look),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (id, name) in ids)
            TitlePlate(id: id, name: name, height: 28, fx: TitleFx.shine),
        ],
      ),
    ],
  );
}

Widget _card(ShopSession s, String uid, String name) => Stack(
  children: [
    Positioned.fill(
      child: PlayerProfileCard(
        key: ValueKey(uid),
        session: s,
        uid: uid,
        name: name,
        avatar: 'minh_anh',
        onClose: () {},
      ),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('title shots', skip: _dir == null, (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    TitlePlate.motion = false;
    await tester.pumpWidget(_app(_plates()));
    await _wait(tester);
    await _save(tester, 'titles_1_plates_still_360');
    await tester.pumpWidget(_app(_plates(look: TitleLook.faded)));
    await _wait(tester);
    await _save(tester, 'titles_2_plates_held_before_360');
    await tester.pumpWidget(_app(_plates(look: TitleLook.locked)));
    await _wait(tester);
    await _save(tester, 'titles_3_plates_locked_360');

    TitlePlate.motion = true;
    await tester.pumpWidget(_app(_plates()));
    await _wait(tester);
    // A new cycle: shine part way across, sparkles twinkling.
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(_app(_plates()));
    await _wait(tester, 2);
    await tester.pump(const Duration(milliseconds: 420));
    await _save(tester, 'titles_4_plates_shine_360');
    await tester.pump(const Duration(milliseconds: 1500));
    await _save(tester, 'titles_5_plates_glow_sparkles_360');

    // The cabinet: own card.
    final frames = MemoryAvatarFrames(
      loadTestData().economy.avatarFrames,
      profiles: {
        'me': const PublicProfile(
          day: 120,
          titles: PlayerTitles(
            uid: 'me',
            pinned: TitleIds.rating,
            customers: 4200,
            stats: {
              TitleIds.rating: TitleStat(timesWon: 2, lastPeriod: 'rating-2'),
              TitleIds.charm: TitleStat(timesWon: 1, lastPeriod: 'season-1'),
              TitleIds.customers1k: TitleStat(permanent: true, retro: true),
            },
            holders: {
              TitleIds.rating: TitleHolder(
                titleId: TitleIds.rating,
                holderUid: 'me',
              ),
              TitleIds.charm: TitleHolder(
                titleId: TitleIds.charm,
                holderUid: 'p1',
              ),
            },
          ),
        ),
        'p3': const PublicProfile(
          day: 9,
          titles: PlayerTitles(uid: 'p3', customers: 640),
        ),
      },
    );
    final s = newSession(avatarFrames: frames)..accountUid = 'me';
    s.state.shopName = 'Tiệm Hoa Sớm Mai';
    await tester.pumpWidget(_app(_card(s, 'me', 'Tiệm Hoa Sớm Mai')));
    await _wait(tester, 4);
    await tester.pump(const Duration(milliseconds: 250)); // burst + toast
    await _save(tester, 'titles_6_cabinet_own_folded_360');
    await tester.ensureVisible(
      find.byKey(const Key('profile-card-title-see-all')),
    );
    await tester.tap(find.byKey(const Key('profile-card-title-see-all')));
    await tester.pump();
    await _wait(tester, 2);
    final scroll = find
        .descendant(
          of: find.byKey(const Key('profile-card')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scroll, const Offset(0, -330));
    await _wait(tester, 2);
    await _save(tester, 'titles_7_cabinet_own_mid_360');
    await tester.drag(scroll, const Offset(0, -400));
    await _wait(tester, 2);
    await _save(tester, 'titles_8_cabinet_own_end_360');
    await tester.pump(const Duration(seconds: 5));

    await tester.pumpWidget(_app(_card(s, 'p3', 'Tiệm Mới')));
    await _wait(tester, 4);
    await _save(tester, 'titles_9a_card_other_folded_360');
    await tester.ensureVisible(
      find.byKey(const Key('profile-card-title-see-all')),
    );
    await tester.tap(find.byKey(const Key('profile-card-title-see-all')));
    await tester.pump();
    await _wait(tester, 2);
    final scroll2 = find
        .descendant(
          of: find.byKey(const Key('profile-card')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scroll2, const Offset(0, -330));
    await _wait(tester, 2);
    await _save(tester, 'titles_9_cabinet_other_none_360');

    // Rank-1 reward rows.
    await tester.pumpWidget(_app(const SizedBox()));
    tester.view.physicalSize = const Size(360, 640);
    final r = await rig(tester, n: 20, pet: 'kim_long', stage: 2);
    await tester.runAsync(() async {
      await r.s.board.publishIfDue();
      await r.s.board.refresh(force: true);
    });
    r.s.charmBoardOpen = true;
    r.s.board.openRewards();
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: r.s,
          builder: (_, _) => CharmBoardScreen(session: r.s),
        ),
      ),
    );
    await _wait(tester, 4);
    await tester.pump(const Duration(milliseconds: 400));
    await _save(tester, 'titles_10_charm_reward_rank1_360x640');
    await tester.tap(find.byKey(const Key('bxh-reward-title-plate-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _wait(tester, 2);
    await _save(tester, 'titles_11_preview_360x640');
    await tester.tap(find.byKey(const Key('title-preview-close')));
    await tester.pump(const Duration(milliseconds: 400));

    r.s.board.closeRewards();
    r.s.openRatingBoard();
    r.s.ratingBoard.openRewards();
    await tester.pump();
    await _wait(tester, 3);
    await tester.pump(const Duration(milliseconds: 400));
    await _save(tester, 'titles_12_rating_reward_rank1_360x640');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
