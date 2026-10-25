import 'package:flutter/material.dart';

import '../data/skins.dart';
import '../logic/pet.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'map_bxh_row.dart';
import 'pot_text.dart';
import 'ui_skin.dart';

/// Preparing-phase map: the morning market, plus rooms that are still coming.
class MapPopup extends StatelessWidget {
  const MapPopup({
    super.key,
    required this.session,
    required this.onClose,
    this.extraRows = const [],
  });

  final ShopSession session;
  final VoidCallback onClose;

  /// More rows after the five (the Mị lực leaderboard row will be one); the
  /// tests use it to check six and seven rows against the frame.
  final List<Widget Function(double height)> extraRows;

  /// The frame is shown 312 dp wide, 516 dp tall (room for 6 rows).
  static const frameWidth = 312.0;
  static const frameHeight = 516.0;

  /// The two bottom corner ornaments (gold pin left, peach blossom right) stand
  /// up to 51 dp above the frame's bottom edge (measured on the 936x1394 art:
  /// the pin top at y=1250, the blossom top at y=1240). The rows run the whole
  /// width, so the list ends this far above the bottom edge (51 + 3 gap), not at
  /// the 30.5 dp of the text safe area.
  static const decorationZone = 54.0;

  /// Padding of the content inside the frame (the list's bottom is the zone).
  static const contentPadding = EdgeInsets.fromLTRB(
    19.5,
    26,
    19.8,
    decorationZone,
  );

  /// Gap above the frame on a tall screen; a short one gets less (never less
  /// than [_minTop]: the close button hangs above the frame's corner).
  static const topGap = 100.0;
  static const _minTop = 32.0;
  static double topFor(double screenHeight) =>
      (screenHeight - frameHeight - _minTop).clamp(_minTop, topGap);

  /// Close button: a 28 dp round X in a 44 dp tap box, its centre 6 dp right of
  /// the frame's right edge and 8 dp above its top edge. The
  /// compass ornament (a circle about 50 dp across in that corner) stays clear.
  static const closeSize = 28.0;
  static const closeHit = 44.0;
  static const closeDx = frameWidth + 6 - closeHit / 2;
  static const closeDy = -8 - closeHit / 2;
  static const _gap = 6.0;
  static const _rowMax = 76.0;
  static const _rowMin = 60.0;

  /// The rows, each given the height the list can spare.
  List<Widget Function(double)> _rows(BuildContext context) {
    final s = session;
    return [..._base(context, s), ...extraRows];
  }

