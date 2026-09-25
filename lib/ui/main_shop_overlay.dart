import 'package:flutter/material.dart';

import '../logic/goals.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'delivery_widgets.dart';
import 'tutorial_overlay.dart';

/// Widgets drawn over the Flame shop scene (spec_tiem_chinh.md): top bar,
/// daily goals card, main button + hint, bottom navigation.
class MainShopOverlay extends StatefulWidget {
  const MainShopOverlay({super.key, required this.session});

  final ShopSession session;

  @override
  State<MainShopOverlay> createState() => _MainShopOverlayState();
}

class _MainShopOverlayState extends State<MainShopOverlay> {
  bool _goalsOpen = false;

  ShopSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final strip = s.hasOnlineStrip;
    final teaser = s.showShipperTeaser;
    final goalsTop = strip ? 368.0 : 312.0;
    final goalsOpen = strip && _goalsOpen;
    final goalsHeight = !strip ? 92.0 : (goalsOpen ? 92.0 : 40.0);
    var buttonTop = _shelfEmptyOpen ? 450.0 : 420.0;
    var bannerTop = 408.0;
    if (strip || teaser) {
      var cursor = goalsTop + goalsHeight + 8;
      if (teaser) {
        cursor += 56 + 8;
      }
      if (_shelfEmptyOpen) {
        bannerTop = cursor;
        buttonTop = cursor + 42;
      } else {
        buttonTop = cursor;
      }
    }
    final hintTop = buttonTop + 60;
    final showHint = hintTop < 548 && !_shelfEmptyOpen;
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
          const Positioned.fill(child: SizedBox.shrink()),
          if (s.shipperRuns.isNotEmpty) ...[
            Positioned.fill(child: ShipperTravel(session: s)),
            Positioned(right: 8, top: 232, child: ShipperDock(session: s)),
          ],
          if (strip)
            Positioned(
              left: 0,
              top: 300,
              width: 360,
              height: 64,
              child: OnlineOrderStrip(session: s),
            ),
          Positioned(
            left: 12,
            top: goalsTop,
            width: 336,
            height: goalsHeight,
            child: GoalsCard(
              session: s,
              collapsed: strip && !_goalsOpen,
              onExpand: () => setState(() => _goalsOpen = true),
            ),
          ),
          if (teaser)
            Positioned(
              left: 12,
              top: goalsTop + goalsHeight + 8,
              width: 336,
              height: 56,
              child: ShipperTeaser(session: s),
            ),
          if (_shelfEmptyOpen)
            Positioned(
              left: 12,
              top: bannerTop,
              width: 336,
              height: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    'Hết hoa rồi, mai nhớ nhập thêm nhé',
                    key: const Key('empty-shelf-banner'),
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
            left: 12,
            top: buttonTop,
            width: 336,
            height: 56,
            child: _mainButton(),
          ),
          if (showHint)
            Positioned(left: 12, right: 12, top: hintTop, child: _hintLine()),
          Positioned(
            left: 0,
            top: 560,
            width: 360,
            height: 80,
            child: BottomNav(session: s),
          ),
          Positioned(
            left: 12,
            top: 52,
            width: 336,
            height: 76,
            child: SameDaySlot(session: s),
          ),
        ],
      ),
    );
  }

  bool get _shelfEmptyOpen =>
      session.state.phase == DayPhase.open && session.shelfEmpty;

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
        if (s.shelfEmpty) {
          return ChunkyButton(
            key: const Key('close-early'),
            label: 'Đóng cửa sớm',
            kind: ButtonKind.ghost,
            fontSize: 18,
            onPressed: s.closeEarly,
          );
        }
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

  Widget _hintLine() {
    final s = session;
    if (s.shopNotice != null) {
      return Text(
        s.shopNotice!,
        key: const Key('shop-hint'),
        textAlign: TextAlign.center,
        style: AppText.caption(size: 11),
      );
    }
    if (s.state.phase == DayPhase.preparing) {
      final low = s.unlockedFlowers.any((f) => s.stockCount(f.id) == 0);
      if (low) {
        return GestureDetector(
          key: const Key('go-market'),
          behavior: HitTestBehavior.opaque,
          onTap: s.backToMarket,
          child: Text(
            'Ghé chợ hoa ›',
            textAlign: TextAlign.center,
            style: AppText.caption(
              size: 11,
              weight: 800,
              color: AppColors.primaryPressed,
            ),
          ),
        );
      }
    }
    final hint = s.state.phase == DayPhase.open && s.nextForPlayer != null
        ? 'Chạm khách đầu hàng hoặc bấm nút để bó'
        : '';
    return Text(
      hint,
      key: const Key('shop-hint'),
      textAlign: TextAlign.center,
      style: AppText.caption(size: 11),
    );
  }
}

