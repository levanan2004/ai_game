import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'frame_metrics.dart';
import 'paint.dart';

/// White card with the chunky solid offset shadow (`shadow.card`).
class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.radius = AppRadius.lg,
    this.color = AppColors.surfaceCard,
    this.shadow = true,
    this.borderColor = AppColors.surfaceBorder,
    this.borderWidth = AppBorder.thin,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final Color color;
  final bool shadow;
  final Color borderColor;
  final double borderWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: AppColors.surfaceBorderStrong,
                  offset: Offset(0, AppSize.shadowOffset),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

OverlayEntry? _tapHintEntry;

/// Bubble above [context]'s widget saying why it cannot be used yet, with
/// the error sound. One bubble at a time, gone after about 2 s. Taps pass
/// through it.
void showTapHint(BuildContext context, String text) {
  final overlay = Overlay.maybeOf(context);
  final box = context.findRenderObject();
  final overlayBox = overlay?.context.findRenderObject();
  if (overlay == null ||
      box is! RenderBox ||
      !box.hasSize ||
      overlayBox is! RenderBox) {
    return;
  }
  SoundScope.maybeOf(context)?.effect('error');
  Rect onOverlay(RenderBox b) => MatrixUtils.transformRect(
    b.getTransformTo(overlayBox),
    Offset.zero & b.size,
  );
  final anchor = onOverlay(box);
  final frameElement = context
      .getElementForInheritedWidgetOfExactType<FrameMetrics>();
  final frameBox = frameElement?.findRenderObject();
  final bounds = frameBox is RenderBox && frameBox.hasSize
      ? onOverlay(frameBox)
      : Offset.zero & overlayBox.size;
  final scale = (frameElement?.widget as FrameMetrics?)?.scale ?? 1;
  _tapHintEntry?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TapHintBubble(
      key: UniqueKey(),
      text: text,
      anchor: anchor,
      bounds: bounds,
      scale: scale,
      onDone: () {
        if (identical(_tapHintEntry, entry)) {
          entry.remove();
          _tapHintEntry = null;
        }
      },
    ),
  );
  _tapHintEntry = entry;
  overlay.insert(entry);
}

class _TapHintBubble extends StatefulWidget {
  const _TapHintBubble({
    super.key,
    required this.text,
    required this.anchor,
    required this.bounds,
    required this.scale,
    required this.onDone,
  });

  final String text;
  final Rect anchor;

  /// The game frame on screen; the bubble stays inside it.
  final Rect bounds;
  final double scale;
  final VoidCallback onDone;

  @override
  State<_TapHintBubble> createState() => _TapHintBubbleState();
}

