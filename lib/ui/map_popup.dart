import 'package:flutter/material.dart';

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
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
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
                        padding: const EdgeInsets.fromLTRB(
                          19.5,
                          28,
                          19.8,
                          30.5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Bản đồ',
                              textAlign: TextAlign.center,
                              style: AppText.title(size: 20, weight: 800),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final n = rows.length;
                                  final fit =
                                      (box.maxHeight - _gap * (n - 1)) / n;
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
    this.highlight = false,
    this.subtitleWidget,
    this.iconDot = false,
  });

  /// Replaces the subtitle line (the leaderboard row shows a chip there).
  final Widget? subtitleWidget;

  /// A red dot at the top left of the picture (a reward waits).
  final bool iconDot;

  /// A new pot is on sale: cream-yellow row and a red dot.
  final bool highlight;

  final String icon;
  final String? image;
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
                    child: ArtImage(
                      image ?? Art.nav(icon),
                      size: 44,
                      fallback: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
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
