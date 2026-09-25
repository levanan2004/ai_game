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
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
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

  /// Standing line on the wooden floor (bottom of the customer row).
  static const _floorY = 272.0;
  static const _bodyW = 64.0;
  static const _bodyH = 120.0;

  /// Transparent padding under the shoes in the 256×480 sprite (feet at y 465).
  static const _footInset = 15 / 480 * _bodyH;

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
      _x[c.id] = (x - target).abs() <= step
          ? target
          : x + (target > x ? step : -step);
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
    // Flat counter only until shop_bg.png has loaded (the picture has one).
    if (_shopBgImage == null) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 276, 360, 24),
        Paint()..color = MockPalette.counterTop,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 276, 360, 4),
        Paint()..color = MockPalette.shelfWood,
      );
    }
    canvas.restore();
  }

  /// Wall, window and counter: from under the awning (y 64) to the goals
  /// card (y 312). `BoxFit.cover`, anchored to the bottom.
  static const _shopBg = Rect.fromLTWH(0, 64, 360, 248);

  ui.Image? get _shopBgImage => _art(Art.scene('shop_bg'));

  void _drawCoverBottom(Canvas c, ui.Image img, Rect dst) {
    final srcW = img.width.toDouble();
    final srcH = img.height.toDouble();
    final scale = math.max(dst.width / srcW, dst.height / srcH);
    final sw = dst.width / scale;
    final sh = dst.height / scale;
    final src = Rect.fromLTWH((srcW - sw) / 2, srcH - sh, sw, sh);
    c.drawImageRect(img, src, dst, _imagePaint);
  }

  void _drawBackground(Canvas c) {
    final img = _shopBgImage;
    if (img != null) {
      _drawCoverBottom(c, img, _shopBg);
    } else {
      c.drawRect(
        const Rect.fromLTWH(0, 64, 360, 212),
        Paint()..color = AppColors.bgShop,
      );
    }
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
    c.drawRect(
      const Rect.fromLTWH(12, 142, 336, 8),
      Paint()..color = MockPalette.shelfWood,
    );
    final flowers = session.unlockedFlowers.take(5).toList();
    for (var i = 0; i < flowers.length; i++) {
      final f = flowers[i];
      final x = 28.0 + i * 64;
      final n = session.stockCount(f.id);
      final empty = n <= 0;
      if (!empty) {
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
          for (final (dx, dy) in const [
            (-10.0, -6.0),
            (10.0, -6.0),
            (0.0, -16.0),
          ]) {
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
      c.drawPath(
        bucket,
        Paint()
          ..color = empty
              ? MockPalette.bucket.withValues(alpha: 0.4)
              : MockPalette.bucket,
      );
      if (empty) {
        _drawText(
          c,
          'Hết',
          AppText.caption(color: AppColors.textSecondary),
          Offset(x + 22, 162),
        );
      } else {
        final fr = session.freshnessFraction(f.id);
        _bar(c, Rect.fromLTWH(x + 4, 154, 36, 4), fr, freshnessColor(fr));
      }
    }
  }

  void _bar(Canvas c, Rect r, double f, Color color) {
    final radius = Radius.circular(r.height / 2);
    c.drawRRect(
      RRect.fromRectAndRadius(r, radius),
      Paint()..color = AppColors.freshnessTrack,
    );
    if (f > 0) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            r.left,
            r.top,
            math.max(r.height, r.width * f.clamp(0, 1)),
            r.height,
          ),
          radius,
        ),
        Paint()..color = color,
      );
    }
  }

  /// Top of the 64×120 sprite so the shoes land on [_floorY].
  double get _bodyTop => _floorY - _bodyH + _footInset;

  void _drawFootShadow(Canvas c, double x) {
    c.drawOval(
      Rect.fromCenter(center: Offset(x, _floorY + 2), width: 46, height: 12),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawCustomer(Canvas c, Customer cu, double cx, {double shake = 0}) {
    final x = cx + shake;
    _drawFootShadow(c, x);
    final img = cu.avatarId.isEmpty
        ? null
        : _art(Art.customerFull(cu.avatarId));
    if (img != null) {
      _drawArt(c, img, Rect.fromLTWH(x - _bodyW / 2, _bodyTop, _bodyW, _bodyH));
      return;
    }
    final fill = Paint()..color = avatarColor(cu.name.hashCode);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppBorder.thin
      ..color = AppColors.surfaceBorderStrong;
    final body = RRect.fromLTRBR(
      x - 22,
      _floorY - 40,
      x + 22,
      _floorY - 10,
      const Radius.circular(12),
    );
    c.drawRRect(body, fill);
    c.drawRRect(body, line);
    c.drawCircle(Offset(x, _floorY - 58), 18, fill);
    c.drawCircle(Offset(x, _floorY - 58), 18, line);
    final parts = cu.name.split(' ');
    final style = AppText.title(size: 10, weight: 800);
    if (parts.length >= 2) {
      _drawText(c, parts.first, style, Offset(x, _floorY - 64));
      _drawText(c, parts.sublist(1).join(' '), style, Offset(x, _floorY - 52));
    } else {
      _drawText(c, cu.name, style, Offset(x, _floorY - 58));
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
      final shake = f < warn && (_time % 2) < 0.4
          ? math.sin(_time * 40) * 2
          : 0.0;
      _drawCustomer(c, cu, x, shake: shake);
      _bar(
        c,
        Rect.fromLTWH(x - 18, _floorY + 6, 36, 4),
        f,
        patienceColor(f, warn),
      );
    }
    final first = session.nextForPlayer;
    if (first != null && session.tableCustomer == null) {
      final x = _x[first.id];
      if (x != null &&
          (x - _slotX[visible.indexOf(first).clamp(0, 2)]).abs() < 1) {
        _drawRequestBubble(c, first, x);
      }
    }
    final extra = session.queue.length - _maxVisible;
    if (extra > 0) {
      _drawText(
        c,
        '+$extra',
        AppText.number(size: 16, color: AppColors.textSecondary),
        const Offset(330, 232),
      );
    }
  }

  /// Occasion chip plus the flower name (always in full, up to 2 lines of
  /// caption 11). Paper and ribbon share the leftover line and are the only
  /// part that may be cut. Bubble width is at most 240.
  void _drawRequestBubble(Canvas c, Customer cu, double x) {
    final e = session.e;
    final occ = e.occasion(cu.request.occasionId);
    final main = cu.request.mainSpecies;
    final flowerLine = '${cu.request.stems[main]} ${e.flower(main).nameVi}';
    final extra =
        '${e.paper(cu.request.paperId).nameVi} · ${e.ribbon(cu.request.ribbonId).nameVi}';
    final chipStyle = AppText.caption(
      size: 8,
      weight: 800,
      color: AppColors.onOccasion(occ.id),
    );
    final textStyle = AppText.caption(
      size: 11,
      weight: 800,
      color: AppColors.textPrimary,
    );
    final chip = TextPainter(
      text: TextSpan(text: occ.nameVi, style: chipStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final chipW = chip.width + 14;
    const maxBubble = 240.0;
    final textMax = math.max(40.0, maxBubble - 6 - chipW - 6 - 10);
    final flower = TextPainter(
      text: TextSpan(text: flowerLine, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: textMax);
    final oneLine = TextPainter(
      text: TextSpan(text: 'A', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final flowerTakesTwo = flower.height > oneLine.height * 1.5;
    TextPainter? extraLine;
    if (!flowerTakesTwo) {
      extraLine = TextPainter(
        text: TextSpan(text: extra, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: textMax);
    }
    final textW = math.max(flower.width, extraLine?.width ?? 0);
    final textH = flower.height + (extraLine?.height ?? 0);
    final w = math.min(maxBubble, 6 + chipW + 6 + textW + 10);
    final h = math.max(24.0, textH + 10);
    final left = x + 26;
    final bottom = _bodyTop + 36;
    final top = bottom - h;
    final bubble = RRect.fromLTRBR(
      left,
      top,
      left + w,
      bottom,
      const Radius.circular(12),
    );
    c.drawRRect(bubble, Paint()..color = AppColors.surfaceCard);
    c.drawRRect(
      bubble,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBorder.thin
        ..color = AppColors.surfaceBorder,
    );
    final tail = Path()
      ..moveTo(left + 4, bottom - 2)
      ..lineTo(left + 16, bottom - 2)
      ..lineTo(left - 4, bottom + 8)
      ..close();
    c.drawPath(tail, Paint()..color = AppColors.surfaceCard);
    final chipTop = top + (h - 14) / 2;
    final chipRect = RRect.fromLTRBR(
      left + 6,
      chipTop,
      left + 6 + chipW,
      chipTop + 14,
      const Radius.circular(7),
    );
    c.drawRRect(chipRect, Paint()..color = AppColors.occasion(occ.id));
    chip.paint(c, chipRect.center - Offset(chip.width / 2, chip.height / 2));
    var ty = top + (h - textH) / 2;
    flower.paint(c, Offset(left + 12 + chipW, ty));
    ty += flower.height;
    extraLine?.paint(c, Offset(left + 12 + chipW, ty));
  }

  void _drawDepartures(Canvas c) {
    for (final d in session.departures) {
      final x = _x[d.customer.id] ?? _slotX[0];
      if (x < -40) continue;
      final shake = d.age < 0.4 ? math.sin(d.age * 50) * 3 : 0.0;
      _drawCustomer(c, d.customer, x, shake: shake);
      if (d.age <= ShopSession.departureSeconds) {
        // Angry bubble with the stars left.
        final r = RRect.fromLTRBR(
          x - 4,
          _bodyTop - 8,
          x + 52,
          _bodyTop + 16,
          const Radius.circular(12),
        );
        c.drawRRect(r, Paint()..color = AppColors.surfaceCard);
        c.drawRRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppBorder.thin
            ..color = AppColors.surfaceBorder,
        );
        paintAngryFace(c, Offset(x + 8, _bodyTop + 4), 7);
        c.drawPath(
          starPath(Offset(x + 25, _bodyTop + 4), 6),
          Paint()..color = AppColors.currencyStar,
        );
        _drawText(
          c,
          '${d.stars}',
          AppText.number(size: 12),
          Offset(x + 40, _bodyTop + 4),
        );
      }
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    // The bouquet table sits on top of this scene. Ignore taps unless the
    // shop screen is actually showing, so a tab tap cannot open another
    // customer.
    if (session.screen != Screen.shop || session.tableCustomer != null) {
      return;
    }
    final p = event.localPosition.toOffset() + const Offset(0, 48);
    final first = session.nextForPlayer;
    if (first == null) return;
    final x = _x[first.id];
    if (x == null) return;
    if ((p.dx - x).abs() <= _bodyW / 2 &&
        p.dy >= _bodyTop &&
        p.dy <= _floorY + 8) {
      session.openTable();
    }
  }
}
