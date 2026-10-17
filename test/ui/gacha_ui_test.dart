import 'package:ai_game/logic/gacha.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/gacha_entry.dart';
import 'package:ai_game/ui/gacha_screen.dart';
import 'package:ai_game/ui/gacha_text.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../load_fonts.dart';
import '../logic/gacha_test.dart';

/// The wheel host of game_root: the screen when open, the intro over the
/// shop, and the entry icon.
Widget gachaHost(ShopSession s, {bool shop = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Center(
    child: SizedBox(
      width: 360,
      height: 640,
      child: Material(
        color: const Color(0xFFB9D7A8),
        child: ListenableBuilder(
          listenable: Listenable.merge([s, s.gacha]),
          builder: (_, _) => Stack(
            children: [
              if (shop)
                Positioned.fill(child: MainShopOverlay(session: s))
              else
                Positioned(
                  right: 12,
                  top: 140,
                  child: GachaEntryIcon(gacha: s.gacha),
                ),
              if (s.gacha.open) Positioned.fill(child: GachaScreen(session: s)),
              if (!s.gacha.open && s.gacha.introDue)
                Positioned.fill(child: GachaIntroPopup(gacha: s.gacha)),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> pumpHost(
  WidgetTester tester,
  ShopSession s, {
  bool shop = false,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(gachaHost(s, shop: shop));
  await tester.pump();
}

Future<ShopSession> ready(
  WidgetTester tester,
  FakeGachaWallet api, {
  DateTime? now,
  bool intro = true,
  GachaHistorySource? history,
  WorldChatSource? worldChat,
}) async {
  late ShopSession s;
  await tester.runAsync(() async {
    s = await synced(api, now: now, history: history, worldChat: worldChat);
  });
  s.state.gachaIntroShown = intro;
  s.gacha.mailbox = FakeGachaMailbox();
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('entry: cream circle, gold border, label, red dot, opens', (
    tester,
  ) async {
    final s = await ready(tester, FakeGachaWallet());
    await pumpHost(tester, s);
    expect(find.text(GachaText.iconLabel), findsOneWidget);
    expect(find.byKey(const Key('gacha-entry-dot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gacha-entry')));
    await tester.pump();
    expect(find.byKey(const Key('gacha-screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gacha-back')));
    await tester.pump();
    expect(find.byKey(const Key('gacha-screen')), findsNothing);
    expect(find.byKey(const Key('gacha-entry-dot')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('entry sits in the right column below the ticker', (
    tester,
  ) async {
    final chat = MemoryWorldChat()
      ..add(
        ChatMessage(
          id: 'm0000000001',
          uid: 'p1',
          name: 'Tiệm Hoa Lan',
          text: 'Chào cả nhà',
          seq: 1,
          createdAt: midWeek,
        ),
      );
    final s = await ready(tester, FakeGachaWallet(), worldChat: chat);
    s.state.potShopHintShown = true;
    s.state.potShopSeenIds = [for (final p in s.e.pots) p.id];
    await pumpHost(tester, s, shop: true);
    await tester.pump(const Duration(milliseconds: 16));
    final icon = tester.getRect(find.byKey(const Key('gacha-entry')));
    final circle = tester.getRect(find.byKey(const Key('gacha-entry-circle')));
    final ticker = tester.getRect(find.byKey(const Key('world-chat-ticker')));
    // Phú: 8 dp under the ticker, the circle 12 dp from the right edge.
    expect(icon.top, ticker.bottom + 8);
    expect(circle.right, 360 - 12);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('intro once: banner, "Đóng" blinks the icon', (tester) async {
    final s = await ready(tester, FakeGachaWallet(), intro: false);
    await pumpHost(tester, s);
    expect(find.byKey(const Key('gacha-intro')), findsOneWidget);
    expect(find.byKey(const Key('gacha-intro-banner')), findsOneWidget);
    expect(find.text(GachaText.introTitle), findsOneWidget);
    expect(find.text(GachaText.introBody('Chậu Cửu Vĩ Hồ')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gacha-intro-close')));
    await tester.pump();
    expect(find.byKey(const Key('gacha-intro')), findsNothing);
    expect(s.gacha.glowSeq, 1);
    expect(s.state.gachaIntroShown, isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('intro "Xem ngay" opens the wheel', (tester) async {
    final s = await ready(tester, FakeGachaWallet(), intro: false);
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-intro-ok')));
    await tester.pump();
    expect(find.byKey(const Key('gacha-screen')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('screen: card, wheel, glow, banner; countdown beside pity', (
    tester,
  ) async {
    final s = await ready(
      tester,
      FakeGachaWallet(
        cards: {'chau_cuu_vi_ho': 3},
        pity: {
          'chau_cuu_vi_ho': {'n': 12},
        },
      ),
    );
    s.gacha.openScreen();
    await pumpHost(tester, s);
    expect(find.byKey(const Key('gacha-week-card')), findsOneWidget);
    expect(find.byKey(const Key('gacha-wheel')), findsOneWidget);
    expect(find.byKey(const Key('gacha-glow')), findsOneWidget);
    expect(
      find.text(GachaText.weekCardTitle('Chậu Cửu Vĩ Hồ')),
      findsOneWidget,
    );
    expect(
      find.text(GachaText.weekEndsIn('0h thứ Hai 19/10', 4, 14)),
      findsOneWidget,
    );
    expect(
      find.text(GachaText.pityCounter(78, 'Chậu Cửu Vĩ Hồ')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('gacha-reset-soon')), findsNothing);
    final cd = tester.getRect(find.byKey(const Key('gacha-countdown')));
    final pity = tester.getRect(find.byKey(const Key('gacha-pity')));
    expect(cd.top, pity.top, reason: 'side by side');
    expect(find.text(GachaText.owned(3)), findsOneWidget);
    expect(find.text(GachaText.buyBtn), findsOneWidget);
    expect(find.text(GachaText.chip(3)), findsNothing);
    expect(find.text(GachaText.historyBtn), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('last day: orange countdown and reset_soon', (tester) async {
    final s = await ready(
      tester,
      FakeGachaWallet(),
      now: DateTime.utc(2026, 10, 18, 3),
    );
    s.gacha.openScreen();
    await pumpHost(tester, s);
    expect(find.byKey(const Key('gacha-reset-soon')), findsOneWidget);
    expect(find.text(GachaText.pityResetSoon), findsOneWidget);
    // 18/10 10h VN: 14 hours left, never "còn 0 ngày".
    expect(
      find.text(GachaText.weekEndsInHours('0h thứ Hai 19/10', 14)),
      findsOneWidget,
    );
    expect(find.textContaining('còn 0 ngày'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Quay 1: the wheel turns, then the result', (tester) async {
    final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 1});
    final s = await ready(tester, api);
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-spin-1')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gacha-result')), findsNothing);
    // ~2.5 s ease-out, then the landed segment lights up.
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.byKey(const Key('gacha-wheel-lit')), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('gacha-wheel-lit')), findsOneWidget);
    expect(find.byKey(const Key('gacha-wheel-gold')), findsNothing);
    expect(find.byKey(const Key('gacha-result')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('gacha-result')), findsOneWidget);
    expect(find.text(GachaText.resultXu('200.000')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gacha-result-claim')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gacha-result')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('duplicate pot: dup_title', (tester) async {
    final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 1});
    api.nextResults = [
      {
        'featured': true,
        'dup': true,
        'items': RewardBundle([const RewardItem.coins(5000000)]).toJson(),
      },
    ];
    final s = await ready(tester, api);
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-spin-1')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2600));
    // The week's pot: gold flash and the pot shown big on the wheel.
    expect(find.byKey(const Key('gacha-wheel-gold')), findsOneWidget);
    expect(find.byKey(const Key('gacha-wheel-pot')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(GachaText.resultDupTitle), findsOneWidget);
    expect(
      find.text(GachaText.resultDupXu('Chậu Cửu Vĩ Hồ', '5.000.000')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Quay 10: one ~3 s spin, then all 10 gifts at once, Nhận hết', (
    tester,
  ) async {
    final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 10});
    final s = await ready(tester, api);
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-spin-10')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.byKey(const Key('gacha-result')), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('gacha-wheel-lit')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('gacha-result')), findsOneWidget);
    expect(find.text(GachaText.resultTitleX10), findsOneWidget);
    expect(find.byKey(const Key('gacha-result-skip')), findsNothing);
    for (var i = 0; i < 10; i++) {
      expect(find.byKey(Key('gacha-result-cell-$i')), findsOneWidget);
    }
    expect(find.text(GachaText.resultClaimAll), findsOneWidget);
    await tester.tap(find.byKey(const Key('gacha-result-claim')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gacha-result')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduce motion: no turning, the result still opens', (
    tester,
  ) async {
    final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 1});
    final s = await ready(tester, api);
    s.gacha.openScreen();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-spin-1')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gacha-wheel-lit')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('gacha-result')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('segments: each prize lands on its own painted segment', (
    tester,
  ) async {
    final c = (await ready(tester, FakeGachaWallet())).gacha.config;
    int seg(RewardItem i, {bool featured = false}) => gachaSegmentOf(
      SpinResult(items: RewardBundle([i]), featured: featured),
      c,
    );
    expect(seg(const RewardItem.coins(5000000), featured: true), 0);
    expect(seg(const RewardItem.coins(2000000)), GachaSegment.xuBig.index);
    expect(
      seg(const RewardItem.petItem('canh_buom')),
      GachaSegment.petRare.index,
    );
    expect(seg(const RewardItem.pot('chau_su_tu')), GachaSegment.zodiac.index);
    expect(
      seg(const RewardItem.petItem('mu_rom')),
      GachaSegment.petCommon.index,
    );
    expect(seg(const RewardItem.giotHoa(10)), GachaSegment.drop.index);
    expect(seg(const RewardItem.coins(500000)), GachaSegment.xu.index);
    expect(seg(const RewardItem.coins(200000)), GachaSegment.xu.index);
    expect(seg(const RewardItem.treat(3)), GachaSegment.honey.index);
    // Segment k's middle ends under the pointer: (k + 0.5)/8 + turn = 1.
    for (var k = 0; k < 8; k++) {
      expect(((k + 0.5) / 8 + gachaSegmentTurn(k)) % 1, closeTo(0, 1e-9));
    }
  });

  testWidgets(
    'wheel: an icon per segment, gold pity bar 8 dp with the 60 tick',
    (tester) async {
      final s = await ready(
        tester,
        FakeGachaWallet(
          pity: {
            'chau_cuu_vi_ho': {'n': 12},
          },
        ),
      );
      s.gacha.openScreen();
      await pumpHost(tester, s);
      for (var k = 0; k < 8; k++) {
        expect(find.byKey(Key('gacha-seg-$k')), findsOneWidget);
      }
      final bar = tester.getRect(find.byKey(const Key('gacha-pity-bar')));
      expect(bar.height, 8);
      final mark = tester.getRect(find.byKey(const Key('gacha-pity-mark')));
      expect(mark.center.dx - bar.left, closeTo(bar.width * 60 / 90, 1));
      // Banner text sits inside the paper, not on its edge.
      final paper = tester.getRect(find.byKey(const Key('gacha-banner-paper')));
      final name = tester.getRect(find.byKey(const Key('gacha-pot-name')));
      expect(
        paper.contains(name.topLeft) && paper.contains(name.bottomRight),
        isTrue,
      );
      expect((name.center.dx - paper.center.dx).abs(), lessThan(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Quay 10 grid: a name under each gift, rare ones gold + sparkle',
    (tester) async {
      final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 10});
      api.nextResults = [
        for (final i in [
          const RewardItem.coins(2000000),
          const RewardItem.petItem('canh_buom'),
          const RewardItem.pot('chau_su_tu'),
          const RewardItem.petItem('mu_rom'),
          const RewardItem.giotHoa(10),
          const RewardItem.coins(500000),
          const RewardItem.treat(3),
          const RewardItem.giotHoa(3),
          const RewardItem.coins(200000),
          const RewardItem.petItem('vong_hoa_nho'),
        ])
          {
            'items': RewardBundle([i]).toJson(),
          },
      ];
      final s = await ready(tester, api);
      s.gacha.openScreen();
      await pumpHost(tester, s);
      await tester.tap(find.byKey(const Key('gacha-spin-10')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 10; i++) {
        final t = tester.widget<Text>(find.byKey(Key('gacha-result-name-$i')));
        expect(t.style?.fontSize, 11);
        expect(t.data, isNotEmpty);
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('gacha-result-name-2'))).data,
        s.gacha.potName('chau_su_tu'),
      );
      for (final i in [0, 1, 2, 9]) {
        expect(find.byKey(Key('gacha-result-sparkle-$i')), findsOneWidget);
      }
      for (final i in [3, 4, 5, 6, 7, 8]) {
        expect(find.byKey(Key('gacha-result-sparkle-$i')), findsNothing);
      }
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('missing cards: "Thiếu N thẻ" with xu and Pha lê', (
    tester,
  ) async {
    final s = await ready(
      tester,
      FakeGachaWallet(cards: {'chau_cuu_vi_ho': 4}),
    );
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-spin-10')));
    await tester.pump();
    expect(find.text(GachaText.shortTitle(6)), findsOneWidget);
    expect(find.text(GachaText.shortBtnPl('120')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gacha-short-pl')));
    await tester.pump();
    expect(find.text(GachaText.plConfirmTitle('120', 6)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('not enough Pha lê: "Thiếu n Pha lê" popup, Nạp opens the shop', (
    tester,
  ) async {
    final s = await ready(tester, FakeGachaWallet(phaLe: 5));
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-buy-open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gacha-buy-pl')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gacha-pl-ok')));
    await tester.pump();
    expect(find.byKey(const Key('gacha-pl-short')), findsOneWidget);
    expect(find.text(GachaText.plShortTitle('15')), findsOneWidget);
    expect(find.text(GachaText.plShortBody), findsOneWidget);
    expect(find.text('Bạn chưa đủ Pha lê.'), findsNothing);
    await tester.tap(find.byKey(const Key('gacha-pl-short-later')));
    await tester.pump();
    expect(find.byKey(const Key('gacha-pl-short')), findsNothing);
    expect(s.phaleShopOpen, isFalse);
    await tester.tap(find.byKey(const Key('gacha-buy-open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gacha-buy-pl')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gacha-pl-ok')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gacha-pl-short-topup')));
    await tester.pump();
    expect(s.phaleShopOpen, isTrue);
    expect(find.byKey(const Key('gacha-pl-short')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Mua thẻ: title, owned chip, xu quota chip, (i) holds the rest', (
    tester,
  ) async {
    final s = await ready(
      tester,
      FakeGachaWallet(cards: {'chau_cuu_vi_ho': 2}, xuLeft: 7),
    );
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-buy-open')));
    await tester.pump();
    expect(find.text('Thẻ gacha Cửu Vĩ Hồ'), findsOneWidget);
    expect(find.text(GachaText.buyOwned(2)), findsOneWidget);
    expect(
      find.text(GachaText.buyCoinQuota(3, s.gacha.xuDailyMax)),
      findsOneWidget,
    );
    expect(find.text(GachaText.buyCrystalQuota), findsOneWidget);
    expect(find.text(GachaText.buyFootnote), findsOneWidget);
    expect(find.text(GachaText.giftNote), findsNothing);
    expect(find.byKey(const Key('gacha-buy-info-panel')), findsNothing);
    await tester.tap(find.byKey(const Key('gacha-buy-info')));
    await tester.pump();
    expect(find.byKey(const Key('gacha-buy-info-panel')), findsOneWidget);
    expect(find.text('Thẻ không hết hạn.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Mua thẻ: xu quota used up, the xu button dims "Mai mua tiếp"', (
    tester,
  ) async {
    final s = await ready(tester, FakeGachaWallet(xuLeft: 0));
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-buy-open')));
    await tester.pump();
    final max = s.gacha.xuDailyMax;
    expect(find.text(GachaText.buyCoinQuota(max, max)), findsOneWidget);
    expect(find.text(GachaText.buyCoinSoldOut), findsOneWidget);
    final b = tester.widget<ChunkyButton>(
      find.byKey(const Key('gacha-buy-xu')),
    );
    expect(b.enabled, isFalse);
    await tester.tap(find.byKey(const Key('gacha-buy-pl')));
    await tester.pump();
    expect(find.text(GachaText.plConfirmMinor), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('history open to everyone (no VIP)', (tester) async {
    final hist = MemoryGachaHistory([
      SpinRecord(
        at: DateTime.utc(2026, 10, 20, 2, 5),
        potId: 'chau_cuu_vi_ho',
        results: [
          SpinResult(items: RewardBundle([const RewardItem.coins(500000)])),
        ],
      ),
    ]);
    final s = await ready(tester, FakeGachaWallet(), history: hist);
    expect(s.wallet?.vip?.level ?? 0, 0);
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-history-open')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gacha-history')), findsOneWidget);
    expect(find.byKey(const Key('gacha-history-row-0')), findsOneWidget);
    expect(find.textContaining('VIP'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Kho thẻ: this week first with the glow, counts in corners', (
    tester,
  ) async {
    final s = await ready(
      tester,
      FakeGachaWallet(cards: {'chau_ky_lan': 1, 'chau_cuu_vi_ho': 2}),
    );
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-cards-open')));
    await tester.pump();
    final cur = tester.getRect(
      find.byKey(const Key('gacha-card-chau_cuu_vi_ho')),
    );
    final later = tester.getRect(
      find.byKey(const Key('gacha-card-chau_ky_lan')),
    );
    expect(cur.left, lessThan(later.left));
    final cell = tester.widget<TicketCell>(
      find.byKey(const Key('gacha-card-chau_cuu_vi_ho')),
    );
    expect(cell.current, isTrue);
    expect(cell.count, 2);
    expect(find.text(GachaText.inventoryRowCurrent), findsOneWidget);
    await tester.tap(find.byKey(const Key('gacha-card-chau_ky_lan')));
    await tester.pump();
    expect(
      find.text(GachaText.notCurrentToast('Chậu kỳ lân xanh')),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Tỉ lệ opens before any spin', (tester) async {
    final s = await ready(tester, FakeGachaWallet());
    s.gacha.openScreen();
    await pumpHost(tester, s);
    await tester.tap(find.byKey(const Key('gacha-odds-open')));
    await tester.pump();
    expect(find.text(GachaText.oddsTitle), findsOneWidget);
    expect(find.text(GachaText.oddsNoPl), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('countdown texts: days, hours, minutes (Nhất)', () {
    const end = '0h thứ Hai 26/10';
    expect(
      GachaText.weekCountdown(end, const Duration(days: 4, hours: 14)),
      'Đổi chậu lúc 0h thứ Hai 26/10 · còn 4 ngày 14 giờ',
    );
    expect(
      GachaText.weekCountdown(end, const Duration(hours: 14, minutes: 5)),
      'Đổi chậu lúc 0h thứ Hai 26/10 · còn 14 giờ',
    );
    expect(
      GachaText.weekCountdown(end, const Duration(minutes: 42, seconds: 10)),
      'Đổi chậu lúc 0h thứ Hai 26/10 · còn 43 phút',
    );
  });

  test('spelling: Cửu Vĩ Hồ in every shown name', () {
    expect(GachaText.ticketName('chau_cuu_vi_ho'), 'Thẻ gacha Cửu Vĩ Hồ');
    expect(
      GachaText.giftNote,
      'Thẻ quà VIP và sự kiện là thẻ của chậu tuần mà thư vào Hộp thư. '
      'Thẻ quà ngày 7 là thẻ của chậu tuần bạn bấm nhận.',
    );
  });
}