class _TapHintBubbleState extends State<_TapHintBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward().whenComplete(() => widget.onDone());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    return IgnorePointer(
      child: CustomSingleChildLayout(
        delegate: _TapHintLayout(widget.anchor, widget.bounds, 6 * k),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value * 2200;
            final fade = t < 150
                ? t / 150
                : (t > 1900 ? (2200 - t) / 300 : 1.0);
            return Opacity(opacity: fade.clamp(0.0, 1.0), child: child);
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 240 * k),
            child: DecoratedBox(
              key: const Key('tap-hint'),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(AppRadius.md * k),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * k,
                  vertical: 7 * k,
                ),
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: AppText.caption(
                    size: 12 * k,
                    weight: 800,
                    color: AppColors.textInverse,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centred over the anchor, above it when there is room, kept inside
/// [bounds].
class _TapHintLayout extends SingleChildLayoutDelegate {
  _TapHintLayout(this.anchor, this.bounds, this.gap);

  final Rect anchor;
  final Rect bounds;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final left = bounds.left + gap;
    final x = (anchor.center.dx - child.width / 2)
        .clamp(left, math.max(left, bounds.right - child.width - gap))
        .toDouble();
    final above = anchor.top - gap - child.height;
    final y = above >= bounds.top + gap ? above : anchor.bottom + gap;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_TapHintLayout old) =>
      old.anchor != anchor || old.bounds != bounds || old.gap != gap;
}

enum ButtonKind { primary, secondary, ghost }

/// Button with the solid offset shadow; on press it moves down 4 px and the
/// shadow disappears (`motion.pattern.buttonPress`).
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = ButtonKind.primary,
    this.radius = 16,
    this.fontSize = 17,
    this.weight = 800,
    this.enabled = true,
    this.textColor,
    this.disabledHint,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final double radius;
  final double fontSize;
  final int weight;
  final bool enabled;
  final Color? textColor;

  /// Shown by [showTapHint] when the button is tapped while disabled.
  final String? disabledHint;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  bool get _active => widget.enabled && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final (bg, shadow, fg, border) = switch (widget.kind) {
      ButtonKind.primary => (
        AppColors.primaryBase,
        AppColors.primaryPressed,
        AppColors.onPrimary,
        null,
      ),
      ButtonKind.secondary => (
        AppColors.secondaryBase,
        AppColors.secondaryPressed,
        AppColors.onSecondary,
        null,
      ),
      ButtonKind.ghost => (
        AppColors.surfaceCard,
        AppColors.surfaceBorder,
        AppColors.textPrimary,
        AppColors.surfaceBorderStrong,
      ),
    };
    final pressed = _down && _active;
    return Opacity(
      opacity: _active ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _active ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: _active
            ? (_) {
                setState(() => _down = false);
                SoundScope.maybeOf(context)?.effect('ui_tap');
                widget.onPressed?.call();
              }
            : widget.disabledHint == null
            ? null
            : (_) => showTapHint(context, widget.disabledHint!),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSize.shadowOffset),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              pressed ? AppSize.shadowOffset : 0,
              0,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.radius),
              border: border == null
                  ? null
                  : Border.all(color: border, width: 2),
              boxShadow: pressed
                  ? null
                  : [
                      BoxShadow(
                        color: shadow,
                        offset: const Offset(0, AppSize.shadowOffset),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.label,
                  style: AppText.button(
                    size: widget.fontSize,
                    weight: widget.weight,
                    color: widget.textColor ?? fg,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small outlined button (primary border, no chunky shadow).
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.height = 30,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundScope.maybeOf(context)?.effect('ui_tap');
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.primaryBase,
            width: AppBorder.thin,
          ),
        ),
        child: Text(
          label,
          style: AppText.button(
            size: fontSize,
            weight: 700,
            color: AppColors.primaryPressed,
          ),
        ),
      ),
    );
  }
}

/// Rounded pill used in the top bar. No border; fill is `header.chip`.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.headerChip,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: border == null
              ? null
              : Border.all(color: border, width: AppBorder.thin),
        ),
        child: child,
      ),
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ArtImage(
      Art.nav('xu'),
      size: size,
      fallback: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.currencyCoin,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          'đ',
          style: AppText.number(size: size * 0.6, color: AppColors.textInverse),
        ),
      ),
    );
  }
}

class StarIcon extends StatelessWidget {
  const StarIcon({
    super.key,
    required this.radius,
    this.fill = 1,
    this.color = AppColors.currencyStar,
  });

  final double radius;

  /// 0..1 part of the star that is lit (half stars on the Reviews screen).
  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    Widget image({double opacity = 1}) {
      return ArtImage(
        Art.nav('sao'),
        size: size,
        opacity: opacity,
        fallback: CustomPaint(
          size: Size.square(size),
          painter: _StarPainter(radius, 1, color),
        ),
      );
    }

    if (fill >= 1) return image();
    final shown = fill.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          image(opacity: 0.35),
          ClipRect(clipper: _HorizontalFillClipper(shown), child: image()),
        ],
      ),
    );
  }
}

class _HorizontalFillClipper extends CustomClipper<Rect> {
  _HorizontalFillClipper(this.fill);

  final double fill;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fill, size.height);

  @override
  bool shouldReclip(_HorizontalFillClipper old) => old.fill != fill;
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.r, this.fill, this.color);

  final double r;
  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = starPath(Offset(r, r), r);
    canvas.drawPath(path, Paint()..color = AppColors.freshnessTrack);
    if (fill <= 0) return;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width * fill.clamp(0, 1), size.height),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.fill != fill || old.r != r || old.color != color;
}

