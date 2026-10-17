import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/titles.dart';
import '../theme/tokens.dart';

/// Phú's title nameplates (17/10, art in assets/images/danh_hieu/): the
/// frame art with the title's name drawn by code inside its dark panel,
/// one line, 18 sp shrinking to 14 sp, gradient fill with a stroke, and the
/// effects: a diagonal shine every 3 s, 5 twinkling sparkles and a gentle
/// breathing glow ([TitleFx.full]); next to names only the shine
/// ([TitleFx.shine], 28 dp tall).
///
/// Below [refWidth] the plate is laid out at [refWidth] and scaled down as a
/// whole, so a 28 dp plate is the big one in miniature.
class TitlePlate extends StatelessWidget {
  const TitlePlate({
    super.key,
    required this.id,
    required this.name,
    this.width,
    this.height,
    this.fx = TitleFx.full,
    this.look = TitleLook.normal,
    this.burst = false,
  });

  /// The title id (de_nhat_goi_hoa, mi_luc_nhat_troi, title_khach_*).
  final String id;
  final String name;

  /// One of them sets the size (the art keeps its ratio); neither: the
  /// available width.
  final double? width;
  final double? height;
  final TitleFx fx;
  final TitleLook look;

  /// Plays one sparkle burst when built (a milestone just reached).
  final bool burst;

  /// Width the plate is laid out at when shown smaller.
  static const refWidth = 300.0;

  /// Off in tests that settle animations; reduce-motion also stops them.
  static bool motion = true;

  /// The size of [id]'s plate for [width] / [height].
  static Size sizeOf(String id, {double? width, double? height}) {
    final a = titleArtOf(id)?.aspect ?? 3.2;
    if (width != null) return Size(width, width / a);
    final h = height ?? 28;
    return Size(h * a, h);
  }

  @override
  Widget build(BuildContext context) {
    final art = titleArtOf(id);
    if (name.isEmpty) return const SizedBox.shrink();
    if (art == null) return _Pill(name: name);
    Widget sized(double w) {
      final h = w / art.aspect;
      final ref = math.max(w, refWidth);
      Widget plate = _Plate(
        art: art,
        name: name,
        fx: look == TitleLook.normal ? fx : TitleFx.none,
        burst: burst && look == TitleLook.normal,
      );
      if (look == TitleLook.locked) {
        plate = Opacity(
          opacity: 0.4,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(_grey),
            child: plate,
          ),
        );
      } else if (look == TitleLook.faded) {
        plate = Opacity(opacity: 0.7, child: plate);
      }
      return SizedBox(
        width: w,
        height: h,
        child: FittedBox(
          child: SizedBox(width: ref, height: ref / art.aspect, child: plate),
        ),
      );
    }

    if (width != null) return sized(width!);
    if (height != null) return sized(height! * art.aspect);
    return LayoutBuilder(builder: (context, c) => sized(c.maxWidth));
  }
}

/// Next to names (Phú 20:50): a compact chip, not the scaled plate. 22 dp
/// tall, radius 11, background in the title's text colours (gold or pink
/// gradient; milestones #3F7F52), name 11 sp bold, with the shine sweep.
class TitleChip extends StatefulWidget {
  const TitleChip({super.key, required this.id, required this.name});

  final String id;
  final String name;

  static const height = 22.0;

  @override
  State<TitleChip> createState() => _TitleChipState();
}

class _TitleChipState extends State<TitleChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on =
        TitlePlate.motion &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (on && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!on) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = titleArtOf(widget.id)?.scheme ?? TitleScheme.milestone;
    final milestone = identical(scheme, TitleScheme.milestone);
    final chip = Container(
      key: const Key('title-chip'),
      height: TitleChip.height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: milestone ? const Color(0xFF3F7F52) : null,
        gradient: milestone
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: scheme.fill,
              ),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _plateStyle(11).copyWith(
            height: 1.0,
            color: milestone ? scheme.fill.first : scheme.stroke,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation.weight(700)],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, child) {
        final t = _loop.isAnimating ? _loop.value : 1.0;
        if (t > _shineEnd) return child!;
        return ShaderMask(
          key: const Key('title-chip-shine'),
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => _shine(t).createShader(r),
          child: child,
        );
      },
      child: chip,
    );
  }
}

/// A cabinet / profile plate of a milestone is 360 dp wide (Phú), wider than
/// the card's padded column: it may spill into the card's side padding.
class WideTitlePlate extends StatelessWidget {
  const WideTitlePlate({super.key, required this.plate, this.width = 360});

