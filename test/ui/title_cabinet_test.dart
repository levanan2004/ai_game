// Danh hiệu cabinet on the profile card, the nameplate (Phú) and the
// milestone toasts with the device's seen record.
import 'package:ai_game/data/titles.dart';
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/title_plate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'charm_board_screen_test.dart' show loadFonts;

PublicProfile _me({MilestoneNote note = MilestoneNote.none}) => PublicProfile(
  day: 120,
  titles: PlayerTitles(
    uid: 'me',
    pinned: TitleIds.rating,
    customers: 4200,
    note: note,
    stats: const {
      TitleIds.rating: TitleStat(timesWon: 2, lastPeriod: 'rating-2'),
      TitleIds.charm: TitleStat(timesWon: 1, lastPeriod: 'season-1'),
      TitleIds.customers1k: TitleStat(permanent: true, retro: true),
    },
    holders: const {
      TitleIds.rating: TitleHolder(titleId: TitleIds.rating, holderUid: 'me'),
      TitleIds.charm: TitleHolder(titleId: TitleIds.charm, holderUid: 'p1'),
    },
  ),
);

Future<void> _mount(WidgetTester tester, ShopSession s, String uid) async {
  tester.view.physicalSize = const Size(360, 1400);
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
                uid: uid,
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
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  test('the seen record is per account and survives a reload', () async {
    final backing = <String, String>{};
    final a = ProgressStore.memory(backing);
    expect(await a.titlesSeen('me'), isEmpty);
    await a.saveTitlesSeen('me', {TitleIds.customers1k});
    final b = ProgressStore.memory(backing);
    expect(await b.titlesSeen('me'), {TitleIds.customers1k});
    expect(await b.titlesSeen('other'), isEmpty);
    backing[ProgressStore.titlesSeenKey('x')] = 'not json';
    expect(await b.titlesSeen('x'), isEmpty);
  });

  test('text size: 18 sp when it fits, down to 14, then 2 lines at 13, '
      'never below', () {
    final short = fitTitleText('Đệ Nhất Gói Hoa', const Size(300, 40));
    expect(short, (size: titleMaxSp, lines: 1, fits: true));
    final mid = fitTitleText('Chủ Shop Được Yêu Mến', const Size(170, 40));
    expect(mid.fits, isTrue);
    expect(mid.size, lessThan(titleMaxSp));
    expect(mid.size, greaterThanOrEqualTo(titleMinSp));
    expect(mid.lines, 1);
    final two = fitTitleText('Chủ Shop Được Yêu Mến', const Size(120, 40));
    expect(two, (size: titleTwoLineSp, lines: 2, fits: true));
    final tight = fitTitleText('Chủ Shop Được Yêu Mến', const Size(60, 20));
    expect(tight, (size: titleTwoLineSp, lines: 2, fits: false));
  });

  testWidgets('effects: full = glow, shine, sparkles; next to names only the '
      'shine; faded / locked none', (tester) async {
    TitlePlate.motion = true;
    Future<void> show(Widget w) async {
      await tester.pumpWidget(MaterialApp(home: Center(child: w)));
      await tester.pump(const Duration(milliseconds: 300)); // shine crossing
    }

    await show(
      const TitlePlate(
        id: TitleIds.rating,
        name: 'Đệ Nhất Gói Hoa',
        width: 320,
      ),
    );
    expect(find.byKey(const Key('title-plate-glow')), findsOneWidget);
    expect(find.byKey(const Key('title-plate-shine')), findsOneWidget);
    expect(find.byKey(const Key('title-plate-sparkles')), findsOneWidget);
    expect(find.text('Đệ Nhất Gói Hoa'), findsOneWidget);
    expect(tester.getSize(find.byType(TitlePlate)).width, 320);

    await show(
      const TitlePlate(
        id: TitleIds.charm,
        name: 'Mị Lực Nhất Trời',
        height: 28,
        fx: TitleFx.shine,
      ),
    );
    expect(tester.getSize(find.byType(TitlePlate)).height, 28);
    expect(find.byKey(const Key('title-plate-shine')), findsOneWidget);
    expect(find.byKey(const Key('title-plate-glow')), findsNothing);
    expect(find.byKey(const Key('title-plate-sparkles')), findsNothing);

    for (final look in [TitleLook.faded, TitleLook.locked]) {
      await show(
        TitlePlate(
          id: TitleIds.customers10k,
          name: 'Chủ Shop Được Yêu Mến',
          width: 320,
          look: look,
        ),
      );
      expect(find.byKey(const Key('title-plate-shine')), findsNothing);
      expect(find.byKey(const Key('title-plate-glow')), findsNothing);
    }

    // Reduce motion: still plate, no moving shine.
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: TitlePlate(
              id: TitleIds.rating,
              name: 'Đệ Nhất Gói Hoa',
              width: 320,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('title-plate-shine')), findsNothing);
    expect(find.byKey(const Key('title-plate-glow')), findsOneWidget);

    // Next to names: the compact chip (22 dp, radius 11) with the shine.
    await show(const TitleChip(id: TitleIds.charm, name: 'Mị Lực Nhất Trời'));
    expect(tester.getSize(find.byKey(const Key('title-chip'))).height, 22);
    expect(find.byKey(const Key('title-chip-shine')), findsOneWidget);
    final box =
        tester
                .widget<Container>(find.byKey(const Key('title-chip')))
                .decoration!
            as BoxDecoration;
    expect(box.borderRadius, BorderRadius.circular(11));
    expect(box.gradient, isNotNull);
    await show(
      const TitleChip(id: TitleIds.customers1k, name: 'Người Bán Hoa Tận Tâm'),
    );
    final green =
        tester
                .widget<Container>(find.byKey(const Key('title-chip')))
                .decoration!
            as BoxDecoration;
    expect(green.color, const Color(0xFF3F7F52));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('your cabinet: 5 cells in their states, the retro toast once', (
    tester,
  ) async {
    final backing = <String, String>{};
    final frames = MemoryAvatarFrames(
      loadTestData().economy.avatarFrames,
      profiles: {'me': _me(note: MilestoneNote.short)},
    );
    final s = newSession(avatarFrames: frames, backing: backing)
      ..accountUid = 'me';
    await _mount(tester, s, 'me');
    // Folded: the 2 titles held now.
    expect(find.text(TitleText.count(2)), findsOneWidget);
    expect(
      find.byKey(const Key('profile-card-title-mi_luc_nhat_troi')),
      findsNothing,
    );
    await _tap(tester, const Key('profile-card-title-see-all'));
    for (final id in s.e.titles.cabinet) {
      expect(
        find.byKey(Key('profile-card-title-$id')),
        findsOneWidget,
        reason: id,
      );
    }
    // Rating: held and worn, ×2; the 22 dp chip next to the name.
    expect(
      find.byKey(const Key('profile-card-title-times-de_nhat_goi_hoa')),
      findsOneWidget,
    );
    expect(find.text(TitleText.wearing), findsOneWidget);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const Key('profile-card-wearing')),
              matching: find.byType(TitleChip),
            ),
          )
          .height,
      22,
    );
    // Charm: held before, faded, "Đã từng giữ 1 mùa", no badge.
    expect(find.text(TitleText.timesWon(1)), findsOneWidget);
    expect(
      find.byKey(const Key('profile-card-title-times-mi_luc_nhat_troi')),
      findsNothing,
    );
    final charm = tester.widget<TitlePlate>(
      find.byKey(const Key('profile-card-title-plate-mi_luc_nhat_troi')),
    );
    expect(charm.look, TitleLook.faded);
    // 1k reached: "Vĩnh viễn", colour, one burst; 10k / 100k progress.
    expect(find.text(TitleText.permanent), findsOneWidget);
    final k1 = tester.widget<TitlePlate>(
      find.byKey(const Key('profile-card-title-plate-title_khach_1k')),
    );
    expect((k1.look, k1.burst), (TitleLook.normal, true));
    expect(find.text('Bán cho 4.200/10.000 khách'), findsOneWidget);
    expect(find.text('Bán cho 4.200/100.000 khách'), findsOneWidget);
    expect(
      tester
          .widget<TitlePlate>(
            find.byKey(const Key('profile-card-title-plate-title_khach_10k')),
          )
          .look,
      TitleLook.locked,
    );
    expect(find.text(TitleText.customersNotCounted), findsOneWidget);
    // The retro toast, and the seen record.
    expect(
      find.text(
        'Tiệm của bạn đã phục vụ 1.000 khách từ trước, nên nhận luôn danh hiệu '
        '"Người Bán Hoa Tận Tâm".',
      ),
      findsOneWidget,
    );
    expect(await s.progressStore.titlesSeen('me'), {TitleIds.customers1k});
    // Tap 10k: Nhất's hint; tap 1k: desc + wear.
    await _tap(tester, const Key('profile-card-title-title_khach_10k'));
    expect(
      find.text('Bán hoa cho 10.000 khách để nhận danh hiệu này.'),
      findsOneWidget,
    );
    expect(find.text(TitleText.customersOnline), findsOneWidget);
    await _tap(tester, const Key('profile-card-title-title_khach_1k'));
    expect(find.text('Đã bán hoa cho 1.000 khách'), findsOneWidget);
    await _tap(tester, const Key('profile-card-title-wear-title_khach_1k'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(frames.pins, [TitleIds.customers1k]);
    expect(
      find.text(
        'Đã đeo "Người Bán Hoa Tận Tâm". Danh hiệu hiện cạnh tên bạn trên các bảng xếp hạng.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));

    // Open again: seen, so no toast and no burst.
    await tester.pumpWidget(const SizedBox());
    await _mount(tester, s, 'me');
    expect(find.textContaining('từ trước, nên nhận luôn'), findsNothing);
    expect(
      tester
          .widget<TitlePlate>(
            find.byKey(const Key('profile-card-title-plate-title_khach_1k')),
          )
          .burst,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('someone with no titles: champion cells locked with a hint', (
    tester,
  ) async {
    final frames = MemoryAvatarFrames(
      loadTestData().economy.avatarFrames,
      profiles: {
        'p3': const PublicProfile(
          day: 3,
          titles: PlayerTitles(uid: 'p3', customers: 640),
        ),
      },
    );
    final s = newSession(avatarFrames: frames)..accountUid = 'me';
    await _mount(tester, s, 'p3');
    expect(find.text(TitleText.emptyOther), findsOneWidget);
    expect(find.text(TitleText.count(0)), findsOneWidget);
    await _tap(tester, const Key('profile-card-title-see-all'));
    expect(find.byKey(const Key('profile-card-title-empty')), findsNothing);
    expect(find.byKey(const Key('profile-card-title-lock')), findsNWidgets(2));
    expect(find.text(TitleText.locked), findsNWidgets(2));
    expect(find.text('Bán cho 640/1.000 khách'), findsOneWidget);
    expect(find.byKey(const Key('profile-card-title-note')), findsNothing);
    await _tap(tester, const Key('profile-card-title-mi_luc_nhat_troi'));
    expect(find.text(TitleText.lockedHintCharm), findsOneWidget);
    expect(
      find.byKey(const Key('profile-card-title-wear-mi_luc_nhat_troi')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
