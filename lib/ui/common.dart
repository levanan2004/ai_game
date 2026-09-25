import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
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
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final double radius;
  final double fontSize;
  final int weight;
  final bool enabled;
  final Color? textColor;

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
                widget.onPressed?.call();
              }
            : null,
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

/// Rounded pill used in the top bar.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.surfaceCard,
    this.borderColor = AppColors.surfaceBorder,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: borderColor, width: AppBorder.thin),
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
    return Container(
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
    return CustomPaint(
      size: Size.square(radius * 2),
      painter: _StarPainter(radius, fill, color),
    );
  }
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

/// Pink/white awning strip under the top bar (bouquet table: 6 px high).
class AwningStrip extends StatelessWidget {
  const AwningStrip({super.key, this.height = 6});

  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(360, height), painter: _AwningPainter());
  }
}

class _AwningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 12, size.height),
        Paint()..color = AppColors.primaryBase,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 12, 0, 12, size.height),
        Paint()..color = AppColors.surfaceCard,
      );
    }
  }

  @override
  bool shouldRepaint(_AwningPainter oldDelegate) => false;
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
    // Holiday: the day pill itself turns pink (spec_popup_va_mo_dau §4).
    final holiday = session.holidayToday != null;
    final dayFill = holiday ? AppColors.primarySoft : AppColors.surfaceCard;
    final dayBorder = holiday ? AppColors.primaryBase : AppColors.surfaceBorder;
    final dayColor = holiday ? AppColors.primaryPressed : null;
    final dayStyle = AppText.number(
      size: showPause ? 13 : 15,
      weight: 700,
      color: dayColor,
    );
    return SizedBox(
      width: 360,
      height: AppSize.topBar,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 10,
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
              top: 10,
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
          if (dayLabel != null)
            Positioned(
              right: 12,
              top: 10,
              child: Pill(
                key: const Key('topbar-day'),
                color: dayFill,
                borderColor: dayBorder,
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
              top: 10,
              width: showPause ? 104 : 140,
              child: Pill(
                key: const Key('topbar-day'),
                color: dayFill,
                borderColor: dayBorder,
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
              left: 318,
              top: 10,
              width: 30,
              child: Pill(
                key: const Key('topbar-pause'),
                onTap: session.togglePause,
                child: Center(
                  child: CustomPaint(
                    size: const Size(12, 12),
                    painter: _PausePainter(session.paused),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PausePainter extends CustomPainter {
  _PausePainter(this.paused);

  final bool paused;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.textSecondary;
    if (paused) {
      final path = Path()
        ..moveTo(2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(2, size.height)
        ..close();
      canvas.drawPath(path, p);
    } else {
      canvas.drawRect(const Rect.fromLTWH(1, 0, 3, 12), p);
      canvas.drawRect(const Rect.fromLTWH(8, 0, 3, 12), p);
    }
  }

  @override
  bool shouldRepaint(_PausePainter old) => old.paused != paused;
}

/// Back chevron button 36×32 (Reviews, Upgrades).
class BackButtonBox extends StatelessWidget {
  const BackButtonBox({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
class OpaqueScreen extends StatelessWidget {
  const OpaqueScreen({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: color,
        child: SizedBox(width: 360, height: 640, child: child),
      ),
    );
  }
}
