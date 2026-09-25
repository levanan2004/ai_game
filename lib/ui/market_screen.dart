import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'paint.dart';
import 'popups.dart';
import 'tutorial_overlay.dart';

/// Chợ hoa buổi sáng (spec_cho_va_tong_ket.md §1).
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  bool _scrolled = false;

  ShopSession get session => widget.session;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final next = n.metrics.pixels > 0.5;
    if (next != _scrolled) setState(() => _scrolled = next);
    return false;
  }

  /// Credit banner (the only banner left; the holiday note became the
  /// poster from spec_popup_va_mo_dau.md §4).
  /// TODO(Phú): credit banner copy is not in a spec.
  String? _banner() {
    final s = session;
    if (!s.onCredit) return null;
    return 'Đang mua chịu, tối đa ${formatK(s.e.minMarketBudget)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final e = s.e;
    final banner = _banner();
    final poster = s.posterHoliday;
    final bannerTop = poster == null ? 106.0 : 182.0;
    final listTop = bannerTop + (banner == null ? 0 : 46);
    final unlocked = [
      for (final f in e.flowers)
        if (s.owned.contains(f.id)) f,
    ];
    final locked = [
      for (final f in e.flowers)
        if (!s.owned.contains(f.id) && f.unlockCost > 0) f,
    ];
    final empty = s.cart.isEmpty;
    final headerH = listTop - 48;
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 48,
            width: 360,
            bottom: 84,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(12, headerH, 12, 12),
                itemCount:
                    unlocked.length + (locked.isEmpty ? 0 : 1 + locked.length),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i < unlocked.length) {
                    return _FlowerRow(session: s, flower: unlocked[i]);
                  }
                  final j = i - unlocked.length;
                  if (j == 0) return const _SoonHeader();
                  return _LockedRow(session: s, flower: locked[j - 1]);
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 48,
            width: 360,
            height: headerH,
            child: const _HeaderPlate(),
          ),
          if (_scrolled)
            Positioned(
              left: 0,
              top: listTop,
              width: 360,
              height: 4,
              child: const ColoredBox(color: AppColors.surfaceBorderStrong),
            ),
          Positioned(
            left: 0,
            top: 0,
            child: TopBar(
              session: s,
              showRating: false,
              dayLabel: '${dayName(s)} · Sáng',
              money: s.state.money - s.cartTotal,
            ),
          ),
          Positioned(
            left: 24,
            top: 58,
            child: Text(
              'Chợ hoa buổi sáng',
              style: AppText.title(size: 22, weight: 800),
            ),
          ),
          if (poster == null)
            Positioned(
              left: 24,
              right: 12,
              top: 86,
              child: Text(
                'Mua hoa theo bó. Hoa tươi được vài ngày, hết hạn là héo.',
                style: AppText.caption(size: 11),
              ),
            )
          else
            Positioned(
              left: 12,
              top: 86,
              width: 336,
              height: 84,
              child: _HolidayPoster(
                session: s,
                holiday: poster.$1,
                daysUntil: poster.$2,
              ),
            ),
          if (banner != null)
            Positioned(
              left: 12,
              top: bannerTop,
              width: 336,
              height: 34,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.accentBase,
                    width: AppBorder.thin,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    banner,
                    key: const Key('market-banner'),
                    style: AppText.caption(
                      size: 11,
                      weight: 800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: 556,
            width: 360,
            height: 84,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(
                  top: BorderSide(
                    color: AppColors.surfaceBorder,
                    width: AppBorder.thin,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 24,
                    top: 8,
                    child: Text(
                      '${s.cartBundles} bó · ${s.cartStems} cành',
                      style: AppText.caption(weight: 800),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    top: 28,
                    child: Text(
                      formatK(s.cartTotal),
                      key: const Key('cart-total'),
                      style: AppText.number(size: 20),
                    ),
                  ),
                  Positioned(
                    left: 148,
                    top: 12,
                    width: 200,
                    height: 56,
                    child: KeyedSubtree(
                      key: TutorialTargets.marketBuy,
                      child: ChunkyButton(
                        key: const Key('market-buy'),
                        label: empty ? 'Mở cửa luôn' : 'Mua & mở cửa',
                        kind: empty ? ButtonKind.ghost : ButtonKind.primary,
                        onPressed: s.buyAndGoToShop,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowerRow extends StatelessWidget {
  const _FlowerRow({required this.session, required this.flower});

  final ShopSession session;
  final FlowerDef flower;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final f = flower;
    final qty = s.cart[f.id] ?? 0;
    final n = s.stockCount(f.id);
    final oldest = s.oldestBatch(f.id);
    final stockText = n == 0
        ? 'Kho: trống'
        : 'Kho: $n cành, còn ${oldest!.freshnessLeft} ngày';
    final fr = s.freshnessFraction(f.id);
    final canAdd = s.canAddBundle(f.id);
    return SizedBox(
      height: 76,
      child: CardBox(
        shadow: false,
        child: Stack(
          children: [
            Positioned(
              left: 10,
              top: 11,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: FlowerIcon(flowerId: f.id, radius: 18),
              ),
            ),
            Positioned(
              left: 74,
              top: 6,
              child: Row(
                children: [
                  Text(f.nameVi, style: AppText.title(size: 15, weight: 800)),
                  if (s.onlineStemDemand(f.id) > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: Key('online-need-${f.id}'),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          AppColors.statusInfo.withValues(alpha: 0.15),
                          const Color(0xFFFFFFFF),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Đơn online: ${s.onlineStemDemand(f.id)}',
                        style: AppText.caption(
                          size: 10,
                          weight: 800,
                          color: AppColors.statusInfo,
                        ),
                      ),
                    ),
                  ],
                  if (s.holidayToday?.featuredFlowers.contains(f.id) ??
                      false) ...[
                    const SizedBox(width: 6),
                    const _HotTag(),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 74,
              top: 28,
              child: Text(
                'Bó ${f.bundleSize} cành · tươi ${s.fullFreshness(f)} ngày',
                style: AppText.caption(size: 11),
              ),
            ),
            Positioned(
              left: 74,
              top: 48,
              child: Row(
                children: [
                  Text(stockText, style: AppText.caption(size: 10)),
                  if (n > 0) ...[
                    const SizedBox(width: 6),
                    ProgressBar(
                      width: 28,
                      height: 4,
                      fraction: fr,
                      color: freshnessColor(fr),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 8,
              child: Text(
                '${formatK(s.bundlePrice(f))}/bó',
                style: AppText.number(size: 14),
              ),
            ),
            Positioned(
              left: 228,
              top: 36,
              child: _StepButton(
                key: Key('minus-${f.id}'),
                plus: false,
                enabled: qty > 0,
                onTap: () => s.removeBundle(f.id),
              ),
            ),
            Positioned(
              left: 256,
              width: 40,
              top: 40,
              child: Text(
                '$qty',
                textAlign: TextAlign.center,
                style: AppText.number(size: 16),
              ),
            ),
            Positioned(
              left: 296,
              top: 36,
              child: KeyedSubtree(
                key: f.id == s.e.unlockedFlowers.first
                    ? TutorialTargets.rosePlus
                    : null,
                child: _StepButton(
                  key: Key('plus-${f.id}'),
                  plus: true,
                  enabled: canAdd,
                  onTap: () => s.addBundle(f.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.plus,
    required this.enabled,
    required this.onTap,
  });

  final bool plus;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: plus ? AppColors.primaryBase : AppColors.surfaceCard,
            shape: BoxShape.circle,
            border: plus
                ? null
                : Border.all(
                    color: AppColors.surfaceBorderStrong,
                    width: AppBorder.thin,
                  ),
          ),
          alignment: Alignment.center,
          child: Text(
            plus ? '+' : '–',
            style: AppText.number(
              size: 16,
              color: plus ? AppColors.textInverse : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Solid `bg.base` so rows scrolling under the title stay hidden.
class _HeaderPlate extends StatelessWidget {
  const _HeaderPlate();

  @override
  Widget build(BuildContext context) {
    return const Listener(
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(color: AppColors.bgBase),
    );
  }
}

class _SoonHeader extends StatelessWidget {
  const _SoonHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
      child: Text(
        'Sắp mở khóa',
        key: const Key('soon-header'),
        style: AppText.heading(size: 14),
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.session, required this.flower});

  final ShopSession session;
  final FlowerDef flower;

  static const _grey = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('locked-${flower.id}'),
      onTap: () => session.openUpgrades(tab: 1),
      child: SizedBox(
        height: 56,
        child: CardBox(
          shadow: false,
          child: Stack(
            children: [
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: 0.5,
                    child: ColorFiltered(
                      colorFilter: _grey,
                      child: FlowerIcon(flowerId: flower.id, radius: 14),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 58,
                top: 0,
                bottom: 0,
                right: 88,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    flower.nameVi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(
                      size: 15,
                      weight: 800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatK(flower.unlockCost),
                    style: AppText.number(
                      size: 14,
                      color: AppColors.textSecondary,
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

/// "Đang hot" on holiday flowers during the holiday (spec §4).
class _HotTag extends StatelessWidget {
  const _HotTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('hot-tag'),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBase,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        'Đang hot',
        style: AppText.caption(
          size: 10,
          weight: 800,
          color: AppColors.textInverse,
        ),
      ),
    );
  }
}

/// Advance holiday poster, 336×84 at y 86 (poster_ngay_le_v0.1.png).
class _HolidayPoster extends StatelessWidget {
  const _HolidayPoster({
    required this.session,
    required this.holiday,
    required this.daysUntil,
  });

  final ShopSession session;
  final HolidayDef holiday;
  final int daysUntil;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final featured = holiday.featuredFlowers.take(3).toList();
    final names = [
      for (final id in holiday.featuredFlowers)
        shortFlowerName(s.e.flower(id).nameVi),
    ];
    return Container(
      key: const Key('holiday-poster'),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primaryBase,
          width: AppBorder.thick,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 10,
            child: Text(
              daysUntil <= 1 ? 'Ngày mai là' : 'Còn $daysUntil ngày tới',
              style: AppText.caption(
                size: 11,
                weight: 700,
                color: AppColors.primaryPressed,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16.0 + featured.length * 40,
            top: 26,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(holiday.nameVi, style: AppText.heading(size: 19)),
            ),
          ),
          Positioned(
            left: 16,
            right: 16.0 + featured.length * 40,
            top: 56,
            child: Text(
              'Khách thích: ${names.join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(size: 11, weight: 700),
            ),
          ),
          for (var i = 0; i < featured.length; i++)
            Positioned(
              right: 12.0 + (featured.length - 1 - i) * 40,
              top: 16,
              width: 38,
              height: 52,
              child: _PosterFlower(
                flowerId: featured[i],
                locked: !s.owned.contains(featured[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PosterFlower extends StatelessWidget {
  const _PosterFlower({required this.flowerId, required this.locked});

  final String flowerId;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: locked ? 0.5 : 1,
          child: ArtImage(
            Art.flower(flowerId),
            size: 44,
            fallback: FlowerIcon(flowerId: flowerId, radius: 14),
          ),
        ),
        if (locked)
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.surfaceBorder,
                  width: AppBorder.thin,
                ),
              ),
              child: Text('Khóa', style: AppText.caption(size: 9, weight: 800)),
            ),
          ),
      ],
    );
  }
}
