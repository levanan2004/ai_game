import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import '../logic/shop_shelf.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import '../audio/sounds.dart';

/// "Giá bán" on the counter ledge, right of the day/time plaque
/// (SPEC_gia_ban_va_bxh_ban_do.md, PA2). It replaces the old bottom tab.
///
/// 56 x 44 dp, the picture is the tap area (both sides >= 44 dp). The plaque
/// sets where it stands ([ShelfGeometry.pricesRect]); it must sit OUTSIDE the
/// shelf layer's `IgnorePointer`, so [ShopShelfLayer] puts it next to it.
///
/// A tap opens the Giá bán screen ([ShopSession.openPrices]); before the day
/// it opens (`pricing.openDay`) the button is dimmed to 45 % and the tap says
/// "Mở vào ngày {n}".
class PricesLedgeButton extends StatefulWidget {
  const PricesLedgeButton({super.key, required this.session});

  final ShopSession session;

  /// Spec colours: face `bgBase`, wood border, pressed face #E8E2CF.
  static const pressedFace = Color(0xFFE8E2CF);
  static const label = 'Giá bán';

  @override
  State<PricesLedgeButton> createState() => _PricesLedgeButtonState();
}

class _PricesLedgeButtonState extends State<PricesLedgeButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final locked = !s.pricesUnlocked;
    const wood = Color(0xFF8C6A5C);
    final radius = BorderRadius.circular(10);
    // Pressed: the face sinks onto the wood layer (1.5 dp).
    final sink = _down ? 1.5 : 0.0;
    return Semantics(
      button: true,
      enabled: !locked,
      label: PricesLedgeButton.label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('prices-ledge'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          if (locked) {
            showTapHint(context, 'Mở vào ngày ${s.e.pricesOpenDay}');
            return;
          }
          SoundScope.maybeOf(context)?.effect('ui_tab');
          s.openPrices();
        },
        child: Opacity(
          opacity: locked ? 0.45 : 1,
          child: SizedBox(
            width: ShelfGeometry.pricesWidth,
            height: ShelfGeometry.pricesHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // the wood layer under the face (1.5 dp lower)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 1.5,
                  bottom: -1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: wood,
                      borderRadius: radius,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: sink,
                  bottom: -sink,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _down
                          ? PricesLedgeButton.pressedFace
                          : AppColors.bgBase,
                      borderRadius: radius,
                      border: Border.all(color: wood, width: 1.8),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: (ShelfGeometry.pricesWidth - 3.6 - 24) / 2,
                          top: 2.2,
                          width: 24,
                          height: 24,
                          child: ArtImage(
                            Art.nav('gia_ban'),
                            key: const Key('prices-ledge-icon'),
                            size: 24,
                            fallback: const SizedBox(width: 24, height: 24),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 27,
                          child: Center(
                            child: Text(
                              PricesLedgeButton.label,
                              key: const Key('prices-ledge-label'),
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.noScaling,
                              style: AppText.make(
                                AppFonts.display,
                                10.5,
                                800,
                                height: 1,
                                color: locked
                                    ? AppColors.textDisabled
                                    : AppColors.primaryPressed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
