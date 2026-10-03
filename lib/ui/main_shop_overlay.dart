import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/goals.dart';
import '../logic/shop_session.dart';
import '../logic/shop_shelf.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'delivery_widgets.dart';
import 'map_popup.dart';
import 'pet_shop_screen.dart';
import 'pot_popup.dart';
import 'shop_shelf_layer.dart';
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
  bool _confirmEnd = false;
  bool _mapOpen = false;

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
              noticeSlot: true,
              showDay: false,
              onStarTap: s.openReviews,
            ),
          ),
          if (s.eventStatus != null)
            Positioned(
              left: 12,
              right: 12,
              top: 52,
              child: Text(
                s.eventStatus!,
                key: const Key('event-status'),
                textAlign: TextAlign.center,
                style: AppText.caption(size: 12, weight: 800),
              ),
            ),
          Positioned.fill(child: ShopShelfLayer(session: s)),
          if (s.shipperRuns.isNotEmpty) ...[
            Positioned.fill(child: ShipperTravel(session: s)),
            Positioned(
              right: _dockRight,
              top: 232,
              child: ShipperDock(session: s),
            ),
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
            child: BottomNav(
              session: s,
              mapOpen: _mapOpen,
              onMap: () {
                s.sounds.effect('popup_open');
                setState(() => _mapOpen = true);
              },
            ),
          ),
          Positioned(
            left: 12,
            top: 60,
            width: 336,
            height: 76,
            child: SameDaySlot(session: s),
          ),
          if (_confirmEnd) _endDayDialog(),
          if (_mapOpen)
            MapPopup(
              session: s,
              onClose: () {
                s.sounds.effect('popup_close');
                setState(() => _mapOpen = false);
              },
            ),
          if (s.potPickerOpen) Positioned.fill(child: PotPopup(session: s)),
          if (s.petCatalogOpen)
            Positioned.fill(child: PetCatalogPopup(session: s)),
          if (s.shopNotice != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 88,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        s.shopNotice!,
                        key: const Key('shop-notice'),
                        textAlign: TextAlign.center,
                        style: AppText.caption(
                          size: 12,
                          weight: 800,
                          color: AppColors.textInverse,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The shipper dock stands on the ledge's right end, where the pet sits;
  /// with a pet along it moves left to end 4 px before the pet.
  double get _dockRight {
    final pet = shelfPet(session.state);
    if (pet == null) return 8;
    return ShelfGeometry.sceneRight - ShelfGeometry.petRect(pet).left - 4;
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
            height: 52,
            fontSize: 18,
            onPressed: s.openShop,
          ),
        );
      case DayPhase.open:
        if (s.shelfEmpty) {
          final blocked = s.mustPlayUntilClose;
          return ChunkyButton(
            key: const Key('close-early'),
            label: 'Kết thúc ngày',
            kind: ButtonKind.ghost,
            height: 52,
            fontSize: 18,
            enabled: !blocked,
            disabledHint: blocked ? ShopSession.playUntilCloseHint : null,
            onPressed: blocked ? null : _askToEndDay,
          );
        }
        final c = s.nextForPlayer;
        if (c == null) {
          return const ChunkyButton(
            key: Key('main-button'),
            label: 'Đang chờ khách...',
            kind: ButtonKind.ghost,
            height: 52,
            fontSize: 18,
            enabled: false,
            onPressed: null,
            disabledHint: 'Chưa có khách, đợi chút nhé',
          );
        }
        return ChunkyButton(
          key: const Key('main-button'),
          label: 'Bó hoa cho ${c.name}',
          height: 52,
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
    final canEnd = s.state.phase == DayPhase.open && s.tutorialStep == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hint.isNotEmpty)
          Flexible(
            child: Text(
              hint,
              key: const Key('shop-hint'),
              textAlign: TextAlign.center,
              style: AppText.caption(size: 11, weight: 700),
            ),
          ),
        if (canEnd) ...[
          if (hint.isNotEmpty) const SizedBox(width: 8),
          GestureDetector(
            key: const Key('end-day'),
            behavior: HitTestBehavior.opaque,
            onTap: _askToEndDay,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Kết thúc ngày',
                style: AppText.caption(
                  size: 11,
                  weight: 800,
                  color: AppColors.primaryPressed,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _askToEndDay() {
    final s = session;
    if (s.mustPlayUntilClose) {
      showTapHint(context, ShopSession.playUntilCloseHint);
      return;
    }
    s.sounds.effect('popup_open');
    setState(() => _confirmEnd = true);
  }

  Widget _endDayDialog() {
    final s = session;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          s.sounds.effect('popup_close');
          setState(() => _confirmEnd = false);
        },
        child: ColoredBox(
          color: AppColors.bgOverlay,
          child: Stack(
            children: [
              Positioned(
                left: 32,
                top: 220,
                width: 296,
                height: 196,
                child: GestureDetector(
                  onTap: () {},
                  child: CardBox(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      children: [
                        Text(
                          'Đóng cửa và sang tổng kết? Khách đang chờ sẽ về, không bị trừ sao. Sáng mai mới mua được hoa.',
                          key: const Key('end-day-confirm'),
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 14, weight: 800),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ChunkyButton(
                                  key: const Key('end-day-no'),
                                  label: 'Ở lại',
                                  kind: ButtonKind.ghost,
                                  fontSize: 15,
                                  onPressed: () {
                                    s.sounds.effect('popup_close');
                                    setState(() => _confirmEnd = false);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ChunkyButton(
                                  key: const Key('end-day-yes'),
                                  label: 'Kết thúc',
                                  fontSize: 15,
                                  onPressed: () {
                                    setState(() => _confirmEnd = false);
                                    s.closeEarly();
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
              ),
            ],
          ),
        ),
      ),
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
          radius: 16,
          borderWidth: 1,
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
      radius: 16,
      borderWidth: 1,
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

/// One goal line. A reached goal is a green dot with a white check stroke.
/// Limit goals ("không quá", "không để quá") keep that check while they hold,
/// and switch to × once they are broken.
class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.metrics});

  final DailyGoal goal;
  final DayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final done = goal.isDone(metrics);
    final exceeded = goal.isExceeded(metrics);
    final limit = goal.isLimit;
    final achieved = done && !exceeded;
    final titleColor = exceeded
        ? AppColors.statusDanger
        : (!limit && done)
        ? AppColors.textSecondary
        : AppColors.textPrimary;
    final progressColor = exceeded
        ? AppColors.statusDanger
        : AppColors.textSecondary;
    final fill = achieved ? AppColors.statusSuccess : AppColors.surfaceCard;
    final border = exceeded
        ? AppColors.statusDanger
        : achieved
        ? AppColors.statusSuccess
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
          child: achieved || exceeded
              ? CustomPaint(
                  painter: _LimitMarkPainter(
                    exceeded: exceeded,
                    color: achieved
                        ? AppColors.textInverse
                        : AppColors.statusDanger,
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
/// ("Bản đồ" instead of "Sổ sách" while preparing).
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.session,
    required this.onMap,
    this.mapOpen = false,
  });

  final ShopSession session;
  final VoidCallback onMap;
  final bool mapOpen;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final preparing = s.state.phase == DayPhase.preparing;
    // Dim only a tab that cannot be used right now. Tapping it explains why.
    final upgradeBlocked = s.state.phase == DayPhase.open
        ? 'Nâng cấp khi tiệm đóng cửa nhé'
        : null;
    const soon = 'Mục này sắp có nhé';
    final items = <(String, Color, VoidCallback?, String?, String?, Screen?)>[
      (
        'Kho hoa',
        AppColors.secondaryBase,
        s.openStock,
        'kho_hoa',
        null,
        Screen.stock,
      ),
      (
        'Nâng cấp',
        AppColors.primaryBase,
        s.openUpgradesFromNav,
        'nang_cap',
        upgradeBlocked,
        Screen.upgrades,
      ),
      (
        'Giá bán',
        AppColors.currencyCoin,
        s.openPrices,
        'gia_ban',
        s.pricesUnlocked ? null : 'Mở vào ngày ${s.e.pricesOpenDay}',
        Screen.prices,
      ),
      (
        'Đánh giá',
        AppColors.currencyStar,
        s.openReviews,
        'danh_gia',
        null,
        Screen.reviews,
      ),
      preparing
          ? ('Bản đồ', AppColors.statusInfo, onMap, 'ban_do', null, null)
          : ('Sổ sách', AppColors.statusInfo, null, 'so_sach', soon, null),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                selected:
                    (items[i].$6 != null && items[i].$6 == s.screen) ||
                    (mapOpen && preparing && i == 4),
                onTap: items[i].$3,
                disabledHint: items[i].$5,
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
    required this.disabledHint,
    required this.selected,
  });

  final String label;
  final Color color;

  /// File name in assets/images/nav, or null for the placeholder.
  final String? icon;
  final VoidCallback? onTap;

  /// Set when the tab cannot be used right now: the tab is dimmed and a tap
  /// explains why instead of opening it.
  final String? disabledHint;
  final bool selected;

  bool get dimmed => disabledHint != null;

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
    final labelColor = dimmed
        ? AppColors.textDisabled
        : selected
        ? AppColors.navActiveLabel
        : AppColors.navLabel;
    return GestureDetector(
      onTap: disabledHint != null
          ? () => showTapHint(context, disabledHint!)
          : onTap == null
          ? null
          : () {
              SoundScope.maybeOf(context)?.effect('ui_tab');
              onTap!();
            },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          if (selected)
            Positioned(
              left: 8,
              top: 16,
              width: 56,
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.navActivePill,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          // Full-colour icon unless the tab really cannot be used.
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
              style: AppText.make(
                AppFonts.display,
                11,
                selected ? 800 : 600,
                height: 1.1,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
