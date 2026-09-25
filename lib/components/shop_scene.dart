import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../logic/shop_session.dart';
import '../theme/mock_palette.dart';
import '../theme/tokens.dart';
import '../ui/art.dart';
import '../ui/paint.dart';

/// Shop scene of the main screen (spec_tiem_chinh.md, y 48 to 300): awning,
/// shelf with flower buckets, customer queue with patience bars, counter.
/// Reads [ShopSession] every frame; tapping the first customer opens the
/// bouquet table.
class ShopScene extends PositionComponent with TapCallbacks {
  ShopScene(this.session, this.images)
    : super(position: Vector2(0, 48), size: Vector2(360, 252));

  final ShopSession session;

  /// Flame image cache (prefix assets/images/), filled by ShopGame.
  final Images images;

  /// Cached art image, or null while loading / missing.
  ui.Image? _art(String path) {
    final key = Art.forFlame(path);
    return images.containsKey(key) ? images.fromCache(key) : null;
  }

  static final _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  void _drawArt(Canvas c, ui.Image img, Rect dst, {double opacity = 1}) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final paint = opacity >= 1
        ? _imagePaint
        : (Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(0, 0, 0, opacity));
    c.drawImageRect(img, src, dst, paint);
  }

  /// Visual x position per customer id (slides towards its slot).
  final Map<int, double> _x = {};
  double _time = 0;

  static const _slotX = [70.0, 146.0, 222.0];
  static const _maxVisible = 3;

  // Coordinates below are in frame space; the component sits at y 48.
  static const _dy = -48.0;

  final Map<String, TextPainter> _textCache = {};

  TextPainter _text(String s, TextStyle style) {
    final key = '$s|${style.fontSize}|${style.color}|${style.fontFamily}';
    return _textCache.putIfAbsent(key, () {
      if (_textCache.length > 200) _textCache.clear();
      return TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 200);
    });
  }

  void _drawText(Canvas c, String s, TextStyle style, Offset center) {
    final tp = _text(s, style);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final visible = session.queue.take(_maxVisible).toList();
    for (var i = 0; i < visible.length; i++) {
      final c = visible[i];
      final target = _slotX[i];
      final x = _x[c.id];
      if (x == null) {
        _x[c.id] = 380;
        continue;
      }
      // Walk in from the right over walkInSeconds, then slide between slots.
      final speed = (380 - _slotX[0]) / math.max(0.3, session.e.walkInSeconds);
      final step = speed * dt;
      _x[c.id] = (x - target).abs() <= step ? target : x + (target > x ? step : -step);
    }
    final ids = {for (final c in session.queue) c.id};
    final departing = {for (final d in session.departures) d.customer.id};
    _x.removeWhere((id, _) => !ids.contains(id) && !departing.contains(id));
    for (final d in session.departures) {
      if (d.age > ShopSession.departureSeconds) {
        final x = _x[d.customer.id] ?? _slotX[0];
        _x[d.customer.id] = x - 420 * dt;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(0, _dy);
    _drawBackground(canvas);
    _drawShelf(canvas);
    _drawQueue(canvas);
    _drawDepartures(canvas);
    // Counter.
    canvas.drawRect(const Rect.fromLTWH(0, 276, 360, 24), Paint()..color = MockPalette.counterTop);
    canvas.drawRect(const Rect.fromLTWH(0, 276, 360, 4), Paint()..color = MockPalette.shelfWood);
    canvas.restore();
  }

  void _drawBackground(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 64, 360, 212), Paint()..color = AppColors.bgShop);
    final pink = Paint()..color = AppColors.primaryBase;
    final white = Paint()..color = AppColors.surfaceCard;
    for (var x = 0.0; x < 360; x += 24) {
      c.drawRect(Rect.fromLTWH(x, 48, 12, 10), pink);
      c.drawRect(Rect.fromLTWH(x + 12, 48, 12, 10), white);
      // Scalloped lower edge.
      c.drawArc(Rect.fromLTWH(x, 52, 12, 12), 0, math.pi, true, pink);
      c.drawArc(Rect.fromLTWH(x + 12, 52, 12, 12), 0, math.pi, true, white);
    }
  }

  void _drawShelf(Canvas c) {
    c.drawRect(const Rect.fromLTWH(12, 142, 336, 8), Paint()..color = MockPalette.shelfWood);
    final flowers = session.unlockedFlowers.take(5).toList();
    for (var i = 0; i < flowers.length; i++) {
      final f = flowers[i];
      final x = 28.0 + i * 64;
      final n = session.stockCount(f.id);
      if (n > 0) {
        final droop = session.isWilting(f.id) ? 4.0 : 0.0;
        final img = _art(Art.flower(f.id));
        if (img != null) {
          // Three stems standing in the bucket (bucket drawn on top).
          for (final (dx, dy) in const [(-9.0, 0.0), (9.0, 0.0), (0.0, -8.0)]) {
            final cx = x + 22 + dx;
            final top = 80 + dy + droop;
            _drawArt(c, img, Rect.fromLTWH(cx - 17, top, 34, 34));
          }
        } else {
          for (final (dx, dy) in const [(-10.0, -6.0), (10.0, -6.0), (0.0, -16.0)]) {
            paintFlower(c, Offset(x + 22 + dx, 104 + dy + droop), 11, f.id);
          }
        }
      }
      final bucket = Path()
        ..moveTo(x + 6, 112)
        ..lineTo(x + 38, 112)
        ..lineTo(x + 34, 142)
        ..lineTo(x + 10, 142)
        ..close();
      c.drawPath(bucket, Paint()..color = MockPalette.bucket);
      final fr = session.freshnessFraction(f.id);
      _bar(c, Rect.fromLTWH(x + 4, 154, 36, 4), fr, freshnessColor(fr));
    }
  }

  void _bar(Canvas c, Rect r, double f, Color color) {
    final radius = Radius.circular(r.height / 2);
    c.drawRRect(RRect.fromRectAndRadius(r, radius), Paint()..color = AppColors.freshnessTrack);
    if (f > 0) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left, r.top, math.max(r.height, r.width * f.clamp(0, 1)), r.height),
          radius,
        ),
        Paint()..color = color,
      );
    }
  }

  void _drawCustomer(Canvas c, Customer cu, double cx, {double shake = 0}) {
    final x = cx + shake;
    final img = cu.avatarId.isEmpty ? null : _art(Art.customer(cu.avatarId));
    if (img != null) {
      // Half-body avatar, 68 px (assets README: queue avatar ~72 px).
      _drawArt(c, img, Rect.fromCenter(center: Offset(x, 228), width: 68, height: 68));
      return;
    }
    final fill = Paint()..color = avatarColor(cu.name.hashCode);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppBorder.thin
      ..color = AppColors.surfaceBorderStrong;
    final body = RRect.fromLTRBR(x - 22, 232, x + 22, 262, const Radius.circular(12));
    c.drawRRect(body, fill);
    c.drawRRect(body, line);
    c.drawCircle(Offset(x, 214), 18, fill);
    c.drawCircle(Offset(x, 214), 18, line);
    final parts = cu.name.split(' ');
    final style = AppText.title(size: 10, weight: 800);
    if (parts.length >= 2) {
      _drawText(c, parts.first, style, Offset(x, 208));
      _drawText(c, parts.sublist(1).join(' '), style, Offset(x, 220));
    } else {
      _drawText(c, cu.name, style, Offset(x, 214));
    }
  }

  void _drawQueue(Canvas c) {
    final visible = session.queue.take(_maxVisible).toList();
    final warn = session.e.patienceWarningAt;
    for (var i = visible.length - 1; i >= 0; i--) {
      final cu = visible[i];
      final x = _x[cu.id] ?? 380;
      final f = cu.patienceFraction;
      // Shake every 2 s when patience is low.
      final shake = f < warn && (_time % 2) < 0.4 ? math.sin(_time * 40) * 2 : 0.0;
      _drawCustomer(c, cu, x, shake: shake);
      _bar(c, Rect.fromLTWH(x - 18, 268, 36, 4), f, patienceColor(f, warn));
    }
    final first = session.nextForPlayer;
    if (first != null && session.tableCustomer == null) {
      final x = _x[first.id];
      if (x != null && (x - _slotX[visible.indexOf(first).clamp(0, 2)]).abs() < 1) {
        _drawRequestBubble(c, first, x);
      }
    }
    final extra = session.queue.length - _maxVisible;
    if (extra > 0) {
      _drawText(c, '+$extra', AppText.number(size: 16, color: AppColors.textSecondary), const Offset(330, 232));
    }
  }

  void _drawRequestBubble(Canvas c, Customer cu, double x) {
    final e = session.e;
    final occ = e.occasion(cu.request.occasionId);
    final main = cu.request.mainSpecies;
    final label = '${cu.request.stems[main]} ${e.flower(main).nameVi}…';
    final chipStyle = AppText.caption(size: 8, weight: 800, color: AppColors.onOccasion(occ.id));
    final textStyle = AppText.caption(size: 10, weight: 800, color: AppColors.textPrimary);
    final chip = _text(occ.nameVi, chipStyle);
    final txt = _text(label, textStyle);
    final chipW = chip.width + 14;
    final w = 6 + chipW + 6 + txt.width + 10;
    final left = x + 26;
    final bubble = RRect.fromLTRBR(left, 168, left + w, 192, const Radius.circular(12));
    c.drawRRect(bubble, Paint()..color = AppColors.surfaceCard);
    c.drawRRect(
      bubble,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBorder.thin
        ..color = AppColors.surfaceBorder,
    );
    final tail = Path()
      ..moveTo(left + 4, 190)
      ..lineTo(left + 16, 190)
      ..lineTo(left - 4, 200)
      ..close();
    c.drawPath(tail, Paint()..color = AppColors.surfaceCard);
    final chipRect = RRect.fromLTRBR(left + 6, 173, left + 6 + chipW, 187, const Radius.circular(7));
    c.drawRRect(chipRect, Paint()..color = AppColors.occasion(occ.id));
    _drawText(c, occ.nameVi, chipStyle, chipRect.center);
    txt.paint(c, Offset(left + 12 + chipW, 180 - txt.height / 2));
  }

  void _drawDepartures(Canvas c) {
    for (final d in session.departures) {
      final x = _x[d.customer.id] ?? _slotX[0];
      if (x < -40) continue;
      final shake = d.age < 0.4 ? math.sin(d.age * 50) * 3 : 0.0;
      _drawCustomer(c, d.customer, x, shake: shake);
      if (d.age <= ShopSession.departureSeconds) {
        // Angry bubble with the stars left.
        final r = RRect.fromLTRBR(x - 4, 166, x + 52, 190, const Radius.circular(12));
        c.drawRRect(r, Paint()..color = AppColors.surfaceCard);
        c.drawRRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppBorder.thin
            ..color = AppColors.surfaceBorder,
        );
        paintAngryFace(c, Offset(x + 8, 178), 7);
        c.drawPath(starPath(Offset(x + 25, 178), 6), Paint()..color = AppColors.currencyStar);
        _drawText(c, '${d.stars}', AppText.number(size: 12), Offset(x + 40, 178));
      }
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    final p = event.localPosition.toOffset() + const Offset(0, 48);
    final first = session.nextForPlayer;
    if (first == null) return;
    final x = _x[first.id];
    if (x == null) return;
    if ((p.dx - x).abs() <= 26 && p.dy >= 192 && p.dy <= 276) {
      session.openTable();
    }
  }
}
