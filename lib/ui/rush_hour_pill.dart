import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/rush_hour_status.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'game_toast.dart';
import 'gio_cao_diem_text.dart';

/// Giờ cao điểm pill (Phú's spec 25/10): 24 tall, radius 12, 8 side
/// padding, 16 icon, 12sp bold. Rush: #E26D5A with the hour's ×weight and a
/// 300 ms bounce when it starts. Lunch: #E8F0EA / #3F7F52. The hour before a
/// rush: the rush pill at 60% with a countdown. Normal hours: hidden. The
/// sub-line only shows as a 2 s toast when a rush or the lunch lull starts.
class RushHourPill extends StatefulWidget {
  const RushHourPill({super.key, required this.session});

  final ShopSession session;

  static const peakFill = Color(0xFFE26D5A);
  static const lunchFill = Color(0xFFE8F0EA);
  static const lunchText = Color(0xFF3F7F52);

  static String _times(RushStatus r) =>
      r.kind == RushKind.peak ? '×${formatMultiplier(r.multiplier)}' : '';

  /// Text of the full pill (icon + this).
  static String fullText(RushStatus r) {
    final name = GioCaoDiemText.peakName(r.labelKey);
    final times = _times(r);
    return switch (r.kind) {
      RushKind.peak => '${GioCaoDiemText.peakCountdown(r.minutesLeft)} $times',
      RushKind.lunch => GioCaoDiemText.lunchCountdown(r.minutesLeft),
      RushKind.upcoming =>
        '${GioCaoDiemText.upcoming(name, formatClock(r.startHour, 0))}'
            ' · ${GioCaoDiemText.countdown(r.minutesLeft)}',
    };
  }

  /// Width of the full pill now (0 when hidden): 8 + icon 16 + 4 + text + 8.
  static double fullWidth(ShopSession s, TextScaler scaler) {
    final r = rushStatusOf(s);
    if (r == null) return 0;
    final tp = TextPainter(
      text: TextSpan(
        text: fullText(r),
        style: AppText.body(size: 12, weight: 700),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = tp.width + 36;
    tp.dispose();
    return w;
  }

  @override
  State<RushHourPill> createState() => _RushHourPillState();
}

class _RushHourPillState extends State<RushHourPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  RushStatus? _last;

  ShopSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _last = rushStatusOf(s);
    _morningToastDue =
        _last?.kind == RushKind.peak && s.state.elapsed < morningToastDelay
        ? _last!.startHour
        : null;
    s.addListener(_changed);
  }

  @override
  void didUpdateWidget(RushHourPill old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) {
      old.session.removeListener(_changed);
      widget.session.addListener(_changed);
      _last = rushStatusOf(s);
    }
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    _bounce.dispose();
    super.dispose();
  }

  /// The morning rush starts with the opening: its toast waits until the
  /// shop has been open [morningToastDelay] on the game clock (Phú 23:57),
  /// so no timer is left behind when the widget goes away.
  static const morningToastDelay = 1.0;

  /// Start hour of the opening rush still waiting for its toast.
  int? _morningToastDue;

  void _changed() {
    if (!mounted) return;
    final now = rushStatusOf(s);
    final was = _last;
    _last = now;
    final elapsed = s.state.elapsed;
    if (now?.kind == RushKind.peak && elapsed < morningToastDelay) {
      _morningToastDue = now!.startHour;
    } else if (now?.kind != RushKind.peak ||
        now!.startHour != _morningToastDue) {
      // Left the opening rush (or jumped past it): no late toast.
      _morningToastDue = null;
    }
    if (_morningToastDue != null && elapsed >= morningToastDelay) {
      _morningToastDue = null;
      _peakToast();
    }
    if (now == was) return;
    final started = now != null && now.kind != was?.kind;
    final toast = started && elapsed >= morningToastDelay;
    if (started && now.kind == RushKind.peak) {
      _bounce.forward(from: 0);
      if (toast) _peakToast();
    } else if (toast && now.kind == RushKind.lunch) {
      showGameToast(
        context,
        '${GioCaoDiemText.lunchLull}\n${GioCaoDiemText.lunchSub}',
      );
    }
    setState(() {});
  }

  void _peakToast() => showGameToast(
    context,
    '${GioCaoDiemText.peakLabel}\n${GioCaoDiemText.peakSub}',
  );

  @override
  Widget build(BuildContext context) {
    final r = _last;
    if (r == null) return const SizedBox.shrink(key: Key('rush-pill-none'));
    final lunch = r.kind == RushKind.lunch;
    final ink = lunch ? RushHourPill.lunchText : Colors.white;
    final times = RushHourPill._times(r);
    final full = RushHourPill.fullText(r);
    // Narrow ledge (Phú 23:57): icon + ×N, the text dropped.
    var compact = '$times${GioCaoDiemText.compactCountdown(r.minutesLeft)}';
    if (times.isEmpty) compact = compact.substring(3);
    final style = AppText.body(size: 12, weight: 700, color: ink);
    return LayoutBuilder(
      builder: (context, box) {
        final tp = TextPainter(
          text: TextSpan(text: full, style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        // 8 + icon 16 + 4 + text + 8.
        final fits = tp.width + 36 <= box.maxWidth;
        tp.dispose();
        return _pill(r, fits ? full : compact, style, compact: !fits);
      },
    );
  }

  Widget _pill(
    RushStatus r,
    String text,
    TextStyle style, {
    bool compact = false,
  }) {
    final lunch = r.kind == RushKind.lunch;
    final fill = lunch ? RushHourPill.lunchFill : RushHourPill.peakFill;
    final pill = Container(
      key: Key('rush-pill-${r.kind.name}'),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clock art, not an icon font glyph (white square, Phú 26/10).
          Image.asset(
            Art.nav('dong_ho'),
            key: const Key('rush-pill-icon'),
            width: 16,
            height: 16,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stack) =>
                const SizedBox(width: 16, height: 16),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            key: Key(compact ? 'rush-pill-compact' : 'rush-pill-text'),
            maxLines: 1,
            style: style,
          ),
        ],
      ),
    );
    return IgnorePointer(
      child: Opacity(
        opacity: r.kind == RushKind.upcoming ? 0.6 : 1,
        child: ScaleTransition(
          scale: TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 1, end: 1.1), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 1.1, end: 1), weight: 1),
          ]).animate(_bounce),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: pill,
          ),
        ),
      ),
    );
  }
}
