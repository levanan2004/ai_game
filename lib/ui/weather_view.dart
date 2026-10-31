// Thời tiết on screen (Phú, spec_phu_and_notes.md): 24 dp pill above the
// clock, 2 s toast, overlay over the shop scene, market forecast, summary.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/weather.dart';
import '../logic/shop_session.dart';
import '../logic/weather.dart';
import '../theme/tokens.dart';
import 'game_toast.dart';

/// Phú's art (mua2_tri_an): one icon per type, petals for Gió. Swap the
/// files to change the look; names stay.
abstract final class WeatherArt {
  static const dir = 'assets/images/thoi_tiet';
  static String icon(String id) => '$dir/thoi_tiet_$id.webp';
  static const petal = '$dir/canh_hoa_bay.webp';

  /// Spec: at most 80 particles; Mưa 60 drops, Gió about 12 petals.
  static const maxParticles = 80;
  static const rainDrops = 60;
  static const petals = 12;
}

String weatherName(ShopSession s, WeatherType t) => s.weatherRules.t(t.nameKey);

/// "{tenThoiTiet}: {anhHuong}" (weather_toast).
String weatherToastText(ShopSession s) {
  final t = s.weatherToday;
  if (t == null) return '';
  return s.weatherRules.t('weather_toast', {
    'tenThoiTiet': weatherName(s, t),
    'anhHuong': s.weatherEffectToday(),
  });
}

/// The 24 dp pill: icon + name. Hidden when off or binh_thuong.
class WeatherPill extends StatelessWidget {
  const WeatherPill({super.key, required this.session, this.onTap});

  static const height = 24.0;

  final ShopSession session;

  /// Default: the 2 s toast with the factors.
  final VoidCallback? onTap;

  static bool visible(ShopSession s) {
    final t = s.weatherToday;
    return t != null && !t.isNormal;
  }

