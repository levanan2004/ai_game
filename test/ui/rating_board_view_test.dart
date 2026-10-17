import 'package:ai_game/data/rating_board.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/profile_card.dart';
import 'package:ai_game/ui/rating_board_view.dart';
import 'package:ai_game/ui/reviews_screen.dart';
import 'package:flutter/material.dart';
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
}) async {
  final clock = at ?? DateTime.utc(2026, 11, 20, 5);
  final board = MemoryRatingBoard();
  final s = newSession(ratingBoard: board, now: () => clock);
  final period = s.e.ratingBoard.periodKey;
  for (var i = 0; i < n; i++) {
    board.put(period, _entry('p$i', 'Tiệm Hoa Số ${i + 1}', 400 - i * 30, 4.9 - i * 0.05));
  }
  if (signedIn) s.accountUid = 'me';
  s.state.shopName = 'Tiệm Hoa Sớm Mai';
  return (s: s, board: board);
}

Future<void> _mount(WidgetTester tester, ShopSession s, {bool reviews = false}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
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

void main() {
  setUpAll(loadFonts);

  testWidgets('tabs, ribbon, rows with the score and count, the card', (
    tester,
  ) async {
    final r = await _rig();
    r.board.put(r.s.e.ratingBoard.periodKey, _entry('me', 'Tiệm Hoa Sớm Mai', 60, 5.0));
    r.s.openRatingBoard();
    await _mount(tester, r.s);
    await _settle(tester);
    expect(find.text(RatingText.boardTitle), findsOneWidget);
    expect(find.text(RatingText.tabCharm), findsOneWidget);
    expect(find.text(RatingText.tabRating), findsOneWidget);
    expect(find.text(RatingText.explain), findsOneWidget);
    expect(find.text(RatingText.seasonEnd(16, 12)), findsOneWidget);
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
    expect(find.text(RatingText.minThreshold(38)), findsOneWidget);
  });

  testWidgets('ⓘ shows how the score works; rewards list from economy.json', (
    tester,
  ) async {
    final r = await _rig();
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
    expect(
      find.text('Hạng 1: 100 Pha lê + 20 Giọt hoa + 10.000.000 xu'),
      findsOneWidget,
    );
    expect(
      find.text('Hạng 4–10: 30 Pha lê + 5 Giọt hoa + 3.000.000 xu'),
      findsOneWidget,
    );
    expect(find.text('Hạng 51–100: 500.000 xu'), findsOneWidget);
    expect(find.text(RatingText.rewardPending), findsNothing);
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
    expect(
      find.text(RatingText.notStarted(2, '09/11/2026')),
      findsOneWidget,
    );

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
}
