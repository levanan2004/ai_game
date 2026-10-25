import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/shop_session.dart';
import '../logic/shop_shelf.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'shop_shelf_layer.dart' show ShopShelfLayer;

/// The one switch for the look of "Giá bán" on the counter ledge.
/// false: gold tag icon + the word "Giá bán" in the board. true: the icon alone
/// (a narrower board, same height; the screen-reader label stays "Giá bán").
const kPricesLedgeIconOnly = false;

/// "Giá bán" on the counter ledge, right of the day/time plaque (PA2). It is
/// drawn as the same kind of board as the plaque: the wood layer 1.5 dp lower,
/// the cream face, the 1.8 dp wood border, radius 8, 32 dp high and standing on
/// the ledge like the plaque. It replaces the old bottom tab.
///
/// The board is 32 dp high but the tap area is 44 dp (the board's bottom, the
/// extra 12 dp reach up over empty scene), and never narrower than 44 dp, so
/// both sides of the hit box are >= 44 dp. The plaque sets where it stands
/// ([ShelfGeometry.pricesRect]); it must sit OUTSIDE the shelf layer's
/// `IgnorePointer`, so [ShopShelfLayer] puts it next to it.
///
/// A tap opens the Giá bán screen ([ShopSession.openPrices]); before the day
/// it opens (`pricing.openDay`) the button is dimmed to 45 % and the tap says
/// "Mở vào ngày {n}".
class PricesLedgeButton extends StatefulWidget {
  const PricesLedgeButton({
    super.key,
    required this.session,
    this.iconOnly = kPricesLedgeIconOnly,
  });

  final ShopSession session;
  final bool iconOnly;

  /// Pressed face (a little darker cream).
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
    final radius = BorderRadius.circular(8);
    // Pressed: the face sinks onto the wood layer (1.5 dp).
    final sink = _down ? 1.5 : 0.0;
    final board = ShelfGeometry.pricesBoardHeight;
    final iconSize = widget.iconOnly ? 22.0 : 18.0;
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
            width: ShelfGeometry.pricesWidthOf(widget.iconOnly),
            height: ShelfGeometry.pricesHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The board stands on the ledge: the bottom 32 dp of the box.
                Positioned(
                  key: const Key('prices-ledge-board'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: board,
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
                            color: ShopShelfLayer.wood,
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
                          key: const Key('prices-ledge-face'),
                          decoration: BoxDecoration(
                            color: _down
                                ? PricesLedgeButton.pressedFace
                                : AppColors.bgBase,
                            borderRadius: radius,
                            border: Border.all(
                              color: ShopShelfLayer.wood,
                              width: 1.8,
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ShelfGeometry.plaquePadX,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ArtImage(
                                      Art.nav('gia_ban'),
                                      key: const Key('prices-ledge-icon'),
                                      size: iconSize,
                                      fallback: SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),
                                    if (!widget.iconOnly) ...[
                                      const SizedBox(width: 3),
                                      Text(
                                        PricesLedgeButton.label,
                                        key: const Key('prices-ledge-label'),
                                        maxLines: 1,
                                        softWrap: false,
                                        textScaler: TextScaler.noScaling,
                                        style: AppText.make(
                                          AppFonts.display,
                                          12,
                                          800,
                                          height: 1,
                                          color: locked
                                              ? AppColors.textDisabled
                                              : AppColors.onSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
