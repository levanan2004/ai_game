import 'package:flutter/material.dart';

import '../logic/pet.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Preparing-phase map: the morning market, plus rooms that are still coming.
class MapPopup extends StatelessWidget {
  const MapPopup({super.key, required this.session, required this.onClose});

  final ShopSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: ColoredBox(
          color: AppColors.bgOverlay,
          child: Stack(
            children: [
              Positioned(
                left: 24,
                top: 100,
                width: 312,
                height: 420,
                child: GestureDetector(
                  onTap: () {},
                  child: CardBox(
                    key: const Key('map-popup'),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bản đồ',
                          textAlign: TextAlign.center,
                          style: AppText.title(size: 20, weight: 800),
                        ),
                        const SizedBox(height: 12),
                        _Place(
                          key: const Key('map-market'),
                          icon: 'cho_hoa',
                          title: 'Chợ hoa',
                          subtitle: 'Mua hoa cho hôm nay',
                          onTap: session.backToMarket,
                        ),
                        const SizedBox(height: 8),
                        _Place(
                          key: const Key('map-pets'),
                          icon: 'thu_cung',
                          title: 'Thú cưng',
                          subtitle: session.petsUnlocked
                              ? session.roomPet != null
                                    ? '${session.petName(session.roomPet!.id)} · '
                                          '${petStageName(session.roomPet!.stage)}'
                                    : 'Phòng thú cưng'
                              : 'Mở vào ngày $strayCatDay',
                          onTap: session.petsUnlocked
                              ? session.openPets
                              : () => showTapHint(
                                  context,
                                  'Mở vào ngày $strayCatDay',
                                ),
                        ),
                        const SizedBox(height: 8),
                        _Place(
                          key: const Key('map-pet-shop'),
                          icon: 'thu_cung',
                          image: Art.pet('meo_au_ngoi'),
                          title: 'Tiệm thú cưng',
                          subtitle: session.petsUnlocked
                              ? 'Nuôi ${session.state.pets.length}/'
                                    '${session.e.pets.length}'
                              : 'Mở vào ngày $strayCatDay',
                          onTap: session.petsUnlocked
                              ? session.openPetCatalog
                              : () => showTapHint(
                                  context,
                                  'Mở vào ngày $strayCatDay',
                                ),
                        ),
                        const SizedBox(height: 8),
                        _Place(
                          key: const Key('map-garden'),
                          icon: 'vuon_nha',
                          title: 'Vườn nhà',
                          subtitle: session.gardenUnlocked
                              ? 'Trồng và tưới hoa'
                              : 'Mở vào ngày ${session.e.gardenOpenDay}',
                          onTap: session.gardenUnlocked
                              ? session.openGarden
                              : () => showTapHint(
                                  context,
                                  'Mở vào ngày ${session.e.gardenOpenDay}',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.image,
  });

  final String icon;
  final String? image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: AppBorder.thin,
          ),
        ),
        child: Row(
          children: [
            ArtImage(
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.heading(size: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.caption(size: 12, weight: 700)),
                ],
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