  @override
  Widget build(BuildContext context) {
    final t = session.weatherToday;
    if (t == null || t.isNormal) return const SizedBox.shrink();
    final r = session.weatherRules;
    final label = r.t('weather_pill_label', {
      'tenThoiTiet': weatherName(session, t),
    });
    return Tooltip(
      message: r.t('weather_tooltip_pill'),
      triggerMode: TooltipTriggerMode.longPress,
      child: GestureDetector(
        key: const Key('weather-pill'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => showGameToast(context, weatherToastText(session)),
        child: Container(
          height: height,
          padding: const EdgeInsets.only(left: 2, right: 8),
          decoration: BoxDecoration(
            color: AppColors.headerChip,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: AppColors.primaryBase, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                WeatherArt.icon(t.id),
                key: Key('weather-pill-icon-${t.id}'),
                width: 20,
                height: 20,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox(width: 20),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                maxLines: 1,
                style: AppText.caption(
                  size: 11,
                  weight: 800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shop-open banner (`weather_banner_<id>`), gone after `bannerAnSauGiay`.
class WeatherBanner extends StatelessWidget {
  const WeatherBanner({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final text = session.weatherBanner;
    final t = session.weatherToday;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: text == null || t == null
          ? const SizedBox.shrink()
          : Container(
              key: const Key('weather-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E3),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primaryBase, width: 1.5),
              ),
              child: Row(
                children: [
                  Image.asset(
                    WeatherArt.icon(t.id),
                    width: 24,
                    height: 24,
                    errorBuilder: (_, _, _) => const SizedBox(width: 24),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 2,
                      style: AppText.caption(
                        size: 12,
                        weight: 800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Over the shop scene, under every control, never takes a touch. Off in
/// Cài đặt (weatherFxOff) and on binh_thuong; 1 s crossfade on change.
class WeatherOverlay extends StatelessWidget {
  const WeatherOverlay({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final t = session.weatherToday;
    final kind = session.state.weatherFxOff ? null : t?.overlay;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(seconds: 1),
        child: kind == null
            ? const SizedBox.expand(key: Key('weather-overlay-none'))
            : _Particles(key: Key('weather-overlay-$kind'), kind: kind),
      ),
    );
  }
}

class _Particles extends StatefulWidget {
  const _Particles({super.key, required this.kind});

  final String kind;

  @override
  State<_Particles> createState() => _ParticlesState();
}

class _ParticlesState extends State<_Particles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == 'gio') {
      return LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            children: [
              for (var i = 0; i < WeatherArt.petals; i++)
                _petal(i, _c.value, box.biggest),
            ],
          ),
        ),
      );
    }
    return CustomPaint(
      size: Size.infinite,
      painter: _WeatherPainter(widget.kind, _c),
    );
  }

  Widget _petal(int i, double t, Size size) {
    final r = math.Random(i * 7919);
    final speed = 0.6 + r.nextDouble() * 0.8;
    final p = (t * speed + r.nextDouble()) % 1.0;
    final y0 = r.nextDouble() * size.height;
    final x = -24 + p * (size.width + 48);
    final y = y0 + math.sin(p * math.pi * 4 + i) * 18 + p * 40;
    return Positioned(
      left: x,
      top: y % size.height,
      child: Transform.rotate(
        angle: p * math.pi * 4,
        child: Opacity(
          opacity: 0.85,
          child: Image.asset(
            WeatherArt.petal,
            width: 16,
            height: 16,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.kind, this.t) : super(repaint: t);

  final String kind;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final v = t.value;
    switch (kind) {
      case 'nang':
        // #F2B544 at 8% + slow light streaks.
        canvas.drawRect(rect, Paint()..color = const Color(0x14F2B544));
        final streak = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x00FFF3C4), Color(0x33FFF3C4), Color(0x00FFF3C4)],
          ).createShader(rect);
        for (var i = 0; i < 3; i++) {
          final x = ((v + i / 3) % 1.0) * size.width * 1.4 - size.width * 0.2;
          final path = Path()
            ..moveTo(x, 0)
            ..lineTo(x + 40, 0)
            ..lineTo(x - 60, size.height)
            ..lineTo(x - 100, size.height)
            ..close();
          canvas.drawPath(path, streak);
        }
      case 'mua':
        // Scene 10% darker; 60 drops at 15°, white 40%.
        canvas.drawRect(rect, Paint()..color = const Color(0x1A000000));
        final drop = Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        final dx = math.tan(15 * math.pi / 180) * 14;
        final n = math.min(WeatherArt.rainDrops, WeatherArt.maxParticles);
        for (var i = 0; i < n; i++) {
          final r = math.Random(i * 104729);
          final x0 = r.nextDouble() * (size.width + 40);
          final sp = 6 + r.nextDouble() * 4;
          final p = (v * sp + r.nextDouble()) % 1.0;
          final y = p * (size.height + 20) - 20;
          final x = x0 - p * size.height * math.tan(15 * math.pi / 180);
          canvas.drawLine(Offset(x, y), Offset(x - dx, y + 14), drop);
        }
      case 'nom_am_u':
        // Grey fog 12%, drifting.
        canvas.drawRect(rect, Paint()..color = const Color(0x1F9AA0A6));
        final fog = Paint()
          ..color = const Color(0x1FB8BEC4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
        for (var i = 0; i < 4; i++) {
          final x = ((v + i / 4) % 1.0) * (size.width + 200) - 100;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, size.height * (0.2 + i * 0.2)),
              width: 220,
              height: 90,
            ),
            fog,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) => old.kind != kind;
}

/// Market: "Dự báo hôm nay" chip (every type, binh_thuong too, as the
/// market board), opens [showWeatherForecast].
class WeatherForecastChip extends StatelessWidget {
  const WeatherForecastChip({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final t = session.weatherToday;
    if (t == null) return const SizedBox.shrink();
    return GestureDetector(
      key: const Key('weather-forecast-chip'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showWeatherForecast(context, session),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.bgBase.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBase, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!t.isNormal) ...[
              Image.asset(
                WeatherArt.icon(t.id),
                width: 18,
                height: 18,
                errorBuilder: (_, _, _) => const SizedBox(width: 18),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              weatherName(session, t),
              style: AppText.caption(
                size: 11,
                weight: 800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sheet(
  BuildContext context, {
  required Key key,
  required String title,
  required List<Widget> body,
  String? button,
  VoidCallback? onButton,
}) {
  return Dialog(
    key: key,
    backgroundColor: const Color(0xFFFFF6E3),
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.primaryBase, width: 2),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.title(size: 18, weight: 800)),
          const SizedBox(height: 8),
          ...body,
          if (button != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                key: const Key('weather-sheet-ok'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBase,
                ),
                onPressed: onButton ?? () => Navigator.of(context).pop(),
                child: Text(button),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// weather_forecast_*: today's weather, its effects (each with its
/// tooltip), the market hint and the no-reroll note.
Future<void> showWeatherForecast(BuildContext context, ShopSession s) {
  final t = s.weatherToday;
  if (t == null) return Future.value();
  final r = s.weatherRules;
  final lines = weatherEffectLines(r, t, s.owned, s.flowerNameVi);
  return showDialog<void>(
    context: context,
    builder: (c) => _sheet(
      c,
      key: const Key('weather-forecast'),
      title: r.t('weather_forecast_title'),
      body: [
        Text(
          r.t('weather_forecast_body', {
            'tenThoiTiet': weatherName(s, t),
            'anhHuong': r.t(t.descKey),
          }),
          style: AppText.body(size: 13, weight: 700),
        ),
        const SizedBox(height: 6),
        for (final (text, tip) in lines)
          Tooltip(
            message: r.t(tip),
            triggerMode: TooltipTriggerMode.tap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• $text',
                style: AppText.body(size: 13, color: AppColors.primaryPressed),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          r.t('weather_forecast_market_hint'),
          style: AppText.caption(size: 11),
        ),
        Text(r.t('weather_tooltip_reroll'), style: AppText.caption(size: 11)),
      ],
    ),
  );
}

/// Day start (weather_day_start_*); binh_thuong has its own one-liner.
/// "Mở tiệm" runs [onOpen] (the shop's open button).
Future<void> showWeatherDayStart(
  BuildContext context,
  ShopSession s, {
  VoidCallback? onOpen,
}) async {
  final t = s.weatherToday;
  if (t == null) return;
  final r = s.weatherRules;
  final body = t.isNormal
      ? r.t('weather_day_start_binh_thuong')
      : r.t('weather_day_start_body', {
          'tenThoiTiet': weatherName(s, t),
          'anhHuong': s.weatherEffectToday(),
        });
  final open = await showDialog<bool>(
    context: context,
    builder: (c) => _sheet(
      c,
      key: const Key('weather-day-start'),
      title: r.t('weather_day_start_title'),
      button: r.t('weather_day_start_ok'),
      body: [Text(body, style: AppText.body(size: 13, weight: 700))],
      onButton: () => Navigator.of(c).pop(true),
    ),
  );
  if (open == true) onOpen?.call();
}

/// Summary: weather_summary_* lines.
class WeatherSummaryCard extends StatelessWidget {
  const WeatherSummaryCard({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final t = session.weatherToday;
    final lines = session.weatherSummary();
    if (t == null || lines.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      key: const Key('weather-summary-chip'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showDialog<void>(
        context: context,
        builder: (c) => _sheet(
          c,
          key: const Key('weather-summary'),
          title: session.weatherRules.t('weather_summary_title'),
          body: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $l', style: AppText.body(size: 13)),
              ),
          ],
        ),
      ),
      child: t.isNormal
          ? Image.asset(
              WeatherArt.icon('nang'),
              width: 28,
              height: 28,
              color: AppColors.textSecondary,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, _, _) => const SizedBox(width: 28),
            )
          : Image.asset(
              WeatherArt.icon(t.id),
              width: 28,
              height: 28,
              errorBuilder: (_, _, _) => const SizedBox(width: 28),
            ),
    );
  }
}