/// Five stars; [value] may be fractional (half stars).
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.value,
    required this.radius,
    required this.gap,
  });

  final double value;
  final double radius;

  /// Centre-to-centre distance.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: gap * 4 + radius * 2,
      height: radius * 2,
      child: Stack(
        children: [
          for (var i = 0; i < 5; i++)
            Positioned(
              left: i * gap,
              top: 0,
              child: StarIcon(
                radius: radius,
                fill: (value - i).clamp(0.0, 1.0),
              ),
            ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.avatarId,
    required this.radius,
    this.initialOnly = true,
    this.textColor = AppColors.textPrimary,
    this.fontSize,
  });

  final String name;

  /// File in assets/images/customers; '' shows the drawn placeholder.
  final String avatarId;
  final double radius;
  final bool initialOnly;
  final Color textColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholder();
    if (avatarId.isEmpty) return placeholder;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.surfaceBorderStrong,
          width: AppBorder.thin,
        ),
      ),
      child: ClipOval(
        child: ArtImage(
          Art.customer(avatarId),
          size: radius * 2,
          fallback: placeholder,
        ),
      ),
    );
  }

  Widget _placeholder() {
    final label = initialOnly
        ? (name.isEmpty ? '' : name.characters.first.toUpperCase())
        : name;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: avatarColor(name.hashCode),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.surfaceBorderStrong,
          width: AppBorder.thin,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: AppText.title(
            size: fontSize ?? radius * 0.9,
            weight: 800,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class OccasionChip extends StatelessWidget {
  const OccasionChip({
    super.key,
    required this.occasionId,
    required this.label,
    this.height = 18,
    this.fontSize = 10,
  });

  final String occasionId;
  final String label;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.occasion(occasionId);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(height / 2),
        border: bg == AppColors.occasionWedding
            ? Border.all(color: AppColors.surfaceBorder)
            : null,
      ),
      // widthFactor 1: hug the label instead of stretching in loose layouts.
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          style: AppText.caption(
            size: fontSize,
            weight: 800,
            color: AppColors.onOccasion(occasionId),
          ),
        ),
      ),
    );
  }
}

/// Thin rounded progress bar (freshness, patience, distribution).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.width,
    required this.height,
    required this.fraction,
    required this.color,
    this.track = AppColors.freshnessTrack,
  });

  final double width;
  final double height;
  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      alignment: Alignment.centerLeft,
      child: f <= 0
          ? null
          : Container(
              width: (width * f).clamp(height, width),
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
    );
  }
}

/// Pink/white awning strip under the top bar.
/// [scalloped] matches the shop scene (10 px stripes plus a rounded edge).
class AwningStrip extends StatelessWidget {
  const AwningStrip({super.key, this.height = 6, this.scalloped = false});

  final double height;
  final bool scalloped;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(360, height),
      painter: _AwningPainter(scalloped: scalloped),
    );
  }
}

class _AwningPainter extends CustomPainter {
  const _AwningPainter({required this.scalloped});

  final bool scalloped;

  @override
  void paint(Canvas canvas, Size size) {
    final pink = Paint()..color = AppColors.primaryBase;
    final white = Paint()..color = AppColors.surfaceCard;
    if (!scalloped) {
      for (var x = 0.0; x < size.width; x += 24) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 12, size.height), pink);
        canvas.drawRect(Rect.fromLTWH(x + 12, 0, 12, size.height), white);
      }
      return;
    }
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 12, 10), pink);
      canvas.drawRect(Rect.fromLTWH(x + 12, 0, 12, 10), white);
      canvas.drawArc(Rect.fromLTWH(x, 4, 12, 12), 0, math.pi, true, pink);
      canvas.drawArc(Rect.fromLTWH(x + 12, 4, 12, 12), 0, math.pi, true, white);
    }
  }

  @override
  bool shouldRepaint(_AwningPainter oldDelegate) =>
      oldDelegate.scalloped != scalloped;
}

/// Day pill name: "Ngày N", or on a holiday its short date ("14/2", "Tết").
/// The summary screen keeps the day number.
String dayName(ShopSession s) =>
    s.holidayToday?.shortLabel ?? 'Ngày ${s.state.day}';

