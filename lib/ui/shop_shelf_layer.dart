import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import '../logic/shop_shelf.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'prices_ledge_button.dart';

/// Clock with the day/time plaque on the left end of the counter ledge and
/// the brought-along pet on the right end (spec_man_hinh_chinh.md).
///
/// Draws only; it never takes a pointer. Taps reach the Flame scene first,
/// which serves its pots and the waiting customer and hands anything left
/// on these pictures to [ShelfTaps], so the shelf cannot cover a
/// tappable spot of the scene or the buttons above it.
class ShopShelfLayer extends StatefulWidget {
  const ShopShelfLayer({super.key, required this.session});

  final ShopSession session;

  /// Spec §4 colours.
  static const wood = Color(0xFF8C6A5C);
  static const shadow = Color(0x595A3C28);

  @override
  State<ShopShelfLayer> createState() => _ShopShelfLayerState();
}

class _ShopShelfLayerState extends State<ShopShelfLayer>
    with TickerProviderStateMixin {
  late ShelfTaps _taps;
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  final _breath = Stopwatch()..start();
  String? _tip;
  Timer? _tipTimer;
  bool _heart = false;
  Timer? _heartTimer;
  final Set<String> _missing = {};

  ShopSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(ShopShelfLayer old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) {
      _detach();
      _attach();
    }
  }

  void _attach() {
    _taps = shelfTapsOf(s)
      ..onClock = _tapClock
      ..onPet = _tapPet
      ..onPetHold = _openPets;
  }

  void _detach() {
    if (_taps.onClock == _tapClock) {
      _taps
        ..onClock = null
        ..onPet = null
        ..onPetHold = null
        ..clockArea = null
        ..petArea = null;
    }
  }

  @override
  void dispose() {
    _detach();
    _tipTimer?.cancel();
    _heartTimer?.cancel();
    _bounce.dispose();
    _hop.dispose();
    super.dispose();
  }

  void _tapClock() {
    if (!mounted) return;
    s.sounds.effect('ui_tap');
    _bounce.forward(from: 0);
    _tipTimer?.cancel();
    setState(() => _tip = shelfClockTip(s));
    _tipTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _tip = null);
    });
  }

  /// First tap: hop and a heart. Another tap while the heart is up opens
  /// the pet room.
  void _tapPet() {
    if (!mounted) return;
    if (_heart) {
      _openPets();
      return;
    }
    s.sounds.effect('ui_tap');
    _hop.forward(from: 0);
    _heartTimer?.cancel();
    setState(() => _heart = true);
    _heartTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _heart = false);
    });
  }

  void _openPets() {
    if (!mounted) return;
    _heartTimer?.cancel();
    if (_heart) setState(() => _heart = false);
    if (!s.petsUnlocked) return;
    s.sounds.effect('ui_tap');
    s.openPets();
  }

  TextStyle get _dayStyle => AppText.make(
    AppFonts.display,
    10,
    700,
    height: 1,
    color: s.holidayToday != null
        ? AppColors.primaryPressed
        : AppColors.primaryBase,
  );

  TextStyle get _timeStyle => AppText.make(
    AppFonts.display,
    13,
    800,
    height: 1,
    color: shelfClosingSoon(s)
        ? AppColors.statusWarning
        : AppColors.onSecondary,
  );

  double _width(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final day = shelfDayLine(s);
    final time = shelfTimeLine(s);
    final dayStyle = _dayStyle;
    final timeStyle = _timeStyle;
    final textW = math.max(_width(day, dayStyle), _width(time, timeStyle));
    final clock = ShelfGeometry.clockRect();
    final plaque = ShelfGeometry.plaqueRect(textW.ceilToDouble());
    final group = clock.expandToInclude(plaque);
    _taps.clockArea = group;

    var pet = shelfPet(s.state);
    if (pet != null && _missing.contains(pet.asset)) pet = null;
    final petRect = pet == null ? null : ShelfGeometry.petRect(pet);
    _taps.petArea = petRect;

    // The drawing never takes a pointer; only the Giá bán button does, so it
    // sits beside the IgnorePointer, not inside it.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: _drawing(
              clock,
              plaque,
              group,
              day,
              time,
              dayStyle,
              timeStyle,
              petRect,
              pet,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: ShelfGeometry.pricesRect(
            plaque,
            iconOnly: kPricesLedgeIconOnly,
          ),
          child: PricesLedgeButton(session: s),
        ),
      ],
    );
  }

  Widget _drawing(
    Rect clock,
    Rect plaque,
    Rect group,
    String day,
    String time,
    TextStyle dayStyle,
    TextStyle timeStyle,
    Rect? petRect,
    PetArt? pet,
  ) {
    return Stack(
      key: const Key('shop-shelf'),
      clipBehavior: Clip.none,
      children: [
        _shadow(group.center.dx, 78),
        Positioned.fromRect(
          rect: plaque,
          child: _Plaque(
            day: day,
            time: time,
            dayStyle: dayStyle,
            timeStyle: timeStyle,
          ),
        ),
        Positioned.fromRect(
          rect: ShelfGeometry.clockImageBox(),
          child: ScaleTransition(
            scale: TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 1, end: 1.08), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 1.08, end: 1), weight: 1),
            ]).animate(_bounce),
            child: Image.asset(
              Art.nav('dong_ho'),
              key: const Key('shelf-clock'),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
        ),
        if (pet != null && petRect != null) ...[
          _shadow(petRect.center.dx, 39),
          Positioned.fromRect(
            rect: ShelfGeometry.petImageBox(pet),
            child: AnimatedBuilder(
              animation: _hop,
              builder: (context, child) {
                final t = _hop.value;
                final lift = _hop.isAnimating ? math.sin(t * math.pi) * 4 : 0.0;
                final phase = _breath.elapsedMilliseconds / 2400 * 2 * math.pi;
                final breathe = 1 + 0.01 * (1 - math.cos(phase));
                return Transform.translate(
                  offset: Offset(0, -lift),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(1, breathe, 1),
                    child: child,
                  ),
                );
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _petImage(pet),
              ),
            ),
          ),
          if (_heart)
            Positioned(
              left: petRect.center.dx - 7,
              top: petRect.top - 16,
              child: AnimatedBuilder(
                animation: _hop,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -10 * _hop.value),
                  child: Opacity(
                    opacity: (1 - _hop.value * 0.4).clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
                child: const Icon(
                  Icons.favorite,
                  key: Key('shelf-heart'),
                  size: 14,
                  color: AppColors.statusDanger,
                ),
              ),
            ),
        ],
        if (_tip != null)
          Positioned(
            left: 4,
            bottom: AppSize.frameHeight - clock.top + 6,
            child: _Tip(text: _tip!),
          ),
      ],
    );
  }

  Widget _petImage(PetArt pet) {
    // Expanded so the picture fills its box before and after decoding.
    return SizedBox.expand(
      key: Key('shelf-pet-${pet.asset}'),
      child: Image.asset(
        Art.pet(pet.asset),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) {
          if (!_missing.contains(pet.asset)) {
            debugPrint('shop shelf: no picture for ${pet.asset}, pet hidden');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _missing.add(pet.asset));
            });
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Spec §3: soft #5A3C28 35% ellipse, 5 tall, blur 3, centred on the
  /// ledge top.
  Widget _shadow(double cx, double width) {
    return Positioned(
      left: cx - width / 2,
      top: ShelfGeometry.ledgeTop + 0.5 - 2.5,
      width: width,
      height: 5,
      child: const CustomPaint(painter: _ShadowPainter()),
    );
  }
}

