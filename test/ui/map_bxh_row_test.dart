import 'dart:async';

import 'package:ai_game/data/charm_board.dart';
import 'package:ai_game/logic/charm_board_controller.dart';
import 'package:ai_game/logic/charm_rewards.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/charm_board_screen.dart' show Bxh, CharmBoardScreen;
import 'package:ai_game/ui/map_bxh_row.dart';
import 'package:ai_game/ui/map_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import 'charm_board_screen_test.dart' show rig;

/// The "Xếp hạng Mị lực" row of the map: where it stands, what the chip says
/// in each of the seven states, that it opens the board, and that it fits.
Future<void> _mount(
  WidgetTester tester,
  ShopSession s, {
  Size size = const Size(360, 640),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => Stack(
            children: [
              MapPopup(session: s, onClose: () {}),
              if (s.charmBoardOpen)
                Positioned.fill(child: CharmBoardScreen(session: s)),
            ],
          ),
        ),
      ),
    ),
  );
  // The row asks the board for one read when the map opens.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

String _chip(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('map-bxh-chip')),
        matching: find.byType(Text),
      ),
    )
    .data!;

/// Never answers: the first read stays on its way.
class _Silent extends MemoryCharmBoard {
  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) => Completer<List<CharmBoardRow>>().future;
}

class _Down extends MemoryCharmBoard {
  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) async => throw StateError('offline');
}

class _Server implements MailService {
  final mails = <GameMail>[];
  final marks = <String, Map<String, MailState>>{};

  @override
  Future<List<GameMail>> inbox(String uid) async => [
    for (final m in mails)
      if (m.target == mailToAll || m.target == uid) m,
  ];

  @override
  Future<Map<String, MailState>> states(String uid) async => {...?marks[uid]};

  @override
  Future<void> markRead(String uid, String mailId) async {}

  @override
  Future<MailClaimResult> claim(String uid, String mailId) async {
    final mine = marks.putIfAbsent(uid, () => {});
    if (mine[mailId]?.claimed == true) return MailClaimResult.already;
    mine[mailId] = const MailState(read: true, claimed: true);
    return MailClaimResult.claimed;
  }
}

