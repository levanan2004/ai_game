import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Popups from spec_popup_va_mo_dau.md: pause, rank up, unlock, holiday.
/// Shared rules: `bg.overlay` behind, card with the solid 4 px shadow,
/// `popupIn` entrance; celebration popups get confetti and ignore taps
/// outside the card.
class PopupLayer extends StatelessWidget {
  const PopupLayer({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final p = s.currentPopup;
    if (p != null) {
      return switch (p) {
        RankUpPopup(:final rank) => RankUpPopupView(
          key: ValueKey('rank-${rank.rank}'),
          session: s,
          rank: rank,
        ),
        UnlockPopup(:final itemId) => UnlockPopupView(
          key: ValueKey('unlock-$itemId'),
          session: s,
          itemId: itemId,
        ),
        HolidayPopup(:final holiday) => HolidayPopupView(
          key: ValueKey('holiday-${holiday.id}'),
          session: s,
          holiday: holiday,
        ),
      };
    }
    if (s.pauseMenuOpen) return PausePopup(session: s);
    return const SizedBox.shrink();
  }
}

/// Dim background + card at [rect] with the `popupIn` animation.
class PopupFrame extends StatelessWidget {
  const PopupFrame({
    super.key,
    required this.rect,
    required this.child,
    this.onOutsideTap,
    this.confetti = false,
  });

  final Rect rect;
  final Widget child;
  final VoidCallback? onOutsideTap;
  final bool confetti;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOutsideTap,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppMotion.slow,
                curve: Curves.easeOutBack,
                builder: (_, t, c) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.85 + 0.15 * t, child: c),
                ),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.surfaceBorderStrong,
                          offset: Offset(0, AppSize.shadowOffset),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
              ),
            ),
            if (confetti) const Positioned.fill(child: Confetti()),
          ],
        ),
      ),
    );
  }
}

/// About 40 paper pieces 6×3 falling for 1.2 s, then fading. Runs once.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  final _pieces = List.generate(40, (i) {
    final r = math.Random(i * 7919 + 13);
    return (
      x: r.nextDouble() * 360,
      delay: r.nextDouble() * 0.25,
      speed: 0.8 + r.nextDouble() * 0.4,
      spin: (r.nextDouble() - 0.5) * 8,
      color: const [
        AppColors.primaryBase,
        AppColors.accentBase,
        AppColors.secondaryBase,
        AppColors.statusInfo,
      ][i % 4],
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          // 0..1.2 s falling, then 0.4 s fade.
          final secs = _c.value * 1.6;
          final fade = secs <= 1.2
              ? 1.0
              : (1 - (secs - 1.2) / 0.4).clamp(0.0, 1.0);
          if (fade <= 0) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, math.min(secs, 1.2) / 1.2, fade),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.fade);

  final List<({double x, double delay, double speed, double spin, Color color})>
  pieces;
  final double t;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      final y = -10 + local * p.speed * size.height * 0.9;
      final x = p.x + math.sin(local * 6 + p.spin) * 8;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      canvas.drawRect(
        const Rect.fromLTWH(-3, -1.5, 6, 3),
        Paint()..color = p.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t || old.fade != fade;
}