/// Top bar: money, star rating, day + time, optional pause button.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.session,
    this.showPause = false,
    this.showRating = true,
    this.onStarTap,
    this.dayLabel,
    this.money,
  });

  final ShopSession session;
  final bool showPause;
  final bool showRating;
  final VoidCallback? onStarTap;

  /// Overrides "Ngày N · HH:MM" (e.g. "Ngày 4 · Sáng"); build it with
  /// [dayName] so holidays show their short date.
  final String? dayLabel;

  /// Overrides the money shown (market shows cash minus cart).
  final int? money;

  @override
  Widget build(BuildContext context) {
    final shownMoney = money ?? session.displayMoney;
    final dayText = dayLabel ?? '${dayName(session)} · ${session.clockText}';
    // Holiday keeps primary.pressed on the date (spec_popup_va_mo_dau §4).
    // The chip fill is header.chip on every day.
    final holiday = session.holidayToday != null;
    final dayColor = holiday ? AppColors.primaryPressed : null;
    final dayStyle = AppText.number(
      size: showPause ? 13 : 15,
      weight: 700,
      color: dayColor,
    );
    final topInset = FrameMetrics.maybeOf(context)?.topInset ?? 0;
    const bar = 56.0;
    final chipTop = 10 + topInset;
    return SizedBox(
      width: 360,
      height: bar + topInset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.headerTop, AppColors.headerBottom],
          ),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: chipTop,
              width: 108,
              child: Pill(
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    const CoinIcon(size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: shownMoney.toDouble()),
                        duration: AppMotion.celebrate,
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatK(v.round()),
                            key: const Key('topbar-money'),
                            style: AppText.number(
                              size: 16,
                              color: shownMoney < 0
                                  ? AppColors.statusDanger
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showRating)
              Positioned(
                left: 128,
                top: chipTop,
                width: 72,
                child: Pill(
                  onTap: onStarTap,
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const StarIcon(radius: 8),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatRating(session.rating.average),
                            style: AppText.number(size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            if (dayLabel != null && !showRating)
              Positioned(
                right: 12,
                top: chipTop,
                child: Pill(
                  key: const Key('topbar-day'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        dayText,
                        style: AppText.number(
                          size: 13,
                          weight: 700,
                          color: dayColor,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                left: 208,
                top: chipTop,
                width: showPause ? 96 : 140,
                child: Pill(
                  key: const Key('topbar-day'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(dayText, style: dayStyle),
                    ),
                  ),
                ),
              ),
            if (showPause)
              Positioned(
                left: 316,
                top: 8 + topInset,
                child: SettingsGear(session: session),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gear that opens Cài đặt (spec_cai_dat.md §1). Replaces the pause icon.
class SettingsGear extends StatelessWidget {
  const SettingsGear({super.key, required this.session, this.keyed = true});

  final ShopSession session;

  /// The copy drawn above the settings dim is not keyed, so the top bar
  /// keeps the single `topbar-pause` target.
  final bool keyed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: keyed ? const Key('topbar-pause') : null,
      onTap: session.togglePause,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.headerChip,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: ArtImage(Art.nav('cai_dat'), size: 22),
      ),
    );
  }
}

/// Back chevron button 36×32 (Reviews, Upgrades).
class BackButtonBox extends StatelessWidget {
  const BackButtonBox({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundScope.maybeOf(context)?.effect('ui_tap');
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: AppBorder.thin,
          ),
        ),
        child: CustomPaint(painter: _ChevronPainter()),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width / 2 + 4, size.height / 2 - 8)
      ..lineTo(size.width / 2 - 4, size.height / 2)
      ..lineTo(size.width / 2 + 4, size.height / 2 + 8);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}

/// Flower icon widget for tray cards and lists.
class FlowerIcon extends StatelessWidget {
  const FlowerIcon({
    super.key,
    required this.flowerId,
    required this.radius,
    this.opacity = 1,
  });

  final String flowerId;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ArtImage(
      Art.flower(flowerId),
      size: radius * 2.2,
      opacity: opacity,
      fallback: CustomPaint(
        size: Size.square(radius * 2.2),
        painter: _FlowerIconPainter(flowerId, radius, opacity),
      ),
    );
  }
}

class _FlowerIconPainter extends CustomPainter {
  _FlowerIconPainter(this.id, this.r, this.opacity);

  final String id;
  final double r;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    paintFlower(canvas, size.center(Offset.zero), r, id, opacity: opacity);
  }

  @override
  bool shouldRepaint(_FlowerIconPainter old) =>
      old.id != id || old.r != r || old.opacity != opacity;
}

/// Swallows taps so screens stacked on the Flame canvas don't leak input.
///
/// A [Listener] (not a [GestureDetector]) so it does not enter the gesture
/// arena and steal taps from tabs and buttons on the screen.
class OpaqueScreen extends StatelessWidget {
  const OpaqueScreen({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: color,
        child: SizedBox(width: 360, height: 640, child: child),
      ),
    );
  }
}
