import 'package:ai_game/data/pet_items.dart';
import 'package:ai_game/ui/art.dart';
import 'package:ai_game/ui/charm_board_screen.dart';
import 'package:ai_game/ui/pet_item_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'charm_board_screen_test.dart' show loadFonts, mount, open, rig;

/// "Phần thưởng mùa": the item column shows the real pictures of the reward
/// tier's items, not a generic square.
void main() {
  setUpAll(loadFonts);

  testWidgets('each reward tier shows the real pictures of its three items', (
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
      final fan = find.byKey(Key('bxh-reward-items-${reward.rankFrom}'));
      await tester.scrollUntilVisible(
        fan,
        80,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      final items = [
        for (final i in r.s.e.petItems)
          if (i.tier == tier) i,
      ];
      expect(items.length, 3, reason: 'a tier has one item per slot');
      expect(
        find.descendant(of: fan, matching: find.byType(PetItemIcon)),
        findsNWidgets(3),
      );
      for (final item in items) {
        final icon = find.byKey(
          Key('bxh-reward-item-${reward.rankFrom}-${item.id}'),
        );
        expect(icon, findsOneWidget, reason: '${item.id} in tier ${tier.key}');
        final image = tester.widget<Image>(
          find.descendant(of: icon, matching: find.byType(Image)),
        );
        expect(
          (image.image as AssetImage).assetName,
          Art.petDo(item.id),
          reason: 'the real picture, not the glyph',
        );
      }
      // no generic star square left in the column
      expect(
        find.descendant(
          of: find.byKey(Key('bxh-reward-${reward.rankFrom}')),
          matching: find.byIcon(Icons.auto_awesome),
        ),
        findsNothing,
      );
      // fits the 108 dp item column at 360 wide: fan and tier line are both
      // inside it, centred on the same axis
      final fanRect = tester.getRect(fan);
      final line = tester.getRect(
        find.byKey(Key('bxh-reward-tier-${reward.rankFrom}')),
      );
      expect(fanRect.width, RewardItemFan.widthFor(3, 30, 20));
      expect(fanRect.width, lessThanOrEqualTo(108));
      expect(line.width, lessThanOrEqualTo(108));
      expect(fanRect.center.dx, closeTo(line.center.dx, 0.5));
      final card = tester.getRect(
        find.byKey(Key('bxh-reward-${reward.rankFrom}')),
      );
      expect(card.contains(fanRect.topLeft), isTrue);
      expect(card.contains(fanRect.bottomRight), isTrue);
      expect(card.contains(line.bottomRight), isTrue);
    }
    expect(tiersSeen.length, greaterThanOrEqualTo(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RewardItemFan: width follows the count and nothing clips', (
    tester,
  ) async {
    expect(RewardItemFan.widthFor(0, 30, 20), 0);
    expect(RewardItemFan.widthFor(1, 30, 20), 30);
    expect(RewardItemFan.widthFor(3, 30, 20), 70);
  });
}