/// "Mục tiêu hôm nay" card.
class GoalsCard extends StatelessWidget {
  const GoalsCard({
    super.key,
    required this.session,
    this.collapsed = false,
    this.onExpand,
  });

  final ShopSession session;
  final bool collapsed;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final m = session.state.metrics;
    final goals = session.state.goals.take(3).toList();
    final done = goals.where((g) => g.isDone(m)).length;
    if (collapsed) {
      return GestureDetector(
        key: const Key('goals-collapsed'),
        onTap: onExpand,
        child: CardBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mục tiêu $done/${goals.length} ›',
                style: AppText.title(size: 15, weight: 800),
              ),
            ),
          ),
        ),
      );
    }
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
              child: _GoalRow(goal: goals[i], metrics: m),
            ),
        ],
      ),
    );
  }
}

/// One goal line. Limit goals ("không quá", "tối đa") show ✓ while they
/// hold and × once they are broken.
class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.metrics});

  final DailyGoal goal;
  final DayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final done = goal.isDone(metrics);
    final exceeded = goal.isExceeded(metrics);
    final limit = goal.isLimit;
    final markColor = exceeded
        ? AppColors.statusDanger
        : AppColors.statusSuccess;
    final titleColor = exceeded
        ? AppColors.statusDanger
        : (!limit && done)
        ? AppColors.textSecondary
        : AppColors.textPrimary;
    final progressColor = exceeded
        ? AppColors.statusDanger
        : AppColors.textSecondary;
    final fill = !limit && done
        ? AppColors.secondaryBase
        : AppColors.surfaceCard;
    final border = exceeded
        ? AppColors.statusDanger
        : limit
        ? AppColors.statusSuccess
        : done
        ? AppColors.secondaryBase
        : AppColors.surfaceBorderStrong;
    return Row(
      children: [
        AnimatedContainer(
          duration: AppMotion.base,
          curve: Curves.easeOutBack,
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: border, width: AppBorder.thin),
          ),
          child: limit
              ? CustomPaint(
                  painter: _LimitMarkPainter(
                    exceeded: exceeded,
                    color: markColor,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            goal.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 12, weight: 700, color: titleColor),
          ),
        ),
        Text(
          goal.progressLabel(metrics),
          style: AppText.number(size: 12, color: progressColor),
        ),
      ],
    );
  }
}

class _LimitMarkPainter extends CustomPainter {
  const _LimitMarkPainter({required this.exceeded, required this.color});

  final bool exceeded;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (exceeded) {
      canvas.drawLine(
        Offset(size.width * 0.28, size.height * 0.28),
        Offset(size.width * 0.72, size.height * 0.72),
        p,
      );
      canvas.drawLine(
        Offset(size.width * 0.72, size.height * 0.28),
        Offset(size.width * 0.28, size.height * 0.72),
        p,
      );
    } else {
      final path = Path()
        ..moveTo(size.width * 0.22, size.height * 0.52)
        ..lineTo(size.width * 0.42, size.height * 0.72)
        ..lineTo(size.width * 0.78, size.height * 0.30);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_LimitMarkPainter old) =>
      old.exceeded != exceeded || old.color != color;
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
    // Dim only a tab that cannot be used right now. Tapping it explains why.
    final upgradeBlocked = s.state.phase == DayPhase.open
        ? 'Nâng cấp khi tiệm đóng cửa nhé'
        : null;
    final items = <(String, Color, VoidCallback?, String?, String?)>[
      ('Kho hoa', AppColors.secondaryBase, null, 'kho_hoa', null),
      (
        'Nâng cấp',
        AppColors.primaryBase,
        s.openUpgradesFromNav,
        'nang_cap',
        upgradeBlocked,
      ),
      ('Giá bán', AppColors.currencyCoin, null, 'gia_ban', null),
      ('Đánh giá', AppColors.currencyStar, s.openReviews, 'danh_gia', null),
      preparing
          ? ('Chợ hoa', AppColors.statusInfo, s.backToMarket, 'cho_hoa', null)
          : ('Sổ sách', AppColors.statusInfo, null, 'so_sach', null),
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
                dimmed: items[i].$5 != null,
                onTap: items[i].$5 != null
                    ? () => s.showNotice(items[i].$5!)
                    : items[i].$3,
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
