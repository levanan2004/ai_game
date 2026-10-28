import 'package:ai_game/logic/platform_flags.dart';
import 'package:ai_game/logic/rewarded_ad.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/free_reward_card.dart';
import 'package:ai_game/ui/game_root.dart' show menuEntries;
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  tearDown(() {
    androidAppOverride = null;
    phaLeTopUpOverride = null;
  });

  Future<void> frame(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<ShopSession> pumpBar(
    WidgetTester tester, {
    required bool compact,
    int money = 0,
  }) async {
    await frame(tester, const Size(360, 160));
    final s = newSession()..state.money = money;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: TopBar(
            session: s,
            showRating: compact,
            showDay: !compact,
            showPhaLe: compact,
          ),
        ),
      ),
    );
    await tester.pump();
    return s;
  }

  testWidgets('web hides both reward plus buttons', (tester) async {
    androidAppOverride = false;
    await pumpBar(tester, compact: true, money: 999990000);
    expect(find.byKey(const Key('topbar-xu-plus')), findsNothing);
    expect(find.byKey(const Key('topbar-pha-le-plus')), findsNothing);
  });

  testWidgets('a long xu balance still shows a full-size +', (tester) async {
    androidAppOverride = true;
    final s = await pumpBar(tester, compact: true, money: 999990000);
    final plus = find.byKey(const Key('topbar-xu-plus'));
    expect(plus, findsOneWidget);
    expect(tester.getSize(plus).height, 16);
    await tester.tap(plus);
    await tester.pump();
    expect(s.rewardedAd, RewardedAdKind.xu);
    expect(s.phaleShopOpen, isFalse);
  });

  testWidgets('the Pha lê + opens the free ad, not the closed shop', (
    tester,
  ) async {
    androidAppOverride = true;
    final s = await pumpBar(tester, compact: true);
    await tester.tap(find.byKey(const Key('topbar-pha-le-plus')));
    await tester.pump();
    expect(s.rewardedAd, RewardedAdKind.phaLe);
    expect(s.phaleShopOpen, isFalse);
  });

  testWidgets('with top-up on, + is the ad and the amount opens the shop', (
    tester,
  ) async {
    androidAppOverride = true;
    phaLeTopUpOverride = true;
    final s = await pumpBar(tester, compact: true, money: 1200);
    await tester.tap(find.byKey(const Key('topbar-pha-le-plus')));
    await tester.pump();
    expect(s.rewardedAd, RewardedAdKind.phaLe);
    expect(s.phaleShopOpen, isFalse);
    s.closeRewardedAd();
    await tester.tap(find.byKey(const Key('topbar-pha-le-amount')));
    await tester.pump();
    expect(s.phaleShopOpen, isTrue);
    expect(s.rewardedAd, isNull);
  });

  testWidgets('the market bar keeps the xu +', (tester) async {
    androidAppOverride = true;
    final s = await pumpBar(tester, compact: false, money: 999990000);
    await tester.tap(find.byKey(const Key('topbar-xu-plus')));
    await tester.pump();
    expect(s.rewardedAd, RewardedAdKind.xu);
  });

  testWidgets('the home page offers xu and Pha lê', (tester) async {
    final s = newSession();
    await tester.pumpWidget(
      MaterialApp(
        home: FreeRewardPage(session: s, onClose: () {}),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('free-reward-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('free-reward-xu')));
    await tester.pump();
    expect(s.rewardedAd, RewardedAdKind.xu);
    s.closeRewardedAd();
    await tester.tap(find.byKey(const Key('free-reward-phale')));
    await tester.pump();
    expect(s.rewardedAd, RewardedAdKind.phaLe);
  });

  testWidgets('the shop scene does not float the gift over the counter', (
    tester,
  ) async {
    await frame(tester, const Size(360, 640));
    androidAppOverride = true;
    final on = newSession();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: MainShopOverlay(session: on),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('free-reward-page')), findsNothing);
    expect(find.byKey(const Key('corner-menu-free_reward')), findsNothing);
  });

  test('the basket offers Quà miễn phí only when ads are on', () {
    androidAppOverride = false;
    expect(
      menuEntries(session: newSession()).map((e) => e.id),
      isNot(contains('free_reward')),
    );
    androidAppOverride = true;
    final s = newSession();
    final entry = menuEntries(
      session: s,
    ).firstWhere((e) => e.id == 'free_reward');
    expect(entry.label, 'Quà miễn phí');
    entry.onTap();
    expect(s.freeRewardOpen, isTrue);
    s.closeFreeReward();
    expect(s.freeRewardOpen, isFalse);
  });

  testWidgets('day summary offers an optional Pha lê ad', (tester) async {
    await frame(tester, const Size(360, 640));
    androidAppOverride = false;
    final off = newSession();
    await tester.pumpWidget(MaterialApp(home: SummaryScreen(session: off)));
    await tester.pump();
    expect(find.byKey(const Key('summary-reward-ad')), findsNothing);

    androidAppOverride = true;
    final on = newSession();
    await tester.pumpWidget(MaterialApp(home: SummaryScreen(session: on)));
    await tester.pump();
    expect(find.byKey(const Key('summary-reward-ad')), findsOneWidget);
    expect(on.rewardedAd, isNull);
    await tester.tap(find.byKey(const Key('summary-reward-ad')));
    await tester.pump();
    expect(on.rewardedAd, RewardedAdKind.phaLe);
    expect(
      find.text('Xem quảng cáo +$rewardedPhaLeAmount Pha lê'),
      findsOneWidget,
    );
  });
}
