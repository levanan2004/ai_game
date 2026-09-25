import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'paint.dart';

/// Chợ hoa buổi sáng (spec_cho_va_tong_ket.md §1).
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key, required this.session});

  final ShopSession session;

  /// Banner text by priority: credit, upcoming holiday, price rise.
  /// TODO(Phú): only the holiday line has example copy in the mockup.
  String? _banner() {
    final s = session;
    final e = s.e;
    if (s.onCredit) {
      return 'Đang mua chịu, tối đa ${formatK(e.minMarketBudget)}';
    }
    final up = e.upcomingHoliday(s.state.day, e.posterDaysBefore);
    if (up != null) {
      return 'Còn ${up.$2} ngày nữa là ${up.$1.nameVi}, nhớ trữ hoa sớm';
    }
    final rise = e.priceRiseHoliday(s.state.day);
    if (rise != null) {
      final names = [
        for (final id in rise.featuredFlowers)
          if (s.owned.contains(id)) e.flower(id).nameVi.toLowerCase(),
      ];
      if (names.isNotEmpty) return 'Dịp ${rise.nameVi}: ${names.join(', ')} đang lên giá';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final e = s.e;
    final banner = _banner();
    final listTop = banner == null ? 106.0 : 152.0;
    final flowers = [
      ...e.flowers.where((f) => s.owned.contains(f.id)),
      ...e.flowers.where((f) => !s.owned.contains(f.id)),
    ];
    final empty = s.cart.isEmpty;
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: TopBar(
              session: s,
              showRating: false,
              dayLabel: 'Ngày ${s.state.day} · Sáng',
              money: s.state.money - s.cartTotal,
            ),
          ),
          Positioned(
            left: 24,
            top: 58,
            child: Text('Chợ hoa buổi sáng', style: AppText.title(size: 22, weight: 800)),
          ),
          Positioned(
            left: 24,
            right: 12,
            top: 86,
            child: Text(
              'Mua hoa theo bó. Hoa tươi được vài ngày, hết hạn là héo.',
              style: AppText.caption(size: 11),
            ),
          ),
          if (banner != null)
            Positioned(
              left: 12,
              top: 106,
              width: 336,
              height: 34,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.accentBase, width: AppBorder.thin),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    banner,
                    key: const Key('market-banner'),
                    style: AppText.caption(size: 11, weight: 800, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: listTop,
            width: 360,
            bottom: 84,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: flowers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => flowers[i].unlockCost > 0 &&
                      !s.owned.contains(flowers[i].id)
                  ? _LockedRow(session: s, flower: flowers[i])
                  : _FlowerRow(session: s, flower: flowers[i]),
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
                  top: BorderSide(color: AppColors.surfaceBorder, width: AppBorder.thin),
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
                    child: ChunkyButton(
                      key: const Key('market-buy'),
                      label: empty ? 'Mở cửa luôn' : 'Mua & mở cửa',
                      kind: empty ? ButtonKind.ghost : ButtonKind.primary,
                      onPressed: s.buyAndGoToShop,
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
              child: Text(f.nameVi, style: AppText.title(size: 15, weight: 800)),
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
                    ProgressBar(width: 28, height: 4, fraction: fr, color: freshnessColor(fr)),
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
              child: _StepButton(
                key: Key('plus-${f.id}'),
                plus: true,
                enabled: canAdd,
                onTap: () => s.addBundle(f.id),
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
                : Border.all(color: AppColors.surfaceBorderStrong, width: AppBorder.thin),
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

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.session, required this.flower});

  final ShopSession session;
  final FlowerDef flower;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => session.openUpgrades(tab: 1),
      child: SizedBox(
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
                  child: FlowerIcon(flowerId: flower.id, radius: 18),
                ),
              ),
              // bg.base at 60% over the row.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.bgBase.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
              Positioned(
                left: 74,
                top: 14,
                child: Text(
                  flower.nameVi,
                  style: AppText.title(size: 15, weight: 800, color: AppColors.textSecondary),
                ),
              ),
              Positioned(
                left: 74,
                top: 38,
                child: Text(
                  'Mở khóa: ${formatK(flower.unlockCost)} ở Nâng cấp',
                  style: AppText.caption(size: 11),
                ),
              ),
              Positioned(
                right: 12,
                top: 23,
                child: Container(
                  width: 52,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text('Khóa', style: AppText.caption(size: 11, weight: 800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