class _ShadowPainter extends CustomPainter {
  const _ShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Offset.zero & size,
      Paint()
        ..color = ShopShelfLayer.shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_ShadowPainter oldDelegate) => false;
}

/// Day/time plaque (spec §4): cream face, 1.8 wood border, radius 8, a wood
/// layer 1.5 below for the raised edge, two centred lines.
class _Plaque extends StatelessWidget {
  const _Plaque({
    required this.day,
    required this.time,
    required this.dayStyle,
    required this.timeStyle,
  });

  final String day;
  final String time;
  final TextStyle dayStyle;
  final TextStyle timeStyle;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return Stack(
      key: const Key('shelf-plaque'),
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 1.5,
          bottom: -1.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ShopShelfLayer.wood,
              borderRadius: radius,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: radius,
              border: Border.all(color: ShopShelfLayer.wood, width: 1.8),
            ),
          ),
        ),
        _line(day, dayStyle, 8.5, const Key('shelf-day')),
        _line(time, timeStyle, 19.5, const Key('shelf-time')),
      ],
    );
  }

  Widget _line(String text, TextStyle style, double centerY, Key key) {
    final size = style.fontSize ?? 10;
    return Positioned(
      left: 0,
      right: 0,
      top: centerY - size / 2,
      height: size,
      child: OverflowBox(
        maxHeight: size * 2,
        child: Text(
          text,
          key: key,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: style,
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          key: const Key('shelf-clock-tip'),
          textScaler: TextScaler.noScaling,
          style: AppText.caption(
            size: 11,
            weight: 800,
            color: AppColors.textInverse,
          ),
        ),
      ),
    );
  }
}
