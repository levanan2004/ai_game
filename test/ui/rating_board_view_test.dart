import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/data/rating_board.dart';
import 'package:ai_game/data/titles.dart';
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/profile_report.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/rating_board_view.dart';
import 'package:ai_game/ui/reviews_screen.dart';
import 'package:ai_game/ui/season_text.dart';
import 'package:ai_game/ui/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'charm_board_screen_test.dart' show loadFonts;

RatingEntry _entry(String uid, String name, int v, double r) {
  final score = (v * r + 100 * 4.0) / (v + 100);
  return RatingEntry(
    uid: uid,
    displayName: name,
    v: v,
    sum: (v * r).round(),
    score: score,
    sortKey: v < 50 ? 0 : (score * 1000).round() * 10000 + v,
  );
}

Future<({ShopSession s, MemoryRatingBoard board})> _rig({
  DateTime? at,
  bool signedIn = true,
  int n = 8,
  MemoryAvatarFrames? frames,
}) async {
  final clock = at ?? DateTime.utc(2026, 11, 20, 5);
  final board = MemoryRatingBoard();
  final s = newSession(
    ratingBoard: board,
    now: () => clock,
    avatarFrames: frames,
  );
  final period = s.e.ratingBoard.periodKey;
  for (var i = 0; i < n; i++) {
    board.put(
      period,
      _entry('p$i', 'Tiệm Hoa Số ${i + 1}', 400 - i * 30, 4.9 - i * 0.05),
    );
  }
  if (signedIn) s.accountUid = 'me';
  s.state.shopName = 'Tiệm Hoa Sớm Mai';
  return (s: s, board: board);
}

