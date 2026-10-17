import 'package:ai_game/data/pet_items.dart';
import 'package:ai_game/logic/charm_rewards.dart';
import 'package:ai_game/ui/charm_board_screen.dart' show SeasonMysteryCell;
import 'package:ai_game/ui/pet_item_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'charm_board_screen_test.dart' show loadFonts, mount, open, rig;

/// "Phần thưởng mùa": each rank wins exactly one pet item of its tier (Hà
/// Phương 17/10), a random one the player does not own yet, so the item
/// column is ONE 56 dp mystery cell ("?") on its tier frame, centred, with
/// the tier line below; tapping it lists what it can be (Nhất).
void main() {
  setUpAll(loadFonts);

  testWidgets('each reward tier shows one 56 dp item cell, centred', (
    tester,
  ) async {
    final r = await rig(tester);
    await mount(tester, r.s);
    await open(tester, r.s);
    r.s.board.openRewards();
    await tester.pump(const Duration(milliseconds: 300));
    final list = find.byKey(const Key('bxh-reward-list'));
    expect(list, findsOneWidget);

    final rewards = r.s.board.config.rewards
        .where((x) => PetItemTier.fromKey(x.itemTier) != null)
        .toList();
    expect(rewards, isNotEmpty);
    final tiersSeen = <PetItemTier>{};
    for (final reward in rewards) {
      final tier = PetItemTier.fromKey(reward.itemTier)!;
      tiersSeen.add(tier);
      final cell = find.byKey(Key('bxh-reward-items-${reward.rankFrom}'));
      await tester.scrollUntilVisible(
        cell,
        80,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      final cells = find.descendant(
        of: cell,
        matching: find.byType(SeasonMysteryCell),
      );
      expect(cells, findsOneWidget, reason: 'one prize per rank');
      final mystery = tester.widget<SeasonMysteryCell>(cells);
      expect(mystery.tier, tier, reason: 'tier-coloured frame');
      expect(mystery.size, 56);
      expect(
        find.descendant(of: cell, matching: find.byType(PetItemIcon)),
        findsNothing,
        reason: 'no picture: the prize is random',
      );
      final mark = tester.widget<Text>(
        find.descendant(
          of: cell,
          matching: find.byKey(const Key('season-mystery-mark')),
        ),
      );
      expect(mark.data, '?');
      expect(mark.style!.color, const Color(0xFFFFF8E7));
      expect(mark.style!.fontSize, 28);
      expect(mark.style!.fontWeight, FontWeight.w900);
      final stroke = tester.widget<Text>(
        find.descendant(
          of: cell,
          matching: find.byKey(const Key('season-mystery-stroke')),
        ),
      );
      expect(
        stroke.style!.foreground!.color.toARGB32(),
        PetItemPalette.of(tier).frame.toARGB32(),
      );
      expect(
        find.descendant(
          of: cell,
          matching: find.byKey(const Key('season-mystery-sparkle')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cell,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label ==
                    'Đồ pet ${seasonTierName(tier.key)} ngẫu nhiên',
          ),
        ),
        findsOneWidget,
      );
      final cellRect = tester.getRect(cell);
      // 56 dp (the board screen is fitted to the phone, so allow a pixel).
      expect(cellRect.width, closeTo(56, 1));
      expect(cellRect.height, closeTo(56, 1));
      final line = tester.getRect(
        find.byKey(Key('bxh-reward-tier-${reward.rankFrom}')),
      );
      expect(line.top, greaterThanOrEqualTo(cellRect.bottom));
      expect(cellRect.center.dx, closeTo(line.center.dx, 0.5));
      final card = tester.getRect(
        find.byKey(Key('bxh-reward-${reward.rankFrom}')),
      );
      expect(card.contains(cellRect.topLeft), isTrue);
      expect(card.contains(cellRect.bottomRight), isTrue);
      expect(card.contains(line.bottomRight), isTrue);
      expect(card.right, lessThanOrEqualTo(360));
    }
    expect(tiersSeen.length, greaterThanOrEqualTo(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tier line under the cell stays "Huyền thoại +N"', (
    tester,
  ) async {
    final r = await rig(tester);
    await mount(tester, r.s);
    await open(tester, r.s);
    r.s.board.openRewards();
    await tester.pump(const Duration(milliseconds: 300));
    final top = r.s.board.config.rewardFor(1)!;
    expect(
      tester.widget<Text>(find.byKey(const Key('bxh-reward-tier-1'))).data,
      '${seasonTierName(top.itemTier)} +${r.s.board.itemCharm(top.itemTier)}',
    );
  });

  testWidgets('tapping the cell lists the tier, owned ones dimmed "Đã có"', (
    tester,
  ) async {
    final r = await rig(tester);
    final top = r.s.board.config.rewardFor(1)!;
    final tier = PetItemTier.fromKey(top.itemTier)!;
    final pool = [
      for (final i in r.s.e.petItems)
        if (i.tier == tier) i,
    ];
    r.s.state.petItems[pool[0].id] = 1;
    await mount(tester, r.s);
    await open(tester, r.s);
    r.s.board.openRewards();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('bxh-reward-mystery-1')));
    await tester.pump();
    expect(find.byKey(const Key('bxh-pool')), findsOneWidget);
    final rarity = seasonTierName(tier.key);
    expect(find.text('Đồ pet $rarity có thể nhận'), findsOneWidget);
    final fallback = seasonFallback(
      r.s.e,
      tier.key,
      period: r.s.board.config.periodKey,
      uid: r.s.accountUid ?? '',
    )!;
    expect(
      find.text(
        'Bạn sẽ nhận ngẫu nhiên 1 món bạn chưa có trong danh sách này. '
        'Nếu đã có đủ, bạn nhận ${seasonAmountText(fallback)} thay thế.',
      ),
      findsOneWidget,
    );
    for (final item in pool) {
      expect(find.byKey(Key('bxh-pool-item-${item.id}')), findsOneWidget);
    }
    expect(find.byKey(Key('bxh-pool-owned-${pool[0].id}')), findsOneWidget);
    expect(find.byKey(Key('bxh-pool-owned-${pool[1].id}')), findsNothing);
    expect(
      tester.widget<Opacity>(find.byKey(Key('bxh-pool-dim-${pool[0].id}'))).opacity,
      0.45,
    );
    expect(find.byKey(Key('bxh-pool-dim-${pool[1].id}')), findsNothing);
    expect(find.text('Đã có'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bxh-pool-close')));
    await tester.pump();
    expect(find.byKey(const Key('bxh-pool')), findsNothing);
    expect(r.s.board.poolTier, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all owned: the list says what comes instead', (tester) async {
    final r = await rig(tester);
    final top = r.s.board.config.rewardFor(1)!;
    final tier = PetItemTier.fromKey(top.itemTier)!;
    for (final i in r.s.e.petItems) {
      if (i.tier == tier) r.s.state.petItems[i.id] = 1;
    }
    await mount(tester, r.s);
    await open(tester, r.s);
    r.s.board.openRewards();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('bxh-reward-mystery-1')));
    await tester.pump();
    final rarity = seasonTierName(tier.key);
    final fallback = seasonFallback(
      r.s.e,
      tier.key,
      period: r.s.board.config.periodKey,
      uid: r.s.accountUid ?? '',
    )!;
    expect(find.byKey(const Key('bxh-pool-desc')), findsNothing);
    expect(
      find.text(
        'Bạn đã có đủ đồ pet $rarity. '
        'Phần thưởng hạng này sẽ là ${seasonAmountText(fallback)}.',
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(180, 120));
    await tester.pump();
    expect(find.byKey(const Key('bxh-pool')), findsNothing);
  });

  testWidgets('the Pha lê column fits "200" at 360 wide', (tester) async {
    final r = await rig(tester);
    await mount(tester, r.s);
    await open(tester, r.s);
    r.s.board.openRewards();
    await tester.pump(const Duration(milliseconds: 300));
    expect(r.s.board.config.rewardFor(1)!.phaLe, 200);
    expect(find.text('200'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