  final TitlePlate Function(double width) plate;
  final double width;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final screen = MediaQuery.maybeSizeOf(context)?.width ?? width;
      final w = math.min(width, math.max(c.maxWidth, screen));
      final h = TitlePlate.sizeOf(plate(w).id, width: w).height;
      return SizedBox(
        width: c.maxWidth,
        height: h,
        child: OverflowBox(minWidth: w, maxWidth: w, child: plate(w)),
      );
    },
  );
}

enum TitleFx { full, shine, none }

/// normal: in colour; faded: held before (70 %, no effects); locked: never
/// held / not reached (grey 40 %, no effects).
enum TitleLook { normal, faded, locked }

/// Fill gradient (top to bottom), stroke and glow of a plate's text.
class TitleScheme {
  const TitleScheme({
    required this.fill,
    required this.stroke,
    required this.glow,
  });

  final List<Color> fill;
  final Color stroke;
  final Color glow;

  /// Phú: gold #FFF3B0 → #F2C94C → #D9902A, stroke #7A3E12.
  static const gold = TitleScheme(
    fill: [Color(0xFFFFF3B0), Color(0xFFF2C94C), Color(0xFFD9902A)],
    stroke: Color(0xFF7A3E12),
    glow: Color(0xFFF2C94C),
  );

  /// Phú: pink #FFD1E8 → #E05A9B, stroke #6B2350.
  static const pink = TitleScheme(
    fill: [Color(0xFFFFD1E8), Color(0xFFE05A9B)],
    stroke: Color(0xFF6B2350),
    glow: Color(0xFFFF8CC6),
  );

  /// Phú: milestone text #FFF8E7, stroke #2E5E3D.
  static const milestone = TitleScheme(
    fill: [Color(0xFFFFF8E7), Color(0xFFFFF8E7)],
    stroke: Color(0xFF2E5E3D),
    glow: Color(0xFFF2C94C),
  );
}

/// One plate's art: file, width/height, the dark panel the text sits in
/// (fractions of the art: left, top, right, bottom) and its colours.
class TitleArt {
  const TitleArt(this.asset, this.aspect, this.panel, this.scheme);

  final String asset;
  final double aspect;
  final Rect panel;
  final TitleScheme scheme;
}

/// The art of [id]; null for an unknown id (a plain pill then).
///
/// The panels were measured on Phú's art (the inner dark area, kept clear
/// of the bows and scissors); Phú to confirm.
TitleArt? titleArtOf(String id) => switch (id) {
  TitleIds.rating => const TitleArt(
    'assets/images/danh_hieu/de_nhat_goi_hoa.webp',
    720 / 218,
    Rect.fromLTRB(0.275, 0.33, 0.78, 0.72),
    TitleScheme.gold,
  ),
  TitleIds.charm => const TitleArt(
    'assets/images/danh_hieu/mi_luc_nhat_troi.webp',
    720 / 239,
    Rect.fromLTRB(0.225, 0.345, 0.76, 0.735),
    TitleScheme.pink,
  ),
  TitleIds.customers1k => const TitleArt(
    'assets/images/danh_hieu/danh_hieu_1k.webp',
    720 / 237,
    Rect.fromLTRB(0.32, 0.36, 0.75, 0.765),
    TitleScheme.milestone,
  ),
  TitleIds.customers10k => const TitleArt(
    'assets/images/danh_hieu/danh_hieu_10k.webp',
    720 / 257,
    Rect.fromLTRB(0.30, 0.39, 0.75, 0.78),
    TitleScheme.milestone,
  ),
  TitleIds.customers100k => const TitleArt(
    'assets/images/danh_hieu/danh_hieu_100k.webp',
    720 / 232,
    Rect.fromLTRB(0.285, 0.37, 0.75, 0.775),
    TitleScheme.milestone,
  ),
  _ => null,
};

const _grey = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Text sizes (Phú): 18 sp, shrinking to 14 sp to stay on one line.
const titleMaxSp = 18.0;
const titleMinSp = 14.0;

/// Phú 20:50: a name that does not fit at 14 sp wraps to 2 lines at 13 sp
/// (line height 1.1); never smaller.
const titleTwoLineSp = 13.0;

/// Stroke (Phú: 3 px) as seen outside the letters: the paint is centred
/// on the outline, so it is drawn twice as wide under the fill.
const titleStrokeWidth = 3.0;

TextStyle _plateStyle(double size) => TextStyle(
  fontFamily: AppFonts.display,
  fontSize: size,
  fontWeight: FontWeight.w800,
  fontVariations: const [FontVariation.weight(800)],
  height: 1.1,
  leadingDistribution: TextLeadingDistribution.even,
);