Future<void> _mount(
  WidgetTester tester,
  ShopSession s, {
  bool reviews = false,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: ListenableBuilder(
              listenable: s,
              builder: (_, _) => Stack(
                children: [
                  if (reviews)
                    Positioned.fill(child: ReviewsScreen(session: s))
                  else if (s.charmBoardOpen)
                    Positioned.fill(child: CharmBoardScreen(session: s)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

final _shotDir = Platform.environment['SHOT_DIR'];

/// 17_* shots when SHOT_DIR is set (the board's 360x640 frame, 2x).
Future<void> _shot(WidgetTester tester, String name) async {
  if (_shotDir == null) return;
  // Let the image assets decode before the capture.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .ancestor(
          of: find.byKey(const Key('bxh-screen')),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${_shotDir!}${Platform.pathSeparator}$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadFonts);

  testWidgets('tabs, ribbon, rows with the score and count, the card', (
    tester,
  ) async {
    final r = await _rig();
    r.board.put(
      r.s.e.ratingBoard.periodKey,
      _entry('me', 'Tiệm Hoa Sớm Mai', 60, 5.0),
    );
    r.s.openRatingBoard();
    await _mount(tester, r.s);
    await _settle(tester);
    expect(find.text(RatingText.boardTitle), findsOneWidget);
    expect(find.text(RatingText.tabCharm), findsOneWidget);
    expect(find.text(RatingText.tabRating), findsOneWidget);
    expect(find.text(RatingText.explain), findsOneWidget);
    // season.ends_in on the shared clock.
    expect(
      find.text(seasonEndsInText(r.s.ratingBoard.season!, r.s.ratingBoard.now)),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mùa 2 chốt lúc 23:59 Chủ nhật 06/12'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rating-row-1')), findsOneWidget);
    // p0: 400 reviews at 4,9 -> (1960 + 400) / 500 = 4,72.
    expect(find.text('4,72'), findsOneWidget);
    expect(find.text(RatingText.rowCount(400)), findsOneWidget);
    // Own row (60 reviews of 5 -> 4,375) is above p7 (190 at 4,55 -> 4,36).
    expect(r.s.ratingBoard.myRank, 8);
    expect(find.text(RatingText.myCard('4,38', 60)), findsOneWidget);
  });

  testWidgets('under the minimum: "cần thêm {k} đánh giá"', (tester) async {
    final r = await _rig();
    r.board.put(r.s.e.ratingBoard.periodKey, _entry('me', 'x', 12, 5.0));
    r.s.openRatingBoard();
    await _mount(tester, r.s);
    await _settle(tester);
    // season.review.min_reviews.
    expect(find.text(SeasonText.reviewMinReviews(50, 12)), findsOneWidget);
  });

  testWidgets('ⓘ shows how the score works; rewards list from economy.json', (
    tester,
  ) async {
    final r = await _rig();
    r.board.put(r.s.e.ratingBoard.periodKey, _entry('me', 'x', 60, 5.0));
    r.s.openRatingBoard();
    await _mount(tester, r.s);
    await _settle(tester);
    await tester.tap(find.byKey(const Key('rating-how-btn')));
    await tester.pump();
    expect(find.text(RatingText.howBody(28, '4,0')), findsOneWidget);
    expect(find.text(RatingText.minRule(50)), findsOneWidget);
    expect(find.text(RatingText.fairNote), findsOneWidget);
    r.s.ratingBoard.closeSheets();
    await tester.pump();
    await tester.tap(find.byKey(const Key('rating-rewards-btn')));
    await tester.pump();
    // Đại 18/10: the Mị lực "Phần thưởng mùa" screen, not a text sheet.
    expect(find.byKey(const Key('rating-rewards')), findsOneWidget);
    expect(find.byKey(const Key('board-tabs')), findsNothing);
    expect(find.text(Bxh.rewardsTitle), findsOneWidget);
    expect(find.text(Bxh.rewardsHead), findsOneWidget);
    expect(find.text(RatingText.rewardsMin(50)), findsOneWidget);
    expect(find.text(RatingText.colXu), findsOneWidget);
    await _shot(tester, '17_danh_gia_thuong');
    Iterable<String> cells(String key) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        )
        .map((w) => w.data ?? '');
    expect(
      cells('rating-reward-1'),
      containsAll(['200', '20', 'Đệ Nhất Gói Hoa']),
    );
    expect(cells('rating-reward-1'), contains(TitleText.rewardTitleNote));
    // Rank 1 starts with the 28 dp mini plate; tap = the large preview.
    final plate = find.byKey(const Key('rating-reward-title-plate-1'));
    expect(tester.getSize(plate).height, 28);
    expect(find.byKey(const Key('rating-reward-title-plate-2')), findsNothing);
    await tester.tap(plate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('title-preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('title-preview-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The list builds lazily: scroll each card in, then read it.
    final list = find.descendant(
      of: find.byKey(const Key('rating-reward-list')),
      matching: find.byType(Scrollable),
    );
    final xu = <String>[];
    for (final k in [1, 2, 3, 4, 11, 51]) {
      await tester.scrollUntilVisible(
        find.byKey(Key('rating-reward-$k')),
        60,
        scrollable: list,
      );
      xu.add(cells('rating-reward-xu-$k').first);
      if (k == 4) {
        expect(cells('rating-reward-4'), containsAll(['60', '5']));
        // Own row: 60 reviews -> rank 8 -> the 4-10 card, "Bạn · hạng 8".
        expect(find.text(Bxh.youAt(8)), findsOneWidget);
      }
      if (k == 11) {
        expect(
          cells('rating-reward-11').where((c) => c == RatingText.none).length,
          1,
        );
      }
      if (k == 51) {
        // 51-100: only xu.
        expect(
          cells('rating-reward-51').where((c) => c == RatingText.none).length,
          2,
        );
      }
    }
    expect(xu, ['10tr', '7tr', '5tr', '3tr', '1tr', '500k']);
    // Running season: "Chưa kết thúc" like Mị lực.
    expect(find.byKey(const Key('rating-claim')), findsOneWidget);
    expect(find.text(Bxh.claimNotEnded), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Back closes the reward screen; the board is there again.
    await tester.tap(find.byKey(const Key('bxh-back')));
    await tester.pump();
    expect(find.byKey(const Key('rating-rewards')), findsNothing);
    expect(r.s.charmBoardOpen, isTrue);
  });

  testWidgets('a row opens the profile card with the ★ score', (tester) async {
    final r = await _rig();
    r.s.openRatingBoard();
    await _mount(tester, r.s);
    await _settle(tester);
    await tester.tap(find.byKey(const Key('rating-row-1')));
    await tester.pump();
    await _settle(tester);
    expect(find.byKey(const Key('profile-card')), findsOneWidget);
    expect(find.text(ProfileText.rating('4,72', 400)), findsOneWidget);
    // Chặn hides the shop (the board's own list).
    await tester.tap(find.byKey(const Key('profile-card-block')));
    await tester.pump();
    expect(r.s.board.isHidden('p0'), isTrue);
    expect(find.byKey(const Key('profile-card-blocked')), findsOneWidget);
  });

  testWidgets('before season 2, empty, guest', (tester) async {
    final early = await _rig(at: DateTime.utc(2026, 11, 1));
    early.s.openRatingBoard();
    await _mount(tester, early.s);
    await _settle(tester);
    expect(find.text(SeasonText.reviewStartsOn('09/11')), findsOneWidget);

    final empty = await _rig(n: 0);
    empty.s.openRatingBoard();
    await _mount(tester, empty.s);
    await _settle(tester);
    expect(find.text(RatingText.empty), findsOneWidget);

    final guest = await _rig(signedIn: false);
    guest.s.openRatingBoard();
    await _mount(tester, guest.s);
    await _settle(tester);
    expect(find.text(RatingText.guestLocked), findsWidgets);
  });

  testWidgets('switching tabs; the Mị lực tab sits under the tabs', (
    tester,
  ) async {
    final r = await _rig();
    r.s.openRatingBoard();
    await _mount(tester, r.s);
    await _settle(tester);
    await tester.tap(find.byKey(const Key('board-tab-charm')));
    await _settle(tester);
    expect(r.s.ratingBoard.tab, isFalse);
    expect(find.byKey(const Key('rating-board')), findsNothing);
    final tabs = tester.getRect(find.byKey(const Key('board-tabs')));
    final card = tester.getRect(find.byKey(const Key('bxh-card')));
    expect(card.top, greaterThan(tabs.bottom));
    await tester.tap(find.byKey(const Key('board-tab-rating')));
    await _settle(tester);
    expect(find.byKey(const Key('rating-board')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bxh-back')));
    await tester.pump();
    expect(r.s.charmBoardOpen, isFalse);
  });

  testWidgets('"Xếp hạng" on Màn Đánh giá opens the Đánh giá tab', (
    tester,
  ) async {
    final r = await _rig();
    r.s.openReviews();
    await _mount(tester, r.s, reviews: true);
    expect(find.text(Bxh.entry), findsOneWidget);
    await tester.tap(find.byKey(const Key('reviews-rating-board')));
    await _settle(tester);
    expect(r.s.charmBoardOpen, isTrue);
    expect(find.byKey(const Key('rating-board')), findsOneWidget);
  });
  testWidgets(
    'the title holder: "Đệ Nhất Gói Hoa ×2" on its card, the season on tap; '
    'Báo cáo opens the report',
    (tester) async {
      // Season 3 of the board (rating-3, from Mon 07/12): rating-2's #1 is p0,
      // who holds the title (titles/de_nhat_goi_hoa) and won it twice.
      final frames = MemoryAvatarFrames(
        loadTestData().economy.avatarFrames,
        profiles: {
          'p0': PublicProfile(
            day: 40,
            titles: PlayerTitles(
              uid: 'p0',
              stats: const {
                TitleIds.rating: TitleStat(timesWon: 2, lastPeriod: 'rating-2'),
              },
              holders: {
                TitleIds.rating: TitleHolder(
                  titleId: TitleIds.rating,
                  holderUid: 'p0',
                  period: 'rating-2',
                  seasonEnd: DateTime.utc(2026, 12, 6, 17),
                ),
              },
            ),
          ),
        },
      );
      final r = await _rig(at: DateTime.utc(2026, 12, 10, 5), frames: frames);
      expect(r.s.ratingBoard.period, 'rating-3');
      for (var i = 0; i < 3; i++) {
        r.board.put(
          'rating-3',
          _entry('p$i', 'Tiệm Hoa Số ${i + 1}', 400 - i * 30, 4.9 - i * 0.05),
        );
      }
      r.board.champions['rating-2'] = 'p0';
      r.s.openRatingBoard();
      await _mount(tester, r.s);
      await _settle(tester);
      expect(r.s.ratingBoard.isChampion('p0'), isTrue);
      await tester.tap(find.byKey(const Key('rating-row-1')));
      await tester.pump();
      await _settle(tester);
      const row = Key('profile-card-title-${TitleIds.rating}');
      expect(find.byKey(row), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(row),
          matching: find.text('Đệ Nhất Gói Hoa'),
        ),
        findsOneWidget,
      );
      expect(find.text(TitleText.timesBadge(2)), findsOneWidget);
      expect(find.text(TitleText.held), findsOneWidget);
      // Not pinned: nothing next to the name.
      expect(find.byKey(const Key('profile-card-wearing')), findsNothing);
      await tester.ensureVisible(find.byKey(row));
      await tester.tap(find.byKey(row));
      await tester.pump();
      expect(find.text('Hạng 1 bảng Đánh giá · mùa 12/2026'), findsOneWidget);
      expect(find.text(TitleText.timesWon(2)), findsOneWidget);
      // Someone else's card: no wear button.
      expect(
        find.byKey(const Key('profile-card-title-wear-${TitleIds.rating}')),
        findsNothing,
      );
      await tester.ensureVisible(find.byKey(const Key('profile-card-report')));
      await tester.tap(find.byKey(const Key('profile-card-report')));
      await tester.pump();
      await _settle(tester);
      expect(r.s.board.reportOpen, isTrue);
      expect(r.s.board.reportTarget!.uid, 'p0');
      expect(r.s.board.reportTarget!.source, reportSourceRatingBoard);
      expect(find.byKey(const Key('bxh-report-sheet')), findsOneWidget);
    },
  );

  testWidgets('your own card: wear a title you hold; a lost one is locked', (
    tester,
  ) async {
    final frames = MemoryAvatarFrames(
      loadTestData().economy.avatarFrames,
      profiles: {
        'me': PublicProfile(
          titles: PlayerTitles(
            uid: 'me',
            stats: const {
              TitleIds.rating: TitleStat(timesWon: 1, lastPeriod: 'rating-2'),
              TitleIds.charm: TitleStat(timesWon: 3, lastPeriod: 'season-2'),
            },
            holders: const {
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
      },
    );
    final r = await _rig(at: DateTime.utc(2026, 12, 10, 5), frames: frames);
    r.board.put('rating-3', _entry('me', 'Tiệm Hoa Sớm Mai', 60, 5.0));
    r.s.openRatingBoard();
    await _mount(tester, r.s);
    await _settle(tester);
    final mine = r.s.ratingBoard.rows.firstWhere((x) => x.entry.uid == 'me');
    await tester.tap(find.byKey(Key('rating-row-${mine.rank}')));
    await tester.pump();
    await _settle(tester);
    // Folded: only the title held now; "Xem tất cả" opens every cell.
    expect(
      find.byKey(const Key('profile-card-title-${TitleIds.charm}')),
      findsNothing,
    );
    expect(find.text(TitleText.count(1)), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('profile-card-title-see-all')),
    );
    await tester.tap(find.byKey(const Key('profile-card-title-see-all')));
    await tester.pump();
    // Held before: faded, "Đã từng giữ 3 mùa" (title.times_won); the "×n"
    // badge is only on a title held now.
    expect(find.text(TitleText.timesWon(3)), findsOneWidget);
    expect(find.text(TitleText.timesBadge(3)), findsNothing);
    const charmRow = Key('profile-card-title-${TitleIds.charm}');
    await tester.ensureVisible(find.byKey(charmRow));
    await tester.tap(find.byKey(charmRow));
    await tester.pump();
    expect(find.text(TitleText.wearLocked), findsOneWidget);
    // Season 2 of Mị lực ended Sun 06/12: "mùa 12/2026" from the clock.
    expect(find.text('Hạng 1 bảng Mị lực · mùa 12/2026'), findsOneWidget);
    const ratingRow = Key('profile-card-title-${TitleIds.rating}');
    await tester.ensureVisible(find.byKey(ratingRow));
    await tester.tap(find.byKey(ratingRow));
    await tester.pump();
    const wear = Key('profile-card-title-wear-${TitleIds.rating}');
    expect(find.text(TitleText.wear), findsOneWidget);
    await tester.ensureVisible(find.byKey(wear));
    await tester.tap(find.byKey(wear));
    await tester.pump();
    await _settle(tester);
    expect(frames.pins, [TitleIds.rating]);
    expect(find.byKey(const Key('profile-card-wearing')), findsOneWidget);
    expect(find.text(TitleText.wearing), findsOneWidget);
    // Nhất's wear toast.
    expect(find.text(TitleText.wearToast('Đệ Nhất Gói Hoa')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a too-short day: the summary says the reviews do not count', (
    tester,
  ) async {
    final r = await _rig();
    r.s.ratingBoard.shortDay = true;
    r.s.state.phase = DayPhase.summary;
    r.s.screen = Screen.summary;
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SummaryScreen(session: r.s)));
    await tester.pump();
    expect(find.text(SeasonText.reviewNotCounted), findsOneWidget);
    expect(r.s.ratingBoard.shortDay, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(SeasonText.reviewNotCounted), findsNothing);
  });

  testWidgets('rewards: under 50 reviews highlights no card', (tester) async {
    final r = await _rig();
    r.board.put(r.s.e.ratingBoard.periodKey, _entry('me', 'x', 12, 5.0));
    r.s.openRatingBoard();
    await _mount(tester, r.s);
    await _settle(tester);
    r.s.ratingBoard.openRewards();
    await tester.pump();
    expect(find.byKey(const Key('rating-rewards')), findsOneWidget);
    expect(find.byKey(const Key('rating-you-at')), findsNothing);
    // No reward rank: Mị lực's "Quay lại" closes the screen.
    await tester.tap(find.byKey(const Key('rating-claim-back')));
    await tester.pump();
    expect(find.byKey(const Key('rating-rewards')), findsNothing);
  });
}