  List<Widget Function(double)> _base(BuildContext context, ShopSession s) {
    return [
      (h) => MapPlace(
        key: const Key('map-market'),
        height: h,
        icon: 'cho_hoa',
        title: 'Chợ hoa',
        subtitle: 'Mua hoa cho hôm nay',
        onTap: s.backToMarket,
      ),
      (h) => MapPlace(
        key: const Key('map-pets'),
        height: h,
        icon: 'thu_cung',
        title: 'Thú cưng',
        subtitle: s.petsUnlocked
            ? s.roomPet != null
                  ? '${s.petName(s.roomPet!.id)} · '
                        '${petStageName(s.roomPet!.stage)}'
                  : 'Phòng thú cưng'
            : 'Mở vào ngày $strayCatDay',
        onTap: s.petsUnlocked
            ? s.openPets
            : () => showTapHint(context, 'Mở vào ngày $strayCatDay'),
      ),
      (h) => MapPlace(
        key: const Key('map-pet-shop'),
        height: h,
        icon: 'thu_cung',
        image: Art.pet('meo_au_ngoi'),
        title: 'Tiệm thú cưng',
        subtitle: s.petsUnlocked
            ? 'Nuôi ${s.state.pets.length}/${s.e.pets.length}'
            : 'Mở vào ngày $strayCatDay',
        onTap: s.petsUnlocked
            ? s.openPetCatalog
            : () => showTapHint(context, 'Mở vào ngày $strayCatDay'),
      ),
      (h) => MapPlace(
        key: const Key('map-pot-shop'),
        height: h,
        icon: 'chau_hoa',
        title: 'Tiệm Chậu Hoa',
        subtitle: s.potsOwnedCount == 0
            ? 'Ghé xem chậu mới'
            : PotText.kinds(s.potsOwnedCount, s.potKindsTotal),
        highlight: s.potShopRedDot,
        onTap: s.openPotShop,
      ),
      (h) => MapBxhRow(session: s, height: h),
      (h) => MapPlace(
        key: const Key('map-garden'),
        height: h,
        icon: 'vuon_nha',
        title: 'Vườn nhà',
        subtitle: s.gardenUnlocked
            ? 'Trồng và tưới hoa'
            : 'Mở vào ngày ${s.e.gardenOpenDay}',
        onTap: s.gardenUnlocked
            ? s.openGarden
            : () => showTapHint(context, 'Mở vào ngày ${s.e.gardenOpenDay}'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows(context);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: ColoredBox(
          color: AppColors.bgOverlay,
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, outer) => Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    // A short screen (the frame is 516 tall) moves the frame up
                    // instead of cutting its bottom off.
                    padding: EdgeInsets.only(top: topFor(outer.maxHeight)),
                    child: GestureDetector(
                      onTap: () {},
                      child: SizedBox(
                        key: const Key('map-popup'),
                        width: frameWidth,
                        height: frameHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: SkinSliceImage(UiSkin.mapFrame, scale: 3),
                            ),
                            Padding(
                              // The safe text area of the frame; the gold pin and
                              // the peach blossom sit outside it, in the corners.
                              padding: contentPadding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Bản đồ',
                                    textAlign: TextAlign.center,
                                    style: AppText.title(size: 20, weight: 800),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, box) {
                                        final n = rows.length;
                                        final fit =
                                            (box.maxHeight - _gap * (n - 1)) /
                                            n;
                                        // Scrolls once the rows would be squeezed
                                        // under their minimum (7 rows or more).
                                        final h = fit.clamp(_rowMin, _rowMax);
                                        return SingleChildScrollView(
                                          key: const Key('map-rows'),
                                          physics: fit < _rowMin
                                              ? const ClampingScrollPhysics()
                                              : const NeverScrollableScrollPhysics(),
                                          child: Column(
                                            children: [
                                              for (var i = 0; i < n; i++) ...[
                                                if (i > 0)
                                                  const SizedBox(height: _gap),
                                                rows[i](h),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
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
                ),
              ),
              // The close button hangs off the frame's top-right corner, clear of
              // the compass ornament, over the dimmed screen so it takes taps.
              LayoutBuilder(
                builder: (context, outer) => Stack(
                  children: [
                    Positioned(
                      key: const Key('map-close-box'),
                      top: topFor(outer.maxHeight) + closeDy,
                      left: (outer.maxWidth - frameWidth) / 2 + closeDx,
                      width: closeHit,
                      height: closeHit,
                      child: Center(
                        child: SkinRoundButton(
                          key: const Key('map-close'),
                          kind: SkinRound.close,
                          width: closeSize,
                          onTap: onClose,
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
    );
  }
}

/// One row of the map: picture, name and a line under it.
class MapPlace extends StatelessWidget {
  const MapPlace({
    super.key,
    required this.height,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.image,
    this.imageSize = 44,
    this.highlight = false,
    this.subtitleWidget,
    this.iconDot = false,
    this.iconData,
  });

  /// A Material icon (24dp) instead of the [icon] / [image] picture.
  final IconData? iconData;

  /// Replaces the subtitle line (the leaderboard row shows a chip there).
  final Widget? subtitleWidget;

  /// A red dot at the top left of the picture (a reward waits).
  final bool iconDot;

  /// A new pot is on sale: cream-yellow row and a red dot.
  final bool highlight;

  final String icon;
  final String? image;

  /// Drawn size of [image] inside the 44dp icon box.
  final double imageSize;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: highlight ? AppColors.accentSoft : AppColors.bgBase,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: highlight ? AppColors.accentBase : AppColors.surfaceBorder,
            width: AppBorder.thin,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: iconData != null
                          ? Icon(
                              iconData,
                              size: 24,
                              color: AppColors.primaryBase,
                            )
                          : ArtImage(
                              image ?? Art.nav(icon),
                              size: image == null ? 44 : imageSize,
                              fallback: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (iconDot)
                    Positioned(
                      left: -4,
                      top: -4,
                      child: ArtImage(
                        Art.menu('cham_do'),
                        key: const Key('map-bxh-dot'),
                        size: 16,
                        fallback: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.statusDanger,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 16, height: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.heading(size: 16),
                  ),
                  if (subtitleWidget != null || subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    subtitleWidget ??
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(size: 12, weight: 700),
                        ),
                  ],
                ],
              ),
            ),
            if (highlight)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ArtImage(
                  Art.menu('cham_do'),
                  key: const Key('map-red-dot'),
                  size: 16,
                  fallback: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.statusDanger,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 16, height: 16),
                  ),
                ),
              ),
            Text(
              '›',
              style: AppText.title(
                size: 22,
                weight: 800,
                color: AppColors.primaryPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiệm Trang Trí row (spec_skin_trang_tri §4), after the base rows; the
/// list scrolls from seven rows on. The shop set waits for closing time.
Widget Function(double) mapDecorateRow(
  BuildContext context,
  ShopSession s,
  VoidCallback onClose,
) =>
    (h) => MapPlace(
      key: const Key('map-decorate'),
      height: h,
      icon: 'chau_hoa',
      iconData: Icons.brush,
      title: s.skins.ui('skin.shop.title'),
      subtitle: s.skins.ui('skin.edit.shop'),
      onTap: () {
        if (s.openDecorate(skinGroupShop)) {
          onClose();
        } else {
          showTapHint(context, s.skins.ui('skin.closedOnly'));
        }
      },
    );