/// How [name] sits in [box] (Phú): the largest size from 18 down to 14
/// (0.5 steps) on one line; else 2 lines at 13 sp ([lines] 2). [fits] is
/// false when even 2 lines at 13 sp overflow (the text is then cut with an
/// ellipsis, never made smaller).
({double size, int lines, bool fits}) fitTitleText(
  String name,
  Size box, {
  TextScaler scaler = TextScaler.noScaling,
}) {
  for (var s = titleMaxSp; s >= titleMinSp; s -= 0.5) {
    final tp = TextPainter(
      text: TextSpan(text: name, style: _plateStyle(s)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final w = tp.width + titleStrokeWidth * 2;
    final h = tp.height + titleStrokeWidth * 2;
    tp.dispose();
    if (w <= box.width && h <= box.height) {
      return (size: s, lines: 1, fits: true);
    }
  }
  final tp = TextPainter(
    text: TextSpan(text: name, style: _plateStyle(titleTwoLineSp)),
    maxLines: 2,
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout(maxWidth: math.max(0, box.width - titleStrokeWidth * 2));
  final ok =
      !tp.didExceedMaxLines && tp.height + titleStrokeWidth * 2 <= box.height;
  tp.dispose();
  return (size: titleTwoLineSp, lines: 2, fits: ok);
}

class _Plate extends StatefulWidget {
  const _Plate({
    required this.art,
    required this.name,
    required this.fx,
    required this.burst,
  });

  final TitleArt art;
  final String name;
  final TitleFx fx;
  final bool burst;

  @override
  State<_Plate> createState() => _PlateState();
}

class _PlateState extends State<_Plate> with TickerProviderStateMixin {
  /// One 3 s cycle: the shine crosses in its first 0.9 s; sparkles and glow
  /// follow the same clock.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  /// Phú: the glow breathes every 2.4 s.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _animate(BuildContext context) =>
      TitlePlate.motion &&
      widget.fx != TitleFx.none &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Plate old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = _animate(context);
    if (on && !_loop.isAnimating) {
      _loop.repeat();
      if (widget.fx == TitleFx.full) {
        _glow.repeat();
      }
    } else if (!on && _loop.isAnimating) {
      _loop.stop();
      _glow.stop();
    }
    if (widget.burst &&
        TitlePlate.motion &&
        _burst.status == AnimationStatus.dismissed) {
      _burst.forward();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _glow.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.art;
    final fx = widget.fx;
    final moving = _animate(context);
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final p = art.panel;
        final panel = Rect.fromLTRB(
          p.left * size.width,
          p.top * size.height,
          p.right * size.width,
          p.bottom * size.height,
        );
        final body = Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                art.asset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fromRect(
              rect: panel,
              child: _PlateText(
                name: widget.name,
                scheme: art.scheme,
                box: panel.size,
              ),
            ),
          ],
        );
        return AnimatedBuilder(
          animation: Listenable.merge([_loop, _glow, _burst]),
          builder: (context, _) {
            final t = moving ? _loop.value : 0.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (fx == TitleFx.full)
                  Positioned(
                    left: size.width * 0.18,
                    right: size.width * 0.18,
                    top: size.height * 0.28,
                    bottom: size.height * 0.24,
                    child: DecoratedBox(
                      key: const Key('title-plate-glow'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size.height * 0.2),
                        boxShadow: [
                          BoxShadow(
                            // Phú: opacity 0.35 → 0.7, blur 6 dp.
                            color: art.scheme.glow.withValues(
                              alpha: moving
                                  ? 0.35 + 0.35 * _breath(_glow.value)
                                  : 0.5,
                            ),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: fx == TitleFx.none || !moving || t > _shineEnd
                      ? body
                      : ShaderMask(
                          key: const Key('title-plate-shine'),
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (r) => _shine(t).createShader(r),
                          child: body,
                        ),
                ),
                if (fx == TitleFx.full)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const Key('title-plate-sparkles'),
                        painter: _Sparkles(t: t, moving: moving),
                      ),
                    ),
                  ),
                if (_burst.isAnimating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const Key('title-plate-burst'),
                        painter: _Burst(_burst.value, art.scheme.glow),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The shine crosses during the first 30 % of the 3 s cycle.
const _shineEnd = 0.3;

LinearGradient _shine(double t) {
  final c = -0.25 + 1.5 * (t / _shineEnd);
  double s(double v) => v.clamp(0.0, 1.0);
  return LinearGradient(
    begin: const Alignment(-1, -1),
    end: const Alignment(1, 1),
    colors: [
      Colors.white.withValues(alpha: 0),
      Colors.white.withValues(alpha: 0.55),
      Colors.white.withValues(alpha: 0),
    ],
    stops: [s(c - 0.1), s(c), s(c + 0.1)],
  );
}

/// 0..1, slow in and out over the cycle.
double _breath(double t) => 0.5 - 0.5 * math.cos(2 * math.pi * t);

class _PlateText extends StatelessWidget {
  const _PlateText({
    required this.name,
    required this.scheme,
    required this.box,
  });

  final String name;
  final TitleScheme scheme;
  final Size box;

  @override
  Widget build(BuildContext context) {
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final fit = fitTitleText(name, box, scaler: scaler);
    final style = _plateStyle(fit.size);
    final lines = fit.lines;
    const align = TextAlign.center;
    final overflow = fit.fits ? TextOverflow.clip : TextOverflow.ellipsis;
    final text = Stack(
      children: [
        // The stroke under the fill (a RichText so finders see one name).
        RichText(
          maxLines: lines,
          softWrap: lines > 1,
          textAlign: align,
          overflow: overflow,
          textScaler: scaler,
          text: TextSpan(
            text: name,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = titleStrokeWidth * 2
                ..strokeJoin = StrokeJoin.round
                ..color = scheme.stroke,
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: scheme.fill,
          ).createShader(r),
          child: Text(
            name,
            key: const Key('title-plate-text'),
            maxLines: lines,
            softWrap: lines > 1,
            textAlign: align,
            overflow: overflow,
            textScaler: scaler,
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(titleStrokeWidth),
        child: text,
      ),
    );
  }
}

/// 5 four-point sparkles at fixed spots on the frame (Phú: 4–7 dp, each
/// lives 0.8 s of the 3 s cycle, on its own start).
class _Sparkles extends CustomPainter {
  _Sparkles({required this.t, required this.moving});

  final double t;
  final bool moving;

  /// x, y (fractions of the plate), start in the cycle, size in dp.
  static const spots = [
    (0.31, 0.24, 0.0, 6.0),
    (0.66, 0.20, 0.35, 4.0),
    (0.79, 0.80, 0.6, 7.0),
    (0.43, 0.84, 0.15, 5.0),
    (0.55, 0.30, 0.8, 5.5),
  ];

  /// Life of one sparkle as a part of the 3 s cycle.
  static const life = 0.8 / 3;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, start, r) in spots) {
      final age = (t - start) % 1.0;
      final a = moving
          ? (age < life ? math.sin(math.pi * age / life) : 0.0)
          : 0.6;
      if (a <= 0.02) continue;
      _star(
        canvas,
        Offset(x * size.width, y * size.height),
        r * (0.6 + 0.4 * a),
        Colors.white.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_Sparkles old) => old.t != t || old.moving != moving;
}

/// One burst of sparkles from the middle (a milestone reached).
class _Burst extends CustomPainter {
  _Burst(this.v, this.color);

  final double v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final a = (1 - v).clamp(0.0, 1.0);
    for (var i = 0; i < 12; i++) {
      final ang = 2 * math.pi * i / 12;
      final d = size.height * (0.15 + 0.75 * Curves.easeOut.transform(v));
      final p = c + Offset(math.cos(ang) * d * 1.6, math.sin(ang) * d);
      _star(
        canvas,
        p,
        size.height * 0.08 * (1 - v * 0.5),
        (i.isEven ? Colors.white : color).withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_Burst old) => old.v != v;
}

void _star(Canvas canvas, Offset c, double r, Color color) {
  final path = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Unknown title id: the name on a soft pill.
class _Pill extends StatelessWidget {
  const _Pill({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primaryBase),
    ),
    child: Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.caption(
        size: 12.5,
        color: AppColors.primaryPressed,
      ).copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

/// "Xem trước danh hiệu": the plate large with every effect (a rank-1
/// reward row's mini plate opens it).
Future<void> showTitlePreview(
  BuildContext context, {
  required String id,
  required String name,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    key: const Key('title-preview'),
    backgroundColor: AppColors.bgBase,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TitleText.rewardPreview,
            style: AppText.title(size: 17, weight: 800),
          ),
          const SizedBox(height: 10),
          TitlePlate(id: id, name: name),
          const SizedBox(height: 4),
          Text(
            TitleText.rewardTitleNote,
            style: AppText.caption(size: 12, color: AppColors.textSecondary),
          ),
          TextButton(
            key: const Key('title-preview-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _close,
              style: AppText.body(
                size: 14,
                weight: 800,
                color: AppColors.primaryPressed,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

/// profile.close (Nhất).
const _close = 'Đóng';
