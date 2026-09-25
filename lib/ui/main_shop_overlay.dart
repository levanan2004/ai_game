import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'tutorial_overlay.dart';

/// Widgets drawn over the Flame shop scene (spec_tiem_chinh.md): top bar,
/// daily goals card, main button + hint, bottom navigation.
class MainShopOverlay extends StatelessWidget {
  const MainShopOverlay({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return SizedBox(
      width: 360,
      height: 640,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: TopBar(
              session: s,
              showPause: true,
              onStarTap: s.openReviews,
            ),
          ),
          Positioned(
            left: 12,
            top: 312,
            width: 336,
            height: 92,
            child: GoalsCard(session: s),
          ),
          Positioned(
            left: 12,
            top: 420,
            width: 336,
            height: 56,
            child: _mainButton(),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 480,
            child: Text(
              _hint(),
              key: const Key('shop-hint'),
              textAlign: TextAlign.center,
              style: AppText.caption(size: 11),
            ),
          ),
          Positioned(
            left: 0,
            top: 560,
            width: 360,
            height: 80,
            child: BottomNav(session: s),
          ),
        ],
      ),
    );
  }

  Widget _mainButton() {
    final s = session;
    switch (s.state.phase) {
      case DayPhase.preparing:
        return KeyedSubtree(
          key: TutorialTargets.openButton,
          child: ChunkyButton(
            key: const Key('main-button'),
            label: 'Mở cửa',
            fontSize: 18,
            onPressed: s.openShop,
          ),
        );
      case DayPhase.open:
        final c = s.nextForPlayer;
        if (c == null) {
          return const ChunkyButton(
            key: Key('main-button'),
            label: 'Đang chờ khách...',
            kind: ButtonKind.ghost,
            fontSize: 18,
            enabled: false,
            onPressed: null,
          );
        }
        return ChunkyButton(
          key: const Key('main-button'),
          label: 'Bó hoa cho ${c.name}',
          fontSize: 18,
          onPressed: s.openTable,
        );
      case DayPhase.market:
      case DayPhase.summary:
        return const SizedBox.shrink();
    }
  }

  String _hint() {
    final s = session;
    if (s.shopNotice != null) return s.shopNotice!;
    if (s.state.phase == DayPhase.preparing) {
      final low = s.unlockedFlowers.any((f) => s.stockCount(f.id) == 0);
      return low ? 'Kho còn ít hoa, ghé chợ trước nhé' : '';
    }
    if (s.nextForPlayer != null) {
      return 'Chạm khách đầu hàng hoặc bấm nút để bó';
    }
    return '';
  }
}

/// "Mục tiêu hôm nay" card.
class GoalsCard extends StatelessWidget {
  const GoalsCard({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final m = session.state.metrics;
    final goals = session.state.goals.take(3).toList();
    return CardBox(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 6,
            child: Text(
              'Mục tiêu hôm nay',
              style: AppText.title(size: 15, weight: 800),
            ),
          ),
          for (var i = 0; i < goals.length; i++)
            Positioned(
              left: 12,
              right: 12,
              top: 38 - 9 + i * 18.0,
              height: 18,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: AppMotion.base,
                    curve: Curves.easeOutBack,
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: goals[i].isDone(m)
                          ? AppColors.secondaryBase
                          : AppColors.surfaceCard,
                      border: Border.all(
                        color: goals[i].isDone(m)
                            ? AppColors.secondaryBase
                            : AppColors.surfaceBorderStrong,
                        width: AppBorder.thin,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goals[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        size: 12,
                        weight: 700,
                        color: goals[i].isDone(m)
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    goals[i].progressLabel(m),
                    style: AppText.number(
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom navigation: Kho hoa, Nâng cấp, Giá bán, Đánh giá, Sổ sách
/// ("Chợ hoa" instead of "Sổ sách" while preparing).
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final preparing = s.state.phase == DayPhase.preparing;
    // Icons from assets/images/nav (Phú v0.1). "Chợ hoa" has no icon yet,
    // so it keeps the drawn placeholder.
    final items = <(String, Color, VoidCallback?, String?)>[
      ('Kho hoa', AppColors.secondaryBase, null, 'kho_hoa'),
      ('Nâng cấp', AppColors.primaryBase, s.openUpgradesFromNav, 'nang_cap'),
      ('Giá bán', AppColors.currencyCoin, null, 'gia_ban'),
      ('Đánh giá', AppColors.currencyStar, s.openReviews, 'danh_gia'),
      preparing
          ? ('Chợ hoa', AppColors.statusInfo, s.backToMarket, null)
          : ('Sổ sách', AppColors.statusInfo, null, 'so_sach'),
    ];
    return DecoratedBox(
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
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: 36 + i * 72 - 36,
              top: 0,
              width: 72,
              height: 80,
              child: _NavButton(
                key: Key('nav-$i'),
                label: items[i].$1,
                color: items[i].$2,
                icon: items[i].$4,
                onTap: items[i].$3,
                dimmed: items[i].$3 == null || (i == 1 && !s.shopClosed),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.dimmed,
  });

  final String label;
  final Color color;

  /// File name in assets/images/nav, or null for the placeholder.
  final String? icon;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    // Old drawn placeholder: coloured dot in a small tile.
    final placeholder = Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: AppBorder.thin,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Icon 28 px above the label; inactive buttons at 45% (assets
          // README, nav section).
          Positioned(
            left: 22,
            top: 18,
            width: 28,
            height: 28,
            child: icon == null
                ? placeholder
                : ArtImage(
                    Art.nav(icon!),
                    size: 28,
                    opacity: dimmed ? 0.45 : 1,
                    fallback: placeholder,
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 52,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.caption(
                size: 11,
                weight: 800,
                color: dimmed ? AppColors.textDisabled : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