void main() {
  setUpAll(loadTestFonts);

  group('the row', () {
    testWidgets('sits between Tiệm Chậu Hoa and Vườn nhà, icon and title', (
      tester,
    ) async {
      final r = await rig(tester, pet: null);
      await _mount(tester, r.s);
      final pot = tester.getRect(find.byKey(const Key('map-pot-shop')));
      final bxh = tester.getRect(find.byKey(const Key('map-bxh')));
      final garden = tester.getRect(find.byKey(const Key('map-garden')));
      expect(pot.bottom, lessThan(bxh.top));
      expect(bxh.bottom, lessThan(garden.top));
      expect(find.text(Bxh.title), findsOneWidget);
      expect(find.text('Chợ hoa'), findsOneWidget);
      // Six rows of the same height, none under 60.
      expect(bxh.height, greaterThanOrEqualTo(60));
      expect(bxh.height, pot.height);
    });

    testWidgets('a tap anywhere on the row opens the board', (tester) async {
      final r = await rig(tester, pet: null);
      await _mount(tester, r.s);
      await tester.tapAt(
        tester.getRect(find.byKey(const Key('map-bxh'))).centerRight -
            const Offset(40, 0),
      );
      await tester.pump();
      expect(r.s.charmBoardOpen, isTrue);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('bxh-screen')), findsOneWidget);
      // Back from the board: the map is still there under it.
      await tester.tap(find.byKey(const Key('bxh-back')));
      await tester.pump();
      expect(r.s.charmBoardOpen, isFalse);
      expect(find.byKey(const Key('map-bxh')), findsOneWidget);
    });

    testWidgets('before the pets open it is locked like the pet rows', (
      tester,
    ) async {
      final r = await rig(tester);
      r.s.state.day = 3;
      await _mount(tester, r.s);
      expect(find.text('Mở vào ngày 5'), findsWidgets);
      expect(find.byKey(const Key('map-bxh-chip')), findsNothing);
      await tester.tap(find.byKey(const Key('map-bxh')));
      await tester.pump();
      expect(r.s.charmBoardOpen, isFalse);
    });
  });

  group('the seven chips', () {
    testWidgets('1 rank 4-100: "Hạng n" green, with the Mị lực', (
      tester,
    ) async {
      final r = await rig(tester, n: 12, pet: 'kim_long', stage: 2);
      await tester.runAsync(() => r.s.board.publishIfDue());
      await _mount(tester, r.s);
      final rank = r.s.board.myRank!;
      expect(rank, greaterThan(3), reason: '12 others score more than 300');
      expect(r.s.board.mapChip, BoardMapChip.ranked);
      expect(_chip(tester), Bxh.rankN(rank));
      expect(
        find.text(Bxh.mapCharm(r.s.board.myCharm)),
        findsOneWidget,
        reason: '{n} Mị lực, the local number',
      );
      final bg =
          (tester
                      .widget<Container>(find.byKey(const Key('map-bxh-chip')))
                      .decoration!
                  as BoxDecoration)
              .color;
      final band = MapBxhView(BoardMapChip.ranked, rank).colors.$1;
      expect(bg, band);
      expect(
        find.bySemanticsLabel(Bxh.mapA11y(Bxh.mapA11yRank(rank))),
        findsOneWidget,
      );
    }, semanticsEnabled: true);

    testWidgets('2 rank 1-3: gold, read out as top 3', (tester) async {
      final r = await rig(tester, n: 1, pet: 'kim_long', stage: 2);
      await tester.runAsync(() => r.s.board.publishIfDue());
      await _mount(tester, r.s);
      final rank = r.s.board.myRank!;
      expect(rank, lessThanOrEqualTo(3));
      expect(_chip(tester), Bxh.rankN(rank));
      expect(
        MapBxhView(BoardMapChip.ranked, rank).colors.$1,
        const Color(0xFFFDEFC6),
      );
      expect(
        find.bySemanticsLabel(Bxh.mapA11y(Bxh.mapA11yTop3(rank))),
        findsOneWidget,
      );
    }, semanticsEnabled: true);

    testWidgets('3 outside the top 100: 100+', (tester) async {
      final r = await rig(tester, n: 100, pet: 'kim_long', stage: 0);
      await _mount(tester, r.s);
      expect(r.s.board.mapChip, BoardMapChip.outside);
      expect(_chip(tester), Bxh.outRank);
      expect(find.byKey(const Key('map-bxh-charm')), findsOneWidget);
    });

    testWidgets('4 no pet, or under 20: Chưa xếp hạng, no caption', (
      tester,
    ) async {
      final none = await rig(tester, pet: null);
      await _mount(tester, none.s);
      expect(_chip(tester), Bxh.unranked);
      expect(find.byKey(const Key('map-bxh-charm')), findsNothing);
      final low = await rig(tester, pet: 'ca_chep', stage: 0);
      await _mount(tester, low.s);
      expect(low.s.board.me, BoardMe.underMin);
      expect(_chip(tester), Bxh.unranked);
    });

    testWidgets('5 guest: Đăng nhập with a lock, never "Khách"', (
      tester,
    ) async {
      final r = await rig(tester, signedIn: false);
      await _mount(tester, r.s);
      expect(_chip(tester), 'Đăng nhập');
      expect(find.text('Khách'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('loading is an empty grey chip, a failed read hides it', (
      tester,
    ) async {
      final r = await rig(tester);
      final s = newSession(charmBoard: _Silent(), now: r.now)
        ..accountUid = 'me'
        ..state.day = 8
        ..state.addPet('kim_long', fedDay: 1)
        ..state.petCharm = 'kim_long';
      await _mount(tester, s);
      expect(s.board.mapChip, BoardMapChip.loading);
      expect(find.byKey(const Key('map-bxh-skeleton')), findsOneWidget);
      expect(find.byKey(const Key('map-bxh-chip')), findsNothing);

      final down = newSession(charmBoard: _Down(), now: r.now)
        ..accountUid = 'me'
        ..state.day = 8
        ..state.addPet('kim_long', fedDay: 1)
        ..state.petCharm = 'kim_long';
      await _mount(tester, down);
      expect(down.board.mapChip, BoardMapChip.hidden);
      expect(find.byKey(const Key('map-bxh-chip')), findsNothing);
      expect(find.byKey(const Key('map-bxh-skeleton')), findsNothing);
      expect(find.text(Bxh.title), findsOneWidget);
    });
  });

  group('the season is over', () {
    testWidgets(
      '6 Đang chốt bảng with an hourglass, 7 reward waiting adds the red dot',
      (tester) async {
        var clock = DateTime.utc(2026, 10, 20, 8);
        final board = MemoryCharmBoard(now: () => clock);
        final s = newSession(charmBoard: board, now: () => clock)
          ..accountUid = 'me'
          ..state.day = 8
          ..state.shopName = 'Tiệm Hoa Sớm Mai'
          ..state.addPet('kim_long', fedDay: 1);
        s.state.ownedPet('kim_long')!.stage = 2;
        s.state.petCharm = 'kim_long';
        final server = _Server();
        final feed = MailboxFeed(service: server, now: () => clock);
        s.board.attachMailbox(feed);
        await feed.bindUser('me');
        await board.publish(
          period: s.e.charmBoard.periodKey,
          entry: CharmBoardEntry.forPlayer(
            uid: 'other',
            displayName: 'x',
            charm: 500,
          ),
        );
        clock = clock.add(const Duration(hours: 1));
        await s.board.open();
        clock = clock.add(const Duration(minutes: 1));
        await s.board.refresh(force: true);
        expect(s.board.myRank, 2);
        expect(s.board.mapChip, BoardMapChip.ranked);

        // Season over, no reward mail yet.
        clock = DateTime.utc(2026, 11, 20);
        await tester.runAsync(() => s.board.open());
        expect(s.board.mapChip, BoardMapChip.closing);
        await _mount(tester, s);
        expect(_chip(tester), Bxh.claimPending);
        expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
        expect(find.byKey(const Key('map-bxh-dot')), findsNothing);
        expect(
          MapBxhView(BoardMapChip.closing, 2).a11y,
          'Xếp hạng Mị lực, đang chốt bảng',
        );

        // The payout wrote the mail.
        server.mails.add(
          charmRewardMail(
            period: s.e.charmBoard.periodKey,
            rank: 2,
            uid: 'me',
            rewards: RewardBundle([const RewardItem.phaLe(70)]),
          ),
        );
        await tester.runAsync(() => feed.refresh());
        await tester.pump();
        expect(s.board.mapChip, BoardMapChip.rewardReady);
        expect(_chip(tester), Bxh.rankN(2));
        expect(find.byKey(const Key('map-bxh-dot')), findsOneWidget);
        expect(
          MapBxhView(BoardMapChip.rewardReady, 2).a11y,
          'Xếp hạng Mị lực, có thưởng đang chờ nhận',
        );

        // Claimed: the dot goes, the rank stays.
        await tester.runAsync(() => s.board.claimReward());
        await tester.pump();
        expect(s.board.claim, BoardClaim.done);
        expect(find.byKey(const Key('map-bxh-dot')), findsNothing);
        expect(_chip(tester), Bxh.rankN(2));
      },
    );
  });

  test('the screen-reader sentences are the approved ones', () {
    expect(
      MapBxhView(BoardMapChip.ranked, 12).a11y,
      'Xếp hạng Mị lực, hạng 12',
    );
    expect(
      MapBxhView(BoardMapChip.ranked, 2).a11y,
      'Xếp hạng Mị lực, hạng 2, nằm trong top 3',
    );
    expect(
      const MapBxhView(BoardMapChip.outside, null).a11y,
      'Xếp hạng Mị lực, chưa vào top 100',
    );
    expect(
      const MapBxhView(BoardMapChip.unranked, null).a11y,
      'Xếp hạng Mị lực, chưa có hạng',
    );
    expect(
      const MapBxhView(BoardMapChip.guest, null).a11y,
      'Xếp hạng Mị lực, đăng nhập để xếp hạng',
    );
    expect(
      const MapBxhView(BoardMapChip.loading, null).a11y,
      'Xếp hạng Mị lực',
      reason: 'loading reads only the title',
    );
    expect(Bxh.mapCharm(340), '340 Mị lực');
  });

  test('the chip colours follow the shield bands', () {
    Color bg(int r) => MapBxhView(BoardMapChip.ranked, r).colors.$1;
    expect(bg(1), const Color(0xFFFDEFC6));
    expect(bg(3), const Color(0xFFFDEFC6));
    expect(bg(4), const Color(0xFFDCEFD9));
    expect(bg(10), const Color(0xFFDCEFD9));
    expect(bg(11), const Color(0xFFE1EDF5));
    expect(bg(50), const Color(0xFFE1EDF5));
    expect(bg(51), const Color(0xFFF3E6DC));
    expect(bg(100), const Color(0xFFF3E6DC));
  });

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    testWidgets('six rows with the longest chip fit, nothing overflows '
        '(${size.width.round()})', (tester) async {
      final r = await rig(tester, n: 12, pet: 'kim_long', stage: 2);
      await tester.runAsync(() => r.s.board.publishIfDue());
      await _mount(tester, r.s, size: size);
      expect(tester.takeException(), isNull);
      final frame = tester.getRect(find.byKey(const Key('map-popup')));
      final row = tester.getRect(find.byKey(const Key('map-bxh')));
      final chip = tester.getRect(find.byKey(const Key('map-bxh-chip')));
      final caption = tester.getRect(find.byKey(const Key('map-bxh-charm')));
      expect(chip.height, 22);
      expect(caption.right, lessThanOrEqualTo(row.right - 10));
      expect(chip.bottom, lessThanOrEqualTo(row.bottom));
      expect(
        tester.getRect(find.byKey(const Key('map-garden'))).bottom,
        lessThanOrEqualTo(frame.bottom - 30.5),
      );
    });
  }
}
