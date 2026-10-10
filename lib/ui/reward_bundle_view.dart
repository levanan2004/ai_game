import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/pet.dart';
import '../logic/reward_rarity.dart';
import '../logic/rewards.dart';
import 'art.dart';
import 'common.dart';
import 'phuc_loi_art.dart';
import '../theme/tokens.dart';

/// Pha lê, the designer's cut-out (`nav/pha_le`, 128 px WebP). The
/// diamond icon only shows if the file cannot be loaded.
class PhaLeIcon extends StatelessWidget {
  const PhaLeIcon({super.key, this.size = 20, this.hud = false});

  final double size;

  /// Top bar: Phú's 64px cut, sharper at pill size than the 128px one.
  final bool hud;

  static const color = Color(0xFF6FC3E8);

  @override
  Widget build(BuildContext context) {
    return ArtImage(
      Art.nav(hud ? 'pha_le_64' : giftKind(giftPhaLe)!.asset),
      size: size,
      fallback: Icon(Icons.diamond_rounded, size: size, color: color),
    );
  }
}

/// One icon per reward item in its rarity frame ([rewardRarity]), the
/// amount under it. Up to [perRow] items share a row (frames shrink to fit
/// the width); more wrap onto the next row. Used by every gift popup: the
/// mailbox, giftcodes and the admin previews.
class RewardBundleView extends StatelessWidget {
  const RewardBundleView({
    super.key,
    required this.bundle,
    this.iconSize = 28,
    this.spacing = 8,
    this.framed = true,
  });

  final RewardBundle bundle;
  final double iconSize;
  final double spacing;

  /// False draws the bare icon (no rarity frame).
  final bool framed;

  /// Frame canvas per icon edge: the empty area is about half the canvas.
  static const frameScale = 2.1;

  /// Items per row before wrapping.
  static const perRow = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final full = framed ? iconSize * frameScale : iconSize;
        final cell = box.maxWidth.isFinite
            ? math.min(full, (box.maxWidth - spacing * (perRow - 1)) / perRow)
            : full;
        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final item in bundle.items)
              SizedBox(
                key: Key(
                  'reward-${item.kind.json}'
                  '${item.id == null ? '' : '-${item.id}'}',
                ),
                width: cell,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (framed)
                      RarityFrame(
                        rarity: rewardRarity(item),
                        size: cell,
                        child: rewardIcon(
                          item,
                          size: RarityFrame.iconFor(rewardRarity(item), cell),
                        ),
                      )
                    else
                      rewardIcon(item, size: cell),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rewardAmountText(item),
                        maxLines: 1,
                        style: AppText.number(size: iconSize * 0.55),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
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
    RewardKind.pet => ArtImage(Art.pet(petArtId(item.id!, 0)), size: size),
    // No art per item yet: the frame of its tier.
    RewardKind.petItem => Image.asset(
      'assets/images/phuc_loi/${giftKind(petItemGiftKey(item.id!))?.asset ?? 'khung_thuong'}.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  };
}