/// §1 Popup tạm dừng: card x 40, y 170, 280×300.
class PausePopup extends StatelessWidget {
  const PausePopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    // Card-relative coordinates = spec frame coordinates - (40, 170).
    return PopupFrame(
      key: const Key('pause-popup'),
      rect: const Rect.fromLTWH(40, 170, 280, 300),
      onOutsideTap: s.resumeFromPause,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 20,
            child: Text(
              'Tạm dừng',
              textAlign: TextAlign.center,
              style: AppText.title(size: 24, weight: 800),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 54,
            child: Text(
              'Giờ bán và khách đang đứng yên',
              textAlign: TextAlign.center,
              style: AppText.caption(),
            ),
          ),
          Positioned(
            left: 24,
            top: 92,
            width: 232,
            height: 52,
            child: ChunkyButton(
              key: const Key('pause-resume'),
              label: 'Tiếp tục',
              onPressed: s.resumeFromPause,
            ),
          ),
          Positioned(
            left: 24,
            top: 152,
            width: 232,
            height: 48,
            child: ChunkyButton(
              key: const Key('pause-tutorial'),
              label: 'Xem hướng dẫn',
              kind: ButtonKind.ghost,
              fontSize: 15,
              onPressed: s.openTutorialView,
            ),
          ),
          Positioned(
            left: 24,
            top: 208,
            width: 232,
            height: 48,
            child: ChunkyButton(
              key: const Key('pause-title'),
              label: 'Về màn đầu',
              kind: ButtonKind.ghost,
              fontSize: 15,
              onPressed: s.backToTitle,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 266,
            child: Text(
              'Tiến độ lưu tới sáng nay',
              textAlign: TextAlign.center,
              style: AppText.caption(size: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// §2 Popup lên hạng: card x 32, y 150, 296×340.
class RankUpPopupView extends StatefulWidget {
  const RankUpPopupView({super.key, required this.session, required this.rank});

  final ShopSession session;
  final ShopRankDef rank;

  @override
  State<RankUpPopupView> createState() => _RankUpPopupViewState();
}

class _RankUpPopupViewState extends State<RankUpPopupView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _interval(
    double startMs,
    double lengthMs, [
    Curve curve = Curves.easeOutCubic,
  ]) {
    final t = ((_c.value * 1400 - startMs) / lengthMs).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.session.e;
    final r = widget.rank;
    final ranks = e.shopRanks;
    final i = ranks.indexWhere((x) => x.rank == r.rank);
    final next = i >= 0 && i + 1 < ranks.length ? ranks[i + 1] : null;
    final stars = r.rank.clamp(1, 5);
    // Card-relative = frame - (32, 150).
    return PopupFrame(
      key: const Key('rankup-popup'),
      rect: const Rect.fromLTWH(32, 150, 296, 340),
      confetti: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final badge = _interval(0, 320, Curves.easeOutBack);
          final text = _interval(320 + stars * 80.0, 320);
          return Stack(
            children: [
              Positioned(
                left: 148 - 52,
                top: 46 - 52,
                width: 104,
                height: 104,
                child: Transform.scale(
                  scale: badge,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentBase, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var k = 0; k < stars; k++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: StarIcon(
                                  radius: stars > 3 ? 9 : 13,
                                  fill: _interval(320 + k * 80.0, 80) > 0
                                      ? 1
                                      : 0,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 148 - 64,
                top: 107 - 13,
                width: 128,
                height: 26,
                child: Opacity(
                  opacity: text,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryBase,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'LÊN HẠNG ${r.rank}',
                      style: AppText.caption(
                        size: 12,
                        weight: 800,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 128,
                child: Opacity(
                  opacity: text,
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          r.nameVi,
                          style: AppText.title(size: 24, weight: 800),
                        ),
                      ),
                      Text(
                        'Đã bán tổng cộng ${r.minBouquetsSold} bó hoa',
                        style: AppText.caption(),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: 194,
                width: 256,
                child: Opacity(
                  opacity: text,
                  child: Container(
                    // At least the spec's 72 px; grows when a line wraps.
                    constraints: const BoxConstraints(minHeight: 72),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 3,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _line('Mục tiêu mỗi ngày lớn hơn, thưởng nhiều hơn'),
                        _line('Vùng xanh khi gói hoa hẹp lại một chút'),
                        _line(
                          next == null
                              ? 'Đây là hạng cao nhất'
                              : 'Hạng tiếp theo: ${next.minBouquetsSold} bó',
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                top: 284,
                width: 248,
                height: 48,
                child: ChunkyButton(
                  key: const Key('rankup-ok'),
                  label: 'Tuyệt quá!',
                  onPressed: widget.session.closePopup,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _line(String text, {Color color = AppColors.textPrimary}) => Text(
    '• $text',
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppText.body(size: 11, weight: 700, color: color),
  );
}

/// §3 Popup mở khóa: card x 40, y 170, 280×300.
class UnlockPopupView extends StatelessWidget {
  const UnlockPopupView({
    super.key,
    required this.session,
    required this.itemId,
  });

  final ShopSession session;
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final e = s.e;
    final flower = e.flowers.where((f) => f.id == itemId).firstOrNull;
    final paper = e.papers.where((p) => p.id == itemId).firstOrNull;
    final String title, name, image, sub;
    if (flower != null) {
      title = 'Mở khóa hoa mới!';
      name = flower.nameVi;
      image = Art.flower(itemId);
      sub = 'Đã có bán ở Chợ hoa từ sáng mai';
    } else if (paper != null) {
      title = 'Mở khóa giấy mới!';
      name = paper.nameVi;
      image = Art.paper(itemId);
      sub = 'Đã có trong khay ở Bàn bó hoa';
    } else {
      final r = e.ribbons.firstWhere((r) => r.id == itemId);
      title = 'Mở khóa nơ mới!';
      name = r.nameVi;
      image = Art.ribbon(itemId);
      sub = 'Đã có trong khay ở Bàn bó hoa';
    }
    // "Ra chợ" only for flowers, and only in the morning (market phase).
    final toMarket = flower != null && s.state.phase == DayPhase.market;
    return PopupFrame(
      key: const Key('unlock-popup'),
      rect: const Rect.fromLTWH(40, 170, 280, 300),
      confetti: true,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.heading(size: 20, color: AppColors.primaryBase),
            ),
          ),
          Positioned(
            left: 140 - 50,
            top: 100 - 50,
            width: 100,
            height: 100,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: ArtImage(image, size: 96),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 154,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(name, style: AppText.title(size: 22, weight: 800)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 188,
            child: Text(
              sub,
              textAlign: TextAlign.center,
              style: AppText.caption(size: 11),
            ),
          ),
          if (toMarket) ...[
            Positioned(
              left: 24,
              top: 228,
              width: 108,
              height: 48,
              child: ChunkyButton(
                key: const Key('unlock-close'),
                label: 'Đóng',
                kind: ButtonKind.ghost,
                fontSize: 15,
                onPressed: s.closePopup,
              ),
            ),
            Positioned(
              left: 140,
              top: 228,
              width: 116,
              height: 48,
              child: ChunkyButton(
                key: const Key('unlock-market'),
                label: 'Ra chợ',
                fontSize: 15,
                onPressed: s.closePopupAndGoToMarket,
              ),
            ),
          ] else
            Positioned(
              left: 24,
              top: 228,
              width: 232,
              height: 48,
              child: ChunkyButton(
                key: const Key('unlock-close'),
                label: 'Đóng',
                kind: ButtonKind.ghost,
                fontSize: 15,
                onPressed: s.closePopup,
              ),
            ),
        ],
      ),
    );
  }
}

/// Featured flower names joined the Vietnamese way: "Hồng và Tulip",
/// "Hồng, Cẩm chướng và Tulip". Short names drop the "Hoa " prefix.
String featuredNames(Economy e, List<String> ids, {String sep = ' và '}) {
  final names = [for (final id in ids) shortFlowerName(e.flower(id).nameVi)];
  if (names.length <= 1) return names.join();
  return '${names.sublist(0, names.length - 1).join(', ')}$sep${names.last}';
}

/// "Hoa hồng" -> "Hồng" (the mockups list featured flowers without "Hoa").
String shortFlowerName(String nameVi) {
  const prefix = 'Hoa ';
  if (!nameVi.startsWith(prefix)) return nameVi;
  final rest = nameVi.substring(prefix.length);
  return rest.isEmpty ? nameVi : rest[0].toUpperCase() + rest.substring(1);
}

/// §4 Popup sáng ngày lễ: card x 32, y 150, 296×330.
class HolidayPopupView extends StatelessWidget {
  const HolidayPopupView({
    super.key,
    required this.session,
    required this.holiday,
  });

  final ShopSession session;
  final HolidayDef holiday;

  @override
  Widget build(BuildContext context) {
    final e = session.e;
    final h = holiday;
    final featured = h.featuredFlowers.take(3).toList();
    final effects = [
      (
        'Khách đông gấp ${formatMultiplier(h.customerMultiplier)} lần',
        AppColors.statusSuccess,
      ),
      ('Tiền boa nhiều hơn', AppColors.statusSuccess),
      ('Giá hoa ở chợ cao hơn', AppColors.statusWarning),
    ];
    // Card-relative = frame - (32, 150).
    return PopupFrame(
      key: const Key('holiday-popup'),
      rect: const Rect.fromLTWH(32, 150, 296, 330),
      confetti: true,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 70,
            child: ColoredBox(
              color: AppColors.primaryBase,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hôm nay là',
                    style: AppText.caption(color: AppColors.textInverse),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      h.nameVi,
                      style: AppText.title(
                        size: 22,
                        weight: 800,
                        color: AppColors.textInverse,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 78,
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final id in featured)
                  ArtImage(
                    Art.flower(id),
                    size: 72,
                    opacity: session.owned.contains(id) ? 1 : 0.5,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 152,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Khách thích ${featuredNames(e, featured)}',
                style: AppText.heading(size: 15),
              ),
            ),
          ),
          for (var i = 0; i < effects.length; i++)
            Positioned(
              left: 24,
              top: 186 + i * 22,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: effects[i].$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    effects[i].$1,
                    style: AppText.body(size: 12, weight: 700),
                  ),
                ],
              ),
            ),
          Positioned(
            left: 24,
            top: 270,
            width: 248,
            height: 48,
            child: ChunkyButton(
              key: const Key('holiday-ok'),
              label: 'Ra chợ thôi',
              onPressed: session.closePopup,
            ),
          ),
        ],
      ),
    );
  }
}
