import 'package:flutter/material.dart';

import '../logic/pot_slots.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart' show barPotSlots, displayPotSlots;
import '../theme/tokens.dart';
import 'game_toast.dart';
import 'pet_slots_screen.dart' show DashedRRectPainter;
import 'pot_widgets.dart';
import 'ui_skin.dart';

/// Placing mode (SPEC_tiem_chau_hoa.md §5): the main screen with every pot
/// slot boxed in dashed gold. Tap a slot to see the pot there, then "Đặt ở
/// đây". The pot that was in the slot goes back to the cupboard.
///
/// Sits over the main overlay; the goals card, the main button and the
/// bottom nav are hidden while it is on.
class PlaceModeLayer extends StatelessWidget {
  const PlaceModeLayer({
    super.key,
    required this.session,
    this.bannerTop = 312,
  });

  final ShopSession session;
  final double bannerTop;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final id = s.pendingPlacePotId;
    if (id == null) return const SizedBox.shrink();
    final pot = s.e.pot(id);
    final name = s.potShortName(pot);
    final chosenBar = s.pendingPlaceBar;
    final chosenIndex = s.pendingPlaceIndex;
    Widget slot({required bool bar, required int index}) {
      final r = potSlotHighlight(bar: bar, index: index);
      final chosen = chosenBar == bar && chosenIndex == index;
      return Positioned.fromRect(
        rect: r,
        child: GestureDetector(
          key: Key('place-slot-${bar ? 'bar' : 'stand'}-$index'),
          behavior: HitTestBehavior.opaque,
          onTap: () => s.previewPlaceSlot(bar: bar, index: index),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: chosen
                    ? DecoratedBox(
                        key: const Key('place-chosen'),
                        decoration: BoxDecoration(
                          color: const Color(0x66FFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.accentBase,
                            width: 3,
                          ),
                        ),
                      )
                    : const CustomPaint(
                        painter: DashedRRectPainter(
                          color: AppColors.accentBase,
                          strokeWidth: 2.2,
                          radius: 14,
                        ),
                      ),
              ),
              if (chosen)
                Positioned(
                  left: (r.width - 60 * pot.potScale / 1.1) / 2,
                  top: r.height - 60 * pot.potScale / 1.1 * 0.95 - 3,
                  child: IgnorePointer(
                    child: PotArt(pot: pot, base: 60 / 1.1),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final number = chosenBar == null
        ? 0
        : potSlotNumber(bar: chosenBar, index: chosenIndex);
    return Stack(
      key: const Key('place-mode'),
      children: [
        for (var i = 0; i < barPotSlots; i++) slot(bar: true, index: i),
        for (var i = 0; i < displayPotSlots; i++) slot(bar: false, index: i),
        Positioned(
          left: 12,
          right: 12,
          top: bannerTop,
          height: 48,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.accentBase, width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chạm một chỗ trên kệ để đặt chậu $name',
                        key: const Key('place-banner'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(
                          size: 13,
                          weight: 800,
                          color: AppColors.onSecondary,
                        ).copyWith(height: 1.2),
                      ),
                      Text(
                        'Chậu cũ ở chỗ đó sẽ về kho.',
                        maxLines: 1,
                        style: AppText.body(
                          size: 11,
                          weight: 700,
                          color: AppColors.textSecondary,
                        ).copyWith(height: 1.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 56,
                  child: SkinButton(
                    key: const Key('place-cancel'),
                    label: 'Thôi',
                    kind: SkinButtonKind.secondary,
                    height: 34,
                    fontSize: 14,
                    onPressed: s.cancelPlaceMode,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 520,
          width: 360,
          height: 120,
          child: Container(
            key: const Key('place-bar'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: const BoxDecoration(
              color: AppColors.navBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [
                BoxShadow(color: AppColors.popupShadow, blurRadius: 8),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: FittedBox(
                        child: PotArt(pot: pot, base: 56 / 1.1, shadow: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title(size: 16, weight: 800),
                          ),
                          Text(
                            chosenBar == null
                                ? 'Chưa chọn chỗ nào'
                                : 'Đặt ở chỗ thứ $number trên kệ?',
                            key: const Key('place-ask'),
                            style: AppText.body(size: 12, weight: 700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (chosenBar != null)
                  Row(
                    children: [
                      SizedBox(
                        width: 124,
                        child: SkinButton(
                          key: const Key('place-other'),
                          label: 'Chọn chỗ khác',
                          kind: SkinButtonKind.secondary,
                          height: 42,
                          fontSize: 14,
                          onPressed: s.clearPlacePreview,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Builder(
                          builder: (context) => SkinButton(
                            key: const Key('place-ok'),
                            label: 'Đặt ở đây',
                            height: 42,
                            fontSize: 16,
                            onPressed: () {
                              if (s.confirmPlace()) {
                                showGameToast(context, 'Đã đặt chậu $name');
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
