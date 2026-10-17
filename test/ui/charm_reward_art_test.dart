import 'package:ai_game/data/pet_items.dart';
import 'package:ai_game/ui/art.dart';
import 'package:ai_game/ui/pet_item_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'charm_board_screen_test.dart' show loadFonts, mount, open, rig;

/// "Phần thưởng mùa": each rank wins exactly one pet item of its tier (Hà
/// Phương 17/10), so the item column is ONE 56 dp picture on its tier frame,
/// centred, with the tier line below (Phú).
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
      final icons = find.descendant(
        of: cell,
        matching: find.byType(PetItemIcon),
      );
      expect(icons, findsOneWidget, reason: 'one item per rank');
      final icon = tester.widget<PetItemIcon>(icons);
      expect(icon.tier, tier, reason: 'tier-coloured frame');
      expect(icon.size, 56);
      expect(r.s.e.petItem(icon.itemId!)!.tier, tier);
      final image = tester.widget<Image>(
        find.descendant(of: icons, matching: find.byType(Image)),
      );
      expect(
        (image.image as AssetImage).assetName,
        Art.petDo(icon.itemId!),
        reason: 'the real picture, not the glyph',
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

  testWidgets('the cell shows an item this player does not own yet', (
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
    final icon = tester.widget<PetItemIcon>(
      find.descendant(
        of: find.byKey(const Key('bxh-reward-items-1')),
        matching: find.byType(PetItemIcon),
      ),
    );
    expect(icon.itemId, pool[1].id);
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
