import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/share_text.dart';
import '../theme/tokens.dart';
import 'art.dart';

/// Share image card (spec_khung_chia_se.md). Laid out at 360×450 (4:5) or
/// 360×640 (9:16 story): every px in the spec divided by 3, so
/// [renderSharePng] at pixel ratio 3 gives 1080×1350 / 1080×1920.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.kind,
    required this.shopName,
    required this.caption,
    required this.gameTag,
    required this.photo,
    this.story = false,
  });

  final ShareKind kind;
  final bool story;
  final String shopName;

  /// One line under the photo, drawn in “ ”.
  final String caption;

  /// chia_se.json image_text.game_tag: watermark and story header.
  final String gameTag;

  /// The bouquet or the shop scene; laid out to cover the photo box.
  final Widget photo;

  static const width = 360.0;
  static const feedHeight = 450.0;
  static const storyHeight = 640.0;

  static const dark = Color(0xFF2E5E3C);
  static const cream = Color(0xFFFFF6E3);

  double get height => story ? storyHeight : feedHeight;

  /// Spec px to logical px.
  static double px(double v) => v / 3;

  @override
  Widget build(BuildContext context) {
    // Story: everything moves down into the safe area (spec §4).
    final ribbonTop = px(story ? 270 : 78);
    final frame = story
        ? Rect.fromLTRB(px(80), px(350), px(1000), px(1210))
        : Rect.fromLTRB(px(80), px(150), px(1000), px(1000));
    final captionTop = px(story ? 1250 : 1035);
    final footTop = px(story ? 1360 : 1120);
    // Off screen there is no Material above: no yellow text underline.
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),
            if (story)
              Positioned(
                left: 0,
                right: 0,
                top: px(110),
                child: Text(
                  gameTag,
                  textAlign: TextAlign.center,
                  style: AppText.make(
                    AppFonts.display,
                    px(52),
                    800,
                    height: 1.2,
                    color: dark.withValues(alpha: 0.6),
                  ),
                ),
              ),
            Positioned.fromRect(
              rect: frame,
              child: _PhotoFrame(gameTag: gameTag, child: photo),
            ),
            Positioned(
              left: width / 2 - px(350) - px(50),
              top: ribbonTop,
              width: px(800),
              height: px(100) + px(18),
              child: _Ribbon(text: shopName),
            ),
            Positioned(
              left: px(60),
              right: px(60),
              top: captionTop,
              height: px(56),
              child: Center(
                child: _ShrinkText(
                  '“$caption”',
                  key: const Key('share-caption'),
                  style: AppText.make(
                    AppFonts.body,
                    px(40),
                    800,
                    height: 1.2,
                    color: dark,
                  ),
                  minSize: px(30),
                ),
              ),
            ),
            Positioned(
              left: px(60),
              top: footTop,
              width: px(960),
              height: px(190),
              child: const _Footer(),
            ),
            if (story)
              Positioned(
                left: 0,
                right: 0,
                top: px(1730),
                child: Text(
                  shareStoryFooter,
                  textAlign: TextAlign.center,
                  style: AppText.make(
                    AppFonts.body,
                    px(34),
                    700,
                    height: 1.2,
                    color: AppColors.textSecondary.withValues(alpha: 0.67),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bouquet photo background (spec §5 A): pink-cream gradient, white dots,
/// the bouquet centred at ~85% of the short side.
class ShareBouquetPhoto extends StatelessWidget {
  const ShareBouquetPhoto({super.key, required this.bouquet});

  final Widget bouquet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth, c.maxHeight) * 0.85;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF0E4), Color(0xFFFFDCDA)],
            ),
          ),
          child: CustomPaint(
            painter: _DotsPainter(
              seed: 3,
              count: 40,
              colors: const [Color(0x8CFFFFFF)],
              radii: const [1, 2, 2.67],
            ),
            child: Center(
              child: SizedBox.square(
                dimension: side,
                child: FittedBox(child: bouquet),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.gameTag, required this.child});

  final String gameTag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = ShareCard.px(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShareCard.px(40)),
        border: Border.all(color: ShareCard.dark, width: ShareCard.px(6)),
        boxShadow: [
          BoxShadow(
            color: ShareCard.dark.withValues(alpha: 0.27),
            offset: Offset(ShareCard.px(6), ShareCard.px(12)),
            blurRadius: ShareCard.px(10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(inset - ShareCard.px(6)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ShareCard.px(26)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned(
                right: ShareCard.px(40) - inset,
                bottom: ShareCard.px(40) - inset,
                child: _Outlined(
                  gameTag,
                  style: AppText.make(
                    AppFonts.body,
                    ShareCard.px(24),
                    700,
                    height: 1.2,
                    color: Colors.white.withValues(alpha: 0.67),
                  ),
                  stroke: ShareCard.dark.withValues(alpha: 0.47),
                  width: ShareCard.px(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shop name ribbon (spec §3.3): green rrect with V-cut tails.
class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // ~20 characters, then "…" (spec §3.3).
    final shown = text.characters.length > 20
        ? '${text.characters.take(20)}…'
        : text;
    return CustomPaint(
      painter: _RibbonPainter(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShareCard.px(50 + 24),
          0,
          ShareCard.px(50 + 24),
          ShareCard.px(18),
        ),
        child: Center(
          child: _ShrinkText(
            shown,
            key: const Key('share-shop-name'),
            style: AppText.make(
              AppFonts.display,
              ShareCard.px(56),
              800,
              height: 1.2,
              color: ShareCard.cream,
            ),
            minSize: ShareCard.px(40),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = ShareCard.px;
    final tail = p(50);
    final h = p(100);
    final cx = size.width / 2;
    final w = size.width - 2 * tail;
    final dark = Paint()..color = ShareCard.dark;
    for (final sx in const [-1.0, 1.0]) {
      final x0 = cx + sx * (w / 2 - p(20));
      final x1 = cx + sx * (w / 2 + tail);
      canvas.drawPath(
        Path()
          ..moveTo(x0, p(18))
          ..lineTo(x1, p(18))
          ..lineTo(x1 - sx * p(28), p(18) + h / 2)
          ..lineTo(x1, p(18) + h)
          ..lineTo(x0, p(18) + h)
          ..close(),
        dark,
      );
    }
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w / 2, 0, w, h),
      Radius.circular(p(18)),
    );
    canvas.drawRRect(r, Paint()..color = AppColors.primaryBase);
    canvas.drawRRect(
      r.deflate(p(3)),
      Paint()
        ..color = ShareCard.dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = p(6),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => false;
}

/// "Tải game" block (spec §3.6). No invite codes yet: the code line is
/// hidden and the two lines above move down 24 px.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final p = ShareCard.px;
    // Relative to the block's top-left (x60, y1120).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(p(30)),
        border: Border.all(color: ShareCard.dark, width: p(4)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: p(16),
            top: p(12),
            width: p(220),
            height: p(165),
            child: Image.asset(
              '${Art.root}brand/logo_0_nen${Art.ext}',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: p(250),
            top: p(22 + 24),
            child: Text(
              shareFreeAt,
              style: AppText.make(
                AppFonts.body,
                p(30),
                700,
                height: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Positioned(
            left: p(250),
            top: p(60 + 24),
            child: Text(
              shareLinkLabel,
              key: const Key('share-link'),
              style: AppText.make(
                AppFonts.display,
                p(36),
                800,
                height: 1.2,
                color: AppColors.primaryBase,
              ),
            ),
          ),
          Positioned(
            left: p(782),
            top: p(12),
            width: p(166),
            height: p(166),
            child: QrImageView(
              key: const Key('share-qr'),
              data: shareLink,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: ShareCard.dark,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: ShareCard.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = ShareCard.px;
    canvas.drawRect(Offset.zero & size, Paint()..color = ShareCard.cream);
    _DotsPainter(
      seed: 7,
      count: (size.width * size.height * 9 / 9000).round(),
      colors: const [Color(0x73F4A6C0), Color(0x73F5C451), Color(0x73DCEFD9)],
      radii: [p(4), p(6), p(8)],
    ).paint(canvas, size);
    void border(double inset, double r, double w, Color c) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(inset),
        Radius.circular(r),
      ),
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
    border(p(20), p(36), p(5), ShareCard.dark);
    border(p(34), p(28), p(2), AppColors.primaryBase);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => false;
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.seed,
    required this.count,
    required this.colors,
    required this.radii,
  });

  final int seed;
  final int count;
  final List<Color> colors;
  final List<double> radii;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final o = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      canvas.drawCircle(
        o,
        radii[rng.nextInt(radii.length)],
        Paint()..color = colors[rng.nextInt(colors.length)],
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

/// One line that shrinks from its size down to [minSize], then ends in "…".
class _ShrinkText extends StatelessWidget {
  const _ShrinkText(
    this.text, {
    super.key,
    required this.style,
    required this.minSize,
  });

  final String text;
  final TextStyle style;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        var size = style.fontSize!;
        while (size > minSize) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(fontSize: size),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          if (tp.width <= c.maxWidth) break;
          size = math.max(minSize, size - 0.5);
        }
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style.copyWith(fontSize: size),
        );
      },
    );
  }
}

class _Outlined extends StatelessWidget {
  const _Outlined(
    this.text, {
    required this.style,
    required this.stroke,
    required this.width,
  });

  final String text;
  final TextStyle style;
  final Color stroke;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            color: null,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..color = stroke,
          ),
        ),
        Text(text, style: style),
      ],
    );
  }
}

/// Lays [card] out off screen (spec §6), waits for its images and one
/// frame, and returns it as PNG bytes at 3× (1080 wide).
Future<Uint8List?> renderSharePng(
  BuildContext context,
  Widget card, {
  required Size size,
  List<String> precache = const [],
}) async {
  for (final a in precache) {
    try {
      await precacheImage(AssetImage(a), context);
    } catch (_) {}
  }
  if (!context.mounted) return null;
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -size.width - 1000,
      top: 0,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: RepaintBoundary(key: key, child: card),
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
