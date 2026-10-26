import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/painting.dart';

import '../logic/pot_slots.dart';
import '../logic/shop_session.dart';
import '../logic/shop_shelf.dart';
import '../save/game_state.dart';
import '../theme/mock_palette.dart';
import '../theme/tokens.dart';
import '../ui/art.dart';
import '../ui/main_shop_overlay.dart'
    show notebookButtonLeft, notebookButtonTop;
import '../ui/paint.dart';

/// Shop scene of the main screen: wall from y 44, shelf with flower buckets,
/// chalkboard in a floor corner (words drawn here, not baked into the
/// picture), customer queue with code-drawn floor shadows, counter.
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

  /// Worn skin picture for a shop slot, or null while loading / missing.
  ui.Image? _skin(String slot) {
    final asset = session.skinAsset(slot);
    return asset.isEmpty ? null : _art(asset);
  }

  Set<String>? _wiltedFlowerIds;

  bool _hasWiltedArt(String id) {
    final ids = _wiltedFlowerIds ??= {
      for (final f in session.e.flowers)
        if (f.wiltedArt) f.id,
    };
    return ids.contains(id);
  }

  /// Picture of a flower on the bar: the wilted one while its oldest batch is
  /// about to be thrown away, if the flower has one, else the fresh one.
  ui.Image? _flowerArt(String id, {required bool wilting}) {
    if (wilting && _hasWiltedArt(id)) {
      final w = _art(Art.flowerWilted(id));
      if (w != null) return w;
    }
    return _art(Art.flower(id));
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

  /// This batch's full-body sprites leave 2px under the shoes in the
  /// 256×480 frame. Older sprites still have more padding, so they sit a
  /// little high until the next batch.
  static const _footInset = 2 / 480 * _bodyH;

  // Coordinates below are in frame space; the component sits at y 48.
  static const _dy = -48.0;

  final Map<String, TextPainter> _textCache = {};
  String? _bubbleKey;
  TextPainter? _bubbleChip;
  TextPainter? _bubbleFlower;
  TextPainter? _bubbleExtra;
  TextPainter? _bubbleOneLine;
  double _bubbleChipW = 0;
  double _bubbleTextW = 0;
  double _bubbleTextH = 0;

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
    _drawHoliday(canvas);
    _drawShopSign(canvas);
    _drawWallDecor(canvas);
    _drawFloorDecor(canvas);
    _drawShelf(canvas);
    _drawChalkboard(canvas);
    _drawQueue(canvas);
    _drawDepartures(canvas);
    _drawCounter(canvas);
    _drawStaffBubbles(canvas);
    canvas.restore();
  }

  /// Counter strip, flush with the scene bottom (y 312, where the goals
  /// card starts; An 26/10, fix 10 task 3) so the clock row and the pet
  /// stand on it. The flat colour block is only the fallback for when
  /// neither the strip nor the shop background has loaded.
  static const _counterRect = Rect.fromLTWH(0, 288, 360, 24);

  void _drawCounter(Canvas c) {
    // Skin strips are 1080×72 (3×): tassels and lanterns hang inside the
    // same strip, below the ~12px wood top.
    final counter = _skin('quay') ?? _art(Art.scene('mat_quay'));
    if (counter != null) {
      _drawArt(c, counter, _counterRect);
    } else if (_shopBgImage == null) {
      c.drawRect(_counterRect, Paint()..color = MockPalette.counterTop);
      c.drawRect(
        Rect.fromLTWH(
          _counterRect.left,
          _counterRect.top,
          _counterRect.width,
          4,
        ),
        Paint()..color = MockPalette.shelfWood,
      );
    }
  }

  /// Clock and picture frame on the wall, right of the shop-name board.
  /// Sizes are a quarter of the files (96 and 96×112).
  static const _clock = Rect.fromLTWH(304, 50, 24, 24);
  static const _frame = Rect.fromLTWH(332, 48, 24, 28);

  void _drawWallDecor(Canvas c) {
    final clock = _art(Art.nav('dong_ho'));
    if (clock != null) _drawArt(c, clock, _clock);
    final frame = _art(Art.scene('khung_tranh'));
    if (frame != null) _drawArt(c, frame, _frame);
  }

  /// Bench behind the queue, plants in the floor corners behind the counter.
  void _drawFloorDecor(Canvas c) {
    final bench = _art(Art.scene('ghe_cho'));
    if (bench != null) {
      // 256×112, sitting on the standing line, centred at x 180 (Phu 26/10).
      _drawArt(c, bench, const Rect.fromLTWH(125, _floorY - 40, 110, 40));
    }
    final left = _art(Art.scene('chau_cay_1'));
    if (left != null) {
      // 128×176. Base shares the counter's floor line, so the counter
      // covers the pot.
      _drawArt(c, left, Rect.fromLTWH(0, _counterRect.bottom - 70, 51, 70));
    }
    final right = _art(Art.scene('chau_cay_2'));
    if (right != null) {
      // 128×160. Taller than the board so the leaves show above it
      // in the right corner; the board stands in front.
      _drawArt(c, right, Rect.fromLTWH(284, _counterRect.bottom - 96, 76, 96));
    }
  }

  /// Wooden name board hung on the awning (spec_popup_va_mo_dau.md §7).
  void _drawShopSign(Canvas canvas) {
    final name = session.state.shopName;
    if (name == null || name.isEmpty) return;
    final text = shopSignText(name);
    final width = (text.width + _signFlowerRoom).clamp(160.0, _signMaxWidth);
    final left = (360 - width) / 2;
    // Just under the 56px header so the board is not sliced by it.
    const top = 60.0;
    final board = _skin('bienHieu');
    if (board != null) {
      _drawSignSlices(canvas, board, Rect.fromLTWH(left, top, width, 28));
    } else {
      final outer = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, 28),
        const Radius.circular(6),
      );
      canvas.drawRRect(outer, Paint()..color = AppColors.templeWood);
      canvas.drawRRect(outer.deflate(3), Paint()..color = AppColors.templeText);
      canvas.drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.templeWoodDark,
      );
    }
    text.paint(
      canvas,
      Offset(left + (width - text.width) / 2, top + (28 - text.height) / 2),
    );
    for (final (id, x) in [
      ('rose', left + 4.0),
      ('daisy', left + width - 20),
    ]) {
      final img = _art(Art.flower(id));
      if (img != null) {
        _drawArt(canvas, img, Rect.fromLTWH(x, top + 6, 16, 16));
      }
    }
  }

  /// Signboard skins are 552×84: each end cap is ~36% of the width and
  /// keeps its shape; only the plain middle stretches (Phú).
  void _drawSignSlices(Canvas c, ui.Image img, Rect dst) {
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    final cap = w * 0.36;
    final dstCap = math.min(cap * dst.height / h, dst.width / 2);
    final parts = [
      (Rect.fromLTWH(0, 0, cap, h), dst.left, dstCap),
      (
        Rect.fromLTWH(cap, 0, w - 2 * cap, h),
        dst.left + dstCap,
        dst.width - 2 * dstCap,
      ),
      (Rect.fromLTWH(w - cap, 0, cap, h), dst.right - dstCap, dstCap),
    ];
    for (final (src, x, dw) in parts) {
      if (dw <= 0) continue;
      c.drawImageRect(
        img,
        src,
        Rect.fromLTWH(x, dst.top, dw, dst.height),
        _imagePaint,
      );
    }
  }

  /// Wall, window and counter: tucks under the header (y 44) to the goals
  /// card (y 312). `BoxFit.cover`, anchored to the bottom.
  static const _shopBg = Rect.fromLTWH(0, 44, 360, 268);

  ui.Image? get _shopBgImage => _art(Art.scene('shop_bg'));

  void _drawCoverBottom(Canvas c, ui.Image img, Rect dst) {
    final srcW = img.width.toDouble();
    final srcH = img.height.toDouble();
    final scale = math.max(dst.width / srcW, dst.height / srcH);
    final sw = dst.width / scale;
    final sh = dst.height / scale;
    // Left-anchored (An 26/10): the cabinet painted at the left edge stays
    // whole; the extra width is cropped on the right.
    final src = Rect.fromLTWH(0, srcH - sh, sw, sh);
    c.drawImageRect(img, src, dst, _imagePaint);
  }

  /// Holiday pictures, only on that holiday. Display size is a quarter of
  /// the file (the plan's 120×40 garland, 40×40 counter pieces, 40×56
  /// lanterns, 48×64 apricot pot).
  void _drawHoliday(Canvas c) {
    final id = session.holidayToday?.id;
    switch (id) {
      case 'valentine':
        _drawScene(c, 'le_valentine', const Rect.fromLTWH(120, 48, 120, 40));
      case 'women_0803':
      case 'women_2010':
        _drawScene(c, 'le_phu_nu', const Rect.fromLTWH(120, 48, 120, 40));
      case 'teacher_2011':
        _drawScene(c, 'le_nha_giao', const Rect.fromLTWH(262, 236, 40, 40));
      case 'tet':
        _drawScene(c, 'le_tet_den_long', const Rect.fromLTWH(312, 46, 40, 56));
        _drawScene(c, 'le_tet_li_xi', const Rect.fromLTWH(316, 170, 40, 40));
        _drawScene(c, 'le_tet_mai', const Rect.fromLTWH(258, 208, 48, 64));
    }
  }

  void _drawScene(Canvas c, String id, Rect dst) {
    final img = _art(Art.scene(id));
    if (img != null) _drawArt(c, img, dst);
  }

  void _drawBackground(Canvas c) {
    final img = _skin('nenManHinh') ?? _shopBgImage;
    if (img != null) {
      _drawCoverBottom(c, img, _shopBg);
    } else {
      c.drawRect(_shopBg, Paint()..color = AppColors.bgShop);
    }
  }

  /// Long wooden plank (display 336×20) with up to five buckets. Flowers
  /// in stock take the slots first, so a newly bought species is visible
  /// instead of an empty early flower. The painted shop background also has
  /// a standing shelf on the left; that overlap stays until a clearer
  /// background arrives.
  void _drawShelf(Canvas c) {
    final plank = _art(Art.scene('ke_hoa'));
    if (plank != null) {
      // The plank starts right after the painted window (An 26/10).
      final left = barShelfLeft(_shelfSkin);
      _drawArt(c, plank, Rect.fromLTRB(left, 132, barShelfRight, 152));
    } else {
      c.drawRect(
        Rect.fromLTRB(barShelfLeft(_shelfSkin), 142, barShelfRight, 150),
        Paint()..color = MockPalette.shelfWood,
      );
    }
    final owned = session.unlockedFlowers;
    final counts = <String, int>{};
    final freshLeft = <String, int>{};
    for (final b in session.state.stock) {
      counts[b.flowerId] = (counts[b.flowerId] ?? 0) + b.count;
      if (b.count <= 0) continue;
      final prev = freshLeft[b.flowerId];
      if (prev == null || b.freshnessLeft < prev) {
        freshLeft[b.flowerId] = b.freshnessLeft;
      }
    }
    int countOf(String id) => counts[id] ?? 0;
    final flowers = [
      for (final f in owned)
        if (countOf(f.id) > 0) f,
      for (final f in owned)
        if (countOf(f.id) == 0) f,
    ].take(barPotSlots).toList();
    // Free bar slots (Phu 26/10): the next kinds of the flower list not
    // owned yet, flowers at 50% with a 16 dp lock, no label.
    final locked = [
      for (final f in session.e.flowers)
        if (!owned.contains(f)) f,
    ].take(barPotSlots - flowers.length).toList();
    for (var i = 0; i < barPotSlots; i++) {
      final f = i < flowers.length ? flowers[i] : null;
      final k = i - flowers.length;
      final g = f ?? (k >= 0 && k < locked.length ? locked[k] : null);
      final x = barSlotX(i, _shelfSkin);
      final n = f == null ? 0 : countOf(f.id);
      final empty = f == null || n <= 0;
      final wilting = f != null && (freshLeft[f.id] ?? 9) <= 1;
      final potId = session.state.barPots[i];
      final custom = _art(Art.pot(potId));
      // Flowers first, their stems sunk 20% of the pot's height below the
      // mouth (Phu 26/10); the pot drawn over them hides the stems.
      final potDst = custom != null
          ? _potRect(barPotRect(i, _shelfSkin), potId)
          : Rect.fromLTWH(x + 2, 110, 40, 32);
      if (g != null) {
        final img = _flowerArt(g.id, wilting: wilting);
        final size = custom != null ? 22.0 : 34.0;
        if (img != null) {
          _stems(
            c,
            img,
            potDst,
            size,
            mouth: custom != null ? 0 : _xoMouth,
            droop: wilting ? 4 : 0,
            opacity: empty ? 0.5 : 1,
          );
        } else {
          for (final (dx, dy) in const [
            (-10.0, -6.0),
            (10.0, -6.0),
            (0.0, -16.0),
          ]) {
            paintFlower(c, Offset(x + 22 + dx, 104 + dy), 11, g.id);
          }
        }
      }
      if (custom != null) _drawArt(c, custom, potDst);
      if (custom == null) {
        final bucket = _art(Art.scene('xo_hoa'));
        const bucketRect = Size(40, 32);
        final bucketDst = Rect.fromLTWH(
          x + 2,
          110,
          bucketRect.width,
          bucketRect.height,
        );
        if (bucket != null) {
          _drawArt(c, bucket, bucketDst);
          if (potId != defaultPotId) {
            _potMark(c, bucketDst, potId);
          }
        } else {
          final path = Path()
            ..moveTo(x + 6, 112)
            ..lineTo(x + 38, 112)
            ..lineTo(x + 34, 142)
            ..lineTo(x + 10, 142)
            ..close();
          c.drawPath(
            path,
            Paint()
              ..color = empty
                  ? MockPalette.bucket.withValues(alpha: 0.4)
                  : MockPalette.bucket,
          );
        }
      }
      if (f == null && g != null) {
        _lock(c, Offset(potDst.right - 16, potDst.bottom - 16));
      }
      if (f != null && empty) {
        _drawPill(
          c,
          'Hết',
          AppText.caption(color: AppColors.textSecondary),
          Offset(x + 22, 134),
        );
      } else if (f != null) {
        final left = freshLeft[f.id];
        final fr = left == null
            ? 0.0
            : (left / session.fullFreshness(f)).clamp(0.0, 1.0);
        // Under the pot (Phu 26/10): 4 dp below, 80% of its width, 4 tall.
        final w = potDst.width * 0.8;
        _bar(
          c,
          Rect.fromLTWH(potDst.center.dx - w / 2, potDst.bottom + 4, w, 4),
          fr,
          freshnessColor(fr),
        );
      }
    }
    // Ke 6 chau (round 8): the worn background's own shelf, flush left.
    final shelf = _art(ke6ChauAsset(_shelfSkin));
    if (shelf != null) _drawArt(c, shelf, ke6ChauRect(_shelfSkin));
    final displayPots = ke6ChauPotRects(_shelfSkin);
    // Cabinet flowers (Phu 26/10): decoration only, the first 6 kinds of
    // the flower list, one per pot; no freshness bar, label or number.
    // The flower is about 70% of the pot's height and rises over its rim.
    for (var i = 0; i < displayPots.length; i++) {
      final id = session.state.displayPots[i];
      final all = session.e.flowers;
      final f = i < all.length ? all[i] : null;
      final flower = f == null ? null : _flowerArt(f.id, wilting: false);
      if (id == defaultPotId || id.isEmpty) {
        // The starting pot (Xo xanh, `scene/xo_hoa`), fully opaque, its
        // foot on the tier (An 26/10); the drawn stand-in only if missing.
        final xo = _art(Art.scene('xo_hoa'));
        if (xo != null) {
          final box = _fitBottom(xo, displayPots[i]);
          // Three stems in the bucket, its rim drawn over them.
          if (flower != null) {
            _stems(c, flower, box, box.height * 0.7, mouth: _xoMouth);
          }
          _drawArt(c, xo, box);
        } else {
          _emptyPotSlot(c, displayPots[i]);
        }
        continue;
      }
      final img = _art(Art.pot(id));
      if (img != null) {
        final potDst = _potRect(displayPots[i], id);
        if (flower != null) {
          _stems(c, flower, potDst, potDst.height * 0.7, mouth: 0);
        }
        _drawArt(c, img, potDst);
      } else {
        _potMark(c, displayPots[i], id);
      }
    }
  }

  /// Top of the bucket's mouth in `scene/xo_hoa` (y 10 of 128).
  static const _xoMouth = 10 / 128;

  /// Where the stems end in the flower pictures (ink bottom ~240 of 256).
  static const _flowerInkBottom = 0.94;

  /// Three [size] flowers whose stems end 20% of [pot]'s height below its
  /// mouth ([mouth] is the mouth's top as a fraction of the height). Draw
  /// the pot after, so it hides the stems.
  void _stems(
    Canvas c,
    ui.Image img,
    Rect pot,
    double size, {
    required double mouth,
    double droop = 0,
    double opacity = 1,
  }) {
    final bottom = pot.top + pot.height * (mouth + 0.2) + droop;
    final top = bottom - size * _flowerInkBottom;
    for (final (dx, dy) in const [(-0.2, 0.0), (0.2, 0.0), (0.0, -0.2)]) {
      _drawArt(
        c,
        img,
        Rect.fromLTWH(
          pot.center.dx + dx * pot.width - size / 2,
          top + dy * size,
          size,
          size,
        ),
        opacity: opacity,
      );
    }
  }

  /// 16 dp lock (the same icon and colour as Trang tri's locked items).
  void _lock(Canvas c, Offset topLeft) {
    const icon = Icons.lock;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 16,
          color: const Color(0xFF8A7A5A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, topLeft);
  }

  /// Small pill (caption on the freshness track colour) centred on [center].
  void _drawPill(Canvas c, String s, TextStyle style, Offset center) {
    final tp = _text(s, style);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 10,
        height: tp.height + 2,
      ),
      Radius.circular((tp.height + 2) / 2),
    );
    c.drawRRect(r, Paint()..color = AppColors.freshnessTrack);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Six buckets on the left stand. Each skin is only as tall as its own
  /// bucket, so the pot above does not cover the one below.
  /// Shelf skin of the worn background (`mac_dinh` by default).
  String get _shelfSkin => shelfSkinFor(session.skinAsset('nenManHinh'));

  /// [rect] grown by the pot's `potScale` around its bottom centre, so the
  /// foot stays where it was drawn.
  Rect _potRect(Rect rect, String id) {
    var s = 1.0;
    for (final p in session.e.pots) {
      if (p.id == id) {
        s = p.unlimited ? 1.0 : p.potScale;
        break;
      }
    }
    if (s == 1.0) return rect;
    final w = rect.width * s;
    final h = rect.height * s;
    return Rect.fromLTWH(rect.center.dx - w / 2, rect.bottom - h, w, h);
  }

  /// Stand-in stripe until the painted pot sheet is sliced in.
  void _potMark(Canvas c, Rect rect, String id) {
    final mark = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left + 6, rect.bottom - 8, rect.width - 12, 6),
      const Radius.circular(3),
    );
    c.drawRRect(mark, Paint()..color = _potSwatch(id));
  }

  Color _potSwatch(String id) => switch (id) {
    'dragon' => const Color(0xFF3F7F52),
    'phoenix' => const Color(0xFFF2A477),
    'tiger' => const Color(0xFFF5C451),
    'tortoise' => const Color(0xFF5A4038),
    'qilin' => const Color(0xFFC99A6B),
    'nghe' => const Color(0xFF8C6A5C),
    'crane' => const Color(0xFFDCEFD9),
    'koi' => const Color(0xFF74AD80),
    _ => const Color(0xFFC99A6B),
  };

  static const _emptyPotBody = Color(0xFFC97B4A);
  static const _emptyPotRim = Color(0xFFA85F35);

  /// Empty stand slot: the plain default pot, nothing planted, its foot on
  /// the plank. Tapping it opens Kho chậu; a placed pot replaces it. (No
  /// per-skin empty-pot picture exists yet, so it is drawn here.)
  void _emptyPotSlot(Canvas c, Rect art) {
    final w = art.width;
    final top = art.top + art.height * 0.35;
    final body = Path()
      ..moveTo(art.left + w * 0.18, top)
      ..lineTo(art.right - w * 0.18, top)
      ..lineTo(art.right - w * 0.28, art.bottom)
      ..lineTo(art.left + w * 0.28, art.bottom)
      ..close();
    c.drawPath(body, Paint()..color = _emptyPotBody);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          art.left + w * 0.12,
          top - 4,
          art.right - w * 0.12,
          top + 2,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = _emptyPotRim,
    );
  }

  /// [img] fitted inside [box] keeping its aspect, bottom-centred.
  static Rect _fitBottom(ui.Image img, Rect box) {
    final k = math.min(box.width / img.width, box.height / img.height);
    final w = img.width * k;
    final h = img.height * k;
    return Rect.fromLTWH(box.center.dx - w / 2, box.bottom - h, w, h);
  }

  (bool, int)? _potAt(Offset p) => potSlotAt(p, skin: _shelfSkin);

  /// "Hoa tươi mỗi sớm mai", copied exactly; the picture's board face is
  /// blank. Three short lines so the words stay as large as the small
  /// face allows.
  static const _chalk = ['Hoa tươi', 'mỗi', 'sớm mai'];

  /// Flat slate of `bang_phan.png` (160×192): middle of the frame, slightly
  /// right. Measured from the dark face, inset off the wooden rim.
  static const _chalkSrc = Rect.fromLTRB(46, 48, 126, 145);

  /// Cream chalk, the same #F8F5EA as [AppColors.bgBase].
  static const _chalkFill = AppColors.bgBase;

  TextStyle _chalkStyle(double size) =>
      AppText.make(AppFonts.display, size, 700, height: 1.0, color: _chalkFill);

  Rect _chalkFace(Rect dst) => Rect.fromLTRB(
    dst.left + _chalkSrc.left / 160 * dst.width,
    dst.top + _chalkSrc.top / 192 * dst.height,
    dst.left + _chalkSrc.right / 160 * dst.width,
    dst.top + _chalkSrc.bottom / 192 * dst.height,
  );

  /// One size for every line: the longest fills the face less 6% each side,
  /// and all lines together fill at most 90% of its height.
  double _chalkFit(Rect face) {
    const probe = 20.0;
    var widest = 0.0;
    var tall = 0.0;
    for (final s in _chalk) {
      final tp = _text(s, _chalkStyle(probe));
      widest = math.max(widest, tp.width);
      tall += tp.height;
    }
    return probe *
        math.min(face.width * 0.88 / widest, face.height * 0.9 / tall);
  }

  /// Smallest chalk size still drawn; under it the board stays blank.
  static const _chalkMinFont = 10.0;

  /// Small A-frame beside the door (Phu 26/10): only where the gap under
  /// the pot shelf is at least 72 dp (`ShelfGeometry.chalkboardRect`), with
  /// the words only when they come out [_chalkMinFont] or larger. Drawn
  /// before the queue, so customers pass in front of it.
  void _drawChalkboard(Canvas c) {
    final dst = ShelfGeometry.chalkboardRect(strip: session.hasOnlineStrip);
    if (dst == null) return;
    final art = _art(Art.scene('bang_phan'));
    if (art != null) {
      _drawArt(c, art, dst);
    } else {
      c.drawRRect(
        RRect.fromRectAndRadius(dst, const Radius.circular(4)),
        Paint()..color = AppColors.templeWood,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(dst.deflate(3), const Radius.circular(3)),
        Paint()..color = AppColors.primaryPressed,
      );
    }
    final face = _chalkFace(dst);
    final size = _chalkFit(face);
    if (size < _chalkMinFont) return;
    final lines = [for (final s in _chalk) _text(s, _chalkStyle(size))];
    final cx = face.center.dx;
    var y = face.center.dy - lines.fold(0.0, (sum, tp) => sum + tp.height) / 2;
    for (final tp in lines) {
      tp.paint(c, Offset(cx - tp.width / 2, y));
      y += tp.height;
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

  /// Soft floor contact shadow. Customer sprites are drawn without one.
  void _drawFootShadow(Canvas c, double x) {
    c.drawOval(
      Rect.fromCenter(center: Offset(x, _floorY + 2), width: 46, height: 12),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawCustomer(
    Canvas c,
    Customer cu,
    double cx, {
    double shake = 0,
    Rect? avoid,
  }) {
    final x = cx + shake;
    _drawFootShadow(c, x);
    // Regulars have round portraits only (no queue sprite yet): drawn body.
    final img = cu.avatarId.isEmpty || cu.regularId != null
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
    if (cu.regularId != null) _drawRegularBubble(c, cu, x, avoid: avoid);
  }

  /// Round 40dp portrait bubble 8dp above a regular's head (Phú).
  @visibleForTesting
  /// Shifted 8dp right only when it would touch [avoid] (the Sổ tay
  /// button over the first in the queue, Phú).
  static Rect regularBubbleRect(double x, double floorY, {Rect? avoid}) {
    final r = Rect.fromCircle(
      center: Offset(x, floorY - 76 - 8 - 20),
      radius: 20,
    );
    return avoid != null && r.overlaps(avoid) ? r.shift(const Offset(8, 0)) : r;
  }

  /// The Sổ tay button rect on the shop screen, while it shows.
  @visibleForTesting
  static Rect? notebookButtonRect(ShopSession s) => s.notebookUnlocked
      ? Rect.fromLTWH(notebookButtonLeft, notebookButtonTop(s), 44, 44)
      : null;

  /// 14dp heart at the bubble's bottom-right (Phú).
  @visibleForTesting
  static Rect regularHeartRect(Rect bubble) =>
      Rect.fromLTWH(bubble.right - 14, bubble.bottom - 14, 14, 14);

  static const _regularHeart = Color(0xFFE26D5A);

  void _drawRegularBubble(Canvas c, Customer cu, double x, {Rect? avoid}) {
    final r = regularBubbleRect(x, _floorY, avoid: avoid);
    c.drawOval(r, Paint()..color = AppColors.primarySoft);
    final img = _art('${Art.root}${cu.avatarId}${Art.ext}');
    if (img != null) {
      c.save();
      c.clipPath(Path()..addOval(r));
      _drawArt(c, img, r);
      c.restore();
    }
    c.drawOval(
      r.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primaryBase,
    );
    final h = regularHeartRect(r);
    final heart = Path()
      ..moveTo(h.center.dx, h.bottom)
      ..cubicTo(
        h.left - 2,
        h.top + h.height * 0.55,
        h.left + 1,
        h.top - 1,
        h.center.dx,
        h.top + h.height * 0.3,
      )
      ..cubicTo(
        h.right - 1,
        h.top - 1,
        h.right + 2,
        h.top + h.height * 0.55,
        h.center.dx,
        h.bottom,
      )
      ..close();
    c.drawPath(heart, Paint()..color = _regularHeart);
  }

  void _drawQueue(Canvas c) {
    final visible = session.queue.take(_maxVisible).toList();
    final warn = session.e.patienceWarningAt;
    for (var i = visible.length - 1; i >= 0; i--) {
      final cu = visible[i];
      final x = _x[cu.id] ?? 380;
      final serving = cu.autoServeLeft != null;
      final f = cu.patienceFraction;
      // Shake every 2 s when patience is low. A florist's customer stays still.
      final shake = !serving && f < warn && (_time % 2) < 0.4
          ? math.sin(_time * 40) * 2
          : 0.0;
      _drawCustomer(
        c,
        cu,
        x,
        shake: shake,
        avoid: i == 0 ? notebookButtonRect(session) : null,
      );
      if (!serving) {
        _bar(
          c,
          Rect.fromLTWH(x - 18, _floorY + 6, 36, 4),
          f,
          patienceColor(f, warn),
        );
      }
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
      // The pet on the ledge sits where the count used to be; step left.
      const spot = Offset(330, 232);
      final pet = shelfTapsOf(session).petArea;
      final at = pet != null && pet.inflate(12).contains(spot)
          ? Offset(pet.left - 16, spot.dy)
          : spot;
      _drawText(
        c,
        '+$extra',
        AppText.number(size: 16, color: AppColors.textSecondary),
        at,
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
    final key = '${cu.id}|${occ.id}|$flowerLine|$extra';
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
    late final TextPainter chip;
    late final TextPainter flower;
    late final TextPainter? extraLine;
    late final double chipW;
    late final double textW;
    late final double textH;
    if (_bubbleKey == key && _bubbleChip != null && _bubbleFlower != null) {
      chip = _bubbleChip!;
      flower = _bubbleFlower!;
      extraLine = _bubbleExtra;
      chipW = _bubbleChipW;
      textW = _bubbleTextW;
      textH = _bubbleTextH;
    } else {
      chip = TextPainter(
        text: TextSpan(text: occ.nameVi, style: chipStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      chipW = chip.width + 14;
      const maxBubble = 240.0;
      final textMax = math.max(40.0, maxBubble - 6 - chipW - 6 - 10);
      flower = TextPainter(
        text: TextSpan(text: flowerLine, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: textMax);
      final oneLine = _bubbleOneLine ??= TextPainter(
        text: TextSpan(text: 'A', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final flowerTakesTwo = flower.height > oneLine.height * 1.5;
      extraLine = flowerTakesTwo
          ? null
          : (TextPainter(
              text: TextSpan(text: extra, style: textStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              ellipsis: '…',
            )..layout(maxWidth: textMax));
      textW = math.max(flower.width, extraLine?.width ?? 0);
      textH = flower.height + (extraLine?.height ?? 0);
      _bubbleKey = key;
      _bubbleChip = chip;
      _bubbleFlower = flower;
      _bubbleExtra = extraLine;
      _bubbleChipW = chipW;
      _bubbleTextW = textW;
      _bubbleTextH = textH;
    }
    const maxBubble = 240.0;
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

  /// Florist labels sit above the counter so a foot bubble is not covered.
  void _drawStaffBubbles(Canvas c) {
    final order = _orderBubbleRect();
    for (final cu in session.queue.take(_maxVisible)) {
      if (cu.autoServeLeft == null) continue;
      final x = _x[cu.id] ?? 380;
      // The order bubble owns the head area. A florist label there covers it,
      // so it sits at the feet whenever that bubble is on screen.
      _drawStaffServe(c, cu, x, atFeet: order != null);
    }
  }

  /// Rough rect of the walk-in order bubble, while it is actually drawn.
  Rect? _orderBubbleRect() {
    final first = session.nextForPlayer;
    if (first == null || session.tableCustomer != null) return null;
    final visible = session.queue.take(_maxVisible).toList();
    final i = visible.indexOf(first);
    if (i < 0) return null;
    final x = _x[first.id];
    if (x == null) return null;
    if ((x - _slotX[i.clamp(0, 2)]).abs() >= 1) return null;
    return Rect.fromLTWH(x + 20, _bodyTop - 8, 210, 52);
  }

  /// Label on a customer the florist is wrapping, with a fill bar for the
  /// remaining auto-serve time. Drops to the feet when the head label would
  /// cover the order bubble.
  void _drawStaffServe(
    Canvas c,
    Customer cu,
    double x, {
    required bool atFeet,
  }) {
    final total = session.effects.autoServeSeconds;
    final left = cu.autoServeLeft;
    if (total == null || total <= 0 || left == null) return;
    final done = (1 - left / total).clamp(0.0, 1.0);
    final style = AppText.caption(
      size: 10,
      weight: 800,
      color: AppColors.textPrimary,
    );
    final label = _text('Nhân viên đang bó', style);
    final w = label.width + 16;
    const h = 28.0;
    var bubbleLeft = (x - w / 2).clamp(4.0, 360 - w - 4);
    // Head sits on the hair. Feet sit on the shoes, just over the counter.
    final bottom = atFeet ? _floorY + 22 : _bodyTop + 18;
    final top = bottom - h;
    // At the feet the label would run under the ledge clock; start after it.
    final clock = shelfTapsOf(session).clockArea;
    if (atFeet && clock != null && bubbleLeft < clock.right + 4) {
      bubbleLeft = math.min(clock.right + 4, 360 - w - 4);
    }
    final tx = x.clamp(bubbleLeft + 8, bubbleLeft + w - 8);
    final bubble = RRect.fromLTRBR(
      bubbleLeft,
      top,
      bubbleLeft + w,
      bottom,
      const Radius.circular(10),
    );
    c.drawRRect(bubble, Paint()..color = AppColors.surfaceCard);
    c.drawRRect(
      bubble,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBorder.thick
        ..color = AppColors.statusInfo,
    );
    final tail = atFeet
        ? (Path()
            ..moveTo(tx - 6, top + 1)
            ..lineTo(tx + 6, top + 1)
            ..lineTo(tx, top - 7)
            ..close())
        : (Path()
            ..moveTo(tx - 6, bottom - 1)
            ..lineTo(tx + 6, bottom - 1)
            ..lineTo(tx, bottom + 7)
            ..close());
    c.drawPath(tail, Paint()..color = AppColors.statusInfo);
    final tailFill = atFeet
        ? (Path()
            ..moveTo(tx - 5, top + 1)
            ..lineTo(tx + 5, top + 1)
            ..lineTo(tx, top - 5)
            ..close())
        : (Path()
            ..moveTo(tx - 5, bottom - 1)
            ..lineTo(tx + 5, bottom - 1)
            ..lineTo(tx, bottom + 5)
            ..close());
    c.drawPath(tailFill, Paint()..color = AppColors.surfaceCard);
    _drawText(
      c,
      'Nhân viên đang bó',
      style,
      Offset(bubbleLeft + w / 2, top + 10),
    );
    _bar(
      c,
      Rect.fromLTWH(bubbleLeft + 8, bottom - 8, w - 16, 4),
      done,
      AppColors.statusInfo,
    );
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
        final gian = _art(Art.nav('gian'));
        if (gian != null) {
          _drawArt(c, gian, Rect.fromLTWH(x - 2, _bodyTop - 6, 20, 20));
        } else {
          paintAngryFace(c, Offset(x + 8, _bodyTop + 4), 7);
        }
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
    if (session.screen != Screen.shop ||
        session.tableCustomer != null ||
        session.potPickerOpen ||
        session.placeModeActive) {
      return;
    }
    final p = event.localPosition.toOffset() + const Offset(0, 48);
    final slot = _potAt(p);
    if (slot != null) {
      session.openPotPicker(bar: slot.$1, index: slot.$2);
      return;
    }
    final first = session.nextForPlayer;
    final x = first == null ? null : _x[first.id];
    if (x != null &&
        (p.dx - x).abs() <= _bodyW / 2 &&
        p.dy >= _bodyTop &&
        p.dy <= _floorY + 8) {
      session.openTable();
      return;
    }
    // Pots and the customer come first; the ledge clock and pet get the rest.
    shelfTapsOf(session).tap(p);
  }

  /// Holding the pet opens its room (spec_man_hinh_chinh.md §7).
  @override
  void onLongTapDown(TapDownEvent event) {
    if (session.screen != Screen.shop ||
        session.tableCustomer != null ||
        session.potPickerOpen ||
        session.placeModeActive) {
      return;
    }
    final p = event.localPosition.toOffset() + const Offset(0, 48);
    if (_potAt(p) != null) return;
    shelfTapsOf(session).hold(p);
  }
}

/// Centred on the 360 scene, the board must end before the corner buttons
/// (Hộp thư, Phúc lợi) at x 276, or the envelope covers the name's end.
const _signMaxWidth = 184.0;

/// Rose on the left, daisy on the right, plus a little air.
const _signFlowerRoom = 44.0;

/// The shop name laid out for the board: 14px, stepping down to 9px until
/// the whole name fits between the flowers. Only a name too long even at
/// 9px gets an ellipsis.
@visibleForTesting
const shopSignTextRoom = _signMaxWidth * 0.6;

final Map<String, TextPainter> _shopSignCache = {};

/// See [shopSignTextRoom].
@visibleForTesting
TextPainter shopSignText(String name) {
  final cached = _shopSignCache[name];
  if (cached != null) return cached;
  const room = shopSignTextRoom;
  const minSize = 12.0;
  TextPainter layout(double size, {bool clip = false}) {
    return TextPainter(
      text: TextSpan(
        text: name,
        style: AppText.make(
          AppFonts.display,
          size,
          800,
          color: AppColors.primaryPressed,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: clip ? '\u2026' : null,
    )..layout(maxWidth: clip ? room : double.infinity);
  }

  TextPainter? fitted;
  for (var size = 14.0; size >= minSize; size -= 0.5) {
    final text = layout(size);
    if (text.width <= room) {
      fitted = text;
      break;
    }
  }
  fitted ??= layout(minSize, clip: true);
  if (_shopSignCache.length > 16) _shopSignCache.clear();
  return _shopSignCache[name] = fitted;
}
