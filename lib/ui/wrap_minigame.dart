import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/payment.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'paint.dart';

/// Wrap mini-game (spec_ban_bo_hoa.md "Mini-game gói hoa", economy
/// `wrapMiniGame`): hold to grow a circle, release inside the green ring.
/// Reward-only: a miss still sells the bouquet, only the bonus tip is lost.
class WrapMiniGame extends StatefulWidget {
  const WrapMiniGame({
    super.key,
    required this.session,
    required this.zone,
    required this.onDone,
  });

  final ShopSession session;
  final WrapZone zone;
  final VoidCallback onDone;

  @override
  State<WrapMiniGame> createState() => _WrapMiniGameState();
}

enum _Phase { ready, holding, wrapping }

class _WrapMiniGameState extends State<WrapMiniGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  _Phase _phase = _Phase.ready;
  double _fill = 0;
  double _wrapT = 0;
  bool? _hit;

  ShopSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_phase == _Phase.holding) {
      setState(() => _fill += dt / s.e.wrapFillSeconds);
      // Holding past full counts as a miss.
      if (_fill > 1) _release();
    } else if (_phase == _Phase.wrapping) {
      final total = s.wrapAnimationSeconds;
      setState(() => _wrapT += dt);
      if (_wrapT >= total) {
        _phase = _Phase.ready;
        s.finishWrap(hit: _hit ?? false);
        widget.onDone();
      }
    }
  }

  void _press() {
    if (_phase != _Phase.ready || _hit != null) return;
    setState(() {
      _phase = _Phase.holding;
      _fill = 0;
    });
  }

  void _release() {
    if (_phase != _Phase.holding) return;
    setState(() {
      _hit = _fill <= 1 && widget.zone.contains(_fill);
      _phase = _Phase.wrapping;
      _wrapT = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wrapFraction = s.wrapAnimationSeconds <= 0
        ? 1.0
        : (_wrapT / s.wrapAnimationSeconds).clamp(0.0, 1.0);
    return ColoredBox(
      color: AppColors.bgOverlay,
      child: Stack(
        children: [
          Positioned(
            left: 32,
            top: 150,
            width: 296,
            height: 300,
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
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: Text(
                      // TODO(Phú): mini-game copy is not in the spec yet.
                      'Giữ nút, thả tay khi vòng vào vùng xanh',
                      textAlign: TextAlign.center,
                      style: AppText.caption(),
                    ),
                  ),
                  Positioned.fill(
                    top: 30,
                    child: CustomPaint(
                      painter: _WrapPainter(
                        zone: widget.zone,
                        fill: _fill.clamp(0, 1),
                        hit: _hit,
                        wrapFraction: _phase == _Phase.wrapping
                            ? wrapFraction
                            : 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 48,
            top: 464,
            width: 264,
            height: 52,
            child: Listener(
              key: const Key('wrap-hold'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _press(),
              onPointerUp: (_) => _release(),
              onPointerCancel: (_) => _release(),
              child: Opacity(
                opacity: _hit == null ? 1 : 0.5,
                child: Container(
                  margin: EdgeInsets.only(
                    top: _phase == _Phase.holding ? AppSize.shadowOffset : 0,
                    bottom: _phase == _Phase.holding ? 0 : AppSize.shadowOffset,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBase,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _phase == _Phase.holding
                        ? null
                        : const [
                            BoxShadow(
                              color: AppColors.primaryPressed,
                              offset: Offset(0, AppSize.shadowOffset),
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    // TODO(Phú): button label not in the spec yet.
                    'Giữ để gói',
                    style: AppText.button(size: 17, weight: 800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WrapPainter extends CustomPainter {
  _WrapPainter({
    required this.zone,
    required this.fill,
    required this.hit,
    required this.wrapFraction,
  });

  final WrapZone zone;
  final double fill;
  final bool? hit;
  final double wrapFraction;

  static const maxR = 110.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 - 6);
    // Outer guide.
    canvas.drawCircle(
      c,
      maxR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBorder.thin
        ..color = AppColors.surfaceBorder,
    );
    // Green zone ring.
    final inner = zone.start * maxR;
    final outer = zone.end * maxR;
    canvas.drawCircle(
      c,
      (inner + outer) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - inner
        ..color = AppColors.secondarySoft,
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppBorder.thin
      ..color = AppColors.secondaryBase;
    canvas.drawCircle(c, inner, edge);
    canvas.drawCircle(c, outer, edge);
    // Growing circle.
    final r = fill * maxR;
    if (r > 0) {
      canvas.drawCircle(
        c,
        r,
        Paint()..color = AppColors.primarySoft.withValues(alpha: 0.8),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppBorder.thick
          ..color = AppColors.primaryBase,
      );
    }
    // Bouquet symbol in the middle.
    paintFlower(canvas, c, 18, 'rose');
    // Hearts on a hit.
    if (hit == true) {
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.5;
        final d = 40 + wrapFraction * 50;
        _heart(canvas, c + Offset(math.cos(a), math.sin(a)) * d, 9);
      }
    }
    // Wrap progress after release.
    if (wrapFraction > 0) {
      final rect = Rect.fromLTWH(c.dx - 60, size.height - 14, 120, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = AppColors.freshnessTrack,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left, rect.top, rect.width * wrapFraction, 6),
          const Radius.circular(3),
        ),
        Paint()..color = AppColors.secondaryBase,
      );
    }
  }

  void _heart(Canvas canvas, Offset c, double s) {
    final p = Path()
      ..moveTo(c.dx, c.dy + s * 0.8)
      ..cubicTo(c.dx - s * 1.4, c.dy - s * 0.2, c.dx - s * 0.6, c.dy - s * 1.2,
          c.dx, c.dy - s * 0.4)
      ..cubicTo(c.dx + s * 0.6, c.dy - s * 1.2, c.dx + s * 1.4, c.dy - s * 0.2,
          c.dx, c.dy + s * 0.8)
      ..close();
    canvas.drawPath(p, Paint()..color = AppColors.primaryBase);
  }

  @override
  bool shouldRepaint(_WrapPainter old) => true;
}
