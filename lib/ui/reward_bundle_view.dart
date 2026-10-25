import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/pot_rules.dart' show GachaConfig;
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

  /// Edge of a Thẻ gacha card in a cell (Phú: 56dp).
  static const ticketCellSize = 56.0;

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
                    // Thẻ gacha: Phú's card art of its pot (it has its own
                    // frame), 56dp tall at most, no rarity frame.
                    if (item.kind == RewardKind.ticket)
                      SizedBox(
                        height: math.min(ticketCellSize, cell),
                        child: Center(
                          child: rewardIcon(
                            item,
                            size: math.min(ticketCellSize, cell),
                          ),
                        ),
                      )
                    else if (framed)
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
/// Xu: "200k", "500k" under a million, then "2tr", "1,5tr" (Nhất).
String rewardAmountText(RewardItem item) => item.kind == RewardKind.coins
    ? formatHudMoney(item.amount)
    : '×${item.amount}';

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
    // Phú's card of its pot (3:4 in the square); a card without a pot is
    // this week's (gift cards of Phúc lợi are claimed now).
    RewardKind.ticket => ticketCardIcon(
      item.id ?? GachaConfig.current.potOfWeekAt(DateTime.now()),
      size: size,
    ),
    // No art per item yet: the frame of its tier.
    RewardKind.petItem => Image.asset(
      'assets/images/phuc_loi/${giftKind(petItemGiftKey(item.id!))?.asset ?? 'khung_thuong'}.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  };
}

/// `gacha/<asset id>/icon_the.webp` of [potId]'s Thẻ gacha (~265×335,
/// BoxFit.contain); Phú's generic `gacha/the_gacha.webp` when the card has
/// no pot or the pot has no art.
/// [assetId] when known, else from [GachaConfig.current].
Widget ticketCardIcon(String? potId, {double size = 28, String? assetId}) {
  final asset =
      assetId ??
      (potId == null ? null : GachaConfig.current.assetIdByPot[potId]);
  Widget plain() => Image.asset(
    'assets/images/gacha/the_gacha.webp',
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
  if (asset == null) return plain();
  return Image.asset(
    Art.gachaPot(asset, 'icon_the'),
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => plain(),
  );
}

/// [bundle] with each Thẻ gacha that names no pot given [potId] (display
/// only: the pot of the week a gift mail arrived; the server decides).
RewardBundle withTicketPot(RewardBundle bundle, String? potId) {
  if (potId == null) return bundle;
  return RewardBundle([
    for (final item in bundle.items)
      item.kind == RewardKind.ticket && item.id == null
          ? RewardItem(kind: RewardKind.ticket, id: potId, amount: item.amount)
          : item,
  ]);
}
