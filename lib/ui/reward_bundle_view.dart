import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/pet.dart';
import '../logic/rewards.dart';
import 'art.dart';
import 'common.dart';
import '../theme/tokens.dart';

/// Pha lê, the designer's cut-out (`nav/pha_le`, 128 px WebP). The
/// diamond icon only shows if the file cannot be loaded.
class PhaLeIcon extends StatelessWidget {
  const PhaLeIcon({super.key, this.size = 20});

  final double size;

  static const color = Color(0xFF6FC3E8);

  @override
  Widget build(BuildContext context) {
    return ArtImage(
      Art.nav(giftKind(giftPhaLe)!.asset),
      size: size,
      fallback: Icon(Icons.diamond_rounded, size: size, color: color),
    );
  }
}

/// One icon + amount per reward item. Used by every gift popup: admin
/// gifts now, the mailbox, login rewards and giftcodes later.
class RewardBundleView extends StatelessWidget {
  const RewardBundleView({
    super.key,
    required this.bundle,
    this.iconSize = 28,
    this.spacing = 12,
  });

  final RewardBundle bundle;
  final double iconSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final item in bundle.items)
          Row(
            key: Key(
              'reward-${item.kind.json}${item.id == null ? '' : '-${item.id}'}',
            ),
            mainAxisSize: MainAxisSize.min,
            children: [
              rewardIcon(item, size: iconSize),
              const SizedBox(width: 4),
              Text(
                rewardAmountText(item),
                style: AppText.number(size: iconSize * 0.55),
              ),
            ],
          ),
      ],
    );
  }
}

/// "50k" for xu, "×3" for everything else.
String rewardAmountText(RewardItem item) =>
    item.kind == RewardKind.coins ? formatK(item.amount) : '×${item.amount}';

/// The existing art for one reward kind.
Widget rewardIcon(RewardItem item, {double size = 28}) {
  return switch (item.kind) {
    RewardKind.coins => CoinIcon(size: size),
    RewardKind.giotHoa => ArtImage(Art.pet(giftDrop), size: size),
    RewardKind.phaLe => PhaLeIcon(size: size),
    RewardKind.pot => ArtImage(Art.pot(item.id!), size: size),
    RewardKind.treat => ArtImage(Art.pet(item.id ?? giftBiscuit), size: size),
    RewardKind.cat => ArtImage(Art.pet(giftKind(giftCat)!.asset), size: size),
    RewardKind.petSkin => ArtImage(Art.pet(item.id!), size: size),
  };
}
