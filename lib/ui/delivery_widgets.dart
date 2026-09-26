import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/delivery.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Horizontal strip of open online orders (spec_giao_hang §3).
class OnlineOrderStrip extends StatelessWidget {
  const OnlineOrderStrip({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final orders = session.stripOrders;
    return SizedBox(
      key: const Key('online-strip'),
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _StripCell(
          key: ValueKey(orders[i].id),
          session: session,
          order: orders[i],
        ),
      ),
    );
  }
}

class _StripCell extends StatefulWidget {
  const _StripCell({super.key, required this.session, required this.order});

  final ShopSession session;
  final OnlineOrder order;

  @override
  State<_StripCell> createState() => _StripCellState();
}

class _StripCellState extends State<_StripCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _onTap() {
    final o = widget.order;
    if (o.status == OrderStatus.accepted) {
      widget.session.openOnlineOrder(o.id);
      return;
    }
    _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final o = widget.order;
    final urgent = s.orderUrgent(o);
    final blinkOn = (s.state.elapsed * 2).floor().isEven;
    final occ = s.e.occasion(o.request.occasionId);
    final time = o.kind == OrderKind.preorder
        ? deadlineClock(s.e, o.deadline)
        : countdownLabel(o.deadline - s.state.elapsed);
    return GestureDetector(
      key: Key('strip-${o.id}'),
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = t == 0 || t == 1 ? 0.0 : math.sin(t * 3 * math.pi) * 3;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Container(
          width: 120,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.surfaceBorder,
              width: AppBorder.thin,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(width: 4, color: AppColors.occasion(occ.id)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderShort(s.e, o.request),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(size: 12, weight: 800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StatusChip(status: o.status),
                        const Spacer(),
                        Opacity(
                          opacity: urgent && !blinkOn ? 0.35 : 1,
                          child: Text(
                            time,
                            style: AppText.number(
                              size: 11,
                              color: urgent
                                  ? AppColors.statusDanger
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      OrderStatus.accepted => (
        'Chờ bó',
        AppColors.accentSoft,
        AppColors.accentBase,
      ),
      OrderStatus.packed => (
        'Chờ xe',
        Color.alphaBlend(
          AppColors.statusInfo.withValues(alpha: 0.15),
          const Color(0xFFFFFFFF),
        ),
        AppColors.statusInfo,
      ),
      _ => ('Đang giao', AppColors.secondarySoft, AppColors.secondaryBase),
    };
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppText.caption(size: 9, weight: 800, color: fg),
      ),
    );
  }
}

/// Keeps the same-day card mounted long enough to slide back up on timeout.
class SameDaySlot extends StatefulWidget {
  const SameDaySlot({super.key, required this.session});

  final ShopSession session;

  @override
  State<SameDaySlot> createState() => _SameDaySlotState();
}

class _SameDaySlotState extends State<SameDaySlot>
    with SingleTickerProviderStateMixin {
  OnlineOrder? _order;
  var _leaving = false;
  var _gen = 0;
  late final AnimationController _slide;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: AppMotion.base);
    _curve = CurvedAnimation(
      parent: _slide,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _order = widget.session.incomingSameDay;
    if (_order != null) _slide.forward();
  }

  @override
  void didUpdateWidget(SameDaySlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  void _follow() {
    final next = widget.session.incomingSameDay;
    if (next != null) {
      if (_order?.id != next.id) {
        _gen++;
        _order = next;
        _leaving = false;
        _slide.forward(from: 0);
      }
      return;
    }
    if (_order != null && !_leaving) {
      _leaving = true;
      final gen = ++_gen;
      _slide.reverse().whenComplete(() {
        if (!mounted || gen != _gen) return;
        setState(() {
          _order = null;
          _leaving = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    if (o == null) return const IgnorePointer(child: SizedBox.expand());
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.4),
          end: Offset.zero,
        ).animate(_curve),
        child: SameDayCard(session: widget.session, order: o),
      ),
    );
  }
}

/// Same-day order under the top bar (spec_giao_hang v0.2 §4).
class SameDayCard extends StatelessWidget {
  const SameDayCard({super.key, required this.session, required this.order});

  final ShopSession session;
  final OnlineOrder order;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final o = order;
    final d = s.e.delivery;
    final fraction = d.acceptSeconds <= 0
        ? 0.0
        : (o.acceptLeft / d.acceptSeconds).clamp(0.0, 1.0);
    final short = s.sameDayShortage(o);
    final canTake = short == null;
    return SizedBox(
      width: 336,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: Container(
              key: const Key('sameday-card'),
              width: 336,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                // design_tokens shadow.popup (#2E3A2C33 is RRGGBBAA).
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.popupShadow,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    top: 20,
                    width: 36,
                    height: 36,
                    child: CustomPaint(
                      painter: _AcceptRingPainter(fraction),
                      child: const Icon(
                        Icons.smartphone,
                        size: 16,
                        color: AppColors.statusInfo,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 54,
                    top: 8,
                    right: 88,
                    child: Text(
                      'Đơn online mới',
                      style: AppText.caption(size: 11, weight: 800),
                    ),
                  ),
                  Positioned(
                    left: 54,
                    top: 24,
                    right: 88,
                    child: Text(
                      o.line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 12, weight: 800),
                    ),
                  ),
                  Positioned(
                    left: 54,
                    top: 44,
                    right: 88,
                    child: Text(
                      short == null
                          ? deliverWindowLabel(d.deadlineSeconds)
                          : 'Thiếu ${short.$2} ${short.$1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(
                        size: 11,
                        weight: 800,
                        color: short == null
                            ? AppColors.textSecondary
                            : AppColors.statusDanger,
                      ),
                    ),
                  ),
                  if (s.extraIncoming > 0)
                    Positioned(
                      right: 8,
                      bottom: 4,
                      child: Container(
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBase,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+${s.extraIncoming}',
                          style: AppText.caption(
                            size: 10,
                            weight: 800,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 22,
            width: 72,
            height: 32,
            child: ChunkyButton(
              key: const Key('sameday-accept'),
              label: 'Nhận',
              kind: ButtonKind.secondary,
              fontSize: 13,
              enabled: canTake,
              onPressed: canTake ? () => s.acceptSameDay(o) : null,
            ),
          ),
          Positioned(
            right: 4,
            top: 2,
            child: GestureDetector(
              key: const Key('sameday-skip'),
              onTap: () => s.skipSameDay(o),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptRingPainter extends CustomPainter {
  const _AcceptRingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final track = Paint()
      ..color = AppColors.surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final arc = Paint()
      ..color = AppColors.statusInfo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_AcceptRingPainter old) => old.fraction != fraction;
}

/// Day-3 teaser under the goals, before any shipper is hired.
class ShipperTeaser extends StatelessWidget {
  const ShipperTeaser({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('shipper-teaser'),
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          ArtImage(Art.shipper('bike'), size: 40),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              key: const Key('shipper-teaser-open'),
              onTap: () => session.openUpgrades(tab: 2),
              child: Text(
                'Thuê shipper để nhận đơn online ›',
                style: AppText.body(size: 13, weight: 800),
              ),
            ),
          ),
          GestureDetector(
            key: const Key('shipper-teaser-close'),
            onTap: session.dismissTeaser,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.close,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hired vehicles on the shop floor (spec_giao_hang §5).
class ShipperDock extends StatelessWidget {
  const ShipperDock({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final runs = session.shipperRuns;
    if (runs.isEmpty) return const SizedBox.shrink();
    return Row(
      key: const Key('shipper-dock'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in runs) ...[
          _DockCell(session: session, run: r),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _DockCell extends StatelessWidget {
  const _DockCell({required this.session, required this.run});

  final ShopSession session;
  final ShipperRun run;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = s.state.elapsed;
    final delivering = run.deliveringAt(t);
    final returning = run.returningAt(t);
    final away = delivering || returning;
    final loaded = !away && run.load.isNotEmpty;
    final progress = _progress(t);
    final barColor = returning ? AppColors.statusInfo : AppColors.secondaryBase;
    final loadedCount = away
        ? (run.trip.length - run.handed).clamp(0, run.capacity)
        : run.load.length;
    return SizedBox(
      width: 56,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: away ? 0.45 : 1,
            child: Column(
              children: [
                if (loaded)
                  SizedBox(
                    width: 40,
                    height: 22,
                    child: CustomPaint(
                      painter: _AcceptRingPainter(_loadFraction(t)),
                      child: Center(
                        child: ArtImage(
                          Art.shipperPose(run.id, riding: false),
                          size: 28,
                        ),
                      ),
                    ),
                  )
                else
                  ArtImage(Art.shipperPose(run.id, riding: away), size: 40),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < run.capacity; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < loadedCount
                              ? AppColors.secondaryBase
                              : AppColors.surfaceBorderStrong,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (loaded)
            Positioned(
              left: 8,
              top: -4,
              width: 40,
              height: 22,
              child: ChunkyButton(
                key: Key('shipper-go-${run.id}'),
                label: 'Đi',
                fontSize: 11,
                onPressed: () => s.sendShipper(run.id),
              ),
            ),
          if (away)
            Positioned(
              left: 4,
              bottom: 0,
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          if (run.floatText != null)
            Positioned(
              top: -16,
              left: 0,
              right: 0,
              child: Text(
                run.floatText!,
                textAlign: TextAlign.center,
                style: AppText.number(
                  size: 11,
                  color: run.floatText == 'Trễ'
                      ? AppColors.statusDanger
                      : AppColors.currencyCoin,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _loadFraction(double t) {
    final wait = session.e.delivery.loadWaitSeconds;
    if (wait <= 0) return 1;
    return ((t - run.loadStarted) / wait).clamp(0.0, 1.0);
  }

  double _progress(double t) {
    if (run.deliveringAt(t)) {
      final span = run.routeDoneAt - run.departAt;
      if (span <= 0) return 1;
      return (t - run.departAt) / span;
    }
    if (run.returningAt(t)) {
      final span = run.backAt - run.routeDoneAt;
      if (span <= 0) return 1;
      return (t - run.routeDoneAt) / span;
    }
    return 0;
  }
}

/// A small vehicle crossing the floor while a trip is out.
class ShipperTravel extends StatelessWidget {
  const ShipperTravel({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final t = session.state.elapsed;
    ShipperRun? run;
    for (final r in session.shipperRuns) {
      if (r.deliveringAt(t) || r.returningAt(t)) run = r;
    }
    if (run == null) return const SizedBox.shrink();
    final delivering = run.deliveringAt(t);
    final span = delivering
        ? run.routeDoneAt - run.departAt
        : run.backAt - run.routeDoneAt;
    final p = span <= 0
        ? 1.0
        : ((t - (delivering ? run.departAt : run.routeDoneAt)) / span).clamp(
            0.0,
            1.0,
          );
    final along = delivering ? p : 1 - p;
    final x = 80 + along * 230;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: x,
            top: 268,
            child: ArtImage(Art.shipperPose(run.id, riding: true), size: 24),
          ),
        ],
      ),
    );
  }
}
