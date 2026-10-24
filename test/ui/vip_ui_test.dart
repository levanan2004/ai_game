import 'package:ai_game/data/rating_board.dart';
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/vip.dart';
import 'package:ai_game/logic/wallet.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/phale_shop_screen.dart';
import 'package:ai_game/ui/vip_badge.dart';
import 'package:ai_game/ui/vip_screen.dart';
import 'package:ai_game/ui/vip_text.dart';
import 'package:ai_game/ui/ui_chung.dart';
import 'package:ai_game/ui/world_chat_sheet.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../logic/vip_test.dart' show FakeVipWallet, vipSession;
import 'charm_board_screen_test.dart' as board_test;

/// VIP on screen (spec 4): Màn VIP (tier card, carousel, hall, Cài đặt,
/// "Nạp Pha lê"), the level-up popup, and the badge / colour / title on
/// Tin thế giới, the two boards and the profile card.
void main() {
  setUpAll(board_test.loadFonts);

  Future<void> host(WidgetTester tester, ShopSession s) async {
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
              listenable: Listenable.merge([s, s.vip]),
              builder: (_, _) => Stack(
                children: [
                  if (s.vip.open) Positioned.fill(child: VipScreen(session: s)),
                  if (s.vip.levelUp != null)
                    Positioned.fill(child: VipLevelUpPopup(session: s)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<ShopSession> opened(
    WidgetTester tester,
    FakeVipWallet api, {
    VipSource? vip,
    bool seen = true,
  }) async {
    final s = vipSession(
      api,
      vip: vip,
      backing: seen ? {ProgressStore.vipSeenKey('me'): '${api.level}'} : {},
    );
    await tester.runAsync(() async {
      await s.syncWallet();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    s.vip.openScreen();
    await host(tester, s);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    return s;
  }

  testWidgets('badge: the asset of the tier, the name in its colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VipName(
            name: 'Tiệm Lan',
            level: 7,
            style: const TextStyle(fontSize: 14),
            badgeKey: const Key('b'),
          ),
        ),
      ),
    );
    final img = find.descendant(
      of: find.byKey(const Key('b')),
      matching: find.byType(Image),
    );
    var provider = tester.widget<Image>(img).image;
    if (provider is ResizeImage) provider = provider.imageProvider;
    expect((provider as AssetImage).assetName, vipCrownArt(7));
    expect(tester.getSize(find.byKey(const Key('b'))), const Size(18, 18));
    expect(
      tester.widget<Text>(find.text('Tiệm Lan')).style!.color,
      vipNameColor(7),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VipName(name: 'Tiệm Lan', level: 0, style: TextStyle()),
        ),
      ),
    );
    expect(find.byType(VipBadge), findsNothing);
    expect(find.text(VipText.title10), findsNothing);
  });

  testWidgets(
    'Màn VIP: tier card, next tier line, carousel, rules, Nạp Pha lê',
    (tester) async {
      final s = await opened(
        tester,
        FakeVipWallet(level: 2, vnd: 200000, nextVnd: 500000),
      );
      expect(find.byKey(const Key('vip-screen')), findsOneWidget);
      expect(find.text(VipText.screenTitle), findsOneWidget);
      expect(find.text(VipText.current(2)), findsOneWidget);
      expect(find.text(VipText.next(300000, 3)), findsOneWidget);
      expect(find.text('Còn 300.000 điểm nữa lên VIP 3'), findsOneWidget);
      expect(find.text(VipText.progress(200000, 500000)), findsOneWidget);
      expect(find.text('Còn 300.000 điểm nữa lên VIP 3'), findsOneWidget);
      expect(find.text('200.000/500.000 điểm đã nạp'), findsOneWidget);
      // The VIP point note fits at 360 (wraps, never clipped).
      final note = find.byKey(const Key('vip-points-note'));
      expect(note, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(note).didExceedMaxLines,
        isFalse,
      );
      expect(tester.getRect(note).right, lessThanOrEqualTo(360));
      expect(find.byKey(const Key('vip-tier-badge')), findsOneWidget);
      // Carousel opens on the own tier's card (index = level, i.e. the next).
      expect(find.byKey(const Key('vip-card-3')), findsOneWidget);
      expect(find.text(VipText.cardGift(20)), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('vip-carousel')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(s.vip.card, 3);
      expect(find.byKey(const Key('vip-card-4')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vip-topup')));
      await tester.pump();
      expect(s.vip.open, isFalse);
      expect(s.phaleShopOpen, isTrue);
    },
  );

  testWidgets(
    'Cấp VIP carousel: tags, arrows, dots, ←/→, mouse drag, no sheet',
    (tester) async {
      final s = await opened(
        tester,
        FakeVipWallet(level: 2, vnd: 200000, nextVnd: 500000),
      );
      // Starts on the next level's card; the settings sheet stays shut.
      expect(s.vip.card, 2);
      expect(s.vip.settingsOpen, isFalse);
      expect(find.byKey(const Key('vip-settings')), findsNothing);
      expect(find.text(VipText.cardNext), findsOneWidget);
      // Dot tap jumps (animated) to that level.
      await tester.ensureVisible(find.byKey(const Key('vip-dot-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vip-dot-1')));
      await tester.pumpAndSettle();
      expect(s.vip.card, 1);
      expect(find.text(VipText.cardCurrent), findsOneWidget);
      // Arrow keys move prev/next.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(s.vip.card, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(s.vip.card, 3);
      // A level beyond next: lock + what is still missing (not threshold).
      final need = s.vip.tier(4)!.minVnd - 200000;
      expect(find.text(VipText.cardLocked(need)), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(s.vip.card, 2);
      // Arrow buttons; prev dims and stops at the first level.
      await tester.tap(find.byKey(const Key('vip-prev')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vip-prev')));
      await tester.pumpAndSettle();
      expect(s.vip.card, 0);
      expect(
        tester.getSemantics(find.byKey(const Key('vip-prev'))).label,
        VipText.cardPrev,
      );
      await tester.tap(find.byKey(const Key('vip-prev')));
      await tester.pumpAndSettle();
      expect(s.vip.card, 0);
      await tester.tap(find.byKey(const Key('vip-arrow-next')));
      await tester.pumpAndSettle();
      expect(s.vip.card, 1);
      // A mouse drag turns the page (web/desktop).
      await tester.drag(
        find.byKey(const Key('vip-carousel')),
        const Offset(-300, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(s.vip.card, 2);
      // The sheet opens only from "..." (covered by the Cài đặt VIP test).
      expect(find.byKey(const Key('vip-settings')), findsNothing);
    },
  );

  testWidgets('VIP 0, top tier, guest: the line of each', (tester) async {
    var s = await opened(
      tester,
      FakeVipWallet(level: 0, vnd: 0, nextVnd: 50000),
    );
    expect(find.text(VipText.firstTopUp), findsOneWidget);
    expect(find.text(VipText.none), findsWidgets);
    s.vip.closeScreen();
    s = await opened(tester, FakeVipWallet(level: 10, vnd: 15000000));
    expect(find.text(VipText.max), findsOneWidget);
    s.accountUid = null;
    s.vip.openScreen();
    await tester.pump();
    expect(find.text(VipText.guestLocked), findsOneWidget);
    expect(find.byKey(const Key('vip-settings-open')), findsNothing);
  });

  testWidgets(
    'Bảng vinh danh: rows by date, anonymous rows, empty, hidden note',
    (tester) async {
      final src = MemoryVipSource(
        hall: [
          VipHallRow(uid: 'u1', at: DateTime(2026, 10, 15), name: 'Tiệm Ngọc'),
          VipHallRow(uid: 'u2', at: DateTime(2026, 10, 16), hidden: true),
          VipHallRow(uid: 'me', at: DateTime(2026, 10, 17), name: 'Tiệm Mình'),
        ],
      )..status = const VipStatus(level: 10, vnd: 15000000);
      final s = await opened(
        tester,
        FakeVipWallet(level: 10, vnd: 15000000),
        vip: src,
      );
      await tester.tap(find.byKey(const Key('vip-tab-hall')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      expect(find.byKey(const Key('vip-hall')), findsOneWidget);
      expect(find.text(VipText.hallSubtitle), findsOneWidget);
      expect(find.text(VipText.hallPrivacyNote), findsOneWidget);
      expect(find.byKey(const Key('vip-hall-row-1')), findsOneWidget);
      expect(find.text('Tiệm Ngọc'), findsOneWidget);
      expect(find.text('15/10/2026'), findsOneWidget);
      expect(find.byKey(const Key('vip-hall-anon-2')), findsOneWidget);
      expect(find.text(VipText.anonName), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'\d\s?(đ|₫|VND)')),
        findsNothing,
        reason: 'no amount on the hall',
      );
      // Cài đặt VIP: hide, toast, note.
      await tester.tap(find.byKey(const Key('vip-settings-open')));
      await tester.pump();
      expect(find.text(VipText.hallHideTitle), findsOneWidget);
      expect(find.text(VipText.hideBadgeTitle), findsOneWidget);
      expect(find.text(VipText.hideBadgeSubtitle), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('vip-badge-hide')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(src.badgeHidden, isTrue);
      expect(s.vip.badgeHidden, isTrue);
      expect(find.text(VipText.hideBadgeOnToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('vip-badge-hide')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(src.badgeHidden, isFalse);
      expect(find.text(VipText.hideBadgeOffToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      // A failed save says so; the switch stays as it was.
      src.fail = true;
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('vip-badge-hide')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(find.text(VipText.hideBadgeFail), findsOneWidget);
      expect(s.vip.badgeHidden, isFalse);
      src.fail = false;
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('vip-hall-hide')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(src.hidden, isTrue);
      expect(find.text(VipText.hallHideOnToast), findsOneWidget);
      s.vip.closeSettings();
      await tester.pump();
      expect(find.byKey(const Key('vip-hall-hidden-note')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'tabs Quyền lợi VIP / Vinh danh same size, bar 8 dp, ... opens Cài đặt VIP',
    (tester) async {
      final s = await opened(
        tester,
        FakeVipWallet(level: 2, vnd: 200000, nextVnd: 500000),
        vip: MemoryVipSource()..status = const VipStatus(level: 2, vnd: 200000),
      );
      final perks = find.text(VipText.perksTitle);
      final hall = find.text('Vinh danh');
      expect(perks, findsOneWidget);
      expect(hall, findsOneWidget);
      expect(tester.getSize(perks).height, tester.getSize(hall).height);
      final fill = find.descendant(
        of: find.byKey(const Key('vip-progress')),
        matching: find.byKey(const Key('slice-progress-fill')),
      );
      expect(tester.getSize(fill).height, 8);
      // The fill is 200k/500k = 40% of the track (inside the frame).
      final bar = tester.getSize(find.byKey(const Key('vip-progress')));
      const p = UiChung.thanhTienDo;
      final k = p.slice!.height / 8;
      final track = bar.width - p.slice!.left / k - (p.w - p.slice!.right) / k;
      expect(tester.getSize(fill).width, closeTo(track * 0.4, 0.5));
      expect(tester.getSize(fill).width, greaterThan(0));
      expect(find.byType(LeafRoundButton), findsOneWidget);
      await tester.tap(find.byKey(const Key('vip-settings-open')));
      await tester.pump();
      expect(s.vip.settingsOpen, isTrue);
    },
  );

  testWidgets(
    'Cửa hàng Pha lê header: nut_vip_vang VIP button, opens Màn VIP',
    (tester) async {
      final s = vipSession(FakeVipWallet(level: 3, vnd: 500000));
      await tester.runAsync(() async {
        await s.syncWallet();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: PhaleShopScreen(session: s)));
      await tester.pump();
      expect(find.byKey(const Key('vip-badge-gold')), findsOneWidget);
      expect(find.byKey(const Key('vip-badge-green')), findsNothing);
      final label = tester.widget<Text>(find.text('VIP 3'));
      expect(label.style?.color, const Color(0xFF2E5E3D));
      expect(label.style?.fontWeight, FontWeight.w800);
      await tester.tap(find.byKey(const Key('phale-vip')));
      await tester.pump();
      expect(s.vip.open, isTrue);
    },
  );

  testWidgets('Bảng vinh danh empty', (tester) async {
    await opened(tester, FakeVipWallet(level: 1), vip: MemoryVipSource());
    await tester.tap(find.byKey(const Key('vip-tab-hall')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    expect(find.text(VipText.hallEmpty), findsOneWidget);
  });

  testWidgets('level-up popup: tier, gift in Hộp thư, perks, Nhận', (
    tester,
  ) async {
    final s = await opened(
      tester,
      FakeVipWallet(level: 3, vnd: 600000),
      seen: false,
    );
    expect(find.byKey(const Key('vip-levelup')), findsOneWidget);
    expect(find.text(VipText.levelUpTitle(3)), findsOneWidget);
    expect(find.text(VipText.levelUpBody(35)), findsOneWidget);
    expect(find.text(VipText.levelUpNewPerks), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('vip-levelup')),
        matching: find.textContaining(VipText.perkFrame('Hoa đào')),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vip-levelup-ok')));
    await tester.pump();
    expect(s.vip.levelUp, isNull);
    expect(find.byKey(const Key('vip-levelup')), findsNothing);
  });

  testWidgets(
    'Tin thế giới: badge after the name and the VIP 10 title, as stamped',
    (tester) async {
      final c = MemoryWorldChat(on: true)
        ..add(
          ChatMessage(
            id: 'm0000000001',
            uid: 'u2',
            name: 'Tiệm Lan',
            text: 'chào',
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
            text: 'hi',
            seq: 2,
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
      await s.chat.useStore(store);
      await s.board.useHiddenPlayers(store);
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
        find.byKey(const Key('world-chat-vip-m0000000001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('world-chat-vip-title-m0000000001')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('world-chat-vip-m0000000002')), findsNothing);
      expect(
        tester.widget<Text>(find.text('Tiệm Lan')).style!.color,
        vipNameColor(10),
      );
      // The profile card from the message: crown 32 and title.
      await tester.tap(find.byKey(const Key('world-chat-more-m0000000001')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('world-chat-menu-profile')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('profile-card-vip')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('profile-card-vip'))),
        const Size(32, 32),
      );
      expect(find.byKey(const Key('profile-card-vip-title')), findsOneWidget);
    },
  );

  testWidgets(
    'Mị lực board: badge on the podium and the rows from player_avatars',
    (tester) async {
      final e = loadTestData().economy;
      final frames = MemoryAvatarFrames(
        e.avatarFrames,
        vips: {'p0': 10, 'p3': 5},
      );
      final r = await board_test.rig(tester, frames: frames);
      await board_test.mount(tester, r.s);
      await board_test.open(tester, r.s);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(find.byKey(const Key('bxh-podium-vip-1')), findsOneWidget);
      expect(find.byKey(const Key('bxh-row-vip-4')), findsOneWidget);
      expect(find.byKey(const Key('bxh-row-vip-5')), findsNothing);
      expect(find.byKey(const Key('bxh-podium-vip-2')), findsNothing);
      // A hidden player shows no tier.
      await tester.runAsync(() => r.s.board.hidePlayer('p3', 'Tiệm Hoa Số 4'));
      await tester.pump();
      expect(find.byKey(const Key('bxh-row-vip-4')), findsNothing);
    },
  );

  testWidgets('Đánh giá board: badge and VIP 10 title on the rows', (
    tester,
  ) async {
    final e = loadTestData().economy;
    final board = MemoryRatingBoard();
    final frames = MemoryAvatarFrames(
      e.avatarFrames,
      vips: {'p0': 10, 'p1': 2},
    );
    final s = newSession(
      ratingBoard: board,
      avatarFrames: frames,
      now: () => DateTime.utc(2026, 11, 20, 5),
    );
    final period = s.ratingBoard.period;
    for (var i = 0; i < 4; i++) {
      final v = 400 - i * 30;
      const r = 4.8;
      final score = (v * r + 100 * 4.0) / (v + 100);
      board.put(
        period,
        RatingEntry(
          uid: 'p$i',
          displayName: 'Tiệm $i',
          v: v,
          sum: (v * r).round(),
          score: score,
          sortKey: (score * 1000).round() * 10000 + v,
        ),
      );
    }
    s.accountUid = 'me';
    s.openRatingBoard();
    await board_test.mount(tester, s);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('rating-row-vip-1')), findsOneWidget);
    expect(find.byKey(const Key('rating-row-vip-title-1')), findsOneWidget);
    expect(find.byKey(const Key('rating-row-vip-2')), findsOneWidget);
    expect(find.byKey(const Key('rating-row-vip-title-2')), findsNothing);
    expect(find.byKey(const Key('rating-row-vip-3')), findsNothing);
  });
}
