import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../data/pot_book.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'pet_shop_grid.dart' show petGroupedCount;
import 'ui_skin.dart';

/// Greyscale (0,2126 / 0,7152 / 0,0722) for pots the player does not own.
const potGrayFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// "300 Pha lê": a set reward as text.
/// The "how to get" line of a pot. A pot bought with xu builds its price from
/// the live price ("Mua 3 tr xu"), so the text can never drift from the price;
/// any other howVi (a gift day, Pha le) is shown as the data has it.
String potHowText(PotDef pot) {
  final how = pot.howVi ?? '';
  if (!pot.paysPhaLe && pot.price > 0 && how.startsWith('Mua ')) {
    return 'Mua ${priceLabelUnit(pot.price)}';
  }
  return how;
}

String potRewardText(int phaLe) => '${petGroupedCount(phaLe)} Pha lê';

/// A pot picture in a square frame of `base × potScale`, its foot at 95% of
/// the frame (spec SPEC_C_final §3). [gray] draws it grey and faint, as for
/// a pot the player does not own yet. An owned pot gets a soft shadow.
class PotArt extends StatelessWidget {
  const PotArt({
    super.key,
    required this.pot,
    this.base = 78,
    this.gray = false,
    this.shadow = true,
  });

  final PotDef pot;
  final double base;
  final bool gray;
  final bool shadow;

  double get frame => base * pot.potScale;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    Widget img = Image.asset(
      Art.pot(pot.id),
      width: f,
      height: f,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => SizedBox(width: f, height: f),
    );
    if (gray) {
      img = Opacity(
        opacity: 0.3,
        child: ColorFiltered(colorFilter: potGrayFilter, child: img),
      );
    }
    return SizedBox(
      width: f,
      height: f,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (shadow && !gray)
            Positioned(
              left: f * 0.19,
              top: f * 0.95 - f * 0.045,
              width: f * 0.62,
              height: f * 0.09,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x453C2D19),
                  borderRadius: BorderRadius.circular(f),
                ),
              ),
            ),
          Positioned.fill(child: img),
        ],
      ),
    );
  }
}

/// Progress of a set: [value] of [total] pots, drawn as a rounded bar that
/// eases to the new value (SPEC_C_final §5). [done] turns it honey-yellow.
class CollectionProgress extends StatelessWidget {
  const CollectionProgress({
    super.key,
    required this.value,
    required this.total,
    this.done = false,
    this.height = 12,
  });

  final int value;
  final int total;
  final bool done;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            return TweenAnimationBuilder<double>(
              tween: Tween(end: target),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) {
                final inner = box.maxWidth - 2;
                final w = (inner * v).clamp(height - 2, inner);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: const Key('progress-fill'),
                    margin: const EdgeInsets.all(0.5),
                    width: w,
                    height: height - 3,
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.accentBase
                          : AppColors.primaryBase,
                      borderRadius: BorderRadius.circular(height),
                    ),
                    child: height >= 9
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(5, 1.5, 5, 0),
                              height: 3,
                              decoration: BoxDecoration(
                                color: done
                                    ? const Color(0xFFFFE7A3)
                                    : const Color(0xFF7DB88B),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Top bar, round back button and the ribbon title of a pot screen, for a
/// `Stack` that fills the 360×640 frame.
List<Widget> potScreenHeader(
  ShopSession s, {
  required String title,
  required VoidCallback onBack,
  Key? backKey,
}) => [
  Positioned(
    left: 0,
    top: 0,
    child: TopBar(
      session: s,
      showRating: false,
      showDay: false,
      showPhaLe: true,
    ),
  ),
  Positioned(
    left: 16,
    top: 54,
    child: SkinRoundButton(
      key: backKey,
      kind: SkinRound.back,
      width: 40,
      onTap: onBack,
    ),
  ),
  Positioned(
    left: 70,
    right: 70,
    top: 54,
    child: Center(
      child: SkinRibbon(title: title, width: 220, height: 46, fontSize: 18),
    ),
  ),
];

/// Three tabs (Hoàng đạo, Sơn Hải, Linh vật), each with a small progress bar
/// and a gold tick when the set is complete.
class PotGroupTabs extends StatelessWidget {
  const PotGroupTabs({
    super.key,
    required this.session,
    required this.selected,
    required this.onSelect,
    required this.keyPrefix,
  });

  final ShopSession session;
  final String selected;
  final void Function(String group) onSelect;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Row(
      children: [
        for (var i = 0; i < potGroupIds.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _tab(s, potGroupIds[i])),
        ],
      ],
    );
  }

  Widget _tab(ShopSession s, String group) {
    final on = group == selected;
    final owned = s.groupOwned(group);
    final total = s.groupTotal(group);
    final done = total > 0 && owned >= total;
    return GestureDetector(
      key: Key('$keyPrefix-$group'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(group),
      child: SizedBox(
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: on ? AppColors.primaryBase : AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on
                        ? AppColors.primaryPressed
                        : AppColors.surfaceBorder,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 4,
              right: 4,
              top: 5,
              child: Text(
                s.potGroupName(group),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title(
                  size: 13,
                  weight: 800,
                  color: on ? AppColors.textInverse : AppColors.textPrimary,
                ).copyWith(height: 1.25),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 28,
              child: CollectionProgress(
                value: owned,
                total: total,
                done: done,
                height: 8,
              ),
            ),
            if (done)
              Positioned(
                right: 2,
                top: -6,
                child: Container(
                  key: Key('$keyPrefix-done-$group'),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.statusWarning,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 9, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The gift icon of the reward lines.
class RewardGiftIcon extends StatelessWidget {
  const RewardGiftIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    Art.nav('qua'),
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => Icon(Icons.card_giftcard, size: size),
  );
}
